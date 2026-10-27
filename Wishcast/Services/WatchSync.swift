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
    /// The newest summary, kept until the watch connection is ready to take it.
    private var latest: WatchSummary?
    private var lastSent: WatchSummary?

    #if os(iOS)
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ summary: WatchSummary) {
        latest = summary
        push()
    }

    /// Sends `latest` if the watch can take it and something changed (other than the time).
    fileprivate func push() {
        guard let summary = latest, WCSession.isSupported(),
              WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled,
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
    // The first summary usually arrives before the session finishes activating; send it then.
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.push() }
    }

    // The watch app was installed (or the paired watch changed).
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.lastSent = nil
            self.push()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
