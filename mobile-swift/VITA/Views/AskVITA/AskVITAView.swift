import SwiftUI
import VITADesignSystem
import CausalityEngine

struct AskVITAView: View {
    var appState: AppState
    @State private var viewModel = AskVITAViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: VITASpacing.xl) {
                        if !viewModel.hasQueried {
                            emptyState
                        } else {
                            resultsView
                        }
                    }
                    .padding(.bottom, 100) // Space for input bar
                }

                QueryInputView(viewModel: viewModel, appState: appState)
            }
            .background(VITAColors.background)
            .navigationTitle("Ask VITA")
        }
    }

    private var emptyState: some View {
        VStack(spacing: VITASpacing.xl) {
            Spacer().frame(height: VITASpacing.xxxl)

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(VITAColors.teal.opacity(0.6))

            VStack(spacing: VITASpacing.sm) {
                Text("Ask anything about your health")
                    .font(VITATypography.title3)
                    .foregroundStyle(VITAColors.textPrimary)

                Text("VITA will trace causal chains through your\nmeals, glucose, HRV, sleep, and behavior data")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: VITASpacing.sm) {
                Text("Try asking:")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)

                FlowLayout(spacing: VITASpacing.sm) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        ChipView(label: suggestion) {
                            viewModel.queryText = suggestion
                            Task { await viewModel.query(appState: appState) }
                        }
                    }
                }
                .padding(.horizontal, VITASpacing.lg)
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: VITASpacing.lg) {
            ForEach(Array(viewModel.explanations.enumerated()), id: \.offset) { index, explanation in
                CausalExplanationCard(
                    explanation: explanation,
                    nodes: viewModel.causalNodes(for: explanation),
                    glucoseDataPoints: viewModel.glucoseDataPoints,
                    mealAnnotations: viewModel.mealAnnotations,
                    counterfactuals: viewModel.counterfactuals
                )
                .padding(.horizontal, VITASpacing.lg)
            }

            if !viewModel.counterfactuals.isEmpty {
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    Text("What You Can Change")
                        .font(VITATypography.title3)
                        .padding(.horizontal, VITASpacing.lg)

                    ForEach(Array(viewModel.counterfactuals.enumerated()), id: \.offset) { _, cf in
                        CounterfactualCard(counterfactual: cf)
                            .padding(.horizontal, VITASpacing.lg)
                    }
                }
            }
        }
        .padding(.top, VITASpacing.lg)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
