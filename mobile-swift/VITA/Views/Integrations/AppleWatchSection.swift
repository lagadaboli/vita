import SwiftUI
import VITADesignSystem

struct AppleWatchSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(VITAColors.teal)
                Text("Apple Watch")
                    .font(VITATypography.title3)
                Spacer()
                ConnectionStatusBadge(name: "", icon: "applewatch", status: viewModel.watchConnectionStatus)
            }

            VStack(spacing: VITASpacing.md) {
                HStack {
                    Text("Connection")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                    Spacer()
                    Text(viewModel.watchConnectionDetail)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }

                HStack {
                    Text("Last sync")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                    Spacer()
                    if viewModel.watchSyncDate == Date.distantPast {
                        Text("No sync yet")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    } else {
                        Text(viewModel.watchSyncDate, style: .relative)
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    }
                }

                Divider()

                HStack(spacing: VITASpacing.xl) {
                    WatchMetricItem(
                        label: "HRV",
                        value: isLoading ? "--" : "\(Int(viewModel.watchHRV))",
                        unit: "ms"
                    )
                    WatchMetricItem(
                        label: "HR",
                        value: isLoading ? "--" : "\(Int(viewModel.watchHR))",
                        unit: "bpm"
                    )
                    WatchMetricItem(
                        label: "Steps",
                        value: isLoading ? "--" : "\(viewModel.watchSteps)",
                        unit: ""
                    )
                }
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            .redacted(reason: isLoading ? .placeholder : [])
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
