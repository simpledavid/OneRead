import Foundation

/// Curated AI/tech glossary loaded from `domain_glossary.json`.
///
/// It keeps modern AI and technical terms (tokenizer, agentic, embeddings,
/// acronyms and product names) consistent. It can be extended by editing JSON.
struct DomainGlossaryEntry: Decodable {
    let word: String
    let meaningZh: String
    let phonetic: String?
    let example: String?
    let exampleZh: String?
}

enum DomainGlossary {
    private static let index: [String: DomainGlossaryEntry] = buildIndex()

    static func lookup(candidates: [String]) -> WordLookup? {
        for candidate in candidates where !candidate.isEmpty {
            let collapsed = candidate.replacingOccurrences(of: "-", with: "")
            if let entry = index[candidate] ?? index[collapsed],
               isContextIndependent(entry.word) {
                return WordLookup(
                    word: entry.word,
                    meaningZh: entry.meaningZh,
                    phonetic: entry.phonetic ?? "",
                    example: entry.example ?? "",
                    exampleZh: entry.exampleZh ?? ""
                )
            }
        }
        return nil
    }

    /// Only bypass contextual AI for terms whose spelling identifies the sense:
    /// acronyms (ALS, BCI), exact compounds (brain-computer, open-source), and
    /// distinctive mixed-case/digit product names (OpenAI, GPT-4). Ordinary
    /// lowercase words such as `open`, `model`, `compute`, and `attention` remain
    /// context-sensitive even when they also have a common technical meaning.
    private static func isContextIndependent(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        if (2...10).contains(letters.count), letters.allSatisfy(\.isUppercase) {
            return true
        }
        if word.contains("-") || word.contains(where: \.isNumber) {
            return true
        }
        return word.dropFirst().contains(where: \.isUppercase)
    }

    private static func buildIndex() -> [String: DomainGlossaryEntry] {
        guard let url = Bundle.main.url(forResource: "domain_glossary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DomainGlossaryEntry].self, from: data) else {
            return [:]
        }

        var index: [String: DomainGlossaryEntry] = [:]
        for entry in entries {
            for key in keys(for: entry.word) where index[key] == nil {
                index[key] = entry
            }
        }
        return index
    }

    /// Keys an entry by its lowercased headword and a hyphen-free variant, so an
    /// incoming candidate matches whether or not it kept the hyphen
    /// (e.g. "fine-tune" and "finetune", "GPT-4" and "gpt4").
    private static func keys(for word: String) -> [String] {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let lower = word.lowercased().trimmingCharacters(in: allowed.inverted)
        guard !lower.isEmpty else {
            return []
        }

        let collapsed = lower.replacingOccurrences(of: "-", with: "")
        return collapsed == lower ? [lower] : [lower, collapsed]
    }
}
