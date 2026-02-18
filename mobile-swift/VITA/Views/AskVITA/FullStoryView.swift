import SwiftUI
import VITADesignSystem
import CausalityEngine

/// Deep-dive view combining annotated glucose chart, three-part narrative,
/// causal chain flow, and top counterfactuals. Deep-link destination for iOS notifications (Tier 2).
struct FullStoryView: View {
    let explanation: CausalExplanation
    let glucoseDataPoints: [GlucoseDataPoint]
    let mealAnnotations: [MealAnnotationPoint]
    let counterfactuals: [Counterfactual]
    let nodes: [CausalChainNode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VITASpacing.xl) {
                // Annotated Glucose Chart
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    Text("Glucose & Meals")
                        .font(VITATypography.title3)
                        .foregroundStyle(VITAColors.textPrimary)

                    AnnotatedGlucoseChart(
                        dataPoints: glucoseDataPoints,
                        mealAnnotations: mealAnnotations
                    )
                    .frame(height: 220)
                }
                .padding(.horizontal, VITASpacing.lg)

                // Three-Part Narrative (Why / Evidence / Fix)
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    Text("What Happened")
                        .font(VITATypography.title3)
                        .foregroundStyle(VITAColors.textPrimary)

                    narrativeSection
                }
                .padding(.horizontal, VITASpacing.lg)

                // Causal Chain Flow
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(VITAColors.teal)
                        Text("Causal Chain")
                            .font(VITATypography.title3)
                        Spacer()
                        ConfidenceBar(confidence: explanation.confidence, label: "Confidence")
                            .frame(width: 120)
                    }

                    CausalChainView(nodes: nodes)
                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
                .padding(.horizontal, VITASpacing.lg)

                // Counterfactuals
                if !counterfactuals.isEmpty {
                    VStack(alignment: .leading, spacing: VITASpacing.md) {
                        Text("What You Can Change")
                            .font(VITATypography.title3)
                            .foregroundStyle(VITAColors.textPrimary)
                            .padding(.horizontal, VITASpacing.lg)

                        ForEach(Array(counterfactuals.prefix(3).enumerated()), id: \.offset) { _, cf in
                            CounterfactualCard(counterfactual: cf)
                                .padding(.horizontal, VITASpacing.lg)
                        }
                    }
                }
            }
            .padding(.vertical, VITASpacing.lg)
        }
        .background(VITAColors.background)
        .navigationTitle("Full Story")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var narrativeSection: some View {
        let parts = splitNarrative(explanation.narrative)

        return VStack(alignment: .leading, spacing: VITASpacing.md) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                HStack(alignment: .top, spacing: VITASpacing.md) {
                    let icons = ["questionmark.circle", "chart.bar", "lightbulb"]
                    let colors = [VITAColors.coral, VITAColors.teal, VITAColors.amber]
                    let labels = ["Why", "Evidence", "Fix"]

                    VStack {
                        Image(systemName: icons[min(index, 2)])
                            .font(.callout)
                            .foregroundStyle(colors[min(index, 2)])
                            .frame(width: 28, height: 28)
                        Text(labels[min(index, 2)])
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                    }

                    Text(part)
                        .font(VITATypography.narrative)
                        .foregroundStyle(VITAColors.textSecondary)
                        .lineSpacing(4)
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    /// Split narrative into 3 parts by sentence boundaries.
    private func splitNarrative(_ narrative: String) -> [String] {
        let sentences = narrative.components(separatedBy: ". ")
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != "." }

        guard sentences.count >= 3 else {
            // Pad to 3 parts if fewer sentences
            var padded = sentences
            while padded.count < 3 { padded.append("") }
            return padded.filter { !$0.isEmpty }
        }
        return Array(sentences.prefix(3))
    }
}
