import Foundation

final class ArticleRSSParser: NSObject, XMLParserDelegate {
    private let source: ArticleFeedSource
    private var articles: [Article] = []

    /// Stop parsing once we have collected enough items. Feeds are almost always
    /// ordered newest-first, so this avoids parsing huge archives (e.g. a feed
    /// with 1000+ entries) when we only keep `itemLimit`. Keyword-filtered
    /// sources need a larger window because matches may appear further down.
    private var parseLimit: Int {
        source.filterKeywords.isEmpty ? source.itemLimit : max(source.itemLimit * 4, 80)
    }
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSummary = ""
    private var currentAuthor = ""
    private var currentDate = ""
    private var currentImageURL = ""
    private var isInsideItem = false

    init(source: ArticleFeedSource) {
        self.source = source
    }

    func parse(data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let lowerName = elementName.lowercased()
        currentElement = lowerName.contains(":") ? String(lowerName.split(separator: ":").last ?? Substring(lowerName)) : lowerName

        if currentElement == "item" || currentElement == "entry" {
            isInsideItem = true
            currentTitle = ""
            currentLink = ""
            currentSummary = ""
            currentAuthor = ""
            currentDate = ""
            currentImageURL = ""
        }

        if isInsideItem, currentElement == "link", let href = attributeDict["href"], currentLink.isEmpty {
            currentLink = href
        }

        if isInsideItem, currentImageURL.isEmpty {
            let type = attributeDict["type"]?.lowercased() ?? ""
            let isImageElement = currentElement.contains("thumbnail") || currentElement.contains("image")
            let isImageEnclosure = currentElement == "enclosure" && type.contains("image")
            let isImageMedia = currentElement.contains("content") && type.contains("image")
            if isImageElement || isImageEnclosure || isImageMedia,
               let imageURL = attributeDict["url"] ?? attributeDict["href"] {
                let decodedURL = decodedHTMLAttribute(imageURL)
                if decodedURL.hasPrefix("http"), !decodedURL.lowercased().hasSuffix(".svg") {
                    currentImageURL = decodedURL
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else {
            return
        }

        switch currentElement {
        case "title":
            currentTitle += string
        case "link", "guid":
            if currentLink.isEmpty {
                currentLink += string
            }
        case "description", "summary", "content", "encoded":
            currentSummary += string
        case "creator", "author", "name":
            currentAuthor += string
        case "pubdate", "published", "updated":
            currentDate += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard isInsideItem,
              let string = String(data: CDATABlock, encoding: .utf8) else {
            return
        }

        switch currentElement {
        case "description", "summary", "content", "encoded":
            currentSummary += string
        case "creator", "author", "name":
            currentAuthor += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        guard name == "item" || name == "entry" else {
            currentElement = ""
            return
        }

        let title = cleaned(currentTitle)
        guard !title.isEmpty else {
            resetItem()
            return
        }

        let fullText = cleaned(currentSummary)
        let teaser = teaserText(from: fullText)
        let date = parseDate(currentDate)
        let subtitle = teaser.isEmpty ? "Latest AI news" : teaser
        let minutes = max(2, min(8, title.count / 18 + 3))
        let link = cleaned(currentLink)
        let imageURL = currentImageURL.isEmpty ? firstImageURL(in: currentSummary) : currentImageURL
        let body = articleBody(from: fullText, sourceName: source.name)
        let searchText = ([title, subtitle, fullText] + body).joined(separator: " ")

        articles.append(
            Article(
                id: link.isEmpty ? title : link,
                title: title,
                subtitle: subtitle,
                source: source.name,
                author: cleaned(currentAuthor).isEmpty ? source.name : cleaned(currentAuthor),
                category: source.category,
                readingMinutes: minutes,
                publishNote: relativeDateText(date),
                summary: teaser.isEmpty ? "Latest AI news from \(source.name). Open the original link to read the full story." : teaser,
                keyPoints: keyPoints(from: body, sourceName: source.name),
                body: body,
                paragraphTranslations: [],
                vocabulary: localVocabulary(for: searchText),
                urlString: link,
                imageURLString: imageURL,
                publishedAt: date
            )
        )

        resetItem()

        if articles.count >= parseLimit {
            parser.abortParsing()
        }
    }

    private func resetItem() {
        isInsideItem = false
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentSummary = ""
        currentAuthor = ""
        currentDate = ""
        currentImageURL = ""
    }

    private func cleaned(_ string: String) -> String {
        string
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
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
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstImageURL(in html: String) -> String {
        let patterns = [
            #"<img[^>]+src=["']([^"']+)["']"#,
            #"<media:thumbnail[^>]+url=["']([^"']+)["']"#,
            #"<media:content[^>]+url=["']([^"']+)["']"#
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

            let value = decodedHTMLAttribute(String(html[valueRange]))
            if value.hasPrefix("http"), !value.lowercased().hasSuffix(".svg") {
                return value
            }
        }

        return ""
    }

    private func decodedHTMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .htmlDecoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func teaserText(from text: String) -> String {
        guard !text.isEmpty else {
            return ""
        }

        let sentences = text
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "! ", with: "!\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var teaser = ""
        for sentence in sentences {
            if teaser.isEmpty {
                teaser = sentence
            } else if teaser.count + sentence.count + 1 <= 200 {
                teaser += " " + sentence
            } else {
                break
            }
        }

        if teaser.count > 240 {
            teaser = String(teaser.prefix(237)).trimmingCharacters(in: .whitespaces) + "…"
        }

        return teaser
    }

    private func articleBody(from summary: String, sourceName: String) -> [String] {
        let fallback = "This is a recent story from \(sourceName). The RSS feed does not include the full article, so use the original link for deeper reading."
        let sourceText = summary.isEmpty ? fallback : summary
        let sentenceText = sourceText
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "! ", with: "!\n")
            .replacingOccurrences(of: "? ", with: "?\n")

        let sentences = sentenceText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sentences.isEmpty else {
            return [fallback]
        }

        var paragraphs: [String] = []
        var buffer: [String] = []
        var bufferWords = 0

        for sentence in sentences {
            buffer.append(sentence)
            bufferWords += wordCount(sentence)
            if bufferWords >= 42 {
                paragraphs.append(buffer.joined(separator: " "))
                buffer = []
                bufferWords = 0
            }
        }

        if !buffer.isEmpty {
            paragraphs.append(buffer.joined(separator: " "))
        }

        return paragraphs.isEmpty ? [sourceText] : paragraphs
    }

    private func keyPoints(from body: [String], sourceName: String) -> [String] {
        let firstSentences = body
            .flatMap {
                $0.replacingOccurrences(of: ". ", with: ".\n")
                    .components(separatedBy: "\n")
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)

        let points = Array(firstSentences)
        return points.isEmpty ? ["Latest story from \(sourceName)"] : points
    }

    private func localVocabulary(for text: String) -> [ArticleVocabulary] {
        let rawWords = text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        let wordSet = Set(rawWords)
        let dictionary: [(key: String, word: String, meaning: String, phonetic: String)] = [
            ("acquire", "acquire", "收购；获得", "/əˈkwaɪər/"),
            ("acquisition", "acquisition", "收购；获得", "/ˌækwɪˈzɪʃən/"),
            ("agent", "agent", "智能体；代理程序", "/ˈeɪdʒənt/"),
            ("autonomous", "autonomous", "自主的；自动运行的", "/ɔːˈtɑːnəməs/"),
            ("capability", "capability", "能力；功能", "/ˌkeɪpəˈbɪləti/"),
            ("chip", "chip", "芯片", "/tʃɪp/"),
            ("compute", "compute", "计算；算力", "/kəmˈpjuːt/"),
            ("crypto", "crypto", "加密货币；加密领域", "/ˈkrɪptoʊ/"),
            ("deploy", "deploy", "部署；推出", "/dɪˈplɔɪ/"),
            ("developer", "developer", "开发者", "/dɪˈveləpər/"),
            ("funding", "funding", "融资；资金", "/ˈfʌndɪŋ/"),
            ("infrastructure", "infrastructure", "基础设施", "/ˈɪnfrəstrʌktʃər/"),
            ("launch", "launch", "发布；推出", "/lɔːntʃ/"),
            ("model", "model", "模型；AI 模型", "/ˈmɑːdəl/"),
            ("openai", "OpenAI", "OpenAI，一家人工智能公司", ""),
            ("policy", "policy", "政策；规则", "/ˈpɑːləsi/"),
            ("regulation", "regulation", "监管；规定", "/ˌreɡjəˈleɪʃən/"),
            ("research", "research", "研究", "/rɪˈsɜːrtʃ/"),
            ("revenue", "revenue", "收入；营收", "/ˈrevənuː/"),
            ("security", "security", "安全；安全性", "/sɪˈkjʊrəti/"),
            ("startup", "startup", "初创公司", "/ˈstɑːrtʌp/"),
            ("token", "token", "代币；文本 token", "/ˈtoʊkən/"),
            ("valuation", "valuation", "估值", "/ˌvæljuˈeɪʃən/")
        ]

        return dictionary
            .filter { wordSet.contains($0.key) }
            .prefix(14)
            .map {
                ArticleVocabulary(
                    word: $0.word,
                    meaningZh: $0.meaning,
                    phonetic: $0.phonetic,
                    example: ""
                )
            }
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
    }

    // Reused across items: building DateFormatters is expensive, so cache them.
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        // Covers RFC 822 (numeric and named time zones) plus a few ISO variants
        // that ISO8601DateFormatter rejects. Order matters: most specific first.
        let formats = [
            "E, d MMM yyyy HH:mm:ss Z",
            "E, d MMM yyyy HH:mm:ss zzz",
            "E, d MMM yyyy HH:mm Z",
            "E, d MMM yyyy HH:mm zzz",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            return formatter
        }
    }()

    private func parseDate(_ rawValue: String) -> Date? {
        let value = cleaned(rawValue)
        guard !value.isEmpty else {
            return nil
        }

        if let date = Self.iso8601WithFractional.date(from: value) {
            return date
        }

        if let date = Self.iso8601Standard.date(from: value) {
            return date
        }

        for formatter in Self.fallbackDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func relativeDateText(_ date: Date?) -> String {
        guard let date else {
            return "Latest"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

