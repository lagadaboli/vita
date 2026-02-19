import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

/// Bridges iPhone ↔ Watch communication for nudge delivery.
/// Uses `transferUserInfo()` to queue delivery even if Watch is unreachable.
public final class WatchConnectivityBridge: NSObject, WCSessionDelegate, Sendable {
    public struct ConnectionStatus: Sendable {
        public let isSupported: Bool
        public let isPaired: Bool
        public let isWatchAppInstalled: Bool
        public let isReachable: Bool
        public let isActivated: Bool
    }

    public static let shared = WatchConnectivityBridge()

    private let session: WCSession

    private override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
    }

    /// Send a nudge payload to the Watch. Queues for delivery if Watch is unreachable.
    public func sendNudge(_ payload: WatchNudgePayload) {
        guard session.activationState == .activated else {
            #if DEBUG
            print("[WatchConnectivityBridge] Session not activated, nudge queued")
            #endif
            return
        }

        let dict = payload.toDictionary()
        session.transferUserInfo(dict)
    }

    /// Returns the current watch connectivity state for UI health/status screens.
    public func connectionStatus() -> ConnectionStatus {
        ConnectionStatus(
            isSupported: WCSession.isSupported(),
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable,
            isActivated: session.activationState == .activated
        )
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
        if let error {
            print("[WatchConnectivityBridge] Activation error: \(error.localizedDescription)")
        }
        #endif
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
