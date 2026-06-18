import SwiftUI
import NaturalLanguage
import UIKit

enum ReadingLevel: Int, CaseIterable, Identifiable {
    case level1 = 1
    case level2 = 2
    case level3 = 3

    var id: Int { rawValue }

    var title: String {
        "Level \(rawValue)"
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

                        if let first = visibleArticles.first {
                            NavigationLink {
                                ArticleReadingView(
                                    article: first,
                                    rank: 1,
                                    pageCount: min(visibleArticles.count, 2),
                                    initialLevel: .level1
                                )
                            } label: {
                                ArticleHomeCard(
                                    article: first,
                                    rank: 1
                                )
                            }
                            .id("home-feature-\(first.id)")
                            .buttonStyle(.plain)
                        }

                        if visibleArticles.count > 1 {
                            ForEach(Array(visibleArticles.dropFirst().prefix(1).enumerated()), id: \.element.id) { index, article in
                                NavigationLink {
                                    ArticleReadingView(
                                        article: article,
                                        rank: index + 2,
                                        pageCount: min(visibleArticles.count, 2),
                                        initialLevel: .level1
                                    )
                                } label: {
                                    ArticleHomeCard(
                                        article: article,
                                        rank: index + 2
                                    )
                                }
                                .buttonStyle(.plain)
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
                store.refreshDailyRecommendationsIfNeeded()
            }
        }
    }

    private func homeContentWidth(for screenWidth: CGFloat) -> CGFloat {
        min(max(screenWidth - 40, 0), 360)
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            Color.clear
                .frame(width: 46, height: 46)

            Spacer()
            Text("One Read")
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Spacer()

            Color.clear
                .frame(width: 46, height: 46)
        }
    }

    private var visibleArticles: [Article] {
        store.dailyArticles
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
                Text(article.source)
                    .lineLimit(1)
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
    }

    private var displayDate: String {
        store.homeReleaseDateText(for: rank)
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
    @State private var readingLevel: ReadingLevel
    @State private var isArticleTranslationVisible = false
    @State private var appliedInitialTranslationPreference = false
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
                    readingLevel: readingLevel
                )
                .padding(.bottom, 172)
            }
            .background(LensBackground())
            .overlay(alignment: .top) {
                readingTopBar
            }
            .overlay(alignment: .bottom) {
                readingBottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            store.requestLeveledContent(for: article, level: readingLevel)
            guard !appliedInitialTranslationPreference else {
                return
            }
            isArticleTranslationVisible = store.showArticleTranslationsEnabled
            appliedInitialTranslationPreference = true
        }
        .onChange(of: readingLevel) { _, newLevel in
            store.requestLeveledContent(for: article, level: newLevel)
        }
    }

    private var readingTopBar: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                ForEach(ReadingLevel.allCases) { level in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            readingLevel = level
                        }
                    } label: {
                        Text(level.title)
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(readingLevel == level ? Palette.ink : Palette.muted)
                            .frame(width: 76)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(readingLevel == level ? Palette.glassStrong : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Palette.muted)
                .frame(width: 42, height: 42)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var readingBottomBar: some View {
        let isSpeaking = speech.isSpeaking(speakableText)

        return VStack(spacing: 14) {
            ReadingWaveform(isActive: isSpeaking)

            Button {
                speech.speak(speakableText)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .heavy))
                    Text(isSpeaking ? "Stop" : "Listen")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSpeaking ? "Stop reading aloud" : "Read article aloud")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [
                    Palette.background.opacity(0),
                    Palette.background.opacity(0.92),
                    Palette.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var speakableText: String {
        ([article.title] + readingParagraphs.map(\.text)).joined(separator: ". ")
    }

    private var readingParagraphs: [LeveledParagraph] {
        ArticleLevelAdapter.paragraphs(
            for: article,
            level: readingLevel,
            rewritten: store.leveledRewrite(for: article, level: readingLevel)
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

struct ArticleCatalogView: View {
    @EnvironmentObject private var store: ArticleStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                libraryHeader
                shelfFilter

                    if store.filteredArticles.isEmpty {
                        emptyLibraryState
                    } else {
                        ForEach(store.filteredArticles) { article in
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
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Library")
            .searchable(text: $store.searchText, prompt: "Search title, body, or source")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await store.refreshLibraryManually()
                        }
                    } label: {
                        Image(systemName: store.isRefreshing ? "hourglass" : "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .accessibilityLabel("Refresh library")
                }
            }
        }

    private var libraryHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("All articles")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Curated from leading AI and tech sources")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            Text("\(store.filteredArticles.count)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.accent)
        }
        .padding(16)
        .cardBackground()
    }

    private var shelfFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ArticleLibraryShelf.allCases) { shelf in
                    ArticleCategoryChip(
                        title: shelf.title,
                        systemImage: shelf.systemImage,
                        isSelected: store.selectedLibraryShelf == shelf
                    ) {
                        store.selectedLibraryShelf = shelf
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyLibraryState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Text("Building your library")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Tap refresh in the top right to pull the latest English articles from available sources.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .cardBackground()
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
    private let listAnchor = "saved-words-list"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        wordsHeader
                        reviewWordsHero {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(listAnchor, anchor: .top)
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

                Text(lookup.meaningZh.isEmpty ? "No definition yet" : lookup.meaningZh)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 10)

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

