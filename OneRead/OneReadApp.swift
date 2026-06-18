import SwiftUI

@main
struct OneReadApp: App {
    @StateObject private var articleStore = ArticleStore()
    @StateObject private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(articleStore)
                .environmentObject(speech)
        }
    }
}
