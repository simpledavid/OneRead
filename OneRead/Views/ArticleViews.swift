import SwiftUI
import NaturalLanguage
import UIKit

enum ReadingLevel: Int, CaseIterable, Identifiable {
    case level1 = 1
    case level2 = 2
    case level3 = 3

    /// Only Standard + Original are offered. `level1` (Easy) is retained for
    /// backward compatibility with persisted values but is never shown.
    static var allCases: [ReadingLevel] { [.level2, .level3] }

    var id: Int { rawValue }

    /// Standard is the editorial learning version; Original keeps the cleaned
    /// source article.
    var title: String {
        switch self {
        case .level1: return "Easy"
        case .level2: return "Standard"
        case .level3: return "Original"
        }
    }

    /// Approximate length, in words, for the AI-condensed version.
    /// `nil` means the original article is shown unchanged (no AI needed).
    var wordTarget: Int? {
        switch self {
        case .level1: return 100
        case .level2: return 100
        case .level3: return nil
        }
    }
}

struct ArticleTodayView: View {
    @EnvironmentObject private var store: ArticleStore

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        homeHeader
                        dailyProgressCard

                        if let first = visibleArticles.first {
                            NavigationLink {
                                ArticleReadingView(
                                    article: first,
                                    rank: 1,
                                    pageCount: min(visibleArticles.count, 2),
                                    initialLevel: .level2
                                )
                            } label: {
                                ArticleHomeCard(
                                    article: first,
                                    rank: 1
                                )
                            }
                            .id("home-feature-\(first.id)")
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { store.triggerImpact() })
                        }

                        if visibleArticles.count > 1 {
                            ForEach(Array(visibleArticles.dropFirst().prefix(1).enumerated()), id: \.element.id) { index, article in
                                NavigationLink {
                                    ArticleReadingView(
                                        article: article,
                                        rank: index + 2,
                                        pageCount: min(visibleArticles.count, 2),
                                        initialLevel: .level2
                                    )
                                } label: {
                                    ArticleHomeCard(
                                        article: article,
                                        rank: index + 2
                                    )
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { store.triggerImpact() })
                            }
                        } else if visibleArticles.isEmpty {
                            emptyState
                        }
                    }
                    .frame(width: homeContentWidth(for: proxy.size.width), alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .padding(.bottom, 112)
                }
                .background(LensBackground())
                .overlay(alignment: .bottom) {
                    if let error = store.refreshErrorMessage {
                        Text(error)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                            .padding(.bottom, 14)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.refreshDailyEditionIfNeeded()
            }
        }
    }

    private func homeContentWidth(for screenWidth: CGFloat) -> CGFloat {
        min(max(screenWidth - 40, 0), 560)
    }

    private var homeHeader: some View {
        Text("OneRead")
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var visibleArticles: [Article] {
        store.dailyArticles
    }

    private var dailyProgressCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Palette.border, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: store.todayProgress)
                    .stroke(
                        store.isTodayComplete ? Color.green : Palette.accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: store.isTodayComplete ? "checkmark" : "book.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(store.isTodayComplete ? Color.green : Palette.ink)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.isTodayComplete ? "Today's learning is complete" : "\(store.todayGoalProgressCount) of \(store.dailyGoalTarget) reads completed")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(store.isTodayComplete ? "Come back tomorrow for the next edition" : "Complete one article to finish today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()
        }
        .padding(16)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(store.todayGoalProgressCount) of \(store.dailyGoalTarget) completed")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath" : "newspaper")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Text(store.isRefreshing ? "Fetching latest stories" : "No articles yet")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text(store.isRefreshing ? "Loading real news images from RSS." : "Pull to reopen later, or check your network.")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardBackground()
    }
}

struct ArticleHomeCard: View {
    @EnvironmentObject private var store: ArticleStore
    let article: Article
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: rank == 1 ? 12 : 11) {
            ArticleHeroImage(article: article)
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )

            HStack {
                Text(displayDate)
                Spacer()
                if store.isCompleted(article) {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text(article.source)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.muted)

            Text(article.title)
                .font(.system(size: rank == 1 ? 20 : 17, weight: .bold, design: .rounded))
                .lineSpacing(2)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(rank == 1 ? 3 : 2)

            Text(cardSubtitle)
                .font(.system(size: rank == 1 ? 15 : 14, weight: .medium, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
        }
        .padding(rank == 1 ? 16 : 14)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayDate). \(article.title)")
        .accessibilityValue(store.isCompleted(article) ? "Completed" : "\(article.readingMinutes) minute read")
    }

    private var displayDate: String {
        store.homeReleaseDateText(for: article, displayRank: rank)
    }

    private var cardSubtitle: String {
        let trimmed = article.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(article.source) · RSS reading"
        }

        return trimmed
    }
}

struct ArticleReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var readingLevel: ReadingLevel
    @State private var isArticleTranslationVisible = false
    @State private var appliedInitialTranslationPreference = false
    @State private var isPaywallPresented = false
    let article: Article
    let rank: Int
    let pageCount: Int

    init(article: Article, rank: Int, pageCount: Int, initialLevel: ReadingLevel) {
        self.article = article
        self.rank = rank
        self.pageCount = pageCount
        _readingLevel = State(initialValue: initialLevel)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ArticleFeaturePage(
                    isArticleTranslationVisible: $isArticleTranslationVisible,
                    article: article,
                    rank: rank,
                    pageCount: pageCount,
                    width: proxy.size.width,
                    height: proxy.size.height,
                    readingLevel: readingLevel,
                    onUpgrade: {
                        isPaywallPresented = true
                    }
                )
            }
            .frame(width: proxy.size.width)
            .clipped()
            .background(LensBackground())
            .safeAreaInset(edge: .top, spacing: 0) {
                readingTopBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                OneReadProView()
            }
            .environmentObject(subscription)
        }
        .onAppear {
            store.requestLeveledContent(for: article, level: readingLevel)
            store.trackReadingLevel(readingLevel, for: article)
            guard !appliedInitialTranslationPreference else {
                return
            }
            isArticleTranslationVisible = store.showArticleTranslationsEnabled
            appliedInitialTranslationPreference = true
        }
        .onChange(of: readingLevel) { _, newLevel in
            store.triggerImpact()
            store.requestLeveledContent(for: article, level: newLevel)
            store.trackReadingLevel(newLevel, for: article)
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var readingTopBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close reader")

            Picker("Reading level", selection: $readingLevel) {
                ForEach(ReadingLevel.allCases) { level in
                    Text(level.title)
                        .tag(level)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Reading level")

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isArticleTranslationVisible.toggle()
                }
            } label: {
                Image(systemName: isArticleTranslationVisible ? "character.bubble.fill" : "character.bubble")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isArticleTranslationVisible ? Palette.accent : Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isArticleTranslationVisible ? "Hide translations" : "Show translations")

            Button {
                speech.speak(speakableText)
            } label: {
                Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(isSpeaking ? Palette.accent : Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSpeaking ? "Stop reading aloud" : "Read article aloud")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(Palette.border)
        }
    }

    private var isSpeaking: Bool {
        speech.isSpeaking(speakableText)
    }

    private var speakableText: String {
        ([article.title] + readingParagraphs.map(\.text)).joined(separator: ". ")
    }

    private var readingParagraphs: [LeveledParagraph] {
        let paragraphs = ArticleLevelAdapter.paragraphs(
            for: article,
            level: readingLevel,
            rewritten: store.leveledRewrite(for: article, level: readingLevel)
        )
        return ReadingAccessPolicy.visibleParagraphs(
            from: paragraphs,
            level: readingLevel,
            articleRank: rank,
            isPro: subscription.isPro
        )
    }
}

private struct ReadingWaveform: View {
    let isActive: Bool
    private let bars: [CGFloat] = [8, 18, 13, 24, 16, 30, 18, 24, 13, 20, 9, 26, 15, 22, 11, 28, 18, 24, 12, 20, 10, 25, 14, 22, 11, 18, 8, 24, 14, 20, 10, 26, 16, 22, 12, 18, 9, 24, 14, 20]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                Capsule(style: .continuous)
                    .fill(color(for: index))
                    .frame(width: 3, height: height)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .accessibilityHidden(true)
    }

    private func color(for index: Int) -> Color {
        isActive ? Palette.accent.opacity(0.9) : Color(red: 0.145, green: 0.165, blue: 0.220)
    }
}

struct SavedArticlesView: View {
    var body: some View {
        NavigationStack {
            SavedArticlesScreen()
        }
    }
}

struct SavedArticlesScreen: View {
    @EnvironmentObject private var store: ArticleStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.savedArticles.isEmpty {
                    emptyState
                } else {
                    ForEach(store.savedArticles) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            ArticleListCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Saved Articles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Text("No saved articles yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Save a story from the reading page and it will show up here.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .cardBackground()
    }
}

private enum SavedWordShelf: String, CaseIterable, Identifiable {
    case learning = "Learning"
    case known = "Known"

    var id: String { rawValue }
}

struct SavedWordsView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    @State private var selectedShelf: SavedWordShelf = .learning
    @State private var selectedLookup: WordLookup?
    @State private var isReviewing = false
    private let listAnchor = "saved-words-list"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        wordsHeader
                        reviewWordsHero {
                            if store.learningWords.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(listAnchor, anchor: .top)
                                }
                            } else {
                                store.triggerImpact()
                                isReviewing = true
                            }
                        }
                        shelfControls
                        wordsListSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 42)
                    .padding(.bottom, 112)
                }
            }
            .background(LensBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedLookup) { lookup in
                WordLookupSheet(lookup: lookup)
                    .presentationDetents([.height(270), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(28)
                    .presentationBackground(Palette.surface)
            }
            .fullScreenCover(isPresented: $isReviewing) {
                WordReviewView(words: store.learningWords)
            }
        }
    }

    private var wordsHeader: some View {
        HStack {
            Spacer()
            Text("Words")
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Spacer()
        }
        .frame(height: 46)
    }

    private func reviewWordsHero(action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Review Your Words")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("Review words you’ve learned to help remember them better.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Palette.amber, Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 4) {
                        Text("A")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Z")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.black.opacity(0.18))
                }
                .frame(width: 88, height: 88)
            }

            Button(action: action) {
                Text(displayedWords.isEmpty ? "Start Saving Words" : "Review Words")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.amber, Palette.accent],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .cardBackground()
    }

    private var shelfControls: some View {
        HStack(spacing: 14) {
            HStack(spacing: 0) {
                ForEach(SavedWordShelf.allCases) { shelf in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedShelf = shelf
                        }
                    } label: {
                        Text(shelf.rawValue)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedShelf == shelf ? Palette.ink : Palette.muted)
                            .frame(width: 102)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedShelf == shelf ? Palette.glassStrong : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )

            Spacer()

            Text("\(displayedWords.count) words")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
        .id(listAnchor)
    }

    private var wordsListSection: some View {
        VStack(spacing: 0) {
            if displayedWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: selectedShelf == .learning ? "book.closed" : "checkmark.circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    Text(selectedShelf == .learning ? "No learning words yet" : "No known words yet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(selectedShelf == .learning ? "Tap a highlighted word while reading and save it here." : "Mark a saved word as known and it will move to this list.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            } else {
                ForEach(Array(displayedWords.enumerated()), id: \.element) { index, word in
                    savedWordRow(for: word)

                    if index < displayedWords.count - 1 {
                        Divider()
                            .overlay(Palette.border)
                            .padding(.leading, 74)
                    }
                }
            }
        }
        .cardBackground()
    }

    private var displayedWords: [String] {
        switch selectedShelf {
        case .learning:
            return store.learningWords
        case .known:
            return store.knownWords
        }
    }

    private func savedWordRow(for word: String) -> some View {
        let lookup = lookup(for: word)
        let display = displayWord(for: lookup, fallback: word)

        return HStack(alignment: .center, spacing: 14) {
            Button {
                speech.speak(display)
            } label: {
                Image(systemName: speech.isSpeaking(display) ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(display)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                if !lookup.phonetic.isEmpty {
                    Text(lookup.phonetic)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                store.triggerImpact()
                selectedLookup = lookup
            }

            Button {
                store.setKnownState(for: display, isKnown: selectedShelf == .learning)
            } label: {
                Image(systemName: selectedShelf == .learning ? "checkmark.circle" : "arrow.uturn.backward.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contextMenu {
            Button(selectedShelf == .learning ? "Mark as Known" : "Move Back to Learning") {
                store.setKnownState(for: display, isKnown: selectedShelf == .learning)
            }

            Button("Remove from Saved", role: .destructive) {
                store.toggleSavedWord(display)
            }
        }
    }

    private func lookup(for word: String) -> WordLookup {
        WordLookupResolver.lookup(
            rawWord: word,
            vocabulary: store.articles.flatMap(\.vocabulary),
            context: ""
        )
    }

    private func displayWord(for lookup: WordLookup, fallback: String) -> String {
        let cleaned = lookup.word.cleanedDisplayWord
        return cleaned.isEmpty ? fallback : cleaned
    }
}

private struct WordReviewQuestion: Identifiable {
    let id = UUID()
    let word: String
    let phonetic: String
    let example: String
    let options: [String]
    let correctIndex: Int
}

// Multiple-choice review: show a saved word (with an example sentence when
// available) and pick its Chinese meaning from three options.
struct WordReviewView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    @Environment(\.dismiss) private var dismiss

    let words: [String]

    @State private var questions: [WordReviewQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var finished = false

    private static let fallbackGlosses = [
        "城市的街道或道路。", "人造或自然的卫星。", "一种常见的水果。",
        "海洋中的大型动物。", "测量温度的工具。", "一年中的某个季节。",
        "用于书写的工具。", "金属制成的容器。", "表示同意的回答。", "一种交通工具。",
    ]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if questions.isEmpty {
                emptyState
            } else if finished {
                summary
            } else {
                quiz(questions[index])
            }
        }
        .onAppear {
            if questions.isEmpty {
                questions = buildQuestions()
            }
        }
    }

    private func quiz(_ question: WordReviewQuestion) -> some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 12)

            Text(question.word)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.accent)

            if !question.example.isEmpty {
                Text(question.example)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
            }

            Spacer(minLength: 12)

            VStack(spacing: 14) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { i, option in
                    optionButton(option, index: i, question: question)
                }
            }
            .padding(.horizontal, 20)

            bottomBar(question)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 14)

            Text("\(index + 1)/\(questions.count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 20)
    }

    private func optionButton(_ option: String, index i: Int, question: WordReviewQuestion) -> some View {
        let isCorrect = i == question.correctIndex
        let answered = selected != nil
        let isSelected = selected == i

        let background: Color
        let border: Color
        if answered, isCorrect {
            background = Color.green.opacity(0.18)
            border = .green
        } else if answered, isSelected {
            background = Color.red.opacity(0.16)
            border = .red
        } else {
            background = Palette.surface
            border = Palette.border
        }

        return Button {
            guard selected == nil else { return }
            selected = i
            store.triggerImpact()
            if isCorrect { correctCount += 1 }
            scheduleAdvance()
        } label: {
            HStack {
                Text(option)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if answered, isCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func bottomBar(_ question: WordReviewQuestion) -> some View {
        HStack {
            Spacer()
            Button {
                store.setKnownState(for: question.word, isKnown: true)
                store.triggerImpact()
                advance()
            } label: {
                Text("I know this word")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                speech.speak(question.word)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.top, 18)
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Palette.accent)
            Text("Review complete")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("\(correctCount) / \(questions.count) correct")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.muted)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.horizontal, 40)
        }
        .padding(28)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No words to review yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Button("Close") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.accent)
        }
    }

    private var progress: CGFloat {
        guard !questions.isEmpty else { return 0 }
        return CGFloat(index + 1) / CGFloat(questions.count)
    }

    private func scheduleAdvance() {
        let current = index
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            await MainActor.run {
                if current == index, selected != nil {
                    advance()
                }
            }
        }
    }

    private func advance() {
        selected = nil
        if index + 1 >= questions.count {
            finished = true
        } else {
            index += 1
        }
    }

    private func buildQuestions() -> [WordReviewQuestion] {
        let chosen = Array(words.shuffled().prefix(10))
        let resolved = chosen.map { (word: $0, lookup: lookup(for: $0)) }
        let glossPool = resolved.map { conciseGloss($0.lookup.meaningZh) }.filter { !$0.isEmpty }

        var result: [WordReviewQuestion] = []
        for item in resolved {
            let correct = conciseGloss(item.lookup.meaningZh)
            guard !correct.isEmpty else { continue }

            var distractors = Array(Set(glossPool).subtracting([correct])).shuffled()
            if distractors.count < 2 {
                distractors += Self.fallbackGlosses.shuffled().filter { $0 != correct }
            }
            let two = Array(distractors.prefix(2))
            let options = (two + [correct]).shuffled()
            guard let correctIndex = options.firstIndex(of: correct) else { continue }

            let display = item.lookup.word.cleanedDisplayWord.isEmpty ? item.word : item.lookup.word.cleanedDisplayWord
            result.append(
                WordReviewQuestion(
                    word: display,
                    phonetic: item.lookup.phonetic,
                    example: item.lookup.example,
                    options: options,
                    correctIndex: correctIndex
                )
            )
        }
        return result
    }

    private func lookup(for word: String) -> WordLookup {
        WordLookupResolver.lookup(
            rawWord: word,
            vocabulary: store.articles.flatMap(\.vocabulary),
            context: ""
        )
    }

    // Trim a generated or curated meaning to one concise quiz option.
    private func conciseGloss(_ raw: String) -> String {
        var text = raw
        if let newline = text.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            text = String(text[..<newline])
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let posRange = text.range(of: "^[a-zA-Z]{1,5}\\.\\s*", options: .regularExpression) {
            text = String(text[posRange.upperBound...])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
