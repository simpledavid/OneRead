import Foundation

struct ArticleFeedSource: Sendable {
    let name: String
    let url: URL
    let category: ArticleCategory
    var filterKeywords: [String] = []
    var itemLimit: Int = 12
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

