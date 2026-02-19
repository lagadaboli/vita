import SwiftUI
import Charts
import VITADesignSystem

struct HRVStressChartView: View {
    let readings: [SkinHealthViewModel.HRVReading]

    private var dateRange: ClosedRange<Date>? {
        guard let first = readings.first?.day, let last = readings.last?.day else { return nil }
        return first...last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.xs) {
            HStack {
                Text("HRV / Stress")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
                Spacer()
                Text("7d")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            if readings.isEmpty {
                Text("No data")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Chart {
                    // Stress zone bands
                    if let range = dateRange {
                        RectangleMark(
                            xStart: .value("S", range.lowerBound),
                            xEnd:   .value("E", range.upperBound),
                            yStart: .value("y0", 0),
                            yEnd:   .value("y1", 40)
                        )
                        .foregroundStyle(VITAColors.coral.opacity(0.07))

                        RectangleMark(
                            xStart: .value("S", range.lowerBound),
                            xEnd:   .value("E", range.upperBound),
                            yStart: .value("y0", 40),
                            yEnd:   .value("y1", 56)
                        )
                        .foregroundStyle(VITAColors.amber.opacity(0.07))
                    }

                    // HRV line
                    ForEach(readings) { r in
                        LineMark(
                            x: .value("Day", r.day),
                            y: .value("HRV", r.hrv)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(VITAColors.teal)

                        PointMark(
                            x: .value("Day", r.day),
                            y: .value("HRV", r.hrv)
                        )
                        .symbolSize(22)
                        .foregroundStyle(pointColor(r))
                    }
                }
                .chartYScale(domain: 20...90)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [40, 56, 90]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }

                // Stress legend
                HStack(spacing: VITASpacing.sm) {
                    stressLegend(color: VITAColors.coral, label: "High stress")
                    stressLegend(color: VITAColors.amber, label: "Moderate")
                    stressLegend(color: VITAColors.teal,  label: "Low")
                }
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private func pointColor(_ r: SkinHealthViewModel.HRVReading) -> Color {
        switch r.stressZone {
        case .high:     return VITAColors.coral
        case .moderate: return VITAColors.amber
        case .low:      return VITAColors.teal
        }
    }

    private func stressLegend(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}
