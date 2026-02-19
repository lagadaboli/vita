import SwiftUI
import VITADesignSystem
#if canImport(UIKit)
import UIKit
#endif

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()
    @State private var isRefreshing = false

    private var isSectionLoading: Bool {
        !appState.isLoaded
            || ((isRefreshing || appState.isHealthSyncing) && !viewModel.hasAnyData && !viewModel.hasLoaded)
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
                guard appState.isLoaded else { return }
                await refreshIntegrations(force: false)
            }
            .task(id: appState.lastHealthRefreshAt) {
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .task(id: appState.lastDeliveryRefreshAt) {
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .onAppear {
                Task {
                    await refreshIntegrations(force: false)
                }
            }
            .onChange(of: appState.selectedTab) { _, selectedTab in
                guard selectedTab == .integrations else { return }
                Task {
                    await refreshIntegrations(force: false)
                }
            }
            .onChange(of: appState.screenTimeStatus) { _, _ in
                viewModel.load(from: appState)
            }
            .refreshable {
                await refreshIntegrations(force: true)
            }
        }
    }

    @MainActor
    private func refreshIntegrations(force: Bool) async {
        guard appState.isLoaded else { return }
        viewModel.load(from: appState)
        if force {
            isRefreshing = true
        }

        await appState.refreshHealthDataIfNeeded(maxAge: 150, force: force)
        await appState.refreshDeliveryOrdersIfNeeded(maxAge: 300, force: force)
        viewModel.load(from: appState)
        if force {
            isRefreshing = false
        }
    }
}

struct ScreenTimeSection: View {
    let viewModel: IntegrationsViewModel
    let appState: AppState
    let isLoading: Bool
    @State private var showManualScreenTimeHelp = false

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
                        openScreenTimeSystemSettings()
                    } label: {
                        HStack(spacing: VITASpacing.sm) {
                            Image(systemName: "lock.shield")
                            Text("Enable Screen Time Access")
                                .font(VITATypography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VITASpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VITAColors.teal)
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
        .alert("Open Screen Time Manually", isPresented: $showManualScreenTimeHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Go to iPhone Settings > Screen Time > Apps with Screen Time Access > VITA.")
        }
    }

    private func openScreenTimeSystemSettings() {
        #if canImport(UIKit)
        let candidates = [
            URL(string: "App-prefs:SCREEN_TIME&path=APPS_WITH_SCREEN_TIME_ACCESS"),
            URL(string: "App-prefs:root=SCREEN_TIME&path=APPS_WITH_SCREEN_TIME_ACCESS"),
            URL(string: "App-prefs:SCREEN_TIME"),
            URL(string: "App-prefs:root=SCREEN_TIME"),
            URL(string: "App-prefs:"),
        ].compactMap { $0 }
        openSettingsCandidate(candidates)
        #endif
    }

    private func openSettingsCandidate(_ candidates: [URL]) {
        guard let url = candidates.first else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                let remaining = Array(candidates.dropFirst())
                if remaining.isEmpty {
                    showManualScreenTimeHelp = true
                } else {
                    openSettingsCandidate(remaining)
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
