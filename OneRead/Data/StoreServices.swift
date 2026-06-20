import Combine
import Foundation

@MainActor
final class ReadingProgressService: ObservableObject {
    @Published private(set) var savedArticleIDs: Set<String>
    @Published private(set) var readArticleIDs: Set<String>
    @Published private(set) var completedArticleIDsByDay: [String: [String]]
    @Published private(set) var readActivityByDay: [String: Int]
    @Published private(set) var openedDays: Set<String>

    private let defaults: UserDefaults
    private let savedKey = "savedArticleIDs"
    private let readKey = "readArticleIDs"
    private let completedKey = "completedArticleIDsByDay"
    private let activityKey = "readActivityByDay"
    private let openedKey = "openedDays"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.savedArticleIDs = Set(defaults.stringArray(forKey: savedKey) ?? [])
        self.readArticleIDs = Set(defaults.stringArray(forKey: readKey) ?? [])
        self.completedArticleIDsByDay = Self.decode([String: [String]].self, from: defaults.data(forKey: completedKey)) ?? [:]
        self.readActivityByDay = Self.decode([String: Int].self, from: defaults.data(forKey: activityKey)) ?? [:]
        self.openedDays = Set(defaults.stringArray(forKey: openedKey) ?? [])
    }

    /// Mark today as "app opened" (GitHub-style: light green even with no reading).
    func recordOpen() {
        let key = Self.dayKey(for: Date())
        guard !openedDays.contains(key) else { return }
        openedDays.insert(key)
        persist()
    }

    var readCount: Int { readArticleIDs.count }

    var completedCount: Int {
        Set(completedArticleIDsByDay.values.flatMap { $0 }).count
    }

    func isSaved(_ article: Article) -> Bool {
        savedArticleIDs.contains(article.id)
    }

    func isRead(_ article: Article) -> Bool {
        readArticleIDs.contains(article.id)
    }

    func isCompleted(_ article: Article, cycleKey: String) -> Bool {
        completedIDs(for: cycleKey).contains(article.id)
    }

    func completedIDs(for cycleKey: String) -> Set<String> {
        Set(completedArticleIDsByDay[cycleKey] ?? [])
    }

    func toggleSaved(_ article: Article) {
        if !savedArticleIDs.insert(article.id).inserted {
            savedArticleIDs.remove(article.id)
        }
        persist()
    }

    @discardableResult
    func markRead(_ article: Article) -> Bool {
        let wasInserted = readArticleIDs.insert(article.id).inserted
        guard wasInserted else { return false }

        let dayKey = Self.dayKey(for: Date())
        readActivityByDay[dayKey, default: 0] += 1
        persist()
        return true
    }

    func toggleRead(_ article: Article) {
        if readArticleIDs.contains(article.id) {
            readArticleIDs.remove(article.id)
        } else {
            _ = markRead(article)
            return
        }
        persist()
    }

    @discardableResult
    func completeArticle(_ article: Article, cycleKey: String, dailyLimit: Int) -> Bool {
        var completed = completedArticleIDsByDay[cycleKey] ?? []
        guard !completed.contains(article.id), completed.count < dailyLimit else {
            return false
        }

        completed.append(article.id)
        completedArticleIDsByDay[cycleKey] = completed
        _ = markRead(article)
        persist()
        return true
    }

    private func persist() {
        defaults.set(Array(savedArticleIDs), forKey: savedKey)
        defaults.set(Array(readArticleIDs), forKey: readKey)
        defaults.set(try? JSONEncoder().encode(completedArticleIDsByDay), forKey: completedKey)
        defaults.set(try? JSONEncoder().encode(readActivityByDay), forKey: activityKey)
        defaults.set(Array(openedDays), forKey: openedKey)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func dayKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

struct SavedVocabularyEntry: Codable, Hashable, Identifiable {
    var id: String { word.lowercased() }
    let word: String
    let meaningZh: String
    let phonetic: String
    let example: String
    let exampleZh: String
    let context: String

    init(
        word: String,
        meaningZh: String = "",
        phonetic: String = "",
        example: String = "",
        exampleZh: String = "",
        context: String = ""
    ) {
        self.word = word
        self.meaningZh = meaningZh
        self.phonetic = phonetic
        self.example = example
        self.exampleZh = exampleZh
        self.context = context
    }
}

@MainActor
final class VocabularyService: ObservableObject {
    @Published private(set) var savedEntries: [SavedVocabularyEntry]
    @Published private(set) var knownWords: [String]

    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore
    private let savedKey = "savedVocabularyWords"
    private let savedEntriesKey = "savedVocabularyEntriesV2"
    private let knownKey = "knownVocabularyWords"

    init(defaults: UserDefaults, cloud: NSUbiquitousKeyValueStore = .default) {
        self.defaults = defaults
        self.cloud = cloud

        // Prefer the iCloud copy; fall back to the local copy (offline / first run).
        let localSaved = defaults.stringArray(forKey: savedKey) ?? []
        let localEntries = Self.decodeEntries(defaults.data(forKey: savedEntriesKey))
        let remoteEntries = Self.decodeEntries(cloud.data(forKey: savedEntriesKey))
        let localKnown = defaults.stringArray(forKey: knownKey) ?? []
        let legacySaved = (cloud.array(forKey: savedKey) as? [String]) ?? localSaved
        self.savedEntries = remoteEntries
            ?? localEntries
            ?? legacySaved.map { SavedVocabularyEntry(word: $0) }
        self.knownWords = (cloud.array(forKey: knownKey) as? [String]) ?? localKnown

        // First run after enabling iCloud: seed the cloud from existing local data.
        if cloud.data(forKey: savedEntriesKey) == nil, !savedEntries.isEmpty {
            cloud.set(try? JSONEncoder().encode(savedEntries), forKey: savedEntriesKey)
        }
        if cloud.array(forKey: knownKey) == nil, !localKnown.isEmpty {
            cloud.set(localKnown, forKey: knownKey)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Another device changed the vocabulary; adopt the cloud values.
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        Task { @MainActor in
            if let remoteEntries = Self.decodeEntries(cloud.data(forKey: savedEntriesKey)) {
                savedEntries = remoteEntries
                defaults.set(try? JSONEncoder().encode(remoteEntries), forKey: savedEntriesKey)
            }
            if let remoteKnown = cloud.array(forKey: knownKey) as? [String] {
                knownWords = remoteKnown
                defaults.set(remoteKnown, forKey: knownKey)
            }
        }
    }

    var savedWords: [String] {
        savedEntries.map(\.word)
    }

    var learningWords: [String] {
        savedWords.filter { !isKnownWord($0) }
    }

    func isSavedWord(_ word: String) -> Bool {
        savedEntries.contains { $0.word.caseInsensitiveCompare(word) == .orderedSame }
    }

    func savedEntry(for word: String) -> SavedVocabularyEntry? {
        savedEntries.first { $0.word.caseInsensitiveCompare(word) == .orderedSame }
    }

    func isKnownWord(_ word: String) -> Bool {
        knownWords.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
    }

    func toggleSavedWord(
        _ word: String,
        meaningZh: String = "",
        phonetic: String = "",
        example: String = "",
        exampleZh: String = "",
        context: String = ""
    ) {
        if let index = savedEntries.firstIndex(where: {
            $0.word.caseInsensitiveCompare(word) == .orderedSame
        }) {
            savedEntries.remove(at: index)
        } else {
            savedEntries.append(
                SavedVocabularyEntry(
                    word: word,
                    meaningZh: meaningZh,
                    phonetic: phonetic,
                    example: example,
                    exampleZh: exampleZh,
                    context: context
                )
            )
            savedEntries.sort {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
        }
        persist()
    }

    func updateSavedWord(
        _ word: String,
        meaningZh: String,
        phonetic: String,
        example: String,
        exampleZh: String,
        context: String
    ) {
        guard let index = savedEntries.firstIndex(where: {
            $0.word.caseInsensitiveCompare(word) == .orderedSame
        }) else {
            return
        }
        savedEntries[index] = SavedVocabularyEntry(
            word: savedEntries[index].word,
            meaningZh: meaningZh,
            phonetic: phonetic,
            example: example,
            exampleZh: exampleZh,
            context: context
        )
        persist()
    }

    func setKnownState(for word: String, isKnown: Bool) {
        knownWords.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
        if isKnown {
            knownWords.append(word)
            knownWords.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        persist()
    }

    private func persist() {
        let encodedEntries = try? JSONEncoder().encode(savedEntries)
        defaults.set(encodedEntries, forKey: savedEntriesKey)
        defaults.set(savedWords, forKey: savedKey)
        defaults.set(knownWords, forKey: knownKey)
        cloud.set(encodedEntries, forKey: savedEntriesKey)
        cloud.set(savedWords, forKey: savedKey)
        cloud.set(knownWords, forKey: knownKey)
        cloud.synchronize()
    }

    private static func decodeEntries(_ data: Data?) -> [SavedVocabularyEntry]? {
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode([SavedVocabularyEntry].self, from: data)
    }
}

@MainActor
final class AIRewriteService: ObservableObject {
    @Published private(set) var provider: AIProvider
    @Published private(set) var modelOverride: String
    @Published private var generatedContent: [String: [String]] = [:]
    @Published private var generatingKeys: Set<String> = []
    @Published private var statusMessages: [String: String] = [:]

    private let defaults: UserDefaults
    private let providerKey = "aiProvider"
    private let modelKey = "aiModelOverride"
    private let keychainAccountPrefix = "OneRead.ai."

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.provider = AIProvider(rawValue: defaults.string(forKey: providerKey) ?? "") ?? .deepseek
        self.modelOverride = defaults.string(forKey: modelKey) ?? ""
    }

    var isOnDeviceRewriteAvailable: Bool {
        ArticleLevelService.isOnDeviceAvailable
    }

    var effectiveModel: String {
        let trimmed = modelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var hasAPIKey: Bool {
        !(KeychainStore.get(keychainAccount) ?? "").isEmpty
    }

    var currentAPIKey: String {
        KeychainStore.get(keychainAccount) ?? ""
    }

    var currentConfig: AILevelConfig? {
        guard let apiKey = KeychainStore.get(keychainAccount), !apiKey.isEmpty else {
            return nil
        }
        return AILevelConfig(provider: provider, model: effectiveModel, apiKey: apiKey)
    }

    func leveledRewrite(for article: Article, level: ReadingLevel) -> [String]? {
        switch level {
        case .level1:
            return article.learningContent?.easy.paragraphs ?? generatedContent[key(for: article, level: level)]
        case .level2:
            return article.learningContent?.standard.paragraphs ?? generatedContent[key(for: article, level: level)]
        case .level3:
            return nil
        }
    }

    func isGeneratingLevel(for article: Article, level: ReadingLevel) -> Bool {
        generatingKeys.contains(key(for: article, level: level))
    }

    func leveledStatusMessage(for article: Article, level: ReadingLevel) -> String? {
        statusMessages[key(for: article, level: level)]
    }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
        defaults.set(provider.rawValue, forKey: providerKey)
    }

    func setModelOverride(_ model: String) {
        modelOverride = model.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(modelOverride, forKey: modelKey)
    }

    func setAPIKey(_ key: String) {
        _ = KeychainStore.set(key, for: keychainAccount)
        objectWillChange.send()
    }

    func requestLeveledContent(for article: Article, level: ReadingLevel) {
        guard level != .level3, leveledRewrite(for: article, level: level) == nil else { return }
        let requestKey = key(for: article, level: level)
        guard generatingKeys.insert(requestKey).inserted else { return }
        statusMessages[requestKey] = "Preparing this reading level…"

        Task {
            // User-provided API keys are no longer part of the product flow.
            // Missing editorial content may still use the on-device fallback.
            let outcome = await ArticleLevelService.rewrite(article: article, level: level, config: nil)
            generatingKeys.remove(requestKey)
            switch outcome {
            case .success(let paragraphs):
                generatedContent[requestKey] = paragraphs
                statusMessages[requestKey] = nil
            case .failure(let message):
                statusMessages[requestKey] = message
            }
        }
    }

    private var keychainAccount: String {
        keychainAccountPrefix + provider.rawValue
    }

    private func key(for article: Article, level: ReadingLevel) -> String {
        "\(article.id)|\(level.rawValue)"
    }
}

struct DailyEditionSchedule {
    private let calendar: Calendar
    private let dailyLimit: Int
    private let dailyGoal: Int
    private let morningReleaseHour = 8
    private let afternoonReleaseHour = 16

    init(calendar: Calendar, dailyLimit: Int, dailyGoal: Int) {
        self.calendar = calendar
        self.dailyLimit = dailyLimit
        self.dailyGoal = dailyGoal
    }

    var currentCycleKey: String {
        cycleKey(for: Date())
    }

    func cycleKey(for date: Date) -> String {
        dayKey(for: date)
    }

    func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func releasedArticleCount(for date: Date) -> Int {
        guard dailyLimit > 1 else { return dailyLimit }
        let hour = calendar.component(.hour, from: date)
        if hour >= afternoonReleaseHour {
            return dailyLimit          // both articles from 16:00
        }
        if hour >= morningReleaseHour {
            return 1                   // first article from 08:00
        }
        return 0                       // nothing before 08:00
    }

    func isEligibleHomeArticle(_ article: Article, relativeTo now: Date) -> Bool {
        if article.editionDate == cycleKey(for: now) {
            return true
        }
        guard article.category == .ai || article.category == .technology else { return false }
        guard let publishedAt = article.publishedAt else { return true }
        let age = now.timeIntervalSince(publishedAt)
        return age >= -300 && age <= 14 * 24 * 60 * 60
    }

    func isTodayComplete(dailyIDs: [String], completedIDs: Set<String>) -> Bool {
        let available = Set(dailyIDs)
        guard !available.isEmpty else {
            return false
        }

        // Either released story can satisfy the daily goal. Each article still
        // keeps its own completion state, so users may finish both.
        return available.intersection(completedIDs).count >= dailyGoal
    }

    func currentStreak(isComplete: (String) -> Bool) -> Int {
        var date = Date()
        if !isComplete(dayKey(for: date)) {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }

        var streak = 0
        while isComplete(dayKey(for: date)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    func activeDaysLast7(isActive: (Date) -> Bool) -> Int {
        (0..<7).reduce(into: 0) { count, offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return }
            if isActive(date) { count += 1 }
        }
    }

    func homeReleaseDateText(
        for slot: ArticleEditionSlot?,
        fallbackRank: Int,
        cycleKey: String?
    ) -> String {
        let hour: Int
        switch slot {
        case .morning:
            hour = morningReleaseHour
        case .afternoon:
            hour = afternoonReleaseHour
        case nil:
            hour = fallbackRank <= 1 ? morningReleaseHour : afternoonReleaseHour
        }
        let time = String(format: "%02d:00", hour)
        return cycleKey == currentCycleKey ? "Today, \(time)" : time
    }
}
