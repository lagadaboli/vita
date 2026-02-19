import SwiftUI
import Charts
import VITADesignSystem

struct SevenDayForecastView: View {
    let forecastPoints: [SkinHealthViewModel.ForecastPoint]
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            // Title
            HStack(spacing: VITASpacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(VITAColors.teal)
                Text("7-Day Skin Forecast")
                    .font(VITATypography.title3)
            }

            Text("Projected trajectory vs. VITA recommendations")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            // Legend
            HStack(spacing: VITASpacing.lg) {
                legendItem(color: VITAColors.coral,  dash: true,  label: "Current path")
                legendItem(color: VITAColors.teal,   dash: false, label: "With recommendations")
            }

            // Chart
            if forecastPoints.isEmpty {
                Text("No forecast data")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(forecastPoints) { point in
                        // Baseline (declining trajectory)
                        LineMark(
                            x: .value("Day", point.dayIndex),
                            y: .value("Score", point.baselineScore),
                            series: .value("Series", "Current")
                        )
                        .foregroundStyle(VITAColors.coral)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                        AreaMark(
                            x: .value("Day", point.dayIndex),
                            y: .value("Score", point.baselineScore),
                            series: .value("Series", "Current")
                        )
                        .foregroundStyle(VITAColors.coral.opacity(0.06))

                        // Improved trajectory
                        LineMark(
                            x: .value("Day", point.dayIndex),
                            y: .value("Score", point.improvedScore),
                            series: .value("Series", "Improved")
                        )
                        .foregroundStyle(VITAColors.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Day", point.dayIndex),
                            y: .value("Score", point.improvedScore),
                            series: .value("Series", "Improved")
                        )
                        .foregroundStyle(VITAColors.teal.opacity(0.10))
                    }
                }
                .chartYScale(domain: 20...100)
                .chartXAxis {
                    AxisMarks(values: Array(0..<forecastPoints.count)) { value in
                        if let idx = value.as(Int.self), idx < forecastPoints.count {
                            AxisValueLabel { Text(forecastPoints[idx].dayLabel).font(.system(size: 9)) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [40, 60, 80, 100]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)

                // Day 7 delta callout
                if let last = forecastPoints.last {
                    let delta = Int(last.improvedScore - last.baselineScore)
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VITAColors.teal)
                        Text("+\(delta) pts by Day 7 with recommendations")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.teal)
                    }
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private func legendItem(color: Color, dash: Bool, label: String) -> some View {
        HStack(spacing: VITASpacing.xs) {
            if dash {
                HStack(spacing: 2) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 7, height: 2.5)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 16, height: 2.5)
            }
            Text(label)
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textSecondary)
        }
    }
}
