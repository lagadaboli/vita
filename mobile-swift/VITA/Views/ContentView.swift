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
            guard !appState.isLoaded else { return }
            await appState.initialize()
        }
    }
}

struct LoadingStateView: View {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: VITASpacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VITAColors.teal)
                .scaleEffect(1.15)

            VStack(spacing: VITASpacing.xs) {
                Text(title)
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)

                Text(message)
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VITASpacing.xl)
        .background(VITAColors.background)
    }
}

struct EmptyDataStateView: View {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: VITASpacing.sm) {
            Text(title)
                .font(VITATypography.headline)
                .foregroundStyle(VITAColors.textPrimary)

            Text(message)
                .font(VITATypography.callout)
                .foregroundStyle(VITAColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}
