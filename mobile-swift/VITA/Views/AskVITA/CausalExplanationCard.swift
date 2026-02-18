import SwiftUI
import VITADesignSystem
import CausalityEngine

struct CausalExplanationCard: View {
    let explanation: CausalExplanation
    let nodes: [CausalChainNode]
    let glucoseDataPoints: [GlucoseDataPoint]
    let mealAnnotations: [MealAnnotationPoint]
    let counterfactuals: [Counterfactual]
    @State private var isExpanded = true

    init(
        explanation: CausalExplanation,
        nodes: [CausalChainNode],
        glucoseDataPoints: [GlucoseDataPoint] = [],
        mealAnnotations: [MealAnnotationPoint] = [],
        counterfactuals: [Counterfactual] = []
    ) {
        self.explanation = explanation
        self.nodes = nodes
        self.glucoseDataPoints = glucoseDataPoints
        self.mealAnnotations = mealAnnotations
        self.counterfactuals = counterfactuals
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.lg) {
            // Header
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(VITAColors.teal)
                Text("Causal Chain")
                    .font(VITATypography.headline)
                Spacer()
                ConfidenceBar(confidence: explanation.confidence, label: "Confidence")
                    .frame(width: 120)
            }

            // Flow diagram
            CausalChainFlowView(nodes: nodes)

            // Narrative
            Text(explanation.narrative)
                .font(VITATypography.narrative)
                .foregroundStyle(VITAColors.textSecondary)
                .lineSpacing(4)

            // Full Story link
            NavigationLink {
                FullStoryView(
                    explanation: explanation,
                    glucoseDataPoints: glucoseDataPoints,
                    mealAnnotations: mealAnnotations,
                    counterfactuals: counterfactuals,
                    nodes: nodes
                )
            } label: {
                HStack {
                    Image(systemName: "text.book.closed")
                        .font(.callout)
                    Text("Full Story")
                        .font(VITATypography.callout)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }
                .foregroundStyle(VITAColors.teal)
                .padding(VITASpacing.md)
                .background(VITAColors.teal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.buttonCornerRadius))
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}
