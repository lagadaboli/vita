import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(viewModel: viewModel)
                    ScreenTimeSection(viewModel: viewModel)
                    DoorDashSection(viewModel: viewModel)
                    InstacartSection(viewModel: viewModel)
                    RotimaticSection(viewModel: viewModel)
                    InstantPotSection(viewModel: viewModel)
                    WeighingMachineSection(viewModel: viewModel)
                    EnvironmentSection(viewModel: viewModel)
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("Integrations")
            .onAppear {
                viewModel.load(from: appState)
                Task {
                    await appState.refreshHealthData()
                    await appState.refreshDeliveryOrders()
                    viewModel.load(from: appState)
                }
            }
            .onReceive(refreshTimer) { _ in
                Task {
                    await appState.refreshHealthData()
                    await appState.refreshDeliveryOrders()
                    viewModel.load(from: appState)
                }
            }
        }
    }
}

struct ScreenTimeSection: View {
    let viewModel: IntegrationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(VITAColors.amber)
                Text("Screen Time")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.zombieScrollSessions.count) alerts")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            ForEach(viewModel.zombieScrollSessions) { session in
                ZombieScrollCard(session: session)
            }
        }
    }
}

struct ZombieScrollCard: View {
    let session: IntegrationsViewModel.ZombieScrollSession

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            HStack(spacing: VITASpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(VITAColors.amber)
                Text("Zombie Scrolling Detected")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.amber)
                Spacer()
                Text(session.timestamp, style: .relative)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.appName)
                        .font(VITATypography.headline)
                        .foregroundStyle(VITAColors.textPrimary)
                    Text(session.context)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                }
                Spacer()
                Text(session.source)
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            HStack(spacing: VITASpacing.xl) {
                metric(value: "\(Int(session.durationMinutes))", label: "minutes")
                metric(value: "\(session.zombieScore)", label: "zombie score", color: zombieScoreColor(session.zombieScore))
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.amber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                .stroke(VITAColors.amber.opacity(0.3), lineWidth: 1)
        )
    }

    private func metric(value: String, label: String, color: Color = VITAColors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: VITASpacing.xs) {
            Text(value)
                .font(VITATypography.metricSmall)
                .foregroundStyle(color)
            Text(label)
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
        }
    }

    private func zombieScoreColor(_ score: Int) -> Color {
        switch score {
        case ..<50: return VITAColors.success
        case 50..<75: return VITAColors.amber
        default: return VITAColors.coral
        }
    }
}
