import SwiftUI
import VITACore
import CausalityEngine

@main
struct VITAApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
