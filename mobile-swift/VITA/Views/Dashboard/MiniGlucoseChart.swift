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
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    ShimmerSkeleton(width: 86, height: 10, cornerRadius: 6)
                    ShimmerSkeleton(width: 140, height: 10, cornerRadius: 6)
                    ShimmerSkeleton(height: 120, cornerRadius: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
