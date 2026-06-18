import Foundation

enum ArticleCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case ai
    case technology
    case founders
    case crypto
    case business
    case culture
    case science
    case life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai:
            return "AI"
        case .technology:
            return "Technology"
        case .founders:
            return "Founders"
        case .crypto:
            return "Crypto"
        case .business:
            return "Business"
        case .culture:
            return "Culture"
        case .science:
            return "Science"
        case .life:
            return "Life"
        }
    }

    var systemImage: String {
        switch self {
        case .ai:
            return "sparkles"
        case .technology:
            return "cpu"
        case .founders:
            return "person.2"
        case .crypto:
            return "bitcoinsign.circle"
        case .business:
            return "chart.line.uptrend.xyaxis"
        case .culture:
            return "theatermasks"
        case .science:
            return "atom"
        case .life:
            return "leaf"
        }
    }
}

struct Article: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let source: String
    let author: String
    let category: ArticleCategory
    let readingMinutes: Int
    let publishNote: String
    let summary: String
    let keyPoints: [String]
    let body: [String]
    let paragraphTranslations: [String]
    let vocabulary: [ArticleVocabulary]
    let urlString: String
    let imageURLString: String
    let publishedAt: Date?

    init(
        id: String,
        title: String,
        subtitle: String,
        source: String,
        author: String,
        category: ArticleCategory,
        readingMinutes: Int,
        publishNote: String,
        summary: String,
        keyPoints: [String],
        body: [String],
        paragraphTranslations: [String] = [],
        vocabulary: [ArticleVocabulary] = [],
        urlString: String = "",
        imageURLString: String = "",
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.source = source
        self.author = author
        self.category = category
        self.readingMinutes = readingMinutes
        self.publishNote = publishNote
        self.summary = summary
        self.keyPoints = keyPoints
        self.body = body
        self.paragraphTranslations = paragraphTranslations
        self.vocabulary = vocabulary
        self.urlString = urlString
        self.imageURLString = imageURLString
        self.publishedAt = publishedAt
    }

    var url: URL? {
        URL(string: urlString)
    }

    var imageURL: URL? {
        URL(string: imageURLString)
    }

    var publishedDateTimeText: String {
        guard let publishedAt else {
            return publishNote
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MM/dd HH:mm"
        return formatter.string(from: publishedAt)
    }
}

struct ArticleVocabulary: Hashable, Codable, Identifiable, Sendable {
    let word: String
    let meaningZh: String
    let phonetic: String
    let example: String
    let exampleZh: String

    var id: String { word.lowercased() }

    init(word: String, meaningZh: String, phonetic: String = "", example: String, exampleZh: String = "") {
        self.word = word
        self.meaningZh = meaningZh
        self.phonetic = phonetic
        self.example = example
        self.exampleZh = exampleZh
    }

    enum CodingKeys: String, CodingKey {
        case word
        case meaningZh = "meaningZh"
        case legacyMeaningZh = "meaning_zh"
        case phonetic
        case example
        case exampleZh = "example_zh"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        meaningZh = (try? container.decode(String.self, forKey: .legacyMeaningZh))
            ?? (try? container.decode(String.self, forKey: .meaningZh))
            ?? ""
        phonetic = (try? container.decode(String.self, forKey: .phonetic)) ?? ""
        example = (try? container.decode(String.self, forKey: .example)) ?? ""
        exampleZh = (try? container.decode(String.self, forKey: .exampleZh)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(word, forKey: .word)
        try container.encode(meaningZh, forKey: .legacyMeaningZh)
        try container.encode(phonetic, forKey: .phonetic)
        try container.encode(example, forKey: .example)
        try container.encode(exampleZh, forKey: .exampleZh)
    }
}
