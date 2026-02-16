import SwiftUI
import VITADesignSystem

struct AppleWatchSection: View {
    let viewModel: IntegrationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(VITAColors.teal)
                Text("Apple Watch")
                    .font(VITATypography.title3)
                Spacer()
                ConnectionStatusBadge(name: "", icon: "applewatch", status: viewModel.watchStatus)
            }

            VStack(spacing: VITASpacing.md) {
                HStack {
                    Text("Last sync")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                    Spacer()
                    if let syncDate = viewModel.watchSyncDate {
                        Text(syncDate, style: .relative)
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    } else {
                        Text("No sync yet")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    }
                }

                Divider()

                HStack(spacing: VITASpacing.xl) {
                    WatchMetricItem(label: "HRV", value: viewModel.watchHRV.map { "\(Int($0))" } ?? "--", unit: "ms")
                    WatchMetricItem(label: "HR", value: viewModel.watchHR.map { "\(Int($0))" } ?? "--", unit: "bpm")
                    WatchMetricItem(label: "Steps", value: "\(viewModel.watchSteps)", unit: "")
                }
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        }
    }
}

struct WatchMetricItem: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: VITASpacing.xs) {
            Text(label)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(VITATypography.metricSmall)
                    .foregroundStyle(VITAColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
