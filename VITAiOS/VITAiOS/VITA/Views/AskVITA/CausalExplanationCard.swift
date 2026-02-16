import SwiftUI
import VITADesignSystem
import CausalityEngine

struct CausalExplanationCard: View {
    let explanation: CausalExplanation
    let nodes: [CausalChainNode]
    @State private var isExpanded = true

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
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}
