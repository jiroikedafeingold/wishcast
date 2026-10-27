import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Receives the summary from the iPhone and keeps the last one, for the app and its complications.
@Observable
final class WatchStore: NSObject {
    private(set) var summary: WatchSummary? = WatchSummary.saved

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    fileprivate func receive(_ payload: [String: Any]) {
        guard let data = payload["summary"] as? Data,
              let summary = try? JSONDecoder().decode(WatchSummary.self, from: data)
        else { return }
        UserDefaults(suiteName: WatchSummary.appGroup)?.set(data, forKey: "watchSummary")
        self.summary = summary
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.receive(context) }
        requestLatest(from: session)
    }

    /// Asks the phone for its latest summary, so opening the watch app shows the current place
    /// without waiting for the system to deliver the application context.
    nonisolated func requestLatest(from session: WCSession = .default) {
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["request": "summary"], replyHandler: { reply in
            Task { @MainActor in self.receive(reply) }
        }, errorHandler: nil)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        requestLatest(from: session)
    }

    // Sent by the phone while this app is open.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.receive(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.receive(userInfo) }
    }
}
