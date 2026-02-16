import SwiftUI
import VITADesignSystem
import CausalityEngine

struct CounterfactualCard: View {
    let counterfactual: Counterfactual

    var body: some View {
        HStack(spacing: VITASpacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(VITAColors.success)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: VITASpacing.sm) {
                Text(counterfactual.description)
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textPrimary)

                HStack(spacing: VITASpacing.lg) {
                    HStack(spacing: VITASpacing.xs) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                        Text("Impact: \(Int(counterfactual.impact * 100))%")
                            .font(VITATypography.caption)
                    }
                    .foregroundStyle(VITAColors.success)

                    HStack(spacing: VITASpacing.xs) {
                        Image(systemName: effortIcon)
                            .font(.caption2)
                        Text(counterfactual.effort.rawValue.capitalized)
                            .font(VITATypography.caption)
                    }
                    .foregroundStyle(effortColor)

                    Spacer()

                    Text("\(Int(counterfactual.confidence * 100))%")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var effortIcon: String {
        switch counterfactual.effort {
        case .trivial: return "checkmark.circle"
        case .moderate: return "figure.walk"
        case .significant: return "mountain.2"
        }
    }

    private var effortColor: Color {
        switch counterfactual.effort {
        case .trivial: return VITAColors.success
        case .moderate: return VITAColors.amber
        case .significant: return VITAColors.coral
        }
    }
}
