import SwiftUI
import WidgetKit

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Redraw widgets with this version's layout rather than waiting for their next refresh.
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
