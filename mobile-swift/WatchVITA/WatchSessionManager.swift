import Foundation
import WatchConnectivity
import VITACore

#if os(watchOS)
/// Manages WCSession on the Watch side.
/// Receives nudge payloads transferred from the iPhone via transferUserInfo().
@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    var latestNudge: WatchNudgePayload?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Deliver any user infos that arrived while the Watch app wasn't running.
        for userInfo in session.receivedApplicationContext.isEmpty ? [] : [session.receivedApplicationContext] {
            if let nudge = WatchNudgePayload.from(dictionary: userInfo) {
                Task { @MainActor in self.latestNudge = nudge }
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let nudge = WatchNudgePayload.from(dictionary: userInfo) else { return }
        Task { @MainActor in self.latestNudge = nudge }
    }
}
#endif
