import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Context-aware definition service for words not already covered by the
/// server-generated article vocabulary or curated terminology. It uses the
/// on-device Apple Intelligence model (iOS 26+) and caches repeated lookups.
actor WordEnrichmentService {
    static let shared = WordEnrichmentService()

    private var cache: [String: String] = [:]

    func cachedMeaning(for word: String, context: String) -> String? {
        cache[Self.key(for: word, context: context)]
    }

    func meaning(for word: String, context: String) async -> String? {
        let key = Self.key(for: word, context: context)
        if let cached = cache[key] {
            return cached.isEmpty ? nil : cached
        }

        let generated = await Self.generate(word: word, context: context) ?? ""
        cache[key] = generated
        return generated.isEmpty ? nil : generated
    }

    private static func key(for word: String, context: String) -> String {
        let normalizedWord = word
            .lowercased()
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let normalizedContext = context
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedWord)|\(normalizedContext.prefix(280))"
    }

    private static func generate(word: String, context: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                return nil
            }

            let instructions = """
            你是一名英汉词典助手，服务于中国英语学习者。只输出给定英文单词在该语境下最常见的简明中文释义，\
            不超过 20 个汉字。只返回中文释义本身，不要英文、不要拼音、不要例句、不要解释。
            """
            let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = trimmedContext.isEmpty
                ? "单词：\(word)\n中文释义："
                : "单词：\(word)\n语境：\(String(trimmedContext.prefix(280)))\n中文释义："

            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                return sanitize(response.content)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    private static func sanitize(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 40 ? String(cleaned.prefix(40)) : cleaned
    }
}
