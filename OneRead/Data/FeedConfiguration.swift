import Foundation

struct FeedConfiguration {
    struct Feed: Sendable {
        let id: String
        let channel: String?
        let name: String
        let url: String
        let category: String
        let authority: Double?
        let filterKeywords: [String]?
        let itemLimit: Int?
        let specialParser: String?
        let appearsOnHome: Bool
    }

    let feeds: [Feed]

    var homeSources: [ArticleFeedSource] {
        sources { $0.appearsOnHome }
    }

    func feed(forChannel channel: String) -> Feed? {
        feeds.first { $0.channel == channel }
    }

    func authority(for sourceName: String) -> Double {
        let normalizedName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return feeds.first {
            $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }?.authority ?? 0.6
    }

    static let bundled = FeedConfiguration(
        feeds: [
            Feed(id: "tldr-ai", channel: "ai", name: "TLDR AI", url: "https://bullrich.dev/tldr-rss/ai.rss", category: ArticleCategory.ai.rawValue, authority: 0.78, filterKeywords: nil, itemLimit: 20, specialParser: nil, appearsOnHome: true),
            Feed(id: "tldr-tech", channel: "tech", name: "TLDR Tech", url: "https://bullrich.dev/tldr-rss/tech.rss", category: ArticleCategory.technology.rawValue, authority: 0.76, filterKeywords: nil, itemLimit: 20, specialParser: nil, appearsOnHome: true),
            Feed(id: "openai-news", channel: nil, name: "OpenAI", url: "https://openai.com/news/rss.xml", category: ArticleCategory.ai.rawValue, authority: 0.95, filterKeywords: nil, itemLimit: 16, specialParser: nil, appearsOnHome: true),
            Feed(id: "google-ai", channel: nil, name: "Google AI", url: "https://blog.google/technology/ai/rss/", category: ArticleCategory.ai.rawValue, authority: 0.9, filterKeywords: nil, itemLimit: 16, specialParser: nil, appearsOnHome: true),
            Feed(id: "the-verge-ai", channel: nil, name: "The Verge AI", url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", category: ArticleCategory.ai.rawValue, authority: 0.82, filterKeywords: nil, itemLimit: 16, specialParser: nil, appearsOnHome: true),
            Feed(id: "ars-ai", channel: nil, name: "Ars Technica AI", url: "https://feeds.arstechnica.com/arstechnica/technology-lab", category: ArticleCategory.technology.rawValue, authority: 0.86, filterKeywords: ["AI", "artificial intelligence", "machine learning", "model"], itemLimit: 14, specialParser: nil, appearsOnHome: true),
            Feed(id: "techcrunch-ai", channel: nil, name: "TechCrunch AI", url: "https://techcrunch.com/category/artificial-intelligence/feed/", category: ArticleCategory.ai.rawValue, authority: 0.76, filterKeywords: nil, itemLimit: 16, specialParser: nil, appearsOnHome: true)
        ]
    )

    private func sources(where predicate: (Feed) -> Bool) -> [ArticleFeedSource] {
        feeds.filter(predicate).compactMap(ArticleFeedSource.init(feed:))
    }
}
