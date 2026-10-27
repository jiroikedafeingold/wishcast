import SwiftUI

@main
struct WishcastWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView(summary: store.summary)
        }
    }
}
