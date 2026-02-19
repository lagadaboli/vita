import SwiftUI
import VITADesignSystem

struct ContentView: View {
    @State var appState: AppState

    var body: some View {
        TabView(
            selection: Binding(
                get: { appState.selectedTab },
                set: { appState.selectedTab = $0 }
            )
        ) {
            DashboardView(appState: appState)
                .tag(AppState.AppTab.dashboard)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.clipboard")
                }

            AskVITAView(appState: appState)
                .tag(AppState.AppTab.askVITA)
                .tabItem {
                    Label("Ask VITA", systemImage: "bubble.left.and.text.bubble.right")
                }

            IntegrationsView(appState: appState)
                .tag(AppState.AppTab.integrations)
                .tabItem {
                    Label("Integrations", systemImage: "link")
                }

            TimelineView(appState: appState)
                .tag(AppState.AppTab.timeline)
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }

            SkinHealthView(appState: appState)
                .tag(AppState.AppTab.skinAudit)
                .tabItem {
                    Label("Skin", systemImage: "face.smiling")
                }

            HealthReportView(appState: appState)
                .tag(AppState.AppTab.report)
                .tabItem {
                    Label("Report", systemImage: "doc.richtext")
                }

            SettingsView(appState: appState)
                .tag(AppState.AppTab.settings)
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

struct ShimmerSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(VITAColors.tertiaryBackground)
            .frame(width: width, height: height)
            .modifier(ShimmerEffect())
    }
}

struct SkeletonCard: View {
    var lines: [CGFloat] = [140, 220, 160]
    var lineHeight: CGFloat = 12
    var spacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, lineWidth in
                ShimmerSkeleton(
                    width: lineWidth,
                    height: lineHeight,
                    cornerRadius: lineHeight / 2
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}

private struct ShimmerEffect: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}
