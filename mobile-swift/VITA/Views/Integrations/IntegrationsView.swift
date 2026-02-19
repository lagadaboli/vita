import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()
    @State private var isRefreshing = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    if isRefreshing || appState.isHealthSyncing || !appState.isLoaded {
                        HStack(spacing: VITASpacing.sm) {
                            ProgressView()
                                .tint(VITAColors.teal)
                            Text("Refreshing integrations...")
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, VITASpacing.xs)
                    }

                    AppleWatchSection(
                        viewModel: viewModel,
                        isLoading: isRefreshing || appState.isHealthSyncing || !appState.isLoaded
                    )
                    ScreenTimeSection(
                        viewModel: viewModel,
                        isLoading: isRefreshing || appState.isHealthSyncing || !appState.isLoaded
                    )
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
            .task(id: appState.isLoaded) {
                await refreshIntegrations()
            }
            .refreshable {
                await refreshIntegrations()
            }
            .onReceive(refreshTimer) { _ in
                Task {
                    await refreshIntegrations()
                }
            }
        }
    }

    @MainActor
    private func refreshIntegrations() async {
        guard appState.isLoaded else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await appState.refreshHealthData()
        await appState.refreshDeliveryOrders()
        viewModel.load(from: appState)
    }
}

struct ScreenTimeSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

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

            if isLoading && viewModel.zombieScrollSessions.isEmpty {
                RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                    .fill(VITAColors.cardBackground)
                    .frame(height: 120)
                    .redacted(reason: .placeholder)
            } else if viewModel.zombieScrollSessions.isEmpty {
                EmptyDataStateView(
                    title: "No Screen Time Alerts Yet",
                    message: viewModel.screenTimeStatusMessage.isEmpty
                        ? "No zombie-scrolling events have been recorded yet."
                        : viewModel.screenTimeStatusMessage
                )
            } else {
                ForEach(viewModel.zombieScrollSessions) { session in
                    ZombieScrollCard(session: session)
                }
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
