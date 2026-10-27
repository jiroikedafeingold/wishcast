import SwiftUI

@main struct MyApp: App {
    @State private var isShowingSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if isShowingSplash {
                        SplashView()
                            .transition(.opacity)
                    }
                }
                .task {
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
