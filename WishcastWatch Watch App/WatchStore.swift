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
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.receive(userInfo) }
    }
}
