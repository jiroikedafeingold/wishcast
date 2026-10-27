import Foundation
#if os(iOS)
import WatchConnectivity
import WidgetKit
#endif

/// What the Apple Watch app and its complications show, already formatted on the phone. Keep the
/// copies in the watch app and complications (WatchSummary.swift) in sync with this one.
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
}

/// Sends the latest summary to the paired Apple Watch, if there is one.
final class WatchSync: NSObject {
    static let shared = WatchSync()
    private var lastSent: WatchSummary?

    #if os(iOS)
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ summary: WatchSummary) {
        // Only when something changed (other than the time); the watch keeps the last one it got.
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled,
              summary.days != lastSent?.days || summary.place != lastSent?.place || summary.wish != lastSent?.wish,
              let data = try? JSONEncoder().encode(summary)
        else { return }
        lastSent = summary
        let payload: [String: Any] = ["summary": data]
        try? WCSession.default.updateApplicationContext(payload)
        // Wakes the watch app so its complications update too (the system limits how often).
        if WCSession.default.isComplicationEnabled {
            WCSession.default.transferCurrentComplicationUserInfo(payload)
        }
    }
    #else
    func send(_ summary: WatchSummary) {}
    #endif
}

#if os(iOS)
extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
