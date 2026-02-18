import SwiftUI
import Charts
import VITACore

/// A meal annotation point overlaid on the glucose chart.
public struct MealAnnotationPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let label: String
    public let glycemicLoad: Double

    public init(timestamp: Date, label: String, glycemicLoad: Double) {
        self.timestamp = timestamp
        self.label = label
        self.glycemicLoad = glycemicLoad
    }
}

/// Glucose chart with vertical meal annotation markers.
/// Inherits glucose line/area styling from `GlucoseChart` pattern, adds `RuleMark` dashed lines
/// at meal timestamps with labels. Leaves existing `GlucoseChart` untouched.
public struct AnnotatedGlucoseChart: View {
    let dataPoints: [GlucoseDataPoint]
    let mealAnnotations: [MealAnnotationPoint]
    let hours: Int

    public init(dataPoints: [GlucoseDataPoint], mealAnnotations: [MealAnnotationPoint], hours: Int = 6) {
        self.dataPoints = dataPoints
        self.mealAnnotations = mealAnnotations
        self.hours = hours
    }

    public var body: some View {
        Chart {
            // Glucose line
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", point.value)
                )
                .foregroundStyle(lineGradient)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", point.value)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)
            }

            // Meal annotation vertical dashed lines
            ForEach(mealAnnotations) { meal in
                RuleMark(x: .value("Meal", meal.timestamp))
                    .foregroundStyle(VITAColors.amber.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 2) {
                            Image(systemName: "fork.knife")
                                .font(.caption2)
                                .foregroundStyle(VITAColors.amber)
                            Text(meal.label)
                                .font(VITATypography.caption2)
                                .foregroundStyle(VITAColors.textSecondary)
                            Text("GL \(Int(meal.glycemicLoad))")
                                .font(VITATypography.caption2)
                                .foregroundStyle(VITAColors.textTertiary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(VITAColors.cardBackground.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartYScale(domain: 60...200)
        .chartYAxis {
            AxisMarks(position: .leading, values: [70, 100, 140, 180]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.15))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .font(VITATypography.caption2)
            }
        }
        .chartBackground { proxy in
            GeometryReader { _ in
                let plotArea = proxy.plotSize
                Rectangle()
                    .fill(VITAColors.glucoseNormal.opacity(0.06))
                    .frame(height: plotArea.height * 0.35)
                    .offset(y: plotArea.height * 0.28)
            }
        }
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [VITAColors.teal, VITAColors.glucoseElevated],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [VITAColors.teal.opacity(0.2), VITAColors.teal.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
