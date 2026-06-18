import SwiftUI
import NaturalLanguage
import UIKit

struct ArticleProfileView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var notifications: NotificationService
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
                    systemImage: "bell.badge.fill",
                    title: "Daily reminders (7am & 4pm)",
                    isOn: Binding(
                        get: { notifications.isEnabled },
                        set: { newValue in
                            Task { await notifications.setEnabled(newValue) }
                        }
                    )
                )

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

            if notifications.permissionDenied {
                Text("Notifications are turned off in iOS Settings. Enable them for One Read to get your morning and afternoon reads.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

            Text("Quick (~100 words) and Standard (~150 words) are condensed by a cloud LLM using your API key. Full always shows the original article.")
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

