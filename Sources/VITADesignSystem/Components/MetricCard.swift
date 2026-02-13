import SwiftUI
import VITACore

public struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: TrendDirection
    let color: Color

    public init(title: String, value: String, unit: String, trend: TrendDirection = .stable, color: Color = VITAColors.teal) {
        self.title = title
        self.value = value
        self.unit = unit
        self.trend = trend
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            Text(title)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: VITASpacing.xs) {
                Text(value)
                    .font(VITATypography.metric)
                    .foregroundStyle(color)

                Text(unit)
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            TrendIndicator(direction: trend, color: color)
        }
        .padding(VITASpacing.cardPadding)
        .frame(width: 140, alignment: .leading)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}

public enum TrendDirection: Sendable {
    case up, down, stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .up: return "Rising"
        case .down: return "Falling"
        case .stable: return "Stable"
        }
    }
}
