import Foundation
import os

private let dailyContentLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "OneRead",
    category: "daily-content"
)

enum OneReadConfiguration {
    static var contentBaseURL: URL? {
        configuredURL(
            environmentKey: "ONE_READ_CONTENT_BASE_URL",
            infoKey: "ONE_READ_CONTENT_BASE_URL"
        )
    }

    static var analyticsURL: URL? {
        configuredURL(
            environmentKey: "ONE_READ_ANALYTICS_URL",
            infoKey: "ONE_READ_ANALYTICS_URL"
        )
    }

    private static func configuredURL(environmentKey: String, infoKey: String) -> URL? {
        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let infoValue = (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = [environmentValue, infoValue]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        return value.flatMap(URL.init(string:))
    }
}

enum DailyContentService {
    struct Result: Sendable {
        let edition: DailyEdition
        let isBundledFallback: Bool
    }

    static func fetchEdition(for dateKey: String) async -> Result {
        if let remoteEdition = await fetchRemoteEdition(for: dateKey) {
            return Result(edition: remoteEdition, isBundledFallback: false)
        }

        return Result(
            edition: SampleArticles.bundledEdition(for: dateKey),
            isBundledFallback: true
        )
    }

    private static func fetchRemoteEdition(for dateKey: String) async -> DailyEdition? {
        guard let baseURL = OneReadConfiguration.contentBaseURL else {
            return nil
        }

        let candidates = [
            baseURL.appendingPathComponent("\(dateKey).json"),
            baseURL.appendingPathComponent("latest.json")
        ]

        for url in candidates {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadRevalidatingCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    continue
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let edition = try decoder.decode(DailyEdition.self, from: data)
                guard validate(edition) else {
                    dailyContentLogger.warning(
                        "Rejected invalid daily edition from \(url.absoluteString, privacy: .public)."
                    )
                    continue
                }

                dailyContentLogger.notice(
                    "Loaded approved daily edition \(edition.date, privacy: .public)."
                )
                return edition
            } catch {
                dailyContentLogger.warning(
                    "Daily edition request failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return nil
    }

    private static func validate(_ edition: DailyEdition) -> Bool {
        guard edition.schemaVersion == 1,
              edition.status == .approved || edition.status == .published,
              edition.articles.count == 2 else {
            return false
        }

        let slots = Set(edition.articles.compactMap(\.editionSlot))
        guard slots == Set([.morning, .afternoon]) else {
            return false
        }

        return edition.articles.allSatisfy { article in
            guard let learning = article.learningContent else {
                return false
            }

            return article.editionDate == edition.date
                && (article.curationStatus == .approved || article.curationStatus == .published)
                && !article.urlString.isEmpty
                && !article.body.isEmpty
                && !learning.easy.paragraphs.isEmpty
                && !learning.standard.paragraphs.isEmpty
                && (5...8).contains(learning.vocabulary.count)
        }
    }
}

struct RetentionEvent: Codable, Sendable {
    let id: UUID
    let name: String
    let timestamp: Date
    let articleID: String?
    let level: Int?
    let metadata: [String: String]
}

enum RetentionAnalytics {
    static func record(
        _ name: String,
        articleID: String? = nil,
        level: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        Task {
            await RetentionAnalyticsStore.shared.record(
                name,
                articleID: articleID,
                level: level,
                metadata: metadata
            )
        }
    }

    static func flush() {
        Task {
            await RetentionAnalyticsStore.shared.flush()
        }
    }
}

private actor RetentionAnalyticsStore {
    static let shared = RetentionAnalyticsStore()

    private let defaults = UserDefaults.standard
    private let queueKey = "retentionAnalyticsEventQueue"
    private let maximumQueuedEvents = 500

    func record(
        _ name: String,
        articleID: String?,
        level: Int?,
        metadata: [String: String]
    ) async {
        var events = loadEvents()
        events.append(
            RetentionEvent(
                id: UUID(),
                name: name,
                timestamp: Date(),
                articleID: articleID,
                level: level,
                metadata: metadata
            )
        )
        if events.count > maximumQueuedEvents {
            events.removeFirst(events.count - maximumQueuedEvents)
        }
        save(events)

        if OneReadConfiguration.analyticsURL != nil {
            await flush()
        }
    }

    func flush() async {
        guard let url = OneReadConfiguration.analyticsURL else {
            return
        }

        let events = loadEvents()
        guard !events.isEmpty else {
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(["events": events]) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return
            }
            save([])
        } catch {
            return
        }
    }

    private func loadEvents() -> [RetentionEvent] {
        guard let data = defaults.data(forKey: queueKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RetentionEvent].self, from: data)) ?? []
    }

    private func save(_ events: [RetentionEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(events), forKey: queueKey)
    }
}
