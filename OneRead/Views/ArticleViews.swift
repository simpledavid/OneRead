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

private struct SavedArticlesScreen: View {
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

struct ArticleProfileView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var activeSheet: ProfileInfoSheetKind?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    meHeader
                    activitySection
                    learnSection
                    languageSection
                    levelSection
                    appSection
                    aiRewriteSection
                    supportSection
                    othersSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 42)
                .padding(.bottom, 112)
            }
            .background(LensBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                ProfileInfoSheet(kind: sheet)
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var meHeader: some View {
        HStack {
            Spacer()
            Text("Me")
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Spacer()
        }
        .frame(height: 46)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("ACTIVITY")
            ReadingActivityHeatmap()
        }
    }

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("LEARN")

            VStack(spacing: 0) {
                NavigationLink {
                    SavedArticlesScreen()
                } label: {
                    ProfileValueRow(
                        systemImage: "bookmark.fill",
                        title: "Saved Articles",
                        value: "\(store.savedArticles.count)"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                NavigationLink {
                    ArticleCatalogView()
                } label: {
                    ProfileValueRow(
                        systemImage: "books.vertical.fill",
                        title: "Library",
                        value: "\(store.articles.count)"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ProfileToggleRow(
                    systemImage: "textformat.alt",
                    title: "Highlight key words",
                    isOn: Binding(
                        get: { store.highlightVocabularyEnabled },
                        set: { store.setHighlightVocabularyEnabled($0) }
                    )
                )
            }
            .cardBackground()
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("LANGUAGE")

            VStack(spacing: 0) {
                ProfileValueRow(
                    systemImage: "character.book.closed",
                    title: "Word explanations",
                    value: store.learningLanguageLabel,
                    showsChevron: false
                )
            }
            .cardBackground()

            Text("Language used for word meanings, not the app interface.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("READING")

            VStack(spacing: 0) {
                ProfileValueRow(
                    systemImage: "book.fill",
                    title: "Articles read",
                    value: "\(store.readCount)",
                    showsChevron: false
                )

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ProfileValueRow(
                    systemImage: "character.book.closed.fill",
                    title: "Words learning",
                    value: "\(store.learningWords.count)",
                    showsChevron: false
                )

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ProfileActionRow(
                    systemImage: "arrow.clockwise",
                    title: store.isRefreshing ? "Refreshing today's articles" : "Refresh today's articles"
                ) {
                    Task {
                        await store.refreshTodayManually()
                    }
                }
            }
            .cardBackground()
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("APP")

            VStack(spacing: 0) {
                ProfileValueRow(systemImage: "moon.fill", title: "Appearance", value: "Dark", showsChevron: false)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ProfileToggleRow(
                    systemImage: "iphone.radiowaves.left.and.right",
                    title: "Haptic",
                    isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.setHapticsEnabled($0) }
                    )
                )
            }
            .cardBackground()
        }
    }

    private var aiRewriteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("AI REWRITE")

            VStack(spacing: 0) {
                NavigationLink {
                    AILevelSettingsView()
                } label: {
                    ProfileValueRow(
                        systemImage: "wand.and.stars",
                        title: "AI model & API key",
                        value: store.hasAPIKey ? store.aiProvider.displayName : "Set up"
                    )
                }
                .buttonStyle(.plain)
            }
            .cardBackground()

            Text("Level 1 (A2) and Level 2 (B1) are rewritten by a cloud LLM using your API key. Level 3 always shows the original article.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("SUPPORT & CONTACT")

            VStack(spacing: 0) {
                Button {
                    activeSheet = .rate
                } label: {
                    ProfileValueRow(systemImage: "star.fill", title: "Rate us", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ShareLink(item: "I’m using One Read to follow AI news in English.") {
                    ProfileValueRow(systemImage: "square.and.arrow.up", title: "Share with friends", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                Link(destination: URL(string: "mailto:simplezdwbtc@gmail.com")!) {
                    ProfileValueRow(systemImage: "envelope.fill", title: "Email us", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                Button {
                    UIPasteboard.general.string = "simplezdwbtc"
                    activeSheet = .wechat
                } label: {
                    ProfileValueRow(systemImage: "message.fill", title: "WeChat", value: nil)
                }
                .buttonStyle(.plain)
            }
            .cardBackground()
        }
    }

    private var othersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("OTHERS")

            VStack(spacing: 0) {
                Button {
                    activeSheet = .about
                } label: {
                    ProfileValueRow(systemImage: "info.circle.fill", title: "About", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                Button {
                    activeSheet = .privacy
                } label: {
                    ProfileValueRow(systemImage: "hand.raised.fill", title: "Privacy policy", value: nil)
                }
                .buttonStyle(.plain)
            }
            .cardBackground()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("One Read")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Palette.muted.opacity(0.28))
            Spacer()
        }
        .padding(.top, 4)
    }

    private func profileSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }
}

private struct ReadingActivityHeatmap: View {
    @EnvironmentObject private var store: ArticleStore

    private var columns: [[Date]] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -83, to: end) else {
            return []
        }

        let days = (0..<84).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }

        return stride(from: 0, to: days.count, by: 7).map { startIndex in
            Array(days[startIndex..<min(startIndex + 7, days.count)])
        }
    }

    private let cellSpacing: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            let count = CGFloat(max(columns.count, 1))
            let cell = max(10, (proxy.size.width - cellSpacing * (count - 1)) / count)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: cellSpacing) {
                            ForEach(column, id: \.self) { day in
                                RoundedRectangle(cornerRadius: cell * 0.26, style: .continuous)
                                    .fill(color(for: store.readingActivityValue(on: day)))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: gridHeight)
        .padding(18)
        .cardBackground()
    }

    private var gridHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let available = screenWidth - 40 - 36
        let count = CGFloat(max(columns.count, 1))
        let cell = max(10, (available - cellSpacing * (count - 1)) / count)
        let rows: CGFloat = 7
        return rows * cell + (rows - 1) * cellSpacing + 16 + 18
    }

    private var monthLabels: [String] {
        guard !columns.isEmpty else {
            return []
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"

        var labels: [String] = []
        var lastMonth = ""

        for column in columns {
            guard let first = column.first else {
                continue
            }

            let label = formatter.string(from: first)
            if label != lastMonth {
                labels.append(label)
                lastMonth = label
            }
        }

        return labels
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 4...:
            return Palette.accent.opacity(0.78)
        case 3:
            return Palette.accent.opacity(0.56)
        case 2:
            return Palette.amber.opacity(0.48)
        case 1:
            return Palette.amber.opacity(0.28)
        default:
            return Palette.surfaceRaised
        }
    }
}

private struct ProfileValueRow: View {
    let systemImage: String
    let title: String
    let value: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.86))
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 12)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.82))
                    .multilineTextAlignment(.trailing)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }
}

private struct ProfileToggleRow: View {
    let systemImage: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.86))
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }
}

private struct ProfileActionRow: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.86))
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 72)
        }
        .buttonStyle(.plain)
    }
}

private enum ProfileInfoSheetKind: String, Identifiable {
    case rate
    case wechat
    case about
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rate:
            return "Rate One Read"
        case .wechat:
            return "WeChat"
        case .about:
            return "About One Read"
        case .privacy:
            return "Privacy"
        }
    }

    var message: String {
        switch self {
        case .rate:
            return "This beta build is best shared through TestFlight feedback for now."
        case .wechat:
            return "WeChat contact copied: simplezdwbtc"
        case .about:
            return "One Read is a lightweight English reading app focused on current AI and tech stories, with real RSS sources and word lookup built in."
        case .privacy:
            return "Your saved words, reading settings, and article cache stay on device. RSS content is fetched from public sources when needed."
        }
    }
}

private struct AILevelSettingsView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var apiKeyField = ""
    @State private var modelField = ""
    @State private var didLoad = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                providerSection
                modelSection
                apiKeySection

                if store.isOnDeviceRewriteAvailable {
                    Text("On-device Apple Intelligence is available and will be used automatically if you leave the API key empty.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .background(LensBackground())
        .navigationTitle("AI Rewrite")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            apiKeyField = store.currentAPIKey
            modelField = store.aiModelOverride
            didLoad = true
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PROVIDER")
            VStack(spacing: 0) {
                ForEach(Array(AIProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    Button {
                        store.setAIProvider(provider)
                        apiKeyField = store.currentAPIKey
                        modelField = store.aiModelOverride
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: store.aiProvider == provider ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(store.aiProvider == provider ? Palette.accent : Palette.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.ink)
                                Text("Default model: \(provider.defaultModel)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AIProvider.allCases.count - 1 {
                        Divider()
                            .overlay(Palette.border)
                            .padding(.leading, 48)
                    }
                }
            }
            .cardBackground()
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MODEL")
            VStack(alignment: .leading, spacing: 10) {
                TextField(store.aiProvider.defaultModel, text: $modelField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .onSubmit { store.setAIModelOverride(modelField) }

                Text("Leave empty to use the provider default (\(store.aiProvider.defaultModel)).")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 4)
            .cardBackground()
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("API KEY")
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Paste your \(store.aiProvider.displayName) API key", text: $apiKeyField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                Text("Get a key at \(store.aiProvider.keyHint). Stored securely in the iOS Keychain.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .cardBackground()

            Button {
                store.setAIModelOverride(modelField)
                store.setAPIKey(apiKeyField)
                savedConfirmation = true
                store.triggerImpact(.medium)
            } label: {
                HStack {
                    Spacer()
                    Text(savedConfirmation ? "Saved" : "Save")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.background)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.accent)
                )
            }
            .buttonStyle(.plain)

            if store.hasAPIKey {
                Button(role: .destructive) {
                    apiKeyField = ""
                    store.setAPIKey("")
                    savedConfirmation = false
                } label: {
                    Text("Remove key")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.amber)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: apiKeyField) { _, _ in
            savedConfirmation = false
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }
}

private struct ProfileInfoSheet: View {
    let kind: ProfileInfoSheetKind

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text(kind.message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(LensBackground())
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
    @Binding var isArticleTranslationVisible: Bool
    let article: Article
    let rank: Int
    let pageCount: Int
    let width: CGFloat
    let height: CGFloat
    let readingLevel: ReadingLevel

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

            ReadingTitleView(title: article.title, vocabulary: article.vocabulary)
                .padding(.top, 2)

            articleReadingStats

            VStack(alignment: .leading, spacing: 22) {
                if isRewriting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Palette.muted)
                        Text("Rewriting for \(readingLevel.title)…")
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

                ForEach(leveledParagraphs, id: \.id) { item in
                    LearningParagraphView(
                        paragraph: item.text,
                        translation: translation(for: item.originalIndex),
                        isTranslationVisible: isArticleTranslationVisible,
                        vocabulary: article.vocabulary,
                        context: item.originalText,
                        onToggleTranslation: {}
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 126)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(LensBackground())
        .onAppear {
            store.markRead(article)
        }
    }

    private var imageHeight: CGFloat {
        218
    }

    private var articleReadingStats: some View {
        HStack(spacing: 16) {
            Text(article.publishedDateTimeText)
            Text("\(wordCount) words")
            Text("\(readingMinutes) mins")
            Spacer(minLength: 6)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
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

    private var isRewriting: Bool {
        store.isGeneratingLevel(for: article, level: readingLevel)
            && store.leveledRewrite(for: article, level: readingLevel) == nil
    }

    private func translation(for index: Int) -> String? {
        guard article.paragraphTranslations.indices.contains(index) else {
            return nil
        }
        return article.paragraphTranslations[index]
    }

}

private struct ReadingTitleView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var selectedLookup: WordLookup?
    @State private var selectedTokenID: Int?
    let title: String
    let vocabulary: [ArticleVocabulary]

    var body: some View {
        InlineWordFlowLayout(horizontalSpacing: 3, verticalSpacing: 2) {
            ForEach(tokens, id: \.id) { token in
                Text(token.display)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color(for: token.lookup))
                    .underline(isHighlighted(token.lookup), color: color(for: token.lookup).opacity(0.85))
                    .fixedSize()
                    .onTapGesture {
                        selectedTokenID = token.id
                        selectedLookup = WordLookupResolver.lookup(
                            rawWord: token.lookup,
                            vocabulary: vocabulary,
                            context: title
                        )
                    }
                    .popover(
                        item: lookupBinding(for: token.id),
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) { lookup in
                        WordLookupSheet(lookup: lookup)
                            .frame(width: 292)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleFontSize: CGFloat {
        switch title.count {
        case ...34:
            return 22
        case 35...52:
            return 20
        case 53...72:
            return 18
        default:
            return 17
        }
    }

    private var tokens: [WordToken] {
        let pieces = title.split(separator: " ", omittingEmptySubsequences: false)
        return pieces.enumerated().map { index, value in
            let display = index == pieces.count - 1 ? String(value) : "\(value) "
            return WordToken(id: index, display: display, lookup: String(value))
        }
    }

    private func color(for word: String) -> Color {
        guard store.highlightVocabularyEnabled else {
            return Palette.ink
        }

        return isHighlighted(word) ? Palette.accent : Palette.ink
    }

    private func isHighlighted(_ word: String) -> Bool {
        guard store.highlightVocabularyEnabled else {
            return false
        }
        let cleaned = word.cleanedLookupWord
        guard cleaned.count > 3 else {
            return false
        }
        return vocabulary.contains { $0.word.lookupCandidates.contains(cleaned) } || CommonWordDictionary.lookup(cleaned) != nil
    }

    private func lookupBinding(for tokenID: Int) -> Binding<WordLookup?> {
        Binding<WordLookup?>(
            get: {
                selectedTokenID == tokenID ? selectedLookup : nil
            },
            set: { value in
                if value == nil {
                    selectedLookup = nil
                    selectedTokenID = nil
                }
            }
        )
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
    let context: String
    let onToggleTranslation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InlineWordFlowLayout(horizontalSpacing: 3, verticalSpacing: 5) {
                ForEach(tokens, id: \.id) { token in
                    Text(token.display)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(color(for: token.lookup))
                        .underline(isHighlighted(token.lookup), color: color(for: token.lookup).opacity(0.86))
                        .fixedSize()
                        .onTapGesture {
                            selectedTokenID = token.id
                            selectedLookup = lookup(token.lookup)
                        }
                        .popover(
                            item: lookupBinding(for: token.id),
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .bottom
                        ) { lookup in
                            WordLookupSheet(lookup: lookup)
                                .frame(width: 292)
                                .presentationCompactAdaptation(.popover)
                        }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

    private func color(for word: String) -> Color {
        guard store.highlightVocabularyEnabled else {
            return Palette.ink
        }

        let cleaned = word.cleanedLookupWord
        if vocabulary.contains(where: { $0.word.cleanedLookupWord == cleaned }) {
            return Palette.accent
        }

        if CommonWordDictionary.lookup(cleaned) != nil {
            return Palette.blue
        }

        return Palette.ink
    }

    private func isHighlighted(_ word: String) -> Bool {
        guard store.highlightVocabularyEnabled else {
            return false
        }
        let cleaned = word.cleanedLookupWord
        return vocabulary.contains(where: { $0.word.cleanedLookupWord == cleaned }) || CommonWordDictionary.lookup(cleaned) != nil
    }

    private func lookupBinding(for tokenID: Int) -> Binding<WordLookup?> {
        Binding<WordLookup?>(
            get: {
                selectedTokenID == tokenID ? selectedLookup : nil
            },
            set: { value in
                if value == nil {
                    selectedLookup = nil
                    selectedTokenID = nil
                }
            }
        )
    }

    private func lookup(_ rawWord: String) -> WordLookup {
        WordLookupResolver.lookup(rawWord: rawWord, vocabulary: vocabulary, context: context)
    }
}

private struct WordToken: Identifiable {
    let id: Int
    let display: String
    let lookup: String
}

private struct LeveledParagraph: Identifiable {
    let id: String
    let originalIndex: Int
    let text: String
    let originalText: String
}

private enum ArticleLevelAdapter {
    static func paragraphs(for article: Article, level: ReadingLevel, rewritten: [String]? = nil) -> [LeveledParagraph] {
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

    /// Level 1 readers get a shorter version; levels 2 and 3 show the full article.
    private static func wordBudget(for level: ReadingLevel) -> Int? {
        switch level {
        case .level1:
            return 130
        case .level2, .level3:
            return nil
        }
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

private enum WordLookupResolver {
    static func lookup(rawWord: String, vocabulary: [ArticleVocabulary], context: String) -> WordLookup {
        let candidates = rawWord.lookupCandidates

        if let match = vocabulary.first(where: { entry in
            let entryCandidates = entry.word.lookupCandidates
            return candidates.contains(where: entryCandidates.contains)
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

        if let match = NativeDictionaryService.shared.lookup(candidates: candidates) {
            return WordLookup(
                word: match.word,
                meaningZh: match.translation,
                phonetic: match.phonetic,
                example: "",
                exampleZh: "",
                context: context,
                needsAI: false
            )
        }

        if let match = candidates.compactMap(CommonWordDictionary.lookup).first {
            var resolved = match
            resolved.context = context
            return resolved
        }

        let fallbackWord = rawWord.cleanedDisplayWord.isEmpty ? rawWord : rawWord.cleanedDisplayWord
        return WordLookup(
            word: fallbackWord,
            meaningZh: "",
            phonetic: "",
            example: "",
            exampleZh: "",
            context: context,
            needsAI: true
        )
    }
}

struct WordLookupSheet: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var speech: SpeechService
    let lookup: WordLookup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Definition")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.muted)
                        .textCase(.uppercase)

                    if !currentPhonetic.isEmpty {
                        Text(currentPhonetic)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.76))
                    }
                }

                Spacer(minLength: 8)

                wordToolButton(systemName: speech.isSpeaking(displayWord) ? "stop.fill" : "speaker.wave.2.fill") {
                    speech.speak(displayWord)
                }

                wordToolButton(systemName: store.isSavedWord(displayWord) ? "bookmark.fill" : "bookmark") {
                    store.toggleSavedWord(displayWord)
                }
            }

            if !currentMeaning.isEmpty {
                Text(currentMeaning)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.glassStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Palette.border, lineWidth: 1)
                    )
            } else {
                Text("No definition yet")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(Palette.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private func wordToolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 38, height: 38)
                .background(Palette.glassStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var currentMeaning: String {
        lookup.meaningZh
    }

    private var currentPhonetic: String {
        lookup.phonetic
    }

    private var displayWord: String {
        let cleaned = lookup.word.cleanedDisplayWord
        return cleaned.isEmpty ? lookup.word : cleaned
    }

    private func annotatedExample(_ text: String) -> AttributedString {
        let target = lookup.word.cleanedLookupWord
        guard !target.isEmpty else {
            var plain = AttributedString(text)
            plain.foregroundColor = Palette.ink
            return plain
        }

        let lowercasedText = text.lowercased()
        guard let range = lowercasedText.range(of: target) else {
            var plain = AttributedString(text)
            plain.foregroundColor = Palette.ink
            return plain
        }

        let before = String(text[..<range.lowerBound])
        let matched = String(text[range])
        let after = String(text[range.upperBound...])

        var attributed = AttributedString(before)
        attributed.foregroundColor = Palette.ink

        var highlighted = AttributedString(matched)
        highlighted.foregroundColor = Palette.blue
        highlighted.backgroundColor = Palette.blue.opacity(0.16)
        attributed += highlighted

        if let note = inlineMeaning {
            var meaning = AttributedString("（\(note)）")
            meaning.foregroundColor = Palette.blue
            meaning.font = .system(size: 15, weight: .semibold, design: .rounded)
            attributed += meaning
        }

        var tail = AttributedString(after)
        tail.foregroundColor = Palette.ink
        attributed += tail

        return attributed
    }

    private var inlineMeaning: String? {
        let meaning = lookup.meaningZh
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty else {
            return nil
        }

        let separators = CharacterSet(charactersIn: "；;，,。.、")
        let firstPart = meaning
            .components(separatedBy: separators)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? meaning

        guard !firstPart.isEmpty else {
            return nil
        }

        if firstPart.count > 8 {
            return String(firstPart.prefix(8))
        }

        return firstPart
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
                proposal: ProposedViewSize(width: itemWidth, height: size.height)
            )
            point.x += itemWidth + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum CommonWordDictionary {
    static func lookup(_ rawWord: String) -> WordLookup? {
        let word = rawWord.cleanedLookupWord
        let entries: [String: WordLookup] = [
            "acquire": WordLookup(word: "acquire", meaningZh: "收购；获得", example: "The company plans to acquire a smaller startup.", exampleZh: "这家公司计划收购一家更小的初创公司。"),
            "acquisition": WordLookup(word: "acquisition", meaningZh: "收购；并购", example: "The acquisition could expand its AI business.", exampleZh: "这次收购可能扩大它的 AI 业务。"),
            "agent": WordLookup(word: "agent", meaningZh: "智能体；代理程序", example: "The agent can complete a workflow.", exampleZh: "这个智能体可以完成一套工作流。"),
            "ai": WordLookup(word: "AI", meaningZh: "人工智能", example: "AI is changing many products.", exampleZh: "人工智能正在改变许多产品。"),
            "announce": WordLookup(word: "announce", meaningZh: "宣布", example: "The company will announce the update tomorrow.", exampleZh: "这家公司明天会宣布这次更新。"),
            "anthropic": WordLookup(word: "Anthropic", meaningZh: "Anthropic，一家人工智能公司", example: "Anthropic builds Claude.", exampleZh: "Anthropic 开发 Claude。"),
            "api": WordLookup(word: "API", meaningZh: "应用程序接口", example: "Developers can access the model through an API.", exampleZh: "开发者可以通过 API 访问这个模型。"),
            "capability": WordLookup(word: "capability", meaningZh: "能力；功能", example: "The new capability helps teams automate tasks.", exampleZh: "这个新能力帮助团队自动化任务。"),
            "celebrate": WordLookup(word: "celebrate", meaningZh: "庆祝", example: "Users celebrate the launch online.", exampleZh: "用户在网上庆祝这次发布。"),
            "chip": WordLookup(word: "chip", meaningZh: "芯片", example: "The startup is building AI chips.", exampleZh: "这家初创公司正在研发 AI 芯片。"),
            "claude": WordLookup(word: "Claude", meaningZh: "Claude，Anthropic 的 AI 助手/模型", example: "Claude can analyze long documents.", exampleZh: "Claude 可以分析长文档。"),
            "cloud": WordLookup(word: "cloud", meaningZh: "云；云端服务", example: "The tool runs in the cloud.", exampleZh: "这个工具运行在云端。"),
            "company": WordLookup(word: "company", meaningZh: "公司", example: "The company released a new tool.", exampleZh: "这家公司发布了一个新工具。"),
            "complex": WordLookup(word: "complex", meaningZh: "复杂的", example: "The model can solve complex tasks.", exampleZh: "这个模型可以处理复杂任务。"),
            "compute": WordLookup(word: "compute", meaningZh: "计算；算力相关", example: "AI labs need more compute.", exampleZh: "AI 实验室需要更多算力。"),
            "controlled": WordLookup(word: "controlled", meaningZh: "受控制的；可控的", example: "The system runs in a customer-controlled environment.", exampleZh: "该系统运行在客户可控的环境中。"),
            "customer": WordLookup(word: "customer", meaningZh: "客户；用户", example: "Enterprise customers want better security.", exampleZh: "企业客户希望有更好的安全性。"),
            "data": WordLookup(word: "data", meaningZh: "数据", example: "Good data improves the result.", exampleZh: "好的数据会改善结果。"),
            "decision": WordLookup(word: "decision", meaningZh: "决定；决策", example: "The board made a quick decision.", exampleZh: "董事会迅速作出了决定。"),
            "deepseek": WordLookup(word: "DeepSeek", meaningZh: "DeepSeek，一家人工智能公司/模型品牌", example: "DeepSeek models are widely discussed.", exampleZh: "DeepSeek 模型被广泛讨论。"),
            "deploy": WordLookup(word: "deploy", meaningZh: "部署；投放", example: "The team will deploy the model next week.", exampleZh: "团队将在下周部署这个模型。"),
            "developer": WordLookup(word: "developer", meaningZh: "开发者", example: "Developers want clearer documentation.", exampleZh: "开发者希望文档更清晰。"),
            "environment": WordLookup(word: "environment", meaningZh: "环境", example: "The agent runs in a secure environment.", exampleZh: "这个智能体运行在安全环境中。"),
            "event": WordLookup(word: "event", meaningZh: "事件；活动", example: "The event drew attention across the industry.", exampleZh: "这场活动吸引了整个行业的关注。"),
            "example": WordLookup(word: "example", meaningZh: "例子；示例", example: "This sentence is a simple example.", exampleZh: "这个句子是一个简单示例。"),
            "execution": WordLookup(word: "execution", meaningZh: "执行", example: "The platform adds secure code execution.", exampleZh: "这个平台增加了安全的代码执行能力。"),
            "feature": WordLookup(word: "feature", meaningZh: "功能；特性", example: "The app includes a new reading feature.", exampleZh: "这个应用加入了一个新的阅读功能。"),
            "founder": WordLookup(word: "founder", meaningZh: "创始人", example: "The founder spoke about the roadmap.", exampleZh: "创始人谈到了路线图。"),
            "funding": WordLookup(word: "funding", meaningZh: "融资；资金", example: "The startup is seeking fresh funding.", exampleZh: "这家初创公司正在寻求新的融资。"),
            "generate": WordLookup(word: "generate", meaningZh: "生成；产生", example: "The model can generate a short summary.", exampleZh: "这个模型可以生成一段简短摘要。"),
            "hostility": WordLookup(word: "hostility", meaningZh: "敌对；冲突状态", example: "The agreement may reduce hostilities.", exampleZh: "这项协议可能减少敌对状态。"),
            "improve": WordLookup(word: "improve", meaningZh: "改进；提升", example: "The update should improve accuracy.", exampleZh: "这次更新应该会提升准确度。"),
            "infrastructure": WordLookup(word: "infrastructure", meaningZh: "基础设施", example: "AI infrastructure is expensive to build.", exampleZh: "AI 基础设施建设成本很高。"),
            "integration": WordLookup(word: "integration", meaningZh: "整合；集成", example: "The integration connects the app with other tools.", exampleZh: "这项集成把应用和其他工具连接起来。"),
            "interface": WordLookup(word: "interface", meaningZh: "界面；交互方式", example: "The chat interface feels more natural.", exampleZh: "这个聊天界面感觉更自然。"),
            "launch": WordLookup(word: "launch", meaningZh: "发布；推出", example: "The company plans to launch the service soon.", exampleZh: "这家公司计划很快推出这项服务。"),
            "market": WordLookup(word: "market", meaningZh: "市场", example: "The market reacted quickly to the news.", exampleZh: "市场很快对这条消息作出了反应。"),
            "model": WordLookup(word: "model", meaningZh: "模型；这里通常指 AI 模型", example: "The model can summarize long articles.", exampleZh: "这个模型可以总结长文章。"),
            "ongoing": WordLookup(word: "ongoing", meaningZh: "持续进行中的", example: "The company is working on an ongoing project.", exampleZh: "这家公司正在推进一个持续进行中的项目。"),
            "openai": WordLookup(word: "OpenAI", meaningZh: "OpenAI，一家人工智能公司", example: "OpenAI released a new model.", exampleZh: "OpenAI 发布了一个新模型。"),
            "orchestration": WordLookup(word: "orchestration", meaningZh: "编排；协调调度", example: "The platform adds better orchestration for agents.", exampleZh: "这个平台为智能体加入了更好的编排能力。"),
            "persistent": WordLookup(word: "persistent", meaningZh: "持续的；长期存在的", example: "The system keeps a persistent state.", exampleZh: "这个系统会保留持续状态。"),
            "system": WordLookup(word: "system", meaningZh: "系统；由多个部分组成的工具或机制", example: "The system needs reliable data.", exampleZh: "这个系统需要可靠的数据。"),
            "product": WordLookup(word: "product", meaningZh: "产品", example: "The product helps teams work faster.", exampleZh: "这个产品帮助团队更快地工作。"),
            "research": WordLookup(word: "research", meaningZh: "研究", example: "The research attracted public attention.", exampleZh: "这项研究引起了公众关注。"),
            "result": WordLookup(word: "result", meaningZh: "结果", example: "The result was better than expected.", exampleZh: "结果比预期更好。"),
            "reliable": WordLookup(word: "reliable", meaningZh: "可靠的", example: "Users need a reliable assistant.", exampleZh: "用户需要一个可靠的助手。"),
            "release": WordLookup(word: "release", meaningZh: "发布；推出", example: "The team will release the app this month.", exampleZh: "团队会在这个月发布这款应用。"),
            "restrict": WordLookup(word: "restrict", meaningZh: "限制", example: "The new rule may restrict access.", exampleZh: "新规则可能会限制访问。"),
            "revenue": WordLookup(word: "revenue", meaningZh: "营收；收入", example: "Cloud revenue continued to grow.", exampleZh: "云业务营收继续增长。"),
            "risk": WordLookup(word: "risk", meaningZh: "风险", example: "The company must manage the risk.", exampleZh: "这家公司必须管理这个风险。"),
            "route": WordLookup(word: "route", meaningZh: "路线；通道", example: "The route is important for global trade.", exampleZh: "这条通道对全球贸易很重要。"),
            "running": WordLookup(word: "running", meaningZh: "运行中的；持续进行的", example: "The startup is building a long-running agent system.", exampleZh: "这家初创公司正在构建一个长期运行的智能体系统。"),
            "secure": WordLookup(word: "secure", meaningZh: "安全的；受保护的", example: "The workflow runs in a secure environment.", exampleZh: "这套流程运行在安全环境中。"),
            "security": WordLookup(word: "security", meaningZh: "安全；安全性", example: "Security matters in enterprise software.", exampleZh: "企业软件非常重视安全性。"),
            "service": WordLookup(word: "service", meaningZh: "服务", example: "The company launched a new AI service.", exampleZh: "这家公司推出了一项新的 AI 服务。"),
            "startup": WordLookup(word: "startup", meaningZh: "初创公司", example: "The startup raised fresh funding.", exampleZh: "这家初创公司获得了新的融资。"),
            "support": WordLookup(word: "support", meaningZh: "支持；支撑", example: "The system is designed to support developers.", exampleZh: "这个系统旨在支持开发者。"),
            "task": WordLookup(word: "task", meaningZh: "任务", example: "The agent can finish a task on its own.", exampleZh: "这个智能体可以独立完成一个任务。"),
            "team": WordLookup(word: "team", meaningZh: "团队", example: "The team is testing the new workflow.", exampleZh: "团队正在测试这套新流程。"),
            "technology": WordLookup(word: "technology", meaningZh: "技术", example: "The technology could reshape search.", exampleZh: "这项技术可能重塑搜索。"),
            "tool": WordLookup(word: "tool", meaningZh: "工具", example: "This tool helps you read faster.", exampleZh: "这个工具帮助你更快阅读。"),
            "trade": WordLookup(word: "trade", meaningZh: "贸易；交易", example: "The route matters for global trade.", exampleZh: "这条通道对全球贸易很重要。"),
            "translation": WordLookup(word: "translation", meaningZh: "翻译", example: "Tap a word to see its translation.", exampleZh: "点击单词查看它的翻译。"),
            "uncertainty": WordLookup(word: "uncertainty", meaningZh: "不确定性", example: "The market still faces uncertainty.", exampleZh: "市场仍然面临不确定性。"),
            "update": WordLookup(word: "update", meaningZh: "更新", example: "The app received a major update.", exampleZh: "这个应用收到了一个重大更新。"),
            "user": WordLookup(word: "user", meaningZh: "用户", example: "Users want a cleaner reading experience.", exampleZh: "用户希望有更清爽的阅读体验。"),
            "valuation": WordLookup(word: "valuation", meaningZh: "估值", example: "The startup reached a high valuation.", exampleZh: "这家初创公司的估值达到了很高水平。"),
            "workflow": WordLookup(word: "workflow", meaningZh: "工作流", example: "The agent can automate a workflow.", exampleZh: "这个智能体可以自动完成一套工作流。"),
            "policy": WordLookup(word: "policy", meaningZh: "政策", example: "The policy may affect AI companies.", exampleZh: "这项政策可能影响 AI 公司。"),
            "chatgpt": WordLookup(word: "ChatGPT", meaningZh: "ChatGPT，OpenAI 的 AI 助手产品", example: "ChatGPT can help explain an article.", exampleZh: "ChatGPT 可以帮助解释一篇文章。")
        ]
        return entries[word]
    }
}

private extension String {
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

struct ArticleCard: View {
    @EnvironmentObject private var store: ArticleStore
    let article: Article
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ArticleHeroImage(article: article)
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Text(String(format: "%02d", rank))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.accent.opacity(0.32))
            }

            VStack(alignment: .leading, spacing: 8) {
                ArticleMetaLine(article: article)

                Text(article.title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.summary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(3)
            }

            HStack {
                Label("\(article.readingMinutes) min", systemImage: "clock")
                Spacer()
                Image(systemName: store.isRead(article) ? "checkmark.circle.fill" : "circle")
                Image(systemName: store.isSaved(article) ? "bookmark.fill" : "bookmark")
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.accent)
        }
        .padding(18)
        .cardBackground()
    }
}

struct ArticleListCard: View {
    @EnvironmentObject private var store: ArticleStore
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArticleHeroImage(article: article)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                ArticleMetaLine(article: article)

                Text(article.title)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: store.isSaved(article) ? "bookmark.fill" : "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(store.isSaved(article) ? Palette.amber : Palette.border)
                .padding(.top, 4)
        }
        .padding(16)
        .cardBackground()
    }
}

struct ArticleMetaLine: View {
    let article: Article

    var body: some View {
        HStack(spacing: 8) {
            Label(article.category.title, systemImage: article.category.systemImage)
            Text("·")
            Text(article.source)
            Text("·")
            Text(article.publishedDateTimeText)
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(Palette.muted)
        .lineLimit(1)
    }
}

struct ArticleVisualMark: View {
    let category: ArticleCategory

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.accentSoft)

            Image(systemName: category.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
    }
}

struct ArticleHeroImage: View {
    let article: Article

    var body: some View {
        ResilientRemoteImage(
            primaryURL: article.imageURL,
            placeholder: placeholder
        )
        .id("\(article.id)|\(article.imageURLString)")
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.surface)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.glass.opacity(0.6))
        }
    }
}

struct ResilientRemoteImage<Placeholder: View>: View {
    let primaryURL: URL?
    let placeholder: Placeholder
    @State private var image: UIImage?
    @State private var activeRequestKey = ""

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .task(id: primaryURL?.absoluteString ?? "no-image") {
            let requestKey = primaryURL?.absoluteString ?? "no-image"
            activeRequestKey = requestKey
            await load(requestKey: requestKey)
        }
        .animation(.easeInOut(duration: 0.18), value: image)
    }

    private func load(requestKey: String) async {
        await MainActor.run {
            guard activeRequestKey == requestKey else {
                return
            }
            image = nil
        }

        if let primaryURL,
           let loaded = await fetchImage(from: primaryURL) {
            await MainActor.run {
                guard activeRequestKey == requestKey else {
                    return
                }
                image = loaded
            }
        }
    }

    private func fetchImage(from url: URL) async -> UIImage? {
        if let cachedImage = ArticleRemoteImageCache.shared.image(for: url) {
            return cachedImage
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("https://tldr.tech/", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let loadedImage = UIImage(data: data) else {
                return nil
            }

            ArticleRemoteImageCache.shared.insert(loadedImage, for: url)
            return loadedImage
        } catch {
            return nil
        }
    }
}

private final class ArticleRemoteImageCache {
    static let shared = ArticleRemoteImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

struct ArticleCategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? .white : Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Palette.accent : Palette.surface)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ArticleStatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}
