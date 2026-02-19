import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()
    @State private var isRefreshing = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var isSectionLoading: Bool {
        isRefreshing || appState.isHealthSyncing || !appState.isLoaded
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(
                        viewModel: viewModel,
                        isLoading: isSectionLoading
                    )
                    ScreenTimeSection(
                        viewModel: viewModel,
                        appState: appState,
                        isLoading: isSectionLoading
                    )
                    DoorDashSection(viewModel: viewModel, isLoading: isSectionLoading)
                    InstacartSection(viewModel: viewModel, isLoading: isSectionLoading)
                    RotimaticSection(viewModel: viewModel, isLoading: isSectionLoading)
                    InstantPotSection(viewModel: viewModel, isLoading: isSectionLoading)
                    WeighingMachineSection(viewModel: viewModel, isLoading: isSectionLoading)
                    EnvironmentSection(viewModel: viewModel, isLoading: isSectionLoading)
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
    let appState: AppState
    let isLoading: Bool
    @State private var isRequestingPermission = false

    private var isAuthorized: Bool {
        if case .authorized = appState.screenTimeStatus {
            return true
        }
        return false
    }

    private var statusMessage: String {
        switch appState.screenTimeStatus {
        case .authorized:
            return "Screen Time monitoring is active."
        case .unavailable(let reason):
            return "Screen Time access unavailable: \(reason). Check Screen Time + Family Controls permissions."
        case .notConfigured:
            return "Screen Time monitoring is not configured."
        }
    }

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
                SkeletonCard(lines: [120, 210, 140], lineHeight: 12)
            } else if !isAuthorized {
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    EmptyDataStateView(
                        title: "Screen Time Access Needed",
                        message: statusMessage
                    )
                    Button {
                        Task {
                            isRequestingPermission = true
                            defer { isRequestingPermission = false }
                            await appState.requestScreenTimeAuthorization()
                        }
                    } label: {
                        HStack(spacing: VITASpacing.sm) {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(VITAColors.teal)
                            } else {
                                Image(systemName: "lock.shield")
                            }
                            Text(isRequestingPermission ? "Requesting Permission..." : "Enable Screen Time Access")
                                .font(VITATypography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VITASpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VITAColors.teal)
                    .disabled(isRequestingPermission)
                }
            } else if viewModel.zombieScrollSessions.isEmpty {
                EmptyDataStateView(
                    title: "No Screen Time Alerts Yet",
                    message: statusMessage.isEmpty
                        ? "No zombie-scrolling events have been recorded yet."
                        : statusMessage
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
