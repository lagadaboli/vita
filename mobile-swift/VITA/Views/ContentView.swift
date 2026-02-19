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

struct ShimmerSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(VITAColors.tertiaryBackground)
            .frame(width: width, height: height)
            .modifier(ShimmerEffect(cornerRadius: cornerRadius))
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
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = -0.9

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.08), location: 0.35),
                            .init(color: Color.white.opacity(0.35), location: 0.50),
                            .init(color: Color.white.opacity(0.08), location: 0.65),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: width * 0.9, height: height * 1.8)
                    .rotationEffect(.degrees(18))
                    .offset(x: phase * width * 1.8, y: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .onAppear {
                phase = -0.9
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    phase = 0.9
                }
            }
    }
}
