import Foundation

enum FeedSpecialParser: String, Codable, Sendable {
    case anthropicNews = "anthropic-news"
    case anthropicResearch = "anthropic-research"
}

struct ArticleFeedSource: Sendable {
    let name: String
    let url: URL
    let category: ArticleCategory
    let authority: Double
    var filterKeywords: [String] = []
    var itemLimit: Int = 12
    var specialParser: FeedSpecialParser?
}

extension ArticleFeedSource {
    init?(feed: FeedConfiguration.Feed) {
        guard let url = URL(string: feed.url),
              let category = ArticleCategory(rawValue: feed.category) else {
            return nil
        }
        self.name = feed.name
        self.url = url
        self.category = category
        self.authority = feed.authority ?? 0.65
        self.filterKeywords = feed.filterKeywords ?? []
        self.itemLimit = feed.itemLimit ?? 12
        self.specialParser = feed.specialParser.flatMap(FeedSpecialParser.init(rawValue:))
    }
}

/// A lightweight async semaphore used to bound concurrent network work.
/// Callers `acquire()` before starting and `release()` when finished.
actor AsyncConcurrencyLimiter {
    private let limit: Int
    private var inUse = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async {
        if inUse < limit {
            inUse += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else if inUse > 0 {
            inUse -= 1
        }
    }
}
