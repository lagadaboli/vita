import SwiftUI
import VITACore

#if os(watchOS)
import WatchConnectivity

@main
struct WatchVITAApp: App {
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            if let nudge = sessionManager.latestNudge {
                WatchNudgeView(nudge: nudge)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.title)
                        .foregroundStyle(.teal)
                    Text("VITA")
                        .font(.headline)
                    Text("Waiting for insights...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
#endif
