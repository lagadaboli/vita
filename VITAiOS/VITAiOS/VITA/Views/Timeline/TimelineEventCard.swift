import SwiftUI
import VITADesignSystem

struct TimelineEventCard: View {
    let event: TimelineViewModel.TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: VITASpacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                HStack {
                    Image(systemName: eventIcon)
                        .font(.callout)
                        .foregroundStyle(event.accentColor)

                    Text(event.title)
                        .font(VITATypography.headline)

                    Spacer()

                    if let value = event.value {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(value)
                                .font(VITATypography.metricSmall)
                                .foregroundStyle(event.accentColor)
                            if let unit = event.unit {
                                Text(unit)
                                    .font(VITATypography.caption2)
                                    .foregroundStyle(VITAColors.textTertiary)
                            }
                        }
                    }
                }

                Text(event.detail)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)

                Text(event.timestamp, style: .relative)
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var eventIcon: String {
        switch event.category {
        case .meal: return "fork.knife"
        case .glucose: return "chart.line.uptrend.xyaxis"
        case .hrv: return "waveform.path.ecg"
        case .heartRate: return "heart"
        case .behavior: return "iphone"
        case .sleep: return "moon.zzz"
        }
    }
}
