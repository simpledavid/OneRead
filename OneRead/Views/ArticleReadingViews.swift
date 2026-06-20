import SwiftUI
import CryptoKit
import NaturalLanguage
import Translation
import UIKit

// On-device translation (Apple Translation framework) used to translate any
// paragraph that has no editorial/AI translation — notably the original text and
// freshly fetched articles. Results are cached in memory, keyed by source text.
@MainActor
final class OnDeviceTranslator: ObservableObject {
    @Published private(set) var translations: [String: String] = [:]

    func translate(_ texts: [String], using session: TranslationSession) async {
        let pending = texts.filter { !$0.isEmpty && translations[$0] == nil }
        guard !pending.isEmpty else {
            return
        }
        let requests = pending.map { TranslationSession.Request(sourceText: $0) }
        guard let responses = try? await session.translations(from: requests) else {
            return
        }
        for response in responses {
            translations[response.sourceText] = response.targetText
        }
    }
}

struct ArticleDetailView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ArticleHeroImage(article: article)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    ArticleMetaLine(article: article)

                    Text(article.title)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.subtitle)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                summaryBlock
                keyPointsBlock
                bodyBlock
                originalLinkBlock
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(article.source)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.toggleRead(article)
                } label: {
                    Image(systemName: store.isRead(article) ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .accessibilityLabel(store.isRead(article) ? "Mark as unread" : "Mark as read")

                Button {
                    store.toggleSaved(article)
                } label: {
                    Image(systemName: store.isSaved(article) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(store.isSaved(article) ? "Remove bookmark" : "Save article")
            }
        }
        .onAppear {
            store.markRead(article)
        }
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(article.summary)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .cardBackground()
    }

    private var keyPointsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shadowing lines")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)

            ForEach(article.keyPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        speech.speak(point)
                    } label: {
                        Image(systemName: speech.speakingWord == point ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Read sentence aloud")

                    Text(point)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .padding(18)
        .cardBackground()
    }

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(article.body, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var originalLinkBlock: some View {
        Group {
            if let url = article.url {
                Link(destination: url) {
                    Label("Open original article", systemImage: "safari")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Palette.accent)
                        )
                }
            }
        }
    }
}

struct ArticleFeaturePage: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var subscription: SubscriptionService
    @Binding var isArticleTranslationVisible: Bool
    let article: Article
    let rank: Int
    let pageCount: Int
    let width: CGFloat
    let height: CGFloat
    let readingLevel: ReadingLevel
    let onUpgrade: () -> Void

    @StateObject private var onDeviceTranslator = OnDeviceTranslator()
    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArticleHeroImage(article: article)
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.36), radius: 22, x: 0, y: 14)

            ReadingTitleView(
                title: article.title,
                vocabulary: visibleVocabulary,
                wordMeaningsByContext: article.learningContent?.wordMeaningsByContext ?? [:]
            )
                .padding(.top, 2)

            articleReadingStats

            VStack(alignment: .leading, spacing: 22) {
                if isRewriting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Palette.muted)
                        Text(readingLevel.wordTarget.map { "Condensing to ~\($0) words…" } ?? "Loading…")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                } else if readingLevel != .level3,
                          store.leveledRewrite(for: article, level: readingLevel) == nil,
                          let status = store.leveledStatusMessage(for: article, level: readingLevel) {
                    Text(status)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(visibleLeveledParagraphs.enumerated()), id: \.element.id) { displayIndex, item in
                    LearningParagraphView(
                        paragraph: item.text,
                        translation: translationText(
                            for: item,
                            displayedIndex: displayIndex
                        ),
                        isTranslationVisible: isArticleTranslationVisible,
                        vocabulary: visibleVocabulary,
                        wordMeaningsByContext: article.learningContent?.wordMeaningsByContext ?? [:],
                        context: item.originalText,
                        onToggleTranslation: {}
                    )
                }

                if !hasFullReadingAccess {
                    readingUpgradeCard
                } else if isArticleTranslationVisible,
                          !subscription.isPro,
                          leveledParagraphs.count > ReadingAccessPolicy.freePreviewParagraphCount {
                    translationUpgradeCard
                }

                completionSection
            }
            .padding(.top, 4)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .frame(width: width, alignment: .top)
        .frame(minHeight: height, alignment: .top)
        .background(LensBackground())
        .translationTask(translationConfig) { session in
            await onDeviceTranslator.translate(paragraphsNeedingOnDeviceTranslation, using: session)
        }
        .onAppear {
            store.markRead(article)
            refreshOnDeviceTranslation()
        }
        .onChange(of: isArticleTranslationVisible) { _, _ in
            refreshOnDeviceTranslation()
        }
        .onChange(of: readingLevel) { _, _ in
            refreshOnDeviceTranslation()
        }
    }

    // Kicks off on-device translation for any visible paragraph that lacks a
    // built-in translation (original text, fetched articles, AI rewrites without
    // a translation). No-op when everything is already covered.
    private func refreshOnDeviceTranslation() {
        guard isArticleTranslationVisible, !paragraphsNeedingOnDeviceTranslation.isEmpty else {
            return
        }
        if translationConfig == nil {
            translationConfig = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "zh-Hans")
            )
        } else {
            translationConfig?.invalidate()
        }
    }

    private var paragraphsNeedingOnDeviceTranslation: [String] {
        let builtIn = builtInTranslations(for: readingLevel)
        return visibleLeveledParagraphs.compactMap { item in
            if builtIn.indices.contains(item.originalIndex),
               !builtIn[item.originalIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    private var imageHeight: CGFloat {
        176
    }

    private var contentWidth: CGFloat {
        max(width - 40, 1)
    }

    private var articleReadingStats: some View {
        HStack(spacing: 16) {
            Text(article.publishedDateTimeText)
            Text("\(wordCount) words")
            Text("\(readingMinutes) mins")
            Spacer(minLength: 6)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(Palette.muted)
        .lineLimit(1)
    }

    private var wordCount: Int {
        leveledParagraphs
            .map(\.text)
            .joined(separator: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .count
    }

    private var readingMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 75.0)))
    }

    private var leveledParagraphs: [LeveledParagraph] {
        ArticleLevelAdapter.paragraphs(
            for: article,
            level: readingLevel,
            rewritten: store.leveledRewrite(for: article, level: readingLevel)
        )
    }

    private var visibleLeveledParagraphs: [LeveledParagraph] {
        ReadingAccessPolicy.visibleParagraphs(
            from: leveledParagraphs,
            level: readingLevel,
            articleRank: rank,
            isPro: subscription.isPro
        )
    }

    private var visibleVocabulary: [ArticleVocabulary] {
        ReadingAccessPolicy.visibleVocabulary(
            from: article.effectiveVocabulary,
            isPro: subscription.isPro
        )
    }

    private var hasFullReadingAccess: Bool {
        ReadingAccessPolicy.hasFullReadingAccess(
            level: readingLevel,
            articleRank: rank,
            isPro: subscription.isPro
        )
    }

    private var isRewriting: Bool {
        guard article.learningContent == nil else {
            return false
        }
        return store.isGeneratingLevel(for: article, level: readingLevel)
            && store.leveledRewrite(for: article, level: readingLevel) == nil
    }

    private func builtInTranslations(for level: ReadingLevel) -> [String] {
        switch level {
        case .level1:
            return article.learningContent?.easy.paragraphTranslations ?? []
        case .level2:
            return article.learningContent?.standard.paragraphTranslations ?? []
        case .level3:
            return article.paragraphTranslations
        }
    }

    private func translationText(for item: LeveledParagraph, displayedIndex: Int) -> String? {
        guard ReadingAccessPolicy.canShowTranslation(
            paragraphIndex: displayedIndex,
            isPro: subscription.isPro
        ) else {
            return nil
        }

        let builtIn = builtInTranslations(for: readingLevel)
        if builtIn.indices.contains(item.originalIndex),
           !builtIn[item.originalIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return builtIn[item.originalIndex]
        }

        // Fall back to the on-device translation, keyed by the displayed text.
        let key = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return onDeviceTranslator.translations[key]
    }

    private var readingUpgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(readingLevel.title) preview", systemImage: "lock.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("The first paragraph is free. Switch to Original to keep reading the full source article, or unlock every AI learning version with Pro.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            upgradeButton
        }
        .padding(18)
        .cardBackground()
    }

    private var translationUpgradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Translation preview", systemImage: "character.bubble")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("The first paragraph translation is free. Pro reveals translations for the complete article.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            upgradeButton
        }
        .padding(18)
        .cardBackground()
    }

    private var upgradeButton: some View {
        Button(action: onUpgrade) {
            HStack {
                Spacer()
                Text("Unlock OneRead Pro")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.background)
                Spacer()
            }
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.accent)
            )
        }
        .buttonStyle(.plain)
    }

    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.completeArticle(article)
            } label: {
                Label(
                    store.isCompleted(article) ? "Completed" : "Finish this read",
                    systemImage: store.isCompleted(article) ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(store.isCompleted(article) ? Color.green : Palette.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(store.isCompleted(article) ? Palette.surfaceRaised : Palette.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(store.isCompleted(article) ? Color.green.opacity(0.5) : Palette.accent, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isCompleted(article))
        }
        .padding(.top, 8)
    }

}

private struct ReadingTitleView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var selectedLookup: WordLookup?
    @State private var selectedTokenID: Int?
    let title: String
    let vocabulary: [ArticleVocabulary]
    let wordMeaningsByContext: [String: [String: String]]

    var body: some View {
        let savedCandidates = SavedWordHighlighter.candidateSet(for: store.savedWords)
        InlineWordFlowLayout(horizontalSpacing: 3, verticalSpacing: 2) {
            ForEach(tokens, id: \.id) { token in
                InteractiveWordTokenView(
                    token: token,
                    isHighlighted: isHighlightedToken(token, savedCandidates: savedCandidates),
                    font: .system(size: titleFontSize, weight: .bold, design: .rounded)
                ) {
                    store.triggerImpact()
                    selectedTokenID = token.id
                    selectedLookup = WordLookupResolver.lookup(
                        rawWord: token.lookup,
                        vocabulary: vocabulary,
                        wordMeaningsByContext: wordMeaningsByContext,
                        context: title
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $selectedLookup, onDismiss: { selectedTokenID = nil }) { lookup in
            WordLookupSheet(
                lookup: lookup,
                onBookmarkChange: { _ in }
            )
                .presentationDetents([.height(270), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .presentationBackground(Palette.surface)
        }
    }

    private func isHighlightedToken(_ token: WordToken, savedCandidates: Set<String>) -> Bool {
        if token.id == selectedTokenID {
            return true
        }
        return SavedWordHighlighter.isSaved(rawWord: token.lookup, in: savedCandidates)
    }

    private var titleFontSize: CGFloat {
        switch title.count {
        case ...34:
            return 20
        case 35...52:
            return 18
        case 53...72:
            return 17
        default:
            return 16
        }
    }

    private var tokens: [WordToken] {
        let pieces = title.split(separator: " ", omittingEmptySubsequences: false)
        return pieces.enumerated().map { index, value in
            let display = index == pieces.count - 1 ? String(value) : "\(value) "
            return WordToken(id: index, display: display, lookup: String(value))
        }
    }

}

struct LearningParagraphView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var selectedLookup: WordLookup?
    @State private var selectedTokenID: Int?
    let paragraph: String
    let translation: String?
    let isTranslationVisible: Bool
    let vocabulary: [ArticleVocabulary]
    let wordMeaningsByContext: [String: [String: String]]
    let context: String
    let onToggleTranslation: () -> Void

    var body: some View {
        let savedCandidates = SavedWordHighlighter.candidateSet(for: store.savedWords)
        VStack(alignment: .leading, spacing: 8) {
            InlineWordFlowLayout(horizontalSpacing: 3, verticalSpacing: 5) {
                ForEach(tokens, id: \.id) { token in
                    InteractiveWordTokenView(
                        token: token,
                        isHighlighted: isHighlightedToken(token, savedCandidates: savedCandidates)
                    ) {
                        store.triggerImpact()
                        selectedTokenID = token.id
                        selectedLookup = lookup(token.lookup)
                    }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(item: $selectedLookup, onDismiss: { selectedTokenID = nil }) { lookup in
                WordLookupSheet(
                    lookup: lookup,
                    onBookmarkChange: { _ in }
                )
                    .presentationDetents([.height(270), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(28)
                    .presentationBackground(Palette.surface)
            }

            if isTranslationVisible, let translation, !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Palette.accent.opacity(0.28))
                            .frame(width: 3)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isTranslationVisible)
    }

    private var tokens: [WordToken] {
        paragraph
            .split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, value in
                let display = index == paragraph.split(separator: " ", omittingEmptySubsequences: false).count - 1
                    ? String(value)
                    : "\(value) "
                return WordToken(id: index, display: display, lookup: String(value))
            }
    }

    private func lookup(_ rawWord: String) -> WordLookup {
        WordLookupResolver.lookup(
            rawWord: rawWord,
            vocabulary: vocabulary,
            wordMeaningsByContext: wordMeaningsByContext,
            context: context
        )
    }

    private func isHighlightedToken(_ token: WordToken, savedCandidates: Set<String>) -> Bool {
        if token.id == selectedTokenID {
            return true
        }
        return SavedWordHighlighter.isSaved(rawWord: token.lookup, in: savedCandidates)
    }
}

private struct WordToken: Identifiable {
    let id: Int
    let display: String
    let lookup: String
}

private struct InteractiveWordTokenView: View {
    let token: WordToken
    let isHighlighted: Bool
    var font: Font = .system(size: 16, weight: .regular, design: .rounded)
    let onTap: () -> Void

    var body: some View {
        Text(token.display)
            .font(font)
            .fontWeight(isHighlighted ? .bold : nil)
            .foregroundStyle(isHighlighted ? Palette.accent : Palette.ink)
            .fixedSize()
            .onTapGesture(perform: onTap)
    }
}

struct LeveledParagraph: Identifiable {
    let id: String
    let originalIndex: Int
    let text: String
    let originalText: String
}

enum ArticleLevelAdapter {
    static func paragraphs(for article: Article, level: ReadingLevel, rewritten: [String]? = nil) -> [LeveledParagraph] {
        if let preGenerated = preGeneratedParagraphs(for: article, level: level),
           !preGenerated.isEmpty {
            return preGenerated.enumerated().map { index, text in
                LeveledParagraph(
                    id: "editorial-\(level.rawValue)-\(index)",
                    originalIndex: index,
                    text: text,
                    originalText: text
                )
            }
        }

        if let rewritten, !rewritten.isEmpty {
            return rewritten.enumerated().map { index, text in
                LeveledParagraph(
                    id: "ai-\(level.rawValue)-\(index)",
                    originalIndex: index,
                    text: text,
                    originalText: text
                )
            }
        }

        let bodyParagraphs = article.body
            .filter { $0 != "Vocabulary:" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let source = bodyParagraphs.isEmpty ? fallbackParagraphs(for: article) : bodyParagraphs

        let budget = wordBudget(for: level)
        var output: [LeveledParagraph] = []
        var usedWords = 0

        for (index, paragraph) in source.enumerated() {
            if let budget, usedWords >= budget, !output.isEmpty {
                break
            }

            let text = simplify(paragraph, level: level)
            guard !text.isEmpty else {
                continue
            }

            output.append(
                LeveledParagraph(
                    id: "\(level.rawValue)-\(index)",
                    originalIndex: index,
                    text: text,
                    originalText: paragraph
                )
            )
            usedWords += wordCount(text)
        }

        return output
    }

    private static func preGeneratedParagraphs(
        for article: Article,
        level: ReadingLevel
    ) -> [String]? {
        switch level {
        case .level1:
            return article.learningContent?.easy.paragraphs
        case .level2:
            return article.learningContent?.standard.paragraphs
        case .level3:
            return nil
        }
    }

    /// Local fallback length used when no editorial or personal rewrite exists:
    /// Easy/Standard trim toward their word target; Original shows everything.
    private static func wordBudget(for level: ReadingLevel) -> Int? {
        level.wordTarget
    }

    private static func fallbackParagraphs(for article: Article) -> [String] {
        let summary = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return [summary]
        }
        let subtitle = article.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return subtitle.isEmpty ? [] : [subtitle]
    }

    /// Rewrites a paragraph for the target reading level.
    /// Level 3 keeps the original sentences; lower levels break compound
    /// sentences into shorter, simpler ones, and Level 1 also drops asides.
    private static func simplify(_ paragraph: String, level: ReadingLevel) -> String {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard level != .level3 else { return trimmed }

        var text = trimmed
        if level == .level1 {
            text = removingAsides(text)
        }

        for marker in clauseBreakers(for: level) {
            text = text.replacingOccurrences(of: marker, with: ". ", options: [.caseInsensitive])
        }

        text = normalizeWhitespace(text)
        if let last = text.last, !".!?".contains(last) {
            text.append(".")
        }
        return capitalizeAfterBreaks(text)
    }

    /// Coordinate conjunctions and separators that join independent clauses,
    /// safe to convert into separate sentences. Level 1 splits more aggressively.
    private static func clauseBreakers(for level: ReadingLevel) -> [String] {
        switch level {
        case .level1:
            return ["; ", " — ", " – ", ", but ", ", so ", ", because ", ", although ", ", while "]
        case .level2:
            return ["; ", " — ", " – ", ", but ", ", so "]
        case .level3:
            return []
        }
    }

    private static func removingAsides(_ text: String) -> String {
        var result = ""
        var depth = 0
        for character in text {
            switch character {
            case "(", "[":
                depth += 1
            case ")", "]":
                if depth > 0 { depth -= 1 }
            default:
                if depth == 0 { result.append(character) }
            }
        }
        return result
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: " .", with: ".")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        while result.contains(". .") {
            result = result.replacingOccurrences(of: ". .", with: ".")
        }
        while result.contains("..") {
            result = result.replacingOccurrences(of: "..", with: ".")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Capitalizes the first letter of the text and the first letter after each
    /// sentence terminator. Never inserts breaks, so numbers stay intact.
    private static func capitalizeAfterBreaks(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        for character in text {
            if capitalizeNext, character.isLetter {
                result.append(Character(character.uppercased()))
                capitalizeNext = false
            } else {
                result.append(character)
            }

            if character == "." || character == "!" || character == "?" {
                capitalizeNext = true
            } else if character.isLetter || character.isNumber {
                capitalizeNext = false
            }
        }
        return result
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
    }
}

struct WordLookup: Identifiable {
    let id = UUID()
    let word: String
    let meaningZh: String
    var phonetic: String = ""
    let example: String
    let exampleZh: String
    var context: String = ""
    var needsAI: Bool = false
}

enum WordLookupResolver {
    static func lookup(
        rawWord: String,
        vocabulary: [ArticleVocabulary],
        wordMeaningsByContext: [String: [String: String]] = [:],
        context: String
    ) -> WordLookup {
        let candidates = rawWord.lookupCandidates

        // Acronyms are highly context-sensitive. Prefer a curated expansion
        // (ALS, BCI, API...) before broad dictionaries that may return an
        // unrelated expansion for the same letters.
        if isUppercaseAcronym(rawWord),
           var match = DomainGlossary.lookup(candidates: candidates) {
            match.context = context
            return match
        }

        if let match = vocabulary.first(where: {
            vocabularyEntry($0, matches: rawWord, candidates: candidates, context: context)
        }) {
            return WordLookup(
                word: match.word,
                meaningZh: match.meaningZh,
                phonetic: match.phonetic,
                example: match.example,
                exampleZh: match.exampleZh,
                context: context,
                needsAI: match.meaningZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        if let meaning = contextualMeaning(
            candidates: candidates,
            context: context,
            wordMeaningsByContext: wordMeaningsByContext
        ) {
            return WordLookup(
                word: rawWord.cleanedDisplayWord,
                meaningZh: meaning,
                example: "",
                exampleZh: "",
                context: context,
                needsAI: false
            )
        }

        // Curated AI/tech glossary keeps established terminology consistent
        // (Claude, Gemini, token, agent…) without re-translating it.
        if var match = DomainGlossary.lookup(candidates: candidates) {
            match.context = context
            return match
        }

        // Unknown acronyms are resolved from their sentence by the on-device AI.
        if isUppercaseAcronym(rawWord) {
            return WordLookup(
                word: rawWord.cleanedDisplayWord,
                meaningZh: "缩写（需结合上下文理解）",
                example: "",
                exampleZh: "",
                context: context,
                needsAI: true
            )
        }

        // The paragraph translation is AI-generated but has no word alignment.
        // Ask the on-device model for this word's meaning in the source sentence
        // instead of letting a context-free dictionary choose a different sense.
        return fallbackLookup(rawWord: rawWord, context: context)
    }

    private static func contextualMeaning(
        candidates: [String],
        context: String,
        wordMeaningsByContext: [String: [String: String]]
    ) -> String? {
        guard !wordMeaningsByContext.isEmpty else {
            return nil
        }
        let normalizedContext = context
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalizedContext.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        guard let meanings = wordMeaningsByContext[digest] else {
            return nil
        }
        for candidate in candidates {
            let key = candidate
                .lowercased()
                .replacingOccurrences(of: "’", with: "'")
                .trimmingCharacters(in: CharacterSet(charactersIn: "'- "))
            if let meaning = meanings[key], !meaning.isEmpty {
                return meaning
            }
        }
        return nil
    }

    private static func vocabularyEntry(
        _ entry: ArticleVocabulary,
        matches rawWord: String,
        candidates: [String],
        context: String
    ) -> Bool {
        let headword = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryCandidates = headword.lookupCandidates
        guard let rawPrimary = candidates.first, let entryPrimary = entryCandidates.first else {
            return false
        }

        // A multi-word term cannot be tapped as one token. Let its first word
        // open the full phrase only when that exact phrase exists in this
        // paragraph; never let another component match elsewhere by accident.
        if headword.contains(where: \.isWhitespace) {
            guard rawPrimary == entryPrimary else {
                return false
            }
            return context.range(
                of: headword,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }

        // Hyphenated compounds are visible and tappable as one token. Require
        // the complete compound, while accepting a hyphen-free spelling variant.
        if headword.contains("-") {
            let collapsedRaw = rawPrimary.replacingOccurrences(of: "-", with: "")
            let collapsedEntry = entryPrimary.replacingOccurrences(of: "-", with: "")
            return collapsedRaw == collapsedEntry
        }

        // Single words may match an inflected form through the normalizer
        // (`models` → `model`, `powered` → `power`).
        return candidates.contains(where: entryCandidates.contains)
    }

    private static func isUppercaseAcronym(_ rawWord: String) -> Bool {
        let cleaned = rawWord.cleanedDisplayWord
        let letters = cleaned.filter(\.isLetter)
        return (2...8).contains(letters.count)
            && letters.allSatisfy(\.isUppercase)
    }

    /// Guarantees a tap always yields something useful, even for a word in no
    /// offline source. Names get a "proper noun" label; anything else is marked
    /// `needsAI` so the sheet can try the on-device model when it is available.
    private static func fallbackLookup(rawWord: String, context: String) -> WordLookup {
        let display = rawWord.cleanedDisplayWord.isEmpty ? rawWord : rawWord.cleanedDisplayWord
        let meaning = isLikelyProperNoun(rawWord, context: context)
            ? "专有名词（可能是公司、产品、人名或地名）"
            : ""
        return WordLookup(
            word: display,
            meaningZh: meaning,
            phonetic: "",
            example: "",
            exampleZh: "",
            context: context,
            needsAI: true
        )
    }

    private static func isLikelyProperNoun(_ rawWord: String, context: String) -> Bool {
        let cleaned = rawWord.cleanedDisplayWord
        guard let first = cleaned.first, first.isUppercase else {
            return false
        }

        // Internal capital (OpenAI, DeepSeek) is a strong brand signal.
        if cleaned.dropFirst().contains(where: { $0.isUppercase }) {
            return true
        }

        // A single leading capital counts as a name only when it is not the start
        // of a sentence or title, which capitalize ordinary words too.
        guard let range = context.range(of: rawWord) else {
            return true
        }
        let preceding = context[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        if preceding.isEmpty {
            return false
        }
        if let last = preceding.last, ".!?:".contains(last) {
            return false
        }
        return true
    }
}

struct WordLookupSheet: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    @EnvironmentObject private var subscription: SubscriptionService
    let lookup: WordLookup
    var onBookmarkChange: ((Bool) -> Void)? = nil
    @State private var enrichedMeaning: String?
    @State private var isEnriching = false
    @State private var isPaywallPresented = false

    var body: some View {
        ZStack {
            Palette.surface
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Capsule(style: .continuous)
                        .fill(Palette.border)
                        .frame(width: 54, height: 5)
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(displayWord)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(Palette.accent)

                            if !currentPhonetic.isEmpty {
                                Text(currentPhonetic)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.ink.opacity(0.78))
                            }
                        }

                        Spacer(minLength: 8)

                        wordToolButton(
                            systemName: speech.isSpeaking(displayWord) ? "stop.fill" : "speaker.wave.2.fill",
                            accessibilityLabel: "Pronounce \(displayWord)"
                        ) {
                            speech.speak(displayWord)
                        }

                        wordToolButton(
                            systemName: bookmarkSystemName,
                            accessibilityLabel: bookmarkAccessibilityLabel
                        ) {
                            handleBookmarkTap()
                        }
                    }

                    definitionContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
        .task(id: lookup.id) {
            if !speech.isSpeaking(displayWord) {
                speech.speak(displayWord)
            }
            await enrichIfNeeded()
        }
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                OneReadProView()
            }
            .environmentObject(subscription)
        }
    }

    @ViewBuilder
    private var definitionContent: some View {
        if !currentMeaning.isEmpty {
            Text(currentMeaning)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .lineSpacing(6)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else if isEnriching {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Palette.accent)
                Text("正在结合上下文生成释义…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        } else {
            Text("暂无释义，可点击发音按钮朗读。")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
    }

    private func enrichIfNeeded() async {
        guard lookup.needsAI, ArticleLevelService.isOnDeviceAvailable else {
            return
        }

        if let cached = await WordEnrichmentService.shared.cachedMeaning(
            for: displayWord,
            context: lookup.context
        ) {
            if !cached.isEmpty {
                enrichedMeaning = cached
            }
            return
        }

        isEnriching = true
        let result = await WordEnrichmentService.shared.meaning(for: displayWord, context: lookup.context)
        isEnriching = false
        if let result, !result.isEmpty {
            enrichedMeaning = result
            if store.isSavedWord(displayWord) {
                store.updateSavedWord(
                    displayWord,
                    meaningZh: result,
                    phonetic: lookup.phonetic,
                    example: lookup.example,
                    exampleZh: lookup.exampleZh,
                    context: lookup.context
                )
            }
        }
    }

    private var currentMeaning: String {
        if let enrichedMeaning, !enrichedMeaning.isEmpty {
            return enrichedMeaning
        }
        return lookup.meaningZh
    }

    private func wordToolButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }


    private var currentPhonetic: String {
        lookup.phonetic
    }

    private var bookmarkSystemName: String {
        store.isSavedWord(displayWord) ? "bookmark.fill" : "bookmark"
    }

    private var bookmarkAccessibilityLabel: String {
        if store.isSavedWord(displayWord) {
            return "Remove saved word"
        }
        if canSaveNewWord {
            return "Save word"
        }
        return "Save more words with OneRead Pro"
    }

    private var canSaveNewWord: Bool {
        ReadingAccessPolicy.canSaveWord(
            savedCount: store.savedWords.count,
            isPro: subscription.isPro
        )
    }

    private func handleBookmarkTap() {
        if store.isSavedWord(displayWord) {
            store.toggleSavedWord(displayWord)
            onBookmarkChange?(false)
            return
        }

        if canSaveNewWord {
            store.toggleSavedWord(
                displayWord,
                meaningZh: enrichedMeaning ?? (lookup.needsAI ? "" : lookup.meaningZh),
                phonetic: lookup.phonetic,
                example: lookup.example,
                exampleZh: lookup.exampleZh,
                context: lookup.context
            )
            onBookmarkChange?(true)
        } else {
            isPaywallPresented = true
        }
    }

    private var displayWord: String {
        let cleaned = lookup.word.cleanedDisplayWord
        return cleaned.isEmpty ? lookup.word : cleaned
    }

}

struct InlineWordFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(1, proposal.width ?? 320)
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = min(size.width, width)
            if rowWidth + itemWidth > width, rowWidth > 0 {
                totalHeight += rowHeight + verticalSpacing
                maxWidth = max(maxWidth, rowWidth)
                rowWidth = itemWidth + horizontalSpacing
                rowHeight = size.height
            } else {
                rowWidth += itemWidth + horizontalSpacing
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        maxWidth = max(maxWidth, rowWidth)
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0
        let maxWidth = max(1, bounds.width)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = min(size.width, maxWidth)
            if point.x + itemWidth > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: point,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: itemWidth, height: size.height)
            )
            point.x += itemWidth + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}


extension String {
    var cleanedLookupWord: String {
        lookupCandidates.first ?? ""
    }

    var lookupCandidates: [String] {
        LookupNormalizer.candidates(for: self)
    }

    var cleanedDisplayWord: String {
        trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}

/// Decides whether a word token should show the "saved" highlight, driven by the
/// persisted saved-words list (so highlights survive relaunching the app/article)
/// rather than ephemeral per-session token IDs. Matching goes through the same
/// lemma-aware candidates used for saving, so inflected forms still match.
enum SavedWordHighlighter {
    static func candidateSet(for savedWords: [String]) -> Set<String> {
        var set = Set<String>()
        for word in savedWords {
            for candidate in word.lookupCandidates {
                set.insert(candidate)
            }
        }
        return set
    }

    static func isSaved(rawWord: String, in candidateSet: Set<String>) -> Bool {
        guard !candidateSet.isEmpty else {
            return false
        }
        return rawWord.lookupCandidates.contains(where: candidateSet.contains)
    }
}

private enum LookupNormalizer {
    static func candidates(for rawWord: String) -> [String] {
        let lowered = rawWord
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")

        let chunks = lowered
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'" || $0 == "-") })
            .map(String.init)

        var ordered: [String] = []
        var seen = Set<String>()

        func append(_ candidate: String) {
            let normalized = candidate
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "'- "))
            guard !normalized.isEmpty else {
                return
            }
            guard seen.insert(normalized).inserted else {
                return
            }
            ordered.append(normalized)
        }

        for chunk in chunks {
            append(chunk)

            if chunk.contains("-") {
                chunk.split(separator: "-").map(String.init).forEach(append)
            }

            let deapostrophed = chunk.replacingOccurrences(of: "'", with: "")
            if deapostrophed != chunk {
                append(deapostrophed)
            }

            if let lemma = lemma(for: chunk) {
                append(lemma)
            }

            if deapostrophed != chunk, let lemma = lemma(for: deapostrophed) {
                append(lemma)
            }

            inflectionRoots(for: chunk).forEach(append)
            inflectionRoots(for: deapostrophed).forEach(append)
        }

        return ordered
    }

    private static func lemma(for word: String) -> String? {
        guard !word.isEmpty else {
            return nil
        }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let lemma = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0?.rawValue

        guard let lemma, !lemma.isEmpty else {
            return nil
        }

        let cleaned = lemma.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "'- "))
        guard !cleaned.isEmpty, cleaned != word.lowercased() else {
            return nil
        }

        return cleaned
    }

    private static func inflectionRoots(for word: String) -> [String] {
        guard word.count > 3 else {
            return []
        }

        var roots: [String] = []

        if word.hasSuffix("'s") {
            roots.append(String(word.dropLast(2)))
        }

        if word.hasSuffix("s'") {
            roots.append(String(word.dropLast()))
        }

        if word.hasSuffix("ies"), word.count > 4 {
            roots.append(String(word.dropLast(3)) + "y")
        }

        if word.hasSuffix("ied"), word.count > 4 {
            roots.append(String(word.dropLast(3)) + "y")
        }

        if word.hasSuffix("ing"), word.count > 5 {
            let stem = String(word.dropLast(3))
            roots.append(stem)
            roots.append(stem + "e")
        }

        if word.hasSuffix("ed"), word.count > 4 {
            let stem = String(word.dropLast(2))
            roots.append(stem)
            roots.append(stem + "e")
        }

        if word.hasSuffix("es"), word.count > 4 {
            roots.append(String(word.dropLast(2)))
        }

        if word.hasSuffix("s"), word.count > 3 {
            roots.append(String(word.dropLast()))
        }

        return roots
    }
}
