import SwiftUI
import VITADesignSystem

struct MiniGlucoseChart: View {
    let dataPoints: [GlucoseDataPoint]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            HStack {
                Text("Glucose")
                    .font(VITATypography.headline)
                Text("Last 6 hours")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
                Spacer()
                if let last = dataPoints.last, !isLoading {
                    Text("\(Int(last.value))")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(VITAColors.glucoseColor(mgDL: last.value))
                    Text("mg/dL")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                    .fill(VITAColors.cardBackground)
                    .frame(height: 160)
                    .redacted(reason: .placeholder)
            } else if dataPoints.isEmpty {
                Text("Waiting for glucose samples...")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                GlucoseChart(dataPoints: dataPoints, hours: 6)
                    .frame(height: 160)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .padding(.horizontal, VITASpacing.lg)
    }
}
