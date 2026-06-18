import Foundation

enum TLDRChannel: String, CaseIterable, Identifiable {
    case ai
    case tech

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai:
            return "AI"
        case .tech:
            return "Tech"
        }
    }

    var systemImage: String {
        switch self {
        case .ai:
            return "sparkles"
        case .tech:
            return "cpu"
        }
    }

    private var configuredFeed: FeedConfiguration.Feed? {
        FeedConfiguration.bundled.feed(forChannel: rawValue)
    }

    var feedURL: URL {
        configuredFeed.flatMap { URL(string: $0.url) } ?? fallbackURL
    }

    private var fallbackURL: URL {
        switch self {
        case .ai:
            return URL(string: "https://bullrich.dev/tldr-rss/ai.rss")!
        case .tech:
            return URL(string: "https://bullrich.dev/tldr-rss/tech.rss")!
        }
    }

    var articleCategory: ArticleCategory {
        switch self {
        case .ai:
            return .ai
        case .tech:
            return .technology
        }
    }

    var sourceName: String {
        configuredFeed?.name ?? "TLDR \(title)"
    }

    var filterKeywords: [String] { [] }
}
