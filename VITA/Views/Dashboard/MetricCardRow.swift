import SwiftUI
import VITADesignSystem

struct MetricCardRow: View {
    let viewModel: DashboardViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VITASpacing.md) {
                MetricCard(
                    title: "HRV",
                    value: "\(Int(viewModel.currentHRV))",
                    unit: "ms",
                    trend: viewModel.hrvTrend,
                    color: viewModel.currentHRV < 40 ? VITAColors.coral : VITAColors.teal
                )

                MetricCard(
                    title: "Heart Rate",
                    value: "\(Int(viewModel.currentHR))",
                    unit: "bpm",
                    trend: .stable,
                    color: viewModel.currentHR > 72 ? VITAColors.amber : VITAColors.teal
                )

                MetricCard(
                    title: "Sleep",
                    value: String(format: "%.1f", viewModel.sleepHours),
                    unit: "hrs",
                    trend: viewModel.sleepHours >= 7.0 ? .stable : .down,
                    color: viewModel.sleepHours < 7.0 ? VITAColors.amber : VITAColors.success
                )

                MetricCard(
                    title: "Glucose",
                    value: "\(Int(viewModel.currentGlucose))",
                    unit: "mg/dL",
                    trend: viewModel.glucoseTrend,
                    color: VITAColors.glucoseColor(mgDL: viewModel.currentGlucose)
                )

                MetricCard(
                    title: "Steps",
                    value: formatSteps(viewModel.steps),
                    unit: "",
                    trend: viewModel.steps > 8000 ? .up : .stable,
                    color: viewModel.steps > 8000 ? VITAColors.success : VITAColors.teal
                )

                MetricCard(
                    title: "Dopamine Debt",
                    value: "\(Int(viewModel.dopamineDebt))",
                    unit: "/100",
                    trend: viewModel.dopamineDebt > 50 ? .up : .stable,
                    color: viewModel.dopamineDebt > 60 ? VITAColors.coral : VITAColors.amber
                )
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
