import Foundation
import Security
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Providers

/// Cloud LLM providers. All of these expose an OpenAI-compatible
/// `/chat/completions` endpoint, so a single generic client serves all of them;
/// only the base URL, default model, and API key differ per provider.
enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case bigmodel
    case deepseek
    case qwen
    case kimi
    case ernie

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bigmodel: return "Zhipu GLM"
        case .deepseek: return "DeepSeek"
        case .qwen: return "Qwen (Tongyi)"
        case .kimi: return "Kimi (Moonshot)"
        case .ernie: return "ERNIE"
        }
    }

    /// OpenAI-compatible base URL (without the trailing `/chat/completions`).
    var baseURL: String {
        switch self {
        case .bigmodel: return "https://open.bigmodel.cn/api/paas/v4"
        case .deepseek: return "https://api.deepseek.com"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .kimi: return "https://api.moonshot.cn/v1"
        case .ernie: return "https://qianfan.baidubce.com/v2"
        }
    }

    var defaultModel: String {
        switch self {
        case .bigmodel: return "glm-4.6"
        case .deepseek: return "deepseek-chat"
        case .qwen: return "qwen-plus"
        case .kimi: return "moonshot-v1-8k"
        case .ernie: return "ernie-4.5-turbo"
        }
    }

    /// Where the user can obtain an API key.
    var keyHint: String {
        switch self {
        case .bigmodel: return "open.bigmodel.cn"
        case .deepseek: return "platform.deepseek.com"
        case .qwen: return "dashscope.console.aliyun.com"
        case .kimi: return "platform.moonshot.cn"
        case .ernie: return "qianfan.baidubce.com"
        }
    }
}

struct AILevelConfig: Sendable {
    let provider: AIProvider
    let model: String
    let apiKey: String
}

// MARK: - Keychain

/// Minimal Keychain wrapper used to store API keys securely (not in UserDefaults).
enum KeychainStore {
    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        var attributes = query
        attributes[kSecValueData as String] = Data(trimmed.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
}

// MARK: - Level rewrite service

/// Rewrites an article's body into a target reading level.
/// Level 3 keeps the original text, so only Level 1 (A2) and Level 2 (B1) are
/// generated. The cloud LLM (with an API key) is the primary path; Apple's
/// on-device foundation model is an optional fallback.
enum ArticleLevelService {
    enum Outcome: Sendable {
        case success([String])
        case failure(String)
    }

    // MARK: On-device availability

    static var isOnDeviceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    static func onDeviceAvailabilityDescription() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "available"
            case .unavailable(.deviceNotEligible):
                return "device not eligible for Apple Intelligence"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is not enabled in Settings"
            case .unavailable(.modelNotReady):
                return "model not ready (still downloading)"
            case .unavailable(let other):
                return "unavailable (\(String(describing: other)))"
            }
        }
        #endif
        return "requires iOS 26 with Apple Intelligence"
    }

    // MARK: Entry point

    static func rewrite(article: Article, level: ReadingLevel, config: AILevelConfig?) async -> Outcome {
        guard level != .level3 else {
            return .failure("Level 3 keeps the original article.")
        }

        let source = sourceText(for: article)
        guard !source.isEmpty else {
            return .failure("This article has no text to rewrite.")
        }

        if let config, !config.apiKey.isEmpty {
            return await cloudRewrite(source: source, level: level, config: config)
        }

        if isOnDeviceAvailable {
            return await onDeviceRewrite(source: source, level: level)
        }

        return .failure("No API key set. Add one in Me › AI Rewrite, or enable Apple Intelligence.")
    }

    // MARK: Prompt

    private static func sourceText(for article: Article) -> String {
        let bodyText = article.body
            .filter { $0 != "Vocabulary:" }
            .joined(separator: "\n\n")
        let candidate = bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? article.summary
            : bodyText
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var systemInstruction: String {
        """
        You rewrite English news articles for English learners. Keep all facts and the \
        original meaning. Do not add opinions, titles, labels, or commentary. Reply with \
        only the rewritten article in English, and separate paragraphs with a blank line.
        """
    }

    private static func userPrompt(source: String, level: ReadingLevel) -> String {
        let guidance: String
        switch level {
        case .level1:
            guidance = "Rewrite the article for a beginner English learner (CEFR A2). Use short, simple sentences, mostly under 12 words. Use common, everyday words and explain difficult ideas simply."
        case .level2:
            guidance = "Rewrite the article for an intermediate English learner (CEFR B1). Use clear sentences of moderate length and common vocabulary, while keeping the important details."
        case .level3:
            guidance = ""
        }
        return """
        \(guidance)

        Article:
        \(source)
        """
    }

    // MARK: Cloud (OpenAI-compatible)

    private static func cloudRewrite(source: String, level: ReadingLevel, config: AILevelConfig) async -> Outcome {
        guard let url = URL(string: config.provider.baseURL + "/chat/completions") else {
            return .failure("Invalid endpoint for \(config.provider.displayName).")
        }

        let payload: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemInstruction],
                ["role": "user", "content": userPrompt(source: source, level: level)]
            ],
            "temperature": 0.4,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("No response from \(config.provider.displayName).")
            }
            guard (200..<300).contains(http.statusCode) else {
                return .failure("\(config.provider.displayName) error \(http.statusCode): \(snippet(data))")
            }
            guard let content = parseContent(from: data) else {
                return .failure("Couldn't read \(config.provider.displayName) response.")
            }
            let paragraphs = splitParagraphs(content)
            return paragraphs.isEmpty ? .failure("Empty rewrite returned.") : .success(paragraphs)
        } catch {
            return .failure("Network error: \(error.localizedDescription)")
        }
    }

    private static func parseContent(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let choices = object["choices"] as? [[String: Any]],
              let first = choices.first else {
            return nil
        }
        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        // Some providers may return content as an array of segments.
        if let message = first["message"] as? [String: Any],
           let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }

    private static func snippet(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 200 ? String(trimmed.prefix(200)) + "…" : trimmed
    }

    // MARK: On-device (Foundation Models)

    private static func onDeviceRewrite(source: String, level: ReadingLevel) async -> Outcome {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: systemInstruction)
                let response = try await session.respond(to: userPrompt(source: source, level: level))
                let paragraphs = splitParagraphs(response.content)
                return paragraphs.isEmpty ? .failure("Empty on-device rewrite.") : .success(paragraphs)
            } catch {
                return .failure("On-device model error: \(error.localizedDescription)")
            }
        }
        #endif
        return .failure("On-device model unavailable: \(onDeviceAvailabilityDescription())")
    }

    // MARK: Shared parsing

    private static func splitParagraphs(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let byBlankLine = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if byBlankLine.count > 1 {
            return byBlankLine
        }

        return normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
