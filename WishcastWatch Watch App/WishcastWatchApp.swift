import SwiftUI

@main
struct WishcastWatchApp: App {
    @State private var store = WatchStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(summary: store.summary)
                // Raising the wrist brings the app back: check for a newer place or week.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.requestLatest() }
                }
        }
    }
}
