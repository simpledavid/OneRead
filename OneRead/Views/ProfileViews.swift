import SwiftUI
import NaturalLanguage
import StoreKit
import UIKit

struct ArticleProfileView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var subscription: SubscriptionService
    @State private var activeSheet: ProfileInfoSheetKind?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        meHeader
                        activitySection
                        learnSection
                        languageSection
                        levelSection
                        appSection
                        subscriptionSection
                        supportSection
                        othersSection
                        footer
                    }
                    .frame(width: max(proxy.size.width - 40, 1), alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 42)
                    .padding(.bottom, 112)
                }
                .frame(width: proxy.size.width)
                .clipped()
                .background(LensBackground())
            }
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
                .simultaneousGesture(TapGesture().onEnded { store.triggerImpact() })
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
                    title: "Articles completed",
                    value: "\(store.completedCount)",
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
                    store.triggerImpact()
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

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileSectionTitle("ONEREAD PRO")

            VStack(spacing: 0) {
                NavigationLink {
                    OneReadProView()
                } label: {
                    ProfileValueRow(
                        systemImage: subscription.isPro ? "checkmark.seal.fill" : "sparkles",
                        title: subscription.isPro ? "OneRead Pro" : "Upgrade to Pro",
                        value: subscription.statusLabel
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { store.triggerImpact() })
            }
            .cardBackground()

            Text("Original articles stay free. Pro unlocks every AI reading level, complete translations, and saved-word review.")
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
                    store.triggerImpact()
                    activeSheet = .rate
                } label: {
                    ProfileValueRow(systemImage: "star.fill", title: "Rate us", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                ShareLink(item: "I’m using OneRead to follow AI news in English.") {
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
                    store.triggerImpact()
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
                    store.triggerImpact()
                    activeSheet = .about
                } label: {
                    ProfileValueRow(systemImage: "info.circle.fill", title: "About", value: nil)
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Palette.border)
                    .padding(.leading, 56)

                Button {
                    store.triggerImpact()
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
            Text("OneRead")
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

    private let cellSize: CGFloat = 16
    private let cellSpacing: CGFloat = 5

    var body: some View {
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
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color(for: store.readingActivityValue(on: day)))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
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
                .lineLimit(2)
                .layoutPriority(1)

            Spacer(minLength: 12)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
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
            return "Rate OneRead"
        case .wechat:
            return "WeChat"
        case .about:
            return "About OneRead"
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
            return "OneRead is a lightweight English reading app focused on current AI and tech stories, with real RSS sources and word lookup built in."
        case .privacy:
            return "Your saved words, reading settings, and article cache stay on device. RSS content is fetched from public sources when needed."
        }
    }
}

struct OneReadProView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscription: SubscriptionService

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                hero
                benefits

                if subscription.isPro {
                    activeSubscriptionCard
                } else {
                    purchaseOptions
                }

                restoreButton
                debugControls
                subscriptionFinePrint
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .background(LensBackground())
        .navigationTitle("OneRead Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            await subscription.refresh()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.accent)

            Text("Learn from the whole story")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("OneRead's editorial AI turns current news into level-appropriate English, translations, and useful vocabulary. You never need to provide an API key.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(
                icon: "text.book.closed.fill",
                title: "All AI reading levels",
                detail: "Read every daily story in Easy or Standard."
            )
            benefitRow(
                icon: "character.bubble.fill",
                title: "Complete translations",
                detail: "Reveal translations for every paragraph."
            )
            benefitRow(
                icon: "character.book.closed.fill",
                title: "Save and review words",
                detail: "Build a personal vocabulary list from every article."
            )

            Divider()
                .overlay(Palette.border)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Original articles, speech, lookup, and article bookmarking always remain free.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .cardBackground()
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var activeSubscriptionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("OneRead Pro is active")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("All AI learning features are unlocked.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    @ViewBuilder
    private var purchaseOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if subscription.isLoading && subscription.products.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Palette.accent)
                    Text("Loading App Store options…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
            } else if subscription.products.isEmpty {
                Text("No subscription products are available in this App Store environment yet.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()
            } else {
                ForEach(subscription.products, id: \.id) { product in
                    Button {
                        Task {
                            await subscription.purchase(product)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.ink)
                                Text(product.id == SubscriptionService.yearlyProductID ? "Best value" : "Flexible monthly access")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(
                                        product.id == SubscriptionService.yearlyProductID
                                            ? Palette.accent
                                            : Palette.muted
                                    )
                            }

                            Spacer(minLength: 12)

                            if subscription.purchasingProductID == product.id {
                                ProgressView()
                                    .tint(Palette.background)
                            } else {
                                Text(product.displayPrice)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Palette.background)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(subscription.purchasingProductID != nil)
                }
            }

            if let errorMessage = subscription.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await subscription.restorePurchases()
            }
        } label: {
            Text("Restore purchases")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.surfaceRaised)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(subscription.isLoading)
    }

    @ViewBuilder
    private var debugControls: some View {
#if DEBUG
        Toggle(
            "Debug: unlock Pro",
            isOn: Binding(
                get: { subscription.debugProOverride },
                set: { subscription.setDebugProOverride($0) }
            )
        )
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .tint(Palette.accent)
        .padding(16)
        .cardBackground()
#endif
    }

    private var subscriptionFinePrint: some View {
        Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .lineSpacing(3)
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
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
