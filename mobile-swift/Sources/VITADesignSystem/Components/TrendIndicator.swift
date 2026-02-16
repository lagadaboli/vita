import SwiftUI

public struct TrendIndicator: View {
    let direction: TrendDirection
    let color: Color

    public init(direction: TrendDirection, color: Color = VITAColors.teal) {
        self.direction = direction
        self.color = color
    }

    public var body: some View {
        HStack(spacing: VITASpacing.xs) {
            Image(systemName: direction.icon)
                .font(.caption2)
            Text(direction.label)
                .font(VITATypography.caption2)
        }
        .foregroundStyle(trendColor)
    }

    private var trendColor: Color {
        switch direction {
        case .up: return VITAColors.amber
        case .down: return VITAColors.info
        case .stable: return VITAColors.success
        }
    }
}
