import Foundation

/// Curated AI/tech glossary loaded from `domain_glossary.json`.
///
/// ECDICT is broad but misses modern AI jargon (tokenizer, agentic, embeddings)
/// and returns the wrong sense for product/company names (Claude → "克劳德男子名",
/// Gemini → "双生子"). This glossary is consulted *before* ECDICT so the AI-context
/// meaning wins, and it can be extended just by editing the JSON.
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
            if let entry = index[candidate] ?? index[collapsed] {
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
