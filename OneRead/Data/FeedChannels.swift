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

    var feedURL: URL {
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
        "TLDR \(title)"
    }

    var filterKeywords: [String] { [] }
}

enum ArticleLibraryShelf: String, CaseIterable, Identifiable {
    case all
    case tldr
    case economist
    case openAI
    case anthropic
    case kimi
    case twitter
    case aiCompanies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .tldr:
            return "TLDR"
        case .economist:
            return "Economist"
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .kimi:
            return "Kimi"
        case .twitter:
            return "X (Twitter)"
        case .aiCompanies:
            return "AI Companies"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .tldr:
            return "bolt.horizontal"
        case .economist:
            return "newspaper"
        case .openAI:
            return "sparkles"
        case .anthropic:
            return "brain"
        case .kimi:
            return "moon"
        case .twitter:
            return "quote.bubble"
        case .aiCompanies:
            return "building.2"
        }
    }

    func matches(_ article: Article) -> Bool {
        switch self {
        case .all:
            return true
        case .tldr:
            return article.source.localizedCaseInsensitiveContains("TLDR")
        case .economist:
            return article.containsAny(["economist", "the economist"])
        case .openAI:
            return article.source.localizedCaseInsensitiveContains("openai")
                || article.containsAny(["openai", "chatgpt", "sora", "gpt-"])
        case .anthropic:
            return article.containsAny(["anthropic", "claude"])
        case .kimi:
            return article.containsAny(["kimi", "moonshot"])
        case .twitter:
            return article.containsAny(["twitter", "x.com", "social network", "elon musk", "xai", "grok"])
        case .aiCompanies:
            return article.containsAny([
                "openai", "anthropic", "claude", "kimi", "moonshot",
                "deepseek", "google", "gemini", "meta", "llama",
                "mistral", "perplexity", "xai", "grok", "cohere",
                "spacex", "starship", "starlink", "minimax", "qwen",
                "alibaba", "tongyi", "dashscope", "glm", "zhipu",
                "bigmodel", "twitter", "x.com", "elon musk"
            ])
        }
    }
}

