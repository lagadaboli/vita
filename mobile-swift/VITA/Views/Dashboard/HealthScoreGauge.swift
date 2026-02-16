import SwiftUI
import VITADesignSystem

struct HealthScoreGauge: View {
    let score: Double

    var body: some View {
        VStack(spacing: VITASpacing.sm) {
            HealthScoreRing(score: score)

            Text(scoreLabel)
                .font(VITATypography.callout)
                .foregroundStyle(VITAColors.healthScoreColor(score))
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Attention"
        }
    }
}
