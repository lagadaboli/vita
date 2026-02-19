import SwiftUI
import VITADesignSystem

struct WeighingMachineSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "scalemass")
                    .font(.title2)
                    .foregroundStyle(VITAColors.info)
                Text("Body Scale")
                    .font(VITATypography.title3)
                Spacer()
                ConnectionStatusBadge(name: "", icon: "checkmark.circle.fill", status: .connected)
            }

            if isLoading {
                SkeletonCard(lines: [120, 170, 110], lineHeight: 12)
            } else if let latest = viewModel.weightReadings.last {
                VStack(spacing: VITASpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.1f", latest.weightKg))
                            .font(VITATypography.metric)
                            .foregroundStyle(VITAColors.textPrimary)
                        Text("kg")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                        Spacer()
                        if let bmi = computeBMI(latest.weightKg) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("BMI")
                                    .font(VITATypography.caption2)
                                    .foregroundStyle(VITAColors.textTertiary)
                                Text(String(format: "%.1f", bmi))
                                    .font(VITATypography.metricSmall)
                                    .foregroundStyle(bmiColor(bmi))
                            }
                        }
                    }

                    if viewModel.weightReadings.count >= 2 {
                        let first = viewModel.weightReadings.first!.weightKg
                        let last = latest.weightKg
                        let diff = last - first
                        HStack(spacing: VITASpacing.sm) {
                            Image(systemName: diff > 0.1 ? "arrow.up.right" : (diff < -0.1 ? "arrow.down.right" : "arrow.right"))
                                .font(.caption)
                                .foregroundStyle(trendColor(diff))
                            Text("7-day: \(diff > 0 ? "+" : "")\(String(format: "%.1f", diff)) kg")
                                .font(VITATypography.caption)
                                .foregroundStyle(trendColor(diff))
                        }
                    }
                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))

                ForEach(viewModel.weightReadings.suffix(5).reversed()) { reading in
                    HStack {
                        Text(reading.timestamp, style: .date)
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f kg", reading.weightKg))
                            .font(VITATypography.metricSmall)
                            .foregroundStyle(VITAColors.textPrimary)
                        if let delta = reading.delta {
                            Text("\(delta > 0 ? "+" : "")\(String(format: "%.1f", delta))")
                                .font(VITATypography.caption)
                                .foregroundStyle(delta > 0.1 ? VITAColors.coral : (delta < -0.1 ? VITAColors.success : VITAColors.textTertiary))
                        }
                    }
                    .padding(.horizontal, VITASpacing.cardPadding)
                    .padding(.vertical, VITASpacing.sm)
                }
            } else {
                EmptyDataStateView(
                    title: "No Weight Data Yet",
                    message: "Body scale or Health data will show here after sync."
                )
            }
        }
    }

    private func computeBMI(_ weightKg: Double) -> Double? {
        let heightM = 1.75 // Placeholder height
        return weightKg / (heightM * heightM)
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return VITAColors.info
        case 18.5..<25: return VITAColors.success
        case 25..<30: return VITAColors.amber
        default: return VITAColors.coral
        }
    }

    private func trendColor(_ diff: Double) -> Color {
        if diff > 0.3 { return VITAColors.coral }
        else if diff < -0.3 { return VITAColors.success }
        return VITAColors.textSecondary
    }
}
