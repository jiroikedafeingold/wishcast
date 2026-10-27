import Foundation

/// What the iPhone sends: the place, wish and week, already formatted and localized there.
/// Keep in sync with WatchSummary in the iOS app (Wishcast/Services/WatchSync.swift).
struct WatchSummary: Codable, Equatable {
    struct Day: Codable, Equatable {
        let weekday: String
        let symbol: String
        let high: String
        let low: String
        /// "H: 3 of 220 · L: 12 of 220", as in the app's day rows.
        let matchText: String
    }

    let place: String
    let wishTitle: String
    let wishSymbol: String
    /// The wish's raw value, for its color.
    let wish: String
    /// "Best case for Nice & Pleasant. Not a prediction."
    let note: String
    let updated: Date
    let days: [Day]

    /// Shared between the watch app (which receives it) and its complications.
    static let appGroup = "group.com.jirofeingold.wishcast"

    static var saved: WatchSummary? {
        UserDefaults(suiteName: appGroup)?.data(forKey: "watchSummary")
            .flatMap { try? JSONDecoder().decode(WatchSummary.self, from: $0) }
    }
}
