import SwiftUI

public struct InsightCard: View {
    let icon: String
    let title: String
    let message: String
    let severity: InsightSeverity
    let timestamp: Date?

    public init(icon: String, title: String, message: String, severity: InsightSeverity = .info, timestamp: Date? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
    }

    public var body: some View {
        HStack(alignment: .top, spacing: VITASpacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(severity.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                HStack(spacing: VITASpacing.sm) {
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(severity.color)

                    Text(title)
                        .font(VITATypography.headline)
                        .foregroundStyle(VITAColors.textPrimary)

                    Spacer()

                    if let timestamp {
                        Text(timestamp, style: .relative)
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                    }
                }

                Text(message)
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}

public enum InsightSeverity: Sendable {
    case info, warning, alert, positive

    public var color: Color {
        switch self {
        case .info: return VITAColors.info
        case .warning: return VITAColors.amber
        case .alert: return VITAColors.coral
        case .positive: return VITAColors.success
        }
    }
}
