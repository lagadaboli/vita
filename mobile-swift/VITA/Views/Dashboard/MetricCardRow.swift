import SwiftUI
import VITADesignSystem

struct MetricCardRow: View {
    let viewModel: DashboardViewModel
    let isLoading: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VITASpacing.md) {
                if isLoading {
                    ForEach(0..<DashboardMetric.allCases.count, id: \.self) { _ in
                        MetricCardSkeleton()
                    }
                } else {
                    NavigationLink(value: DashboardMetric.hrv) {
                        MetricCard(
                            title: "HRV",
                            value: "\(Int(viewModel.currentHRV))",
                            unit: "ms",
                            trend: viewModel.hrvTrend,
                            color: viewModel.currentHRV < 40 ? VITAColors.coral : VITAColors.teal
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.heartRate) {
                        MetricCard(
                            title: "Heart Rate",
                            value: "\(Int(viewModel.currentHR))",
                            unit: "bpm",
                            trend: .stable,
                            color: viewModel.currentHR > 72 ? VITAColors.amber : VITAColors.teal
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.sleep) {
                        MetricCard(
                            title: "Sleep",
                            value: String(format: "%.1f", viewModel.sleepHours),
                            unit: "hrs",
                            trend: viewModel.sleepHours >= 7.0 ? .stable : .down,
                            color: viewModel.sleepHours < 7.0 ? VITAColors.amber : VITAColors.success
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.glucose) {
                        MetricCard(
                            title: "Glucose",
                            value: "\(Int(viewModel.currentGlucose))",
                            unit: "mg/dL",
                            trend: viewModel.glucoseTrend,
                            color: VITAColors.glucoseColor(mgDL: viewModel.currentGlucose)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.weight) {
                        MetricCard(
                            title: "Weight",
                            value: viewModel.currentWeight > 0 ? String(format: "%.1f", viewModel.currentWeight) : "--",
                            unit: "kg",
                            trend: viewModel.weightTrend,
                            color: viewModel.weightTrend == .up ? VITAColors.amber : VITAColors.teal
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.steps) {
                        MetricCard(
                            title: "Steps",
                            value: formatSteps(viewModel.steps),
                            unit: "",
                            trend: viewModel.steps > 8000 ? .up : .stable,
                            color: viewModel.steps > 8000 ? VITAColors.success : VITAColors.teal
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: DashboardMetric.dopamineDebt) {
                        MetricCard(
                            title: "Dopamine Debt",
                            value: "\(Int(viewModel.dopamineDebt))",
                            unit: "/100",
                            trend: viewModel.dopamineDebt > 50 ? .up : .stable,
                            color: viewModel.dopamineDebt > 60 ? VITAColors.coral : VITAColors.amber
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VITASpacing.lg)
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

private struct MetricCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            ShimmerSkeleton(width: 70, height: 10, cornerRadius: 6)

            HStack(alignment: .firstTextBaseline, spacing: VITASpacing.xs) {
                ShimmerSkeleton(width: 52, height: 26, cornerRadius: 8)
                ShimmerSkeleton(width: 24, height: 10, cornerRadius: 6)
            }

            ShimmerSkeleton(width: 64, height: 10, cornerRadius: 6)
        }
        .padding(VITASpacing.cardPadding)
        .frame(width: 140, alignment: .leading)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}
