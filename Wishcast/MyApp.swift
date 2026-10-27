import SwiftUI
import WidgetKit

@main struct MyApp: App {
    @State private var isShowingSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The splash's tag line: the next of the three on every launch.
    private let tagline: LocalizedStringResource

    init() {
        let taglines = SplashView.taglines
        let index = UserDefaults.standard.integer(forKey: "splashTagline")
        tagline = taglines[index % taglines.count]
        nextTaglineIndex = (index + 1) % taglines.count
    }

    private let nextTaglineIndex: Int

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Wishcast is designed for a dark look throughout (also set in Info.plist for iOS).
                .preferredColorScheme(.dark)
                .overlay {
                    if isShowingSplash {
                        SplashView(tagline: tagline)
                            .transition(.opacity)
                    }
                }
                .task {
                    UserDefaults.standard.set(nextTaglineIndex, forKey: "splashTagline")
                    // Redraw widgets with this version's layout rather than waiting for their next refresh.
                    WidgetCenter.shared.reloadAllTimelines()
                    // Screenshot runs go straight to the app.
                    #if DEBUG
                    if ScreenshotMode.shot != nil {
                        isShowingSplash = false
                        return
                    }
                    #endif
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { isShowingSplash = false }
                }
        }
    }
}
