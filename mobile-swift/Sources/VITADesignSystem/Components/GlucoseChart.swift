import SwiftUI
import Charts
import VITACore

public struct GlucoseDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double

    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

public struct GlucoseChart: View {
    let dataPoints: [GlucoseDataPoint]
    let hours: Int

    public init(dataPoints: [GlucoseDataPoint], hours: Int = 6) {
        self.dataPoints = dataPoints
        self.hours = hours
    }

    public var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.value)
            )
            .foregroundStyle(gradient)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.value)
            )
            .foregroundStyle(areaGradient)
            .interpolationMethod(.catmullRom)
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
            GeometryReader { geo in
                let plotArea = proxy.plotSize
                Rectangle()
                    .fill(VITAColors.glucoseNormal.opacity(0.06))
                    .frame(height: plotArea.height * 0.35)
                    .offset(y: plotArea.height * 0.28)
            }
        }
    }

    private var gradient: LinearGradient {
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
