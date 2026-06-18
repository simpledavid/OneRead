import Foundation
import os

/// Fetches and enriches articles from RSS feeds and special-cased sources.
enum FeedService {
    private static let feedLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "OneRead",
        category: "feed"
    )

    /// Total network attempts per feed download = `feedFetchRetries` + 1.
    private static let feedFetchRetries = 1
    private static let minimumBodyWordCount = 70
    private static let htmlConcurrencyLimiter = AsyncConcurrencyLimiter(limit: 6)

    static func fetchArticles(from sources: [ArticleFeedSource]) async -> [Article] {
        await withTaskGroup(of: [Article].self) { group in
            for source in sources {
                group.addTask {
                    await fetchArticles(from: source)
                }
            }

            var fetchedArticles: [Article] = []
            for await sourceArticles in group {
                fetchedArticles.append(contentsOf: sourceArticles)
            }
            return fetchedArticles
        }
    }

    static func fetchArticles(from source: ArticleFeedSource) async -> [Article] {
        switch source.specialParser {
        case .anthropicNews, .anthropicResearch:
            let articles = await fetchAnthropicArticles(from: source)
            if articles.isEmpty {
                feedLogger.warning("Feed \"\(source.name, privacy: .public)\" returned no articles (Anthropic scrape).")
            }
            return articles
        case nil:
            break
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
        let withoutImage = enrichedArticles.filter { $0.imageURLString.isEmpty }.count
        if withoutImage > 0 {
            feedLogger.notice("Feed \"\(source.name, privacy: .public)\": \(withoutImage)/\(enrichedArticles.count) without an original image; using category fallback.")
        }
        return enrichedArticles
    }

    // MARK: - Feed download

    private static func loadFeedData(from source: ArticleFeedSource) async -> Data? {
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

    // MARK: - Enrichment

    static func enrichArticles(for articles: [Article]) async -> [Article] {
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

    private static func fetchHTML(from url: URL) async -> String? {
        await htmlConcurrencyLimiter.acquire()
        let html = await loadHTML(from: url)
        await htmlConcurrencyLimiter.release()
        return html
    }

    private static func loadHTML(from url: URL) async -> String? {
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

    // MARK: - Anthropic scraping

    private static func fetchAnthropicArticles(from source: ArticleFeedSource) async -> [Article] {
        guard let html = await fetchHTML(from: source.url) else {
            return []
        }

        let section: String
        switch source.specialParser {
        case .anthropicResearch:
            section = "research"
        case .anthropicNews, nil:
            section = "news"
        }

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

    private static func extractAnthropicSlugs(from html: String, section: String) -> [String] {
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

    private static func fetchAnthropicArticle(
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

    private static func anthropicKeyPoints(from body: [String]) -> [String] {
        let sentences = body
            .joined(separator: " ")
            .replacingOccurrences(of: ". ", with: ".\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(sentences.prefix(2))
    }

    // MARK: - HTML helpers

    private static func metaContent(in html: String, property: String) -> String {
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

    private static func parseAnthropicDate(from html: String) -> Date? {
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

    private static func parseAnthropicDateString(_ raw: String) -> Date? {
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

    private static func relativeAnthropicDateText(_ date: Date?) -> String {
        guard let date else {
            return "Latest"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func extractAnthropicBody(from html: String) -> [String] {
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

    private static func extractArticleParagraphs(from html: String) -> [String] {
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

    private static func firstImageURL(in html: String, baseURL: URL) -> URL? {
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

    private static func normalizedImageURL(_ value: String, baseURL: URL) -> URL? {
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

    private static func cleanedHTMLText(_ value: String) -> String {
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

    private static func decodedHTMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .htmlDecoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesSourceFilter(_ article: Article, source: ArticleFeedSource) -> Bool {
        guard !source.filterKeywords.isEmpty else {
            return true
        }

        let text = "\(article.title) \(article.subtitle) \(article.summary) \(article.category.title)".lowercased()
        return source.filterKeywords.contains { text.contains($0) }
    }

    private static func bodyWordCount(_ paragraphs: [String]) -> Int {
        paragraphs
            .joined(separator: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .count
    }
}
