import SwiftUI

struct RootView: View {
    @EnvironmentObject private var articleStore: ArticleStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            ArticleTodayView()
                .tabItem {
                    Label("News", systemImage: "book.pages.fill")
                }

            SavedWordsView()
                .tabItem {
                    Label("Words", systemImage: "character.book.closed.fill")
                }

            ArticleProfileView()
                .tabItem {
                    Label("Me", systemImage: "face.smiling.fill")
                }
        }
        .tint(Palette.accent)
        .preferredColorScheme(articleStore.appearanceMode.colorScheme)
        .task {
            NotificationService.clearPreviouslyScheduledReminders()
            RetentionAnalytics.record("app_session")
            await articleStore.refreshScheduledDailyArticlesIfNeeded()
            RetentionAnalytics.flush()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            articleStore.recordAppOpen()
            Task {
                RetentionAnalytics.record("app_session")
                await articleStore.refreshScheduledDailyArticlesIfNeeded()
                RetentionAnalytics.flush()
            }
        }
    }
}
