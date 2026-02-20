import Foundation

public actor WatchConnectivityBridge {
    public init() {}

    public func send(_ payload: WatchNudgePayload) async {
        _ = payload
    }
}
