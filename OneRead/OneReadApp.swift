import SwiftUI

@main
struct OneReadApp: App {
    @StateObject private var articleStore = ArticleStore()
    @StateObject private var speech = SpeechService()
    @StateObject private var notifications = NotificationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(articleStore)
                .environmentObject(speech)
                .environmentObject(notifications)
        }
    }
}
