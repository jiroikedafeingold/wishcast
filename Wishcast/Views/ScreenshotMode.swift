import Foundation

#if DEBUG
/// App Store screenshot staging, used only in Debug builds by `tools/screenshots.sh`.
/// Launch with `-shot N` to open a fixed screen with real forecasts for Denver:
/// 1 the 7-day list · 2 a day's detail · 3 the Snow wish · 4 a wild-guess day ~2 months out · 5 How Wishcast Works.
enum ScreenshotMode {
    static var shot: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-shot"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    static let place = Place(name: "Denver", detail: "Colorado, United States", latitude: 39.739, longitude: -104.985)
}
#endif
