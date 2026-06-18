import Foundation
import os
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Logs the health of each RSS/news source so a dead or empty feed can be
/// diagnosed from Console.app (subsystem: bundle id, category: "feed").
let feedLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OneRead", category: "feed")

@MainActor
final class ArticleStore: ObservableObject {
    // MARK: - Services

    let progress: ReadingProgressService
    let vocabulary: VocabularyService
    let aiRewrite: AIRewriteService

    // MARK: - Published state

    @Published private(set) var articles: [Article]
    @Published private(set) var isRefreshing: Bool
    @Published private(set) var refreshErrorMessage: String?
    @Published private(set) var contentSourceLabel: String
    @Published private(set) var selectedTLDRChannel: TLDRChannel
    @Published var highlightVocabularyEnabled: Bool
    @Published var showArticleTranslationsEnabled: Bool
    @Published var hapticsEnabled: Bool
    @Published private(set) var dailyEditionArticleIDs: [String]
    @Published private(set) var dailyEditionDate: String?

    // MARK: - Private state

    private let defaults: UserDefaults
    private let database: ArticleDatabase?
    private let calendar: Calendar
    private let dailySchedule: DailyEditionSchedule
    private let feedConfiguration: FeedConfiguration
    private var cancellables = Set<AnyCancellable>()

    private let contentSourceLabelKey = "dailyContentSourceLabel"
    private let articleCacheKey = "cachedRSSArticles"
    private let dailyIDsKey = "dailyRecommendedArticleIDs"
    private let dailyDateKey = "dailyRecommendedArticleDate"
    private let selectedTLDRChannelKey = "selectedTLDRChannel"
    private let lastRSSRefreshCycleKey = "lastRSSRefreshCycleKey"
    // Keep the legacy storage key so existing installs retain their current edition.
    private let dailyEditionVersionKey = "dailyRecommendationVersion"
    private let highlightVocabularyKey = "highlightVocabularyEnabled"
    private let showArticleTranslationsKey = "showArticleTranslationsEnabled"
    private let hapticsEnabledKey = "articleHapticsEnabled"
    private let currentDailyEditionVersion = 12
    private let dailyLimit = 2
    private let dailyGoal = 1

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, database: ArticleDatabase? = nil) {
        self.defaults = defaults
        self.calendar = calendar
        self.database = database ?? ArticleDatabase.live()
        self.progress = ReadingProgressService(defaults: defaults)
        self.vocabulary = VocabularyService(defaults: defaults)
        self.aiRewrite = AIRewriteService(defaults: defaults)
        self.dailySchedule = DailyEditionSchedule(
            calendar: calendar,
            dailyLimit: dailyLimit,
            dailyGoal: dailyGoal
        )
        self.feedConfiguration = FeedConfiguration.bundled

        let databaseArticles = self.database?.loadArticles() ?? []
        let cachedArticles = Self.loadCachedArticles(from: defaults)
        self.articles = databaseArticles.isEmpty ? (cachedArticles.isEmpty ? SampleArticles.all : cachedArticles) : databaseArticles

        self.isRefreshing = false
        self.refreshErrorMessage = nil
        self.contentSourceLabel = defaults.string(forKey: contentSourceLabelKey) ?? "Editorial edition"
        let channelRawValue = defaults.string(forKey: selectedTLDRChannelKey) ?? TLDRChannel.ai.rawValue
        self.selectedTLDRChannel = TLDRChannel(rawValue: channelRawValue) ?? .ai
        self.highlightVocabularyEnabled = defaults.object(forKey: highlightVocabularyKey) as? Bool ?? true
        self.showArticleTranslationsEnabled = defaults.object(forKey: showArticleTranslationsKey) as? Bool ?? false
        self.hapticsEnabled = defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
        self.dailyEditionArticleIDs = defaults.stringArray(forKey: dailyIDsKey) ?? []
        self.dailyEditionDate = defaults.string(forKey: dailyDateKey)
        self.articles = mergedArticles(self.articles + SampleArticles.all)

        // Forward service updates so views observing the store refresh.
        progress.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        vocabulary.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        aiRewrite.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        resetStaleDailyEditionIfNeeded()
        refreshDailyEditionIfNeeded()
    }

    // MARK: - Article collections

    var dailyArticles: [Article] {
        let now = Date()
        let planned = dailyEditionArticleIDs.compactMap { id in
            articles.first { article in
                article.id == id && dailySchedule.isEligibleHomeArticle(article, relativeTo: now)
            }
        }
        let fill = homeAIArticles.filter { article in
            !planned.contains { $0.id == article.id }
        }

        let slate = Array((planned + fill).prefix(dailyLimit))
        return Array(slate.prefix(dailySchedule.releasedArticleCount(for: now)))
    }

    var savedArticles: [Article] {
        articles.filter { progress.isSaved($0) }
    }

    var savedWords: [String] {
        vocabulary.savedWords
    }

    var learningWords: [String] {
        vocabulary.learningWords
    }

    var knownWords: [String] {
        vocabulary.knownWords
    }

    var readCount: Int {
        progress.readCount
    }

    var completedCount: Int {
        progress.completedCount
    }

    var todayReadCount: Int {
        dailyArticles.filter { progress.isRead($0) }.count
    }

    var todayCompletedCount: Int {
        let completed = progress.completedIDs(for: dailySchedule.currentCycleKey)
        return dailyArticles.filter { completed.contains($0.id) }.count
    }

    var todayProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayCompletedCount), Double(dailyGoal)) / Double(dailyGoal)
    }

    /// Reads required to finish the day. Two stories are still shown; the second
    /// is optional extra reading.
    var dailyGoalTarget: Int {
        dailyGoal
    }

    var todayGoalProgressCount: Int {
        min(todayCompletedCount, dailyGoal)
    }

    var isTodayComplete: Bool {
        dailySchedule.isTodayComplete(
            dailyIDs: dailyEditionArticleIDs,
            completedIDs: progress.completedIDs(for: dailySchedule.currentCycleKey)
        )
    }

    var currentStreak: Int {
        dailySchedule.currentStreak { cycleKey in
            progress.completedIDs(for: cycleKey).count >= dailyGoal
        }
    }

    var activeDaysLast7: Int {
        dailySchedule.activeDaysLast7 { date in
            !(progress.completedArticleIDsByDay[dailySchedule.dayKey(for: date)] ?? []).isEmpty
        }
    }

    // MARK: - State queries

    func isSaved(_ article: Article) -> Bool {
        progress.isSaved(article)
    }

    func isSavedWord(_ word: String) -> Bool {
        vocabulary.isSavedWord(word)
    }

    func isKnownWord(_ word: String) -> Bool {
        vocabulary.isKnownWord(word)
    }

    func isRead(_ article: Article) -> Bool {
        progress.isRead(article)
    }

    func isCompleted(_ article: Article) -> Bool {
        progress.isCompleted(article, cycleKey: dailySchedule.currentCycleKey)
    }

    // MARK: - User actions

    func toggleSaved(_ article: Article) {
        progress.toggleSaved(article)
        triggerImpact(.medium)
    }

    func toggleSavedWord(_ word: String) {
        vocabulary.toggleSavedWord(word)
        triggerImpact()
    }

    func setKnownState(for word: String, isKnown: Bool) {
        vocabulary.setKnownState(for: word, isKnown: isKnown)
        triggerSelection()
    }

    func setHighlightVocabularyEnabled(_ enabled: Bool) {
        highlightVocabularyEnabled = enabled
        persist()
    }

    func setShowArticleTranslationsEnabled(_ enabled: Bool) {
        showArticleTranslationsEnabled = enabled
        persist()
    }

    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        persist()
    }

    // MARK: - AI rewrite forwarding

    var isOnDeviceRewriteAvailable: Bool {
        aiRewrite.isOnDeviceRewriteAvailable
    }

    var effectiveAIModel: String {
        aiRewrite.effectiveModel
    }

    var aiProvider: AIProvider {
        aiRewrite.provider
    }

    var aiModelOverride: String {
        aiRewrite.modelOverride
    }

    var hasAPIKey: Bool {
        aiRewrite.hasAPIKey
    }

    var currentAPIKey: String {
        aiRewrite.currentAPIKey
    }

    func leveledRewrite(for article: Article, level: ReadingLevel) -> [String]? {
        aiRewrite.leveledRewrite(for: article, level: level)
    }

    func isGeneratingLevel(for article: Article, level: ReadingLevel) -> Bool {
        aiRewrite.isGeneratingLevel(for: article, level: level)
    }

    func leveledStatusMessage(for article: Article, level: ReadingLevel) -> String? {
        aiRewrite.leveledStatusMessage(for: article, level: level)
    }

    func setAIProvider(_ provider: AIProvider) {
        aiRewrite.setProvider(provider)
    }

    func setAIModelOverride(_ model: String) {
        aiRewrite.setModelOverride(model)
    }

    func setAPIKey(_ key: String) {
        aiRewrite.setAPIKey(key)
    }

    func requestLeveledContent(for article: Article, level: ReadingLevel) {
        aiRewrite.requestLeveledContent(for: article, level: level)
    }

    // MARK: - Haptics

#if canImport(UIKit)
    func triggerImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func triggerSelection() {
        guard hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
#else
    func triggerImpact(_ style: Int = 0) {}
    func triggerSelection() {}
#endif

    // MARK: - Reading progress

    func markRead(_ article: Article) {
        let wasUnread = progress.markRead(article)
        if wasUnread {
            RetentionAnalytics.record("article_open", articleID: article.id)
        }
    }

    func trackReadingLevel(_ level: ReadingLevel, for article: Article) {
        RetentionAnalytics.record(
            "reading_level_view",
            articleID: article.id,
            level: level.rawValue
        )
    }

    func completeArticle(_ article: Article) {
        guard progress.completeArticle(article, cycleKey: dailySchedule.currentCycleKey, dailyLimit: dailyLimit) else {
            return
        }

        RetentionAnalytics.record(
            "article_complete",
            articleID: article.id,
            metadata: [
                "edition_date": article.editionDate ?? dailySchedule.currentCycleKey,
                "slot": article.editionSlot?.rawValue ?? "unknown"
            ]
        )
        if isTodayComplete {
            RetentionAnalytics.record(
                "daily_complete",
                metadata: ["edition_date": dailySchedule.currentCycleKey]
            )
        }
        triggerImpact(.medium)
    }

    func toggleRead(_ article: Article) {
        progress.toggleRead(article)
    }

    // MARK: - Daily edition

    func refreshDailyEditionIfNeeded() {
        let previousIDs = dailyEditionArticleIDs
        let previousDate = dailyEditionDate
        createFallbackEdition(force: false)

        if previousIDs != dailyEditionArticleIDs || previousDate != dailyEditionDate {
            persist()
        }
    }

    func refreshScheduledDailyArticlesIfNeeded() async {
        let currentCycle = dailySchedule.cycleKey(for: Date())
        let lastRefreshCycle = defaults.string(forKey: lastRSSRefreshCycleKey)
        guard lastRefreshCycle != currentCycle else {
            return
        }

        await refreshPreGeneratedEdition()
    }

    func selectTLDRChannel(_ channel: TLDRChannel) {
        guard selectedTLDRChannel != channel else {
            return
        }
        selectedTLDRChannel = channel
        defaults.set(channel.rawValue, forKey: selectedTLDRChannelKey)
        showCachedEdition(for: channel)
        Task {
            await refreshLatestRSSNews(resetToday: true)
        }
    }

    func refreshTodayManually() async {
        await refreshPreGeneratedEdition()
    }

    var learningLanguageLabel: String {
        "Chinese (Simplified)"
    }

    var estimatedReadingLevelTitle: String {
        let score = learningWords.count + knownWords.count * 2 + readCount
        switch score {
        case ..<8:
            return "Level 1"
        case 8..<20:
            return "Level 2"
        default:
            return "Level 3"
        }
    }

    func readingActivityValue(on date: Date) -> Int {
        progress.readActivityByDay[dailySchedule.dayKey(for: date)] ?? 0
    }

    func homeReleaseDateText(for rank: Int) -> String {
        dailySchedule.homeReleaseDateText(for: rank, cycleKey: dailyEditionDate)
    }

    // MARK: - Private helpers

    private var homeAIArticles: [Article] {
        let now = Date()
        let eligibleArticles = articles.filter { article in
            dailySchedule.isEligibleHomeArticle(article, relativeTo: now)
        }
        return ArticleCurationService.rankLocally(eligibleArticles, relativeTo: now)
    }

    private func refreshPreGeneratedEdition() async {
        isRefreshing = true
        refreshErrorMessage = nil
        defer {
            isRefreshing = false
        }

        let cycle = dailySchedule.currentCycleKey
        let result = await DailyContentService.fetchEdition(for: cycle)
        let orderedArticles = result.edition.articles.sorted { lhs, rhs in
            editionOrder(lhs.editionSlot) < editionOrder(rhs.editionSlot)
        }

        guard orderedArticles.count == dailyLimit else {
            refreshErrorMessage = "Today's editorial edition is not ready yet."
            return
        }

        articles = mergedArticles(orderedArticles + articles)
        dailyEditionArticleIDs = orderedArticles.map(\.id)
        dailyEditionDate = cycle
        contentSourceLabel = result.isBundledFallback ? "Preview edition" : "Editorial edition"
        defaults.set(cycle, forKey: lastRSSRefreshCycleKey)
        RetentionAnalytics.record(
            "edition_load",
            metadata: [
                "edition_date": cycle,
                "source": result.isBundledFallback ? "bundled" : "remote"
            ]
        )
        persist()
    }

    private func editionOrder(_ slot: ArticleEditionSlot?) -> Int {
        switch slot {
        case .morning:
            return 0
        case .afternoon:
            return 1
        case nil:
            return 2
        }
    }

    private func refreshLatestRSSNews(resetToday: Bool) async {
        isRefreshing = true
        refreshErrorMessage = nil
        let currentCycle = dailySchedule.cycleKey(for: Date())
        let isFirstRefreshForCycle = defaults.string(forKey: lastRSSRefreshCycleKey) != currentCycle
        defer {
            isRefreshing = false
        }

        let latestArticles = await fetchLatestMixedRSSArticles()
        guard !latestArticles.isEmpty else {
            if shouldResetFallbackEdition {
                setFallbackEdition(from: homeAIArticles)
                refreshErrorMessage = "Couldn't find new stories right now. Showing your recent cached articles."
            }
            return
        }

        articles = mergedArticles(latestArticles + articles)
        if shouldResetFallbackEdition || resetToday || isFirstRefreshForCycle {
            setFallbackEdition(from: latestArticles)
        }
        defaults.set(currentCycle, forKey: lastRSSRefreshCycleKey)
        persist()
    }

    private func fetchLatestMixedRSSArticles() async -> [Article] {
        let now = Date()
        let fetchedArticles = await FeedService.fetchArticles(from: feedConfiguration.homeSources)
        let sortedArticles = mergedArticles(fetchedArticles)
        let ai = sortedArticles.filter { article in
            dailySchedule.isEligibleHomeArticle(article, relativeTo: now)
        }

        return await ArticleCurationService.rank(
            ai,
            config: aiRewrite.currentConfig,
            relativeTo: now
        )
    }

    private func createFallbackEdition(force: Bool) {
        let today = dailySchedule.cycleKey(for: Date())
        guard force || dailyEditionDate != today || dailyEditionArticleIDs.isEmpty || shouldResetFallbackEdition else {
            return
        }

        dailyEditionArticleIDs = Array(homeAIArticles.prefix(dailyLimit)).map(\.id)
        dailyEditionDate = today
    }

    private func showCachedEdition(for channel: TLDRChannel) {
        let cached = articles
            .filter { article in
                article.source == channel.sourceName || article.category == channel.articleCategory
            }
            .sorted { lhs, rhs in
                (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }

        guard !cached.isEmpty else {
            dailyEditionArticleIDs = []
            dailyEditionDate = nil
            persist()
            return
        }

        setFallbackEdition(from: cached)
        refreshErrorMessage = nil
        persist()
    }

    private func setFallbackEdition(from candidates: [Article]) {
        let now = Date()
        let eligibleCandidates = candidates.filter { article in
            dailySchedule.isEligibleHomeArticle(article, relativeTo: now)
        }
        let fallback = homeAIArticles.filter { article in
            !eligibleCandidates.contains { $0.id == article.id }
        }

        dailyEditionArticleIDs = Array((eligibleCandidates + fallback).prefix(dailyLimit)).map(\.id)
        dailyEditionDate = dailySchedule.cycleKey(for: Date())
    }

    private var shouldResetFallbackEdition: Bool {
        let resolvableArticleCount = dailyEditionArticleIDs.compactMap { id in
            articles.first { article in
                article.id == id && dailySchedule.isEligibleHomeArticle(article, relativeTo: Date())
            }
        }.count

        return dailyEditionDate != dailySchedule.cycleKey(for: Date()) || resolvableArticleCount < dailyLimit
    }

    private func resetStaleDailyEditionIfNeeded() {
        let previousVersion = defaults.integer(forKey: dailyEditionVersionKey)
        guard previousVersion != currentDailyEditionVersion else {
            return
        }

        dailyEditionArticleIDs = []
        dailyEditionDate = nil
        defaults.removeObject(forKey: lastRSSRefreshCycleKey)
        defaults.set(currentDailyEditionVersion, forKey: dailyEditionVersionKey)
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(contentSourceLabel, forKey: contentSourceLabelKey)
        defaults.set(dailyEditionArticleIDs, forKey: dailyIDsKey)
        defaults.set(dailyEditionDate, forKey: dailyDateKey)
        defaults.set(currentDailyEditionVersion, forKey: dailyEditionVersionKey)
        defaults.set(highlightVocabularyEnabled, forKey: highlightVocabularyKey)
        defaults.set(showArticleTranslationsEnabled, forKey: showArticleTranslationsKey)
        defaults.set(hapticsEnabled, forKey: hapticsEnabledKey)
        persistArticles()
    }

    private func persistArticles() {
        let cachedArticles = Array(articles.prefix(80))
        guard let data = try? JSONEncoder().encode(cachedArticles) else {
            return
        }

        database?.saveArticles(articles)
        defaults.set(data, forKey: articleCacheKey)
    }

    private static func loadCachedArticles(from defaults: UserDefaults) -> [Article] {
        guard let data = defaults.data(forKey: "cachedRSSArticles"),
              let articles = try? JSONDecoder().decode([Article].self, from: data) else {
            return []
        }

        return articles.filter { !$0.imageURLString.isEmpty }
    }

    // MARK: - Article utilities

    private func deduplicated(_ articles: [Article]) -> [Article] {
        var seen: Set<String> = []
        var unique: [Article] = []

        for article in articles {
            let key = article.urlString.isEmpty ? article.title.lowercased() : article.urlString
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(article)
            }
        }

        return unique
    }

    private func mergedArticles(_ articles: [Article]) -> [Article] {
        deduplicated(articles.map { $0.normalizedTextContent() })
            .sorted { lhs, rhs in
                (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }
    }
}

// MARK: - Article helpers

extension Article {
    func normalizedTextContent() -> Article {
        Article(
            id: id.htmlDecoded,
            title: title.htmlDecoded,
            subtitle: subtitle.htmlDecoded,
            source: source.htmlDecoded,
            author: author.htmlDecoded,
            category: category,
            readingMinutes: readingMinutes,
            publishNote: publishNote.htmlDecoded,
            summary: summary.htmlDecoded,
            keyPoints: keyPoints.map(\.htmlDecoded),
            body: body.map(\.htmlDecoded),
            paragraphTranslations: paragraphTranslations.map(\.htmlDecoded),
            vocabulary: vocabulary,
            urlString: urlString,
            imageURLString: imageURLString,
            publishedAt: publishedAt,
            editionDate: editionDate,
            editionSlot: editionSlot,
            curationStatus: curationStatus,
            learningContent: learningContent
        )
    }

    func withImageURL(_ imageURLString: String) -> Article {
        Article(
            id: id,
            title: title,
            subtitle: subtitle,
            source: source,
            author: author,
            category: category,
            readingMinutes: readingMinutes,
            publishNote: publishNote,
            summary: summary,
            keyPoints: keyPoints,
            body: body,
            paragraphTranslations: paragraphTranslations,
            vocabulary: vocabulary,
            urlString: urlString,
            imageURLString: imageURLString,
            publishedAt: publishedAt,
            editionDate: editionDate,
            editionSlot: editionSlot,
            curationStatus: curationStatus,
            learningContent: learningContent
        )
    }

    func withBody(_ body: [String], keyPoints: [String]? = nil) -> Article {
        Article(
            id: id,
            title: title,
            subtitle: subtitle,
            source: source,
            author: author,
            category: category,
            readingMinutes: readingMinutes,
            publishNote: publishNote,
            summary: summary,
            keyPoints: keyPoints ?? self.keyPoints,
            body: body,
            paragraphTranslations: paragraphTranslations,
            vocabulary: vocabulary,
            urlString: urlString,
            imageURLString: imageURLString,
            publishedAt: publishedAt,
            editionDate: editionDate,
            editionSlot: editionSlot,
            curationStatus: curationStatus,
            learningContent: learningContent
        )
    }

    func withEdition(
        date: String,
        slot: ArticleEditionSlot,
        status: ArticleCurationStatus,
        learningContent: ArticleLearningContent
    ) -> Article {
        Article(
            id: id,
            title: title,
            subtitle: subtitle,
            source: source,
            author: author,
            category: category,
            readingMinutes: readingMinutes,
            publishNote: publishNote,
            summary: summary,
            keyPoints: keyPoints,
            body: body,
            paragraphTranslations: paragraphTranslations,
            vocabulary: learningContent.vocabulary,
            urlString: urlString,
            imageURLString: imageURLString,
            publishedAt: publishedAt,
            editionDate: date,
            editionSlot: slot,
            curationStatus: status,
            learningContent: learningContent
        )
    }

    func containsAny(_ keywords: [String]) -> Bool {
        let haystack = "\(title) \(subtitle) \(summary) \(body.joined(separator: " ")) \(source) \(author)"
            .lowercased()
        return keywords.contains { haystack.contains($0.lowercased()) }
    }
}
