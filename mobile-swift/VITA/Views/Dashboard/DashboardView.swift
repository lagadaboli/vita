import SwiftUI
import Charts
import VITADesignSystem
import VITACore

struct DashboardView: View {
    var appState: AppState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    // Health Score Ring
                    HealthScoreGauge(score: viewModel.healthScore)
                        .padding(.top, VITASpacing.md)

                    // Mini Glucose Chart
                    MiniGlucoseChart(dataPoints: viewModel.glucoseReadings)

                    // Metric Cards Row
                    MetricCardRow(viewModel: viewModel)

                    // Insights
                    VStack(alignment: .leading, spacing: VITASpacing.md) {
                        Text("Insights")
                            .font(VITATypography.title3)
                            .padding(.horizontal, VITASpacing.lg)

                        ForEach(viewModel.insights) { insight in
                            InsightAlertCard(insight: insight)
                                .padding(.horizontal, VITASpacing.lg)
                        }
                    }

                    // Integration Status
                    IntegrationStatusRow()
                        .padding(.horizontal, VITASpacing.lg)
                }
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("VITA")
            .task {
                await refreshDashboard()
            }
            .refreshable {
                await refreshDashboard()
            }
            .navigationDestination(for: DashboardMetric.self) { metric in
                MetricHistoryDetailView(metric: metric, viewModel: viewModel)
            }
        }
    }

    @MainActor
    private func refreshDashboard() async {
        await appState.refreshHealthData()
        viewModel.load(from: appState)
    }
}

struct MetricHistoryDetailView: View {
    let metric: DashboardMetric
    let viewModel: DashboardViewModel

    private var points: [DashboardViewModel.MetricHistoryPoint] {
        viewModel.history(for: metric)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VITASpacing.lg) {
                summaryCard
                chartCard
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.top, VITASpacing.md)
            .padding(.bottom, VITASpacing.xxl)
        }
        .background(VITAColors.background)
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            Text("Current")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: VITASpacing.xs) {
                Text(viewModel.formattedCurrentValue(for: metric))
                    .font(VITATypography.metric)
                    .foregroundStyle(chartColor)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }

            Text(viewModel.sourceLabel(for: metric))
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
        }
        .padding(VITASpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Text(metric.historyWindowLabel)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
                Spacer()
                Text("\(points.count) points")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            if points.isEmpty {
                Text("No historical data available yet.")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(chartColor)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(chartColor.opacity(0.12))
                }
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .frame(height: 260)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var chartColor: Color {
        switch metric {
        case .hrv:
            return viewModel.currentHRV < 40 ? VITAColors.coral : VITAColors.teal
        case .heartRate:
            return viewModel.currentHR > 72 ? VITAColors.amber : VITAColors.teal
        case .sleep:
            return viewModel.sleepHours < 7 ? VITAColors.amber : VITAColors.success
        case .glucose:
            return VITAColors.glucoseColor(mgDL: viewModel.currentGlucose)
        case .weight:
            return viewModel.weightTrend == .up ? VITAColors.amber : VITAColors.teal
        case .steps:
            return viewModel.steps > 8000 ? VITAColors.success : VITAColors.teal
        case .dopamineDebt:
            return viewModel.dopamineDebt > 60 ? VITAColors.coral : VITAColors.amber
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let maxValue = values.max() ?? 1
        let minValue = values.min() ?? 0

        switch metric {
        case .glucose:
            let lower = max(50, floor((minValue - 15) / 10) * 10)
            let upper = max(140, ceil((maxValue + 15) / 10) * 10)
            return lower...upper
        case .dopamineDebt:
            return 0...100
        default:
            let lower = min(0, minValue)
            let upper = max(1, maxValue * 1.15)
            return lower...upper
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch metric {
        case .glucose, .heartRate, .hrv:
            return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        default:
            return .dateTime.month(.abbreviated).day()
        }
    }
}
