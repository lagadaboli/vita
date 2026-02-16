import SwiftUI
import VITADesignSystem

struct ContentView: View {
    @State var appState: AppState

    var body: some View {
        TabView {
            DashboardView(appState: appState)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.clipboard")
                }

            AskVITAView(appState: appState)
                .tabItem {
                    Label("Ask VITA", systemImage: "bubble.left.and.text.bubble.right")
                }

            IntegrationsView(appState: appState)
                .tabItem {
                    Label("Integrations", systemImage: "link")
                }

            TimelineView(appState: appState)
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(VITAColors.teal)
        .task {
            await appState.initialize()
        }
    }
}
