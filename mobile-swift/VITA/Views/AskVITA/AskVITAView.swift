import SwiftUI
import VITADesignSystem
import CausalityEngine

struct AskVITAView: View {
    var appState: AppState
    @State private var viewModel = AskVITAViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(spacing: VITASpacing.xl) {
                        if !appState.isLoaded {
                            EmptyDataStateView(
                                title: "Preparing Ask VITA",
                                message: "Health data is still syncing. You can type now and send once sync completes."
                            )
                            .padding(.horizontal, VITASpacing.lg)
                        }

                        if !viewModel.hasQueried {
                            emptyState
                        } else {
                            resultsView
                        }
                    }
                    .frame(width: proxy.size.width, alignment: .topLeading)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    QueryInputView(viewModel: viewModel, appState: appState)
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Ask VITA")
            .sheet(isPresented: $viewModel.isShowingReportShareSheet) {
                if let data = viewModel.reportPDFData {
                    ActivityShareSheet(items: [data])
                }
            }
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !viewModel.counterfactuals.isEmpty {
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    Text("What You Can Change")
                        .font(VITATypography.title3)
                        .padding(.horizontal, VITASpacing.lg)

                    ForEach(Array(viewModel.counterfactuals.enumerated()), id: \.offset) { _, cf in
                        CounterfactualCard(counterfactual: cf)
                            .padding(.horizontal, VITASpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            reportSection
        }
        .padding(.top, VITASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(VITAColors.teal)
                Text("Clinical Report")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                Spacer()
            }

            Text("Generate a provider-ready PDF using your question, causal chain, and measurable health patterns.")
                .font(VITATypography.callout)
                .foregroundStyle(VITAColors.textSecondary)

            if !FoxitConfig.current.isConfigured {
                Text("Configure both Foxit API apps in Settings before generating.")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.amber)
            }

            switch viewModel.reportState {
            case .idle:
                EmptyView()
            case .generatingDocument:
                reportProgress("Generating with Document Generation API…")
            case .optimizingPDF:
                reportProgress("Optimizing with PDF Services API…")
            case .complete:
                HStack(spacing: VITASpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(VITAColors.success)
                    Text("Report ready · \(viewModel.formattedReportFileSize)")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                }
            case .error(let message):
                Text(message)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.error)
            }

            HStack(spacing: VITASpacing.sm) {
                Button {
                    Task { await viewModel.generateReport(appState: appState) }
                } label: {
                    Label("Generate Report", systemImage: "doc.text")
                        .font(VITATypography.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VITASpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(VITAColors.teal)
                .disabled(!viewModel.canGenerateReport || !FoxitConfig.current.isConfigured)

                Button {
                    viewModel.isShowingReportShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(VITATypography.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VITASpacing.sm)
                }
                .buttonStyle(.bordered)
                .tint(VITAColors.teal)
                .disabled(viewModel.reportState != .complete || viewModel.reportPDFData == nil)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .padding(.horizontal, VITASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reportProgress(_ title: String) -> some View {
        HStack(spacing: VITASpacing.sm) {
            ProgressView()
                .tint(VITAColors.teal)
            Text(title)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
        }
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
        let maxWidth = proposal.width ?? 320
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

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
