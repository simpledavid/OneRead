import Foundation
import SwiftData

@MainActor
final class ArticleDatabase {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let schema = Schema([
            StoredArticle.self
        ])
        // This store is only an article cache. Version the file name when the
        // cached Article schema changes so upgrades cannot block app launch.
        let configuration = ModelConfiguration("OneReadLocalStoreV2", schema: schema)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    static func live() -> ArticleDatabase? {
        do {
            return try ArticleDatabase()
        } catch {
            return nil
        }
    }

    func loadArticles() -> [Article] {
        do {
            let records = try context.fetch(FetchDescriptor<StoredArticle>())
            return records
                .map(\.article)
                .sorted { lhs, rhs in
                    (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
                }
        } catch {
            return []
        }
    }

    func clearAll() {
        do {
            try context.delete(model: StoredArticle.self)
            try context.save()
        } catch {
            context.rollback()
        }
    }

    func saveArticles(_ articles: [Article], limit: Int = 300) {
        do {
            let incoming = Array(articles.prefix(limit))
            let records = try context.fetch(FetchDescriptor<StoredArticle>())
            var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

            for article in incoming {
                if let record = recordsByID[article.id] {
                    record.update(from: article)
                } else {
                    let record = StoredArticle(article: article)
                    context.insert(record)
                    recordsByID[article.id] = record
                }
            }

            let retainedIDs = Set(incoming.map(\.id))
            for record in records where !retainedIDs.contains(record.id) && records.count > limit {
                context.delete(record)
            }

            try context.save()
        } catch {
            context.rollback()
        }
    }
}

@Model
final class StoredArticle {
    @Attribute(.unique) var id: String
    var title: String
    var subtitle: String
    var source: String
    var author: String
    var categoryRawValue: String
    var readingMinutes: Int
    var publishNote: String
    var summary: String
    var keyPointsData: Data
    var bodyData: Data
    var paragraphTranslationsData: Data
    var vocabularyData: Data
    var urlString: String
    var imageURLString: String
    var publishedAt: Date?
    var editionDate: String?
    var editionSlotRawValue: String?
    var curationStatusRawValue: String?
    var learningContentData: Data?
    var updatedAt: Date

    init(article: Article) {
        id = article.id
        title = article.title
        subtitle = article.subtitle
        source = article.source
        author = article.author
        categoryRawValue = article.category.rawValue
        readingMinutes = article.readingMinutes
        publishNote = article.publishNote
        summary = article.summary
        keyPointsData = Self.encode(article.keyPoints)
        bodyData = Self.encode(article.body)
        paragraphTranslationsData = Self.encode(article.paragraphTranslations)
        vocabularyData = Self.encode(article.vocabulary)
        urlString = article.urlString
        imageURLString = article.imageURLString
        publishedAt = article.publishedAt
        editionDate = article.editionDate
        editionSlotRawValue = article.editionSlot?.rawValue
        curationStatusRawValue = article.curationStatus?.rawValue
        learningContentData = article.learningContent.map(Self.encode)
        updatedAt = Date()
    }

    var article: Article {
        Article(
            id: id,
            title: title,
            subtitle: subtitle,
            source: source,
            author: author,
            category: ArticleCategory(rawValue: categoryRawValue) ?? .ai,
            readingMinutes: readingMinutes,
            publishNote: publishNote,
            summary: summary,
            keyPoints: Self.decode([String].self, from: keyPointsData, fallback: []),
            body: Self.decode([String].self, from: bodyData, fallback: []),
            paragraphTranslations: Self.decode([String].self, from: paragraphTranslationsData, fallback: []),
            vocabulary: Self.decode([ArticleVocabulary].self, from: vocabularyData, fallback: []),
            urlString: urlString,
            imageURLString: imageURLString,
            publishedAt: publishedAt,
            editionDate: editionDate,
            editionSlot: editionSlotRawValue.flatMap(ArticleEditionSlot.init(rawValue:)),
            curationStatus: curationStatusRawValue.flatMap(ArticleCurationStatus.init(rawValue:)),
            learningContent: learningContentData.flatMap {
                try? JSONDecoder().decode(ArticleLearningContent.self, from: $0)
            }
        )
    }

    func update(from article: Article) {
        title = article.title
        subtitle = article.subtitle
        source = article.source
        author = article.author
        categoryRawValue = article.category.rawValue
        readingMinutes = article.readingMinutes
        publishNote = article.publishNote
        summary = article.summary
        keyPointsData = Self.encode(article.keyPoints)
        bodyData = Self.encode(article.body)
        paragraphTranslationsData = Self.encode(article.paragraphTranslations)
        vocabularyData = Self.encode(article.vocabulary)
        urlString = article.urlString
        imageURLString = article.imageURLString
        publishedAt = article.publishedAt
        editionDate = article.editionDate
        editionSlotRawValue = article.editionSlot?.rawValue
        curationStatusRawValue = article.curationStatus?.rawValue
        learningContentData = article.learningContent.map(Self.encode)
        updatedAt = Date()
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, fallback: T) -> T {
        (try? JSONDecoder().decode(type, from: data)) ?? fallback
    }
}
