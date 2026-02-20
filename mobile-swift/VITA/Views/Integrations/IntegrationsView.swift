import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(viewModel: viewModel, isLoading: false)
                    ScreenTimeSection(viewModel: viewModel, isLoading: false)
                    if viewModel.latestSkinSnapshot != nil {
                        SkinScanSection(viewModel: viewModel, isLoading: false)
                    }
                    DoorDashSection(viewModel: viewModel, isLoading: false)
                    InstacartSection(viewModel: viewModel, isLoading: false)
                    RotimaticSection(viewModel: viewModel, isLoading: false)
                    InstantPotSection(viewModel: viewModel, isLoading: false)
                    WeighingMachineSection(viewModel: viewModel, isLoading: false)
                    EnvironmentSection(viewModel: viewModel, isLoading: false)
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxl)
            }
            .refreshable {
                viewModel.refresh(from: appState)
            }
            .background(VITAColors.background)
            .navigationTitle("Integrations")
            .task(id: appState.isLoaded) {
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .onAppear {
                guard appState.isLoaded else { return }
                viewModel.refresh(from: appState)
            }
            .onChange(of: appState.selectedTab) { _, tab in
                guard tab == .integrations else { return }
                viewModel.refresh(from: appState)
            }
        }
    }
}

struct ScreenTimeSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    private var totalMinutes: Int {
        viewModel.screenTimeSessions.reduce(0) { $0 + $1.minutes }
    }

    private var topSessions: [IntegrationsViewModel.ScreenTimeSession] {
        Array(viewModel.screenTimeSessions.sorted { $0.minutes > $1.minutes }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "hourglass.circle")
                    .font(.title2)
                    .foregroundStyle(VITAColors.teal)
                Text("Screen Time")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.screenTimeSessions.count) sessions")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            if isLoading {
                SkeletonCard(lines: [120, 190, 170], lineHeight: 12)
            } else if viewModel.screenTimeSessions.isEmpty {
                EmptyDataStateView(
                    title: "No Screen Time Yet",
                    message: "Usage sessions will appear here from mock data."
                )
            } else {
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    HStack(spacing: VITASpacing.xl) {
                        miniMetric("Total", formatMinutes(totalMinutes), color: VITAColors.teal)
                        miniMetric("Pickups", "\(viewModel.screenTimeSessions.reduce(0) { $0 + $1.pickups })", color: VITAColors.amber)
                        miniMetric("Top App", topSessions.first?.appName ?? "—", color: VITAColors.textPrimary)
                    }

                    Divider()

                    ForEach(topSessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.appName)
                                    .font(VITATypography.headline)
                                Text(session.category.capitalized)
                                    .font(VITATypography.caption)
                                    .foregroundStyle(VITAColors.textSecondary)
                            }
                            Spacer()
                            Text("\(session.minutes)m")
                                .font(VITATypography.metricSmall)
                                .foregroundStyle(VITAColors.teal)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }
        }
    }

    private func miniMetric(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: VITASpacing.xs) {
            Text(label)
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
            Text(value)
                .font(VITATypography.metricSmall)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

struct SkinScanSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "face.smiling")
                    .font(.title2)
                    .foregroundStyle(VITAColors.teal)
                Text("Skin Scan")
                    .font(VITATypography.title3)
                Spacer()
                Text(viewModel.latestSkinSnapshot.map { $0.timestamp.formatted(date: .abbreviated, time: .shortened) } ?? "No scan")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            if isLoading {
                SkeletonCard(lines: [120, 180, 120], lineHeight: 12)
            } else if let snapshot = viewModel.latestSkinSnapshot {
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    HStack(spacing: VITASpacing.xl) {
                        miniMetric("Score", "\(snapshot.overallScore)/100", color: VITAColors.healthScoreColor(Double(snapshot.overallScore)))
                        miniMetric("Conditions", "\(snapshot.conditions.count)", color: VITAColors.textPrimary)
                        miniMetric("Source", snapshot.source == "demo" ? "Demo" : "PerfectCorp", color: VITAColors.textSecondary)
                    }

                    if !snapshot.conditions.isEmpty {
                        Divider()
                        ForEach(snapshot.conditions) { condition in
                            HStack {
                                Text(displayCondition(condition.type))
                                    .font(VITATypography.callout)
                                Spacer()
                                Text(severityLabel(for: condition.uiScore))
                                    .font(VITATypography.caption)
                                    .foregroundStyle(severityColor(for: condition.uiScore))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }
        }
    }

    private func miniMetric(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: VITASpacing.xs) {
            Text(label)
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
            Text(value)
                .font(VITATypography.metricSmall)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func displayCondition(_ type: String) -> String {
        switch type.lowercased() {
        case "acne": return "Acne"
        case "wrinkle", "hd_wrinkle": return "Wrinkles"
        case "pore", "hd_pore": return "Pores"
        case "texture", "hd_texture": return "Uneven Texture"
        case "moisture", "hd_moisture", "hydration": return "Hydration"
        case "age_spot", "hd_age_spot", "pigmentation": return "Pigmentation"
        case "redness", "hd_redness": return "Redness"
        case "oiliness", "hd_oiliness": return "Oiliness"
        case "dark_circle_v2", "hd_dark_circle": return "Dark Circles"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func severityLabel(for issueScore: Int) -> String {
        if issueScore > 65 { return "Severe" }
        if issueScore > 35 { return "Moderate" }
        return "Mild"
    }

    private func severityColor(for issueScore: Int) -> Color {
        if issueScore > 60 { return VITAColors.coral }
        if issueScore > 35 { return VITAColors.amber }
        return VITAColors.success
    }
}
