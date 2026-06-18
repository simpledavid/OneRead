import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

/// Logs the health of each RSS/news source so a dead or empty feed can be
/// diagnosed from Console.app (subsystem: bundle id, category: "feed").
let feedLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OneRead", category: "feed")

@MainActor
final class ArticleStore: ObservableObject {
    @Published private(set) var articles: [Article]
    @Published private(set) var savedIDs: Set<String>
    @Published private(set) var savedWordIDs: Set<String>
    @Published private(set) var masteredWordIDs: Set<String>
    @Published private(set) var readIDs: Set<String>
    @Published private(set) var readActivityByDay: [String: Int]
    @Published private(set) var dailyRecommendationIDs: [String]
    @Published private(set) var dailyRecommendationDate: String?
    @Published private(set) var isRefreshing: Bool
    @Published private(set) var refreshErrorMessage: String?
    @Published var selectedCategory: ArticleCategory?
    @Published var selectedLibraryShelf: ArticleLibraryShelf
    @Published var searchText: String
    @Published private(set) var selectedTLDRChannel: TLDRChannel
    @Published var highlightVocabularyEnabled: Bool
    @Published var showArticleTranslationsEnabled: Bool
    @Published var hapticsEnabled: Bool
    @Published private(set) var aiProvider: AIProvider
    @Published private(set) var aiModelOverride: String
    @Published private(set) var hasAPIKey: Bool

    private let defaults: UserDefaults
    private let database: ArticleDatabase?
    private let calendar: Calendar
    private let savedKey = "savedArticleIDs"
    private let savedWordKey = "savedArticleWordIDs"
    private let masteredWordKey = "masteredArticleWordIDs"
    private let readKey = "readArticleIDs"
    private let readActivityKey = "articleReadActivityByDay"
    private let articleCacheKey = "cachedRSSArticles"
    private let dailyIDsKey = "dailyRecommendedArticleIDs"
    private let dailyDateKey = "dailyRecommendedArticleDate"
    private let selectedTLDRChannelKey = "selectedTLDRChannel"
    private let lastRSSRefreshCycleKey = "lastRSSRefreshCycleKey"
    private let dailyRecommendationVersionKey = "dailyRecommendationVersion"
    private let highlightVocabularyKey = "highlightVocabularyEnabled"
    private let showArticleTranslationsKey = "showArticleTranslationsEnabled"
    private let hapticsEnabledKey = "articleHapticsEnabled"
    private let aiProviderKey = "aiLevelProviderID"
    private let aiModelOverrideKey = "aiLevelModelOverride"
    private let currentDailyRecommendationVersion = 10
    private let dailyLimit = 2
    private let morningReleaseHour = 7
    private let afternoonReleaseHour = 16
    private let preferredHomeArticleMaxAgeDays = 3

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, database: ArticleDatabase? = nil) {
        self.defaults = defaults
        self.database = database ?? ArticleDatabase.live()
        self.calendar = calendar
        let databaseArticles = self.database?.loadArticles() ?? []
        let cachedArticles = Self.loadCachedArticles(from: defaults)
        self.articles = databaseArticles.isEmpty ? (cachedArticles.isEmpty ? SampleArticles.all : cachedArticles) : databaseArticles
        self.savedIDs = Set(defaults.stringArray(forKey: savedKey) ?? [])
        self.savedWordIDs = Set(defaults.stringArray(forKey: savedWordKey) ?? [])
        self.masteredWordIDs = Set(defaults.stringArray(forKey: masteredWordKey) ?? [])
        self.readIDs = Set(defaults.stringArray(forKey: readKey) ?? [])
        self.readActivityByDay = Self.loadIntMap(forKey: readActivityKey, from: defaults)
        self.dailyRecommendationIDs = defaults.stringArray(forKey: dailyIDsKey) ?? []
        self.dailyRecommendationDate = defaults.string(forKey: dailyDateKey)
        self.isRefreshing = false
        self.refreshErrorMessage = nil
        self.selectedCategory = nil
        self.selectedLibraryShelf = .all
        self.searchText = ""
        let channelRawValue = defaults.string(forKey: selectedTLDRChannelKey) ?? TLDRChannel.ai.rawValue
        self.selectedTLDRChannel = TLDRChannel(rawValue: channelRawValue) ?? .ai
        self.highlightVocabularyEnabled = defaults.object(forKey: highlightVocabularyKey) as? Bool ?? true
        self.showArticleTranslationsEnabled = defaults.object(forKey: showArticleTranslationsKey) as? Bool ?? false
        self.hapticsEnabled = defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
        let providerRaw = defaults.string(forKey: aiProviderKey) ?? AIProvider.bigmodel.rawValue
        let resolvedProvider = AIProvider(rawValue: providerRaw) ?? .bigmodel
        self.aiProvider = resolvedProvider
        self.aiModelOverride = defaults.string(forKey: aiModelOverrideKey) ?? ""
        self.hasAPIKey = !(KeychainStore.get("aiLevelAPIKey.\(resolvedProvider.rawValue)") ?? "").isEmpty
        self.articles = mergedArticles(self.articles + SampleArticles.all)
        self.database?.saveArticles(self.articles)
        resetStaleDailyRecommendationsIfNeeded()
        refreshDailyRecommendationsIfNeeded()
    }

    var dailyArticles: [Article] {
        let planned = dailyRecommendationIDs.compactMap { id in
            articles.first { article in
                article.id == id && isEligibleHomeArticle(article, relativeTo: Date())
            }
        }
        let fill = homeAIArticles.filter { article in
            !planned.contains { $0.id == article.id }
        }

        let slate = Array((planned + fill).prefix(dailyLimit))
        return Array(slate.prefix(releasedArticleCount(for: Date())))
    }

    private var articlesWithRealImages: [Article] {
        articles.filter { !$0.imageURLString.isEmpty }
    }

    var filteredArticles: [Article] {
        articles.filter { article in
            let matchesCategory = selectedCategory.map { $0 == article.category } ?? true
            let matchesShelf = selectedLibraryShelf.matches(article)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = query.isEmpty
                || article.title.lowercased().contains(query)
                || article.subtitle.lowercased().contains(query)
                || article.summary.lowercased().contains(query)
                || article.body.joined(separator: " ").lowercased().contains(query)
                || article.source.lowercased().contains(query)
            return matchesCategory && matchesShelf && matchesSearch
        }
    }

    var savedArticles: [Article] {
        articles.filter { savedIDs.contains($0.id) }
    }

    var savedWords: [String] {
        savedWordIDs.sorted()
    }

    var learningWords: [String] {
        savedWords.filter { !isKnownWord($0) }
    }

    var knownWords: [String] {
        savedWords.filter(isKnownWord)
    }

    var readCount: Int {
        readIDs.count
    }

    var todayReadCount: Int {
        dailyArticles.filter { readIDs.contains($0.id) }.count
    }

    var todayProgress: Double {
        guard !dailyArticles.isEmpty else { return 0 }
        return Double(todayReadCount) / Double(dailyArticles.count)
    }

    func isSaved(_ article: Article) -> Bool {
        savedIDs.contains(article.id)
    }

    func isSavedWord(_ word: String) -> Bool {
        savedWordIDs.contains(Self.wordKey(for: word))
    }

    func isKnownWord(_ word: String) -> Bool {
        masteredWordIDs.contains(Self.wordKey(for: word))
    }

    func isRead(_ article: Article) -> Bool {
        readIDs.contains(article.id)
    }

    func toggleSaved(_ article: Article) {
        if savedIDs.contains(article.id) {
            savedIDs.remove(article.id)
        } else {
            savedIDs.insert(article.id)
        }
        triggerImpact(.medium)
        persist()
    }

    func toggleSavedWord(_ word: String) {
        let key = Self.wordKey(for: word)
        guard !key.isEmpty else {
            return
        }

        if savedWordIDs.contains(key) {
            savedWordIDs.remove(key)
            masteredWordIDs.remove(key)
        } else {
            savedWordIDs.insert(key)
        }
        triggerImpact()
        persist()
    }

    func setKnownState(for word: String, isKnown: Bool) {
        let key = Self.wordKey(for: word)
        guard !key.isEmpty else {
            return
        }

        if isKnown {
            masteredWordIDs.insert(key)
            savedWordIDs.insert(key)
        } else {
            masteredWordIDs.remove(key)
        }
        triggerSelection()
        persist()
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

    // MARK: - On-device leveled article rewrites

    @Published private(set) var leveledContent: [String: [String]] = [:]
    @Published private(set) var leveledGenerating: Set<String> = []
    @Published private(set) var leveledStatus: [String: String] = [:]

    private func leveledKey(_ articleID: String, _ level: ReadingLevel) -> String {
        "\(articleID)|\(level.rawValue)"
    }

    func leveledRewrite(for article: Article, level: ReadingLevel) -> [String]? {
        leveledContent[leveledKey(article.id, level)]
    }

    func isGeneratingLevel(for article: Article, level: ReadingLevel) -> Bool {
        leveledGenerating.contains(leveledKey(article.id, level))
    }

    func leveledStatusMessage(for article: Article, level: ReadingLevel) -> String? {
        leveledStatus[leveledKey(article.id, level)]
    }

    var isOnDeviceRewriteAvailable: Bool {
        ArticleLevelService.isOnDeviceAvailable
    }

    /// The effective model name: the user override if set, otherwise the
    /// provider's sensible default.
    var effectiveAIModel: String {
        let trimmed = aiModelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? aiProvider.defaultModel : trimmed
    }

    private func apiKeyAccount(for provider: AIProvider) -> String {
        "aiLevelAPIKey.\(provider.rawValue)"
    }

    func apiKey(for provider: AIProvider) -> String {
        KeychainStore.get(apiKeyAccount(for: provider)) ?? ""
    }

    var currentAPIKey: String {
        apiKey(for: aiProvider)
    }

    func setAIProvider(_ provider: AIProvider) {
        guard provider != aiProvider else { return }
        aiProvider = provider
        aiModelOverride = ""
        defaults.set(provider.rawValue, forKey: aiProviderKey)
        defaults.set("", forKey: aiModelOverrideKey)
        hasAPIKey = !currentAPIKey.isEmpty
        clearLeveledCache()
    }

    func setAIModelOverride(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        aiModelOverride = trimmed
        defaults.set(trimmed, forKey: aiModelOverrideKey)
        clearLeveledCache()
    }

    func setAPIKey(_ key: String) {
        KeychainStore.set(key, for: apiKeyAccount(for: aiProvider))
        hasAPIKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        clearLeveledCache()
    }

    private func clearLeveledCache() {
        leveledContent.removeAll()
        leveledStatus.removeAll()
    }

    private func currentConfig() -> AILevelConfig? {
        let key = currentAPIKey
        guard !key.isEmpty else { return nil }
        return AILevelConfig(provider: aiProvider, model: effectiveAIModel, apiKey: key)
    }

    func requestLeveledContent(for article: Article, level: ReadingLevel) {
        guard level != .level3 else { return }
        let key = leveledKey(article.id, level)
        guard leveledContent[key] == nil, !leveledGenerating.contains(key) else {
            return
        }

        let config = currentConfig()
        guard config != nil || ArticleLevelService.isOnDeviceAvailable else {
            // No AI configured: the locally simplified version is still shown,
            // so we stay silent here instead of surfacing an error banner.
            return
        }

        leveledStatus[key] = nil
        leveledGenerating.insert(key)
        Task {
            let outcome = await ArticleLevelService.rewrite(article: article, level: level, config: config)
            switch outcome {
            case .success(let paragraphs):
                leveledContent[key] = paragraphs
            case .failure(let message):
                leveledStatus[key] = message
            }
            leveledGenerating.remove(key)
        }
    }

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

    func markRead(_ article: Article) {
        if !readIDs.contains(article.id) {
            recordReadActivity(on: Date())
        }
        readIDs.insert(article.id)
        persist()
    }

    func toggleRead(_ article: Article) {
        if readIDs.contains(article.id) {
            readIDs.remove(article.id)
        } else {
            readIDs.insert(article.id)
        }
        persist()
    }

    func refreshDailyRecommendationsIfNeeded() {
        let previousIDs = dailyRecommendationIDs
        let previousDate = dailyRecommendationDate
        createDailyRecommendations(force: false)

        if previousIDs != dailyRecommendationIDs || previousDate != dailyRecommendationDate {
            persist()
        }
    }

    func refreshScheduledDailyArticlesIfNeeded() async {
        let currentCycle = recommendationCycleKey(for: Date())
        let lastRefreshCycle = defaults.string(forKey: lastRSSRefreshCycleKey)
        guard lastRefreshCycle != currentCycle else {
            return
        }

        await refreshLatestRSSNews(resetToday: false)
    }

    func selectTLDRChannel(_ channel: TLDRChannel) {
        guard selectedTLDRChannel != channel else {
            return
        }
        selectedTLDRChannel = channel
        defaults.set(channel.rawValue, forKey: selectedTLDRChannelKey)
        showCachedRecommendations(for: channel)
        Task {
            await refreshLatestRSSNews(resetToday: true)
        }
    }

    func refreshTodayManually() async {
        await refreshLatestRSSNews(resetToday: true)
    }

    func refreshLibraryManually() async {
        isRefreshing = true
        refreshErrorMessage = nil
        defer {
            isRefreshing = false
        }

        let libraryArticles = await fetchAllRSSArticles()
        guard !libraryArticles.isEmpty else {
            refreshErrorMessage = "No library articles available right now. Try again later."
            return
        }

        articles = mergedArticles(libraryArticles + articles)
        persist()
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
        readActivityByDay[dayKey(for: date)] ?? 0
    }

    func homeReleaseDateText(for rank: Int) -> String {
        let cycleKey = dailyRecommendationDate ?? recommendationCycleKey(for: Date())
        guard let cycleDate = cycleDate(for: cycleKey) else {
            return rank <= 1 ? "07:00" : "16:00"
        }

        var components = calendar.dateComponents([.year, .month, .day], from: cycleDate)
        components.hour = rank <= 1 ? morningReleaseHour : afternoonReleaseHour
        components.minute = 0
        components.second = 0

        guard let scheduledDate = calendar.date(from: components) else {
            return rank <= 1 ? "07:00" : "16:00"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MM/dd HH:mm"
        return formatter.string(from: scheduledDate)
    }

    func refreshLatestRSSNews(resetToday: Bool) async {
        isRefreshing = true
        refreshErrorMessage = nil
        defer {
            isRefreshing = false
        }

        let latestArticles = await fetchLatestMixedRSSArticles()
        guard !latestArticles.isEmpty else {
            if shouldResetDailyRecommendations {
                setDailyRecommendations(from: homeAIArticles)
                refreshErrorMessage = "Couldn't find new stories right now. Showing your recent cached articles."
            }
            return
        }

        articles = mergedArticles(latestArticles + articles)
        if shouldResetDailyRecommendations || resetToday {
            setDailyRecommendations(from: latestArticles)
        }
        defaults.set(recommendationCycleKey(for: Date()), forKey: lastRSSRefreshCycleKey)
        persist()
    }

    private func fetchLatestMixedRSSArticles() async -> [Article] {
        let fetchedArticles = await fetchArticles(from: homeFeedSources())
        let sortedArticles = mergedArticles(fetchedArticles)
        let ai = sortedArticles.filter { article in
            isEligibleHomeArticle(article, relativeTo: Date())
        }
        let dailyLead = Array(ai.prefix(dailyLimit))
        let fill = ai.filter { article in
            !dailyLead.contains { $0.id == article.id }
        }
        let completeDailyLead = Array((dailyLead + fill).prefix(dailyLimit))
        let extras = ai.filter { article in
            !completeDailyLead.contains { $0.id == article.id }
        }

        return deduplicated(completeDailyLead + extras)
    }

    private func fetchArticles(from sources: [ArticleFeedSource]) async -> [Article] {
        await withTaskGroup(of: [Article].self) { group in
            for source in sources {
                group.addTask {
                    await Self.fetchArticles(from: source)
                }
            }

            var fetchedArticles: [Article] = []
            for await sourceArticles in group {
                fetchedArticles.append(contentsOf: sourceArticles)
            }

            return fetchedArticles
        }
    }

    private func fetchAllRSSArticles() async -> [Article] {
        await withTaskGroup(of: [Article].self) { group in
            let sources = libraryFeedSources()
            for source in sources {
                group.addTask {
                    await Self.fetchArticles(from: source)
                }
            }

            var fetchedArticles: [Article] = []
            for await channelArticles in group {
                fetchedArticles.append(contentsOf: channelArticles)
            }

            let perSourceLimit = 40
            return Array(mergedArticles(fetchedArticles).prefix(sources.count * perSourceLimit))
        }
    }

    private func feedSource(for channel: TLDRChannel) -> ArticleFeedSource {
        ArticleFeedSource(
            name: channel.sourceName,
            url: channel.feedURL,
            category: channel.articleCategory,
            filterKeywords: channel.filterKeywords
        )
    }

    private func homeFeedSources() -> [ArticleFeedSource] {
        [
            ArticleFeedSource(
                name: "Anthropic News",
                url: URL(string: "https://www.anthropic.com/news")!,
                category: .ai,
                itemLimit: 15
            ),
            ArticleFeedSource(
                name: "Anthropic Research",
                url: URL(string: "https://www.anthropic.com/research")!,
                category: .ai,
                itemLimit: 12
            ),
            ArticleFeedSource(
                name: "The Verge AI",
                url: URL(string: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "Ars Technica AI",
                url: URL(string: "https://arstechnica.com/ai/feed/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "TechCrunch AI",
                url: URL(string: "https://techcrunch.com/category/artificial-intelligence/feed/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "MIT Technology Review AI",
                url: URL(string: "https://www.technologyreview.com/feed/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "404 Media",
                url: URL(string: "https://www.404media.co/rss/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "Platformer",
                url: URL(string: "https://www.platformer.news/rss/")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 8
            ),
            ArticleFeedSource(
                name: "Stratechery",
                url: URL(string: "https://stratechery.com/feed/")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 8
            ),
            ArticleFeedSource(
                name: "Big Technology",
                url: URL(string: "https://www.bigtechnology.com/feed")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 8
            ),
            ArticleFeedSource(
                name: "AI News",
                url: URL(string: "https://www.artificialintelligence-news.com/feed/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "OpenAI News",
                url: URL(string: "https://openai.com/news/rss.xml")!,
                category: .ai,
                itemLimit: 8
            ),
            ArticleFeedSource(
                name: "Google DeepMind",
                url: URL(string: "https://deepmind.google/blog/rss.xml")!,
                category: .ai,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "Google AI",
                url: URL(string: "https://blog.google/technology/ai/rss/")!,
                category: .ai,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "The Decoder",
                url: URL(string: "https://the-decoder.com/feed/")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "WIRED AI",
                url: URL(string: "https://www.wired.com/feed/tag/ai/latest/rss")!,
                category: .ai
            ),
            ArticleFeedSource(
                name: "Hugging Face",
                url: URL(string: "https://huggingface.co/blog/feed.xml")!,
                category: .ai,
                itemLimit: 8
            ),
            ArticleFeedSource(
                name: "NVIDIA Blog",
                url: URL(string: "https://blogs.nvidia.com/feed/")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "Meta News AI",
                url: URL(string: "https://about.fb.com/news/feed/")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "The Verge AI Companies",
                url: URL(string: "https://www.theverge.com/rss/index.xml")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "Engadget AI Companies",
                url: URL(string: "https://www.engadget.com/rss.xml")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "Ars Technica AI Companies",
                url: URL(string: "https://feeds.arstechnica.com/arstechnica/index")!,
                category: .ai,
                filterKeywords: priorityAICompanyKeywords,
                itemLimit: 10
            ),
            ArticleFeedSource(
                name: "The Verge Tech",
                url: URL(string: "https://www.theverge.com/rss/index.xml")!,
                category: .technology,
                filterKeywords: [
                    "ai", "startup", "chip", "robot", "agent"
                ]
            ),
            ArticleFeedSource(
                name: "Engadget",
                url: URL(string: "https://www.engadget.com/rss.xml")!,
                category: .technology,
                filterKeywords: [
                    "ai", "tech", "robot", "chip", "social media"
                ]
            )
        ]
    }

    private var priorityAICompanyKeywords: [String] {
        [
            "openai", "chatgpt", "sora", "gpt-",
            "anthropic", "claude", "fable", "mythos",
            "meta ai", "meta", "llama", "facebook ai",
            "spacex", "starship", "starlink",
            "kimi", "moonshot",
            "glm", "zhipu", "bigmodel",
            "deepseek",
            "minimax",
            "qwen", "alibaba", "tongyi", "dashscope",
            "google deepmind", "deepmind", "gemini",
            "xai", "grok",
            "mistral", "perplexity", "cohere"
        ]
    }

    private func libraryFeedSources() -> [ArticleFeedSource] {
        let tldrSources = TLDRChannel.allCases.map { channel in
            feedSource(for: channel)
        }

        return homeFeedSources() + tldrSources
    }

    private func createDailyRecommendations(force: Bool) {
        let today = recommendationCycleKey(for: Date())
        guard force || dailyRecommendationDate != today || dailyRecommendationIDs.isEmpty || shouldResetDailyRecommendations else {
            return
        }

        let unread = homeAIArticles.filter { !readIDs.contains($0.id) }
        let basePool = unread.isEmpty ? homeAIArticles : unread

        dailyRecommendationIDs = diverseDailyArticles(from: basePool).map(\.id)
        dailyRecommendationDate = today
    }

    private func showCachedRecommendations(for channel: TLDRChannel) {
        let cached = articles
            .filter { article in
                article.source == channel.sourceName || article.category == channel.articleCategory
            }
            .sorted { lhs, rhs in
                (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }

        guard !cached.isEmpty else {
            dailyRecommendationIDs = []
            dailyRecommendationDate = nil
            persist()
            return
        }

        setDailyRecommendations(from: cached)
        refreshErrorMessage = nil
        persist()
    }

    private func setDailyRecommendations(from recommendedArticles: [Article]) {
        let aiRecommendations = recommendedArticles.filter { article in
            isEligibleHomeArticle(article, relativeTo: Date())
        }
        let fallback = homeAIArticles.filter { article in
            !aiRecommendations.contains { $0.id == article.id }
        }

        dailyRecommendationIDs = diverseDailyArticles(from: aiRecommendations + fallback).map(\.id)
        dailyRecommendationDate = recommendationCycleKey(for: Date())
    }

    private func diverseDailyArticles(from candidates: [Article]) -> [Article] {
        var selected: [Article] = []
        var usedKeys = Set<String>()

        for article in candidates where selected.count < dailyLimit {
            let key = diversityKey(for: article)
            guard !usedKeys.contains(key) else {
                continue
            }

            selected.append(article)
            usedKeys.insert(key)
        }

        if selected.count < dailyLimit {
            for article in candidates where selected.count < dailyLimit {
                guard !selected.contains(where: { $0.id == article.id }) else {
                    continue
                }

                selected.append(article)
            }
        }

        return Array(selected.prefix(dailyLimit))
    }

    private func diversityKey(for article: Article) -> String {
        let groups: [(String, [String])] = [
            ("openai", ["openai", "chatgpt", "sora", "gpt-"]),
            ("anthropic", ["anthropic", "claude", "fable", "mythos"]),
            ("meta", ["meta ai", "meta", "llama", "facebook ai"]),
            ("google", ["google deepmind", "deepmind", "gemini", "google"]),
            ("qwen", ["qwen", "alibaba", "tongyi", "dashscope"]),
            ("deepseek", ["deepseek"]),
            ("kimi", ["kimi", "moonshot"]),
            ("glm", ["glm", "zhipu", "bigmodel"]),
            ("minimax", ["minimax"]),
            ("xai", ["xai", "grok"]),
            ("spacex", ["spacex", "starship", "starlink"]),
            ("chips", ["nvidia", "chip", "gpu", "semiconductor", "compute"]),
            ("robotics", ["robot", "robotics", "humanoid"]),
            ("policy", ["policy", "regulation", "copyright", "lawsuit", "safety"]),
            ("agents", ["agent", "workflow", "automation"])
        ]

        for (key, keywords) in groups where article.containsAny(keywords) {
            return key
        }

        return article.source.lowercased()
    }

    private var shouldResetDailyRecommendations: Bool {
        let resolvableRecommendationCount = dailyRecommendationIDs.compactMap { id in
            articles.first { article in
                article.id == id && isEligibleHomeArticle(article, relativeTo: Date())
            }
        }.count

        return dailyRecommendationDate != recommendationCycleKey(for: Date()) || resolvableRecommendationCount < dailyLimit
    }

    private var homeAIArticles: [Article] {
        articles
            .filter { article in
                isEligibleHomeArticle(article, relativeTo: Date())
            }
            .sorted { lhs, rhs in
                (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }
    }

    private func isHomeAIArticle(_ article: Article) -> Bool {
        article.category == .ai
    }

    private func isEligibleHomeArticle(_ article: Article, relativeTo date: Date) -> Bool {
        isHomeAIArticle(article)
            && !article.imageURLString.isEmpty
            && isPreferredHomeArticleAge(article, relativeTo: date)
    }

    private func isPreferredHomeArticleAge(_ article: Article, relativeTo date: Date) -> Bool {
        guard let publishedAt = article.publishedAt,
              let cutoff = calendar.date(byAdding: .day, value: -preferredHomeArticleMaxAgeDays, to: date) else {
            return false
        }

        return publishedAt >= cutoff
    }

    private func resetStaleDailyRecommendationsIfNeeded() {
        guard defaults.integer(forKey: dailyRecommendationVersionKey) != currentDailyRecommendationVersion else {
            return
        }

        dailyRecommendationIDs = []
        dailyRecommendationDate = nil
        defaults.removeObject(forKey: lastRSSRefreshCycleKey)
        defaults.set(currentDailyRecommendationVersion, forKey: dailyRecommendationVersionKey)
    }

    private func persist() {
        defaults.set(Array(savedIDs), forKey: savedKey)
        defaults.set(Array(savedWordIDs), forKey: savedWordKey)
        defaults.set(Array(masteredWordIDs), forKey: masteredWordKey)
        defaults.set(Array(readIDs), forKey: readKey)
        defaults.set(readActivityByDay, forKey: readActivityKey)
        defaults.set(dailyRecommendationIDs, forKey: dailyIDsKey)
        defaults.set(dailyRecommendationDate, forKey: dailyDateKey)
        defaults.set(currentDailyRecommendationVersion, forKey: dailyRecommendationVersionKey)
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

    private static func loadIntMap(forKey key: String, from defaults: UserDefaults) -> [String: Int] {
        guard let raw = defaults.dictionary(forKey: key) else {
            return [:]
        }

        return raw.reduce(into: [:]) { partialResult, element in
            if let value = element.value as? Int {
                partialResult[element.key] = value
            } else if let value = element.value as? NSNumber {
                partialResult[element.key] = value.intValue
            }
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func recordReadActivity(on date: Date) {
        let key = dayKey(for: date)
        readActivityByDay[key] = min((readActivityByDay[key] ?? 0) + 1, 4)
    }

    private func cycleDate(for cycleKey: String) -> Date? {
        let parts = cycleKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func recommendationCycleKey(for date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        guard hour < morningReleaseHour,
              let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else {
            return dayKey(for: date)
        }

        return dayKey(for: previousDay)
    }

    private func releasedArticleCount(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        if hour < morningReleaseHour {
            return dailyLimit
        }

        if hour < afternoonReleaseHour {
            return 1
        }

        return dailyLimit
    }

    private static func wordKey(for word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

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

    /// Total network attempts per feed download = `feedFetchRetries` + 1.
    private static let feedFetchRetries = 1

    private nonisolated static func fetchArticles(from source: ArticleFeedSource) async -> [Article] {
        if source.url.host == "www.anthropic.com",
           source.url.path == "/news" || source.url.path == "/research" {
            let articles = await fetchAnthropicArticles(from: source)
            let usable = articles.filter { !$0.imageURLString.isEmpty }
            if usable.isEmpty {
                feedLogger.warning("Feed \"\(source.name, privacy: .public)\" returned no usable articles (Anthropic scrape).")
            }
            return usable
        }

        guard let data = await loadFeedData(from: source) else {
            return []
        }

        let parser = ArticleRSSParser(source: source)
        let parsedArticles = Array(parser.parse(data: data)
            .filter { matchesSourceFilter($0, source: source) }
            .prefix(source.itemLimit))

        if parsedArticles.isEmpty {
            feedLogger.warning("Feed \"\(source.name, privacy: .public)\" parsed 0 items from \(data.count) bytes.")
            return []
        }

        let enrichedArticles = await enrichArticles(for: parsedArticles)
        let usable = enrichedArticles.filter { !$0.imageURLString.isEmpty }
        if usable.isEmpty {
            feedLogger.notice("Feed \"\(source.name, privacy: .public)\": \(parsedArticles.count) parsed but none kept an image after enrichment.")
        }
        return usable
    }

    /// Downloads a feed body with a short retry on transient (network / 5xx)
    /// failures, logging each problem so an individual dead source is visible.
    private nonisolated static func loadFeedData(from source: ArticleFeedSource) async -> Data? {
        var request = URLRequest(url: source.url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml,application/atom+xml,application/xml,text/xml,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let maxAttempts = feedFetchRetries + 1
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    feedLogger.warning("Feed \"\(source.name, privacy: .public)\" HTTP \(http.statusCode) (attempt \(attempt)/\(maxAttempts)).")
                    if http.statusCode >= 500, attempt < maxAttempts {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        continue
                    }
                    return nil
                }
                return data
            } catch {
                feedLogger.warning("Feed \"\(source.name, privacy: .public)\" network error (attempt \(attempt)/\(maxAttempts)): \(error.localizedDescription, privacy: .public)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    continue
                }
                return nil
            }
        }

        return nil
    }

    /// Articles with fewer than this many body words are treated as "summary only"
    /// and we attempt to pull the full text from the original page.
    private static let minimumBodyWordCount = 70

    private nonisolated static func enrichArticles(for articles: [Article]) async -> [Article] {
        await withTaskGroup(of: (Int, Article).self) { group in
            for (index, article) in articles.enumerated() {
                group.addTask {
                    let needsImage = article.imageURLString.isEmpty
                    let needsBody = bodyWordCount(article.body) < minimumBodyWordCount

                    guard needsImage || needsBody, let url = article.url,
                          let html = await fetchHTML(from: url) else {
                        return (index, article)
                    }

                    var updated = article

                    if needsImage, let imageURL = firstImageURL(in: html, baseURL: url) {
                        updated = updated.withImageURL(imageURL.absoluteString)
                    }

                    if needsBody {
                        let paragraphs = extractArticleParagraphs(from: html)
                        if bodyWordCount(paragraphs) > bodyWordCount(article.body) {
                            updated = updated.withBody(paragraphs)
                        }
                    }

                    return (index, updated)
                }
            }

            var enriched: [(Int, Article)] = []
            for await result in group {
                enriched.append(result)
            }

            return enriched
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    /// Caps how many article pages we scrape concurrently. Enrichment runs across
    /// every feed at once, so without this a single refresh could fan out into
    /// hundreds of simultaneous HTTP requests.
    private static let htmlConcurrencyLimiter = AsyncConcurrencyLimiter(limit: 6)

    private nonisolated static func fetchHTML(from url: URL) async -> String? {
        await htmlConcurrencyLimiter.acquire()
        let html = await loadHTML(from: url)
        await htmlConcurrencyLimiter.release()
        return html
    }

    private nonisolated static func loadHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        } catch {
            return nil
        }
    }

    private nonisolated static func fetchAnthropicArticles(from source: ArticleFeedSource) async -> [Article] {
        guard let html = await fetchHTML(from: source.url) else {
            return []
        }

        let section = source.url.path == "/research" ? "research" : "news"
        let slugs = extractAnthropicSlugs(from: html, section: section)
        guard !slugs.isEmpty else {
            return []
        }

        let limitedSlugs = Array(slugs.prefix(source.itemLimit))

        return await withTaskGroup(of: (Int, Article?).self) { group in
            for (index, slug) in limitedSlugs.enumerated() {
                group.addTask {
                    let article = await fetchAnthropicArticle(
                        slug: slug,
                        section: section,
                        sourceName: source.name,
                        category: source.category
                    )
                    return (index, article)
                }
            }

            var indexed: [(Int, Article)] = []
            for await result in group {
                if let article = result.1 {
                    indexed.append((result.0, article))
                }
            }

            return indexed
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    private nonisolated static func extractAnthropicSlugs(from html: String, section: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"href="/\(section)/([a-z0-9-]+)""#,
            options: []
        ) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var slugs: [String] = []
        var seen = Set<String>()

        for match in regex.matches(in: html, options: [], range: range) {
            guard match.numberOfRanges > 1,
                  let slugRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let slug = String(html[slugRange])
            guard !seen.contains(slug) else {
                continue
            }

            seen.insert(slug)
            slugs.append(slug)
        }

        return slugs
    }

    private nonisolated static func fetchAnthropicArticle(
        slug: String,
        section: String,
        sourceName: String,
        category: ArticleCategory
    ) async -> Article? {
        guard let url = URL(string: "https://www.anthropic.com/\(section)/\(slug)"),
              let html = await fetchHTML(from: url) else {
            return nil
        }

        let title = metaContent(in: html, property: "og:title")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        let summary = metaContent(in: html, property: "og:description")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL = metaContent(in: html, property: "og:image")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = extractAnthropicBody(from: html)
        guard !body.isEmpty else {
            return nil
        }

        let publishedAt = parseAnthropicDate(from: html)
        let subtitle = summary.isEmpty ? "From \(sourceName)" : summary
        let wordCount = bodyWordCount(body)
        let readingMinutes = max(2, min(12, Int(ceil(Double(wordCount) / 75.0))))
        let keyPoints = anthropicKeyPoints(from: body)

        return Article(
            id: url.absoluteString,
            title: title,
            subtitle: subtitle,
            source: sourceName,
            author: "Anthropic",
            category: category,
            readingMinutes: readingMinutes,
            publishNote: relativeAnthropicDateText(publishedAt),
            summary: subtitle,
            keyPoints: keyPoints,
            body: body,
            paragraphTranslations: [],
            vocabulary: [],
            urlString: url.absoluteString,
            imageURLString: imageURL,
            publishedAt: publishedAt
        )
    }

    private nonisolated static func metaContent(in html: String, property: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            #"<meta[^>]+property=["']\#(escaped)["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']\#(escaped)["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            return decodedHTMLAttribute(String(html[valueRange]))
        }

        return ""
    }

    private nonisolated static func parseAnthropicDate(from html: String) -> Date? {
        if let regex = try? NSRegularExpression(
            pattern: #"<div class="body-3 agate">([^<]+)</div>"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               match.numberOfRanges > 1,
               let valueRange = Range(match.range(at: 1), in: html) {
                let raw = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let date = parseAnthropicDateString(raw) {
                    return date
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"\b(20\d{2}-\d{2}-\d{2})\b"#) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               match.numberOfRanges > 1,
               let valueRange = Range(match.range(at: 1), in: html) {
                let raw = String(html[valueRange])
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: raw) {
                    return date
                }
            }
        }

        return nil
    }

    private nonisolated static func parseAnthropicDateString(_ raw: String) -> Date? {
        let formats = ["MMM d, yyyy", "MMMM d, yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    private nonisolated static func relativeAnthropicDateText(_ date: Date?) -> String {
        guard let date else {
            return "Latest"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private nonisolated static func extractAnthropicBody(from html: String) -> [String] {
        let scope: String
        if let range = html.range(of: #"<article[^>]*>[\s\S]*?</article>"#, options: [.regularExpression, .caseInsensitive]) {
            scope = String(html[range])
        } else {
            scope = html
        }

        guard let regex = try? NSRegularExpression(pattern: #"<p[^>]*>([\s\S]*?)</p>"#, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(scope.startIndex..<scope.endIndex, in: scope)
        var paragraphs: [String] = []
        var totalWords = 0

        for match in regex.matches(in: scope, options: [], range: range) {
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: scope) else {
                continue
            }

            let text = cleanedHTMLText(String(scope[valueRange]))
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            guard words >= 8 else {
                continue
            }

            paragraphs.append(text)
            totalWords += words

            if totalWords >= 2500 || paragraphs.count >= 30 {
                break
            }
        }

        return paragraphs
    }

    private nonisolated static func anthropicKeyPoints(from body: [String]) -> [String] {
        let sentences = body
            .joined(separator: " ")
            .replacingOccurrences(of: ". ", with: ".\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(sentences.prefix(2))
    }

    private nonisolated static func bodyWordCount(_ paragraphs: [String]) -> Int {
        paragraphs
            .joined(separator: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .count
    }

    /// Extracts the main readable paragraphs from an article page so summary-only
    /// RSS items can show real content instead of a single sentence.
    private nonisolated static func extractArticleParagraphs(from html: String) -> [String] {
        let scope: String
        if let range = html.range(of: #"<article[^>]*>[\s\S]*?</article>"#, options: [.regularExpression, .caseInsensitive]) {
            scope = String(html[range])
        } else {
            scope = html
        }

        guard let regex = try? NSRegularExpression(pattern: #"<p[^>]*>([\s\S]*?)</p>"#, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(scope.startIndex..<scope.endIndex, in: scope)
        var paragraphs: [String] = []
        var totalWords = 0

        for match in regex.matches(in: scope, options: [], range: range) {
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: scope) else {
                continue
            }

            let text = cleanedHTMLText(String(scope[valueRange]))
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            guard words >= 12 else {
                continue
            }

            paragraphs.append(text)
            totalWords += words

            if totalWords >= 520 || paragraphs.count >= 9 {
                break
            }
        }

        return paragraphs
    }

    private nonisolated static func cleanedHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&mdash;", with: "-")
            .replacingOccurrences(of: "&ndash;", with: "-")
            .htmlDecoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func firstImageURL(in html: String, baseURL: URL) -> URL? {
        let patterns = [
            #"<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image(?::secure_url)?["']"#,
            #"<meta[^>]+name=["']twitter:image(?::src)?["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image(?::src)?["']"#,
            #"<img[^>]+src=["']([^"']+)["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let rawValue = decodedHTMLAttribute(String(html[valueRange]))
            guard let imageURL = normalizedImageURL(rawValue, baseURL: baseURL) else {
                continue
            }

            return imageURL
        }

        return nil
    }

    private nonisolated static func normalizedImageURL(_ value: String, baseURL: URL) -> URL? {
        guard !value.isEmpty,
              !value.hasPrefix("data:"),
              !value.lowercased().hasSuffix(".svg") else {
            return nil
        }

        if value.hasPrefix("//") {
            return URL(string: "https:\(value)")
        }

        if let absoluteURL = URL(string: value), absoluteURL.scheme?.hasPrefix("http") == true {
            return absoluteURL
        }

        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private nonisolated static func decodedHTMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .htmlDecoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func matchesSourceFilter(_ article: Article, source: ArticleFeedSource) -> Bool {
        guard !source.filterKeywords.isEmpty else {
            return true
        }

        let text = "\(article.title) \(article.subtitle) \(article.summary) \(article.category.title)".lowercased()
        return source.filterKeywords.contains { text.contains($0) }
    }
}

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
            publishedAt: publishedAt
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
            publishedAt: publishedAt
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
            publishedAt: publishedAt
        )
    }

    func containsAny(_ keywords: [String]) -> Bool {
        let haystack = "\(title) \(subtitle) \(summary) \(body.joined(separator: " ")) \(source) \(author)"
            .lowercased()
        return keywords.contains { haystack.contains($0.lowercased()) }
    }
}

