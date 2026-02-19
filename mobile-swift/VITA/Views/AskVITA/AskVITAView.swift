import SwiftUI
import VITADesignSystem
import CausalityEngine

struct AskVITAView: View {
    var appState: AppState
    @State private var viewModel = AskVITAViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !appState.isLoaded {
                                syncingBanner
                                    .padding(.horizontal, VITASpacing.lg)
                                    .padding(.top, VITASpacing.md)
                            }

                            if !viewModel.hasQueried {
                                emptyState
                                    .frame(minHeight: proxy.size.height - 80)
                            } else {
                                chatView
                                    .id("chatTop")
                            }
                        }
                        .frame(width: proxy.size.width, alignment: .topLeading)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        QueryInputView(viewModel: viewModel, appState: appState)
                    }
                    .onChange(of: viewModel.hasQueried) { _, queried in
                        if queried {
                            withAnimation {
                                scrollProxy.scrollTo("chatTop", anchor: .top)
                            }
                        }
                    }
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Ask VITA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.hasQueried {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.hasQueried = false
                                viewModel.explanations = []
                                viewModel.counterfactuals = []
                                viewModel.lastSubmittedQuery = ""
                                viewModel.activatedSources = []
                                viewModel.resetReport()
                            }
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(VITAColors.teal)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingReportShareSheet) {
                if let data = viewModel.reportPDFData {
                    ActivityShareSheet(items: [data])
                }
            }
        }
    }

    // MARK: - Syncing Banner

    private var syncingBanner: some View {
        HStack(spacing: VITASpacing.sm) {
            ProgressView()
                .tint(VITAColors.amber)
                .scaleEffect(0.8)
            Text("Syncing health data — analysis will be more accurate once complete.")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
        }
        .padding(VITASpacing.md)
        .background(VITAColors.amber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.buttonCornerRadius))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VITASpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(VITAColors.teal.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38))
                    .foregroundStyle(VITAColors.teal)
            }

            // Headline
            VStack(spacing: VITASpacing.xs) {
                Text("Ask anything about your health")
                    .font(VITATypography.title3)
                    .foregroundStyle(VITAColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("VITA traces causal chains through your glucose,\nHRV, meals, sleep, and behavior data.")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Data source pills
            HStack(spacing: VITASpacing.xs) {
                ForEach(["Glucose", "HRV", "Meals", "Sleep", "Behavior"], id: \.self) { source in
                    dataSourcePill(source)
                }
            }

            // Suggestions
            VStack(alignment: .center, spacing: VITASpacing.sm) {
                Text("Try asking")
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

            Spacer()
            Spacer()
        }
        .padding(.horizontal, VITASpacing.lg)
    }

    private func dataSourcePill(_ label: String) -> some View {
        Text(label)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(VITAColors.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(VITAColors.teal.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(alignment: .leading, spacing: VITASpacing.xl) {
            // User query bubble
            HStack {
                Spacer(minLength: 48)
                Text(viewModel.lastSubmittedQuery)
                    .font(VITATypography.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, VITASpacing.md)
                    .padding(.vertical, VITASpacing.sm)
                    .background(VITAColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.top, VITASpacing.lg)

            if viewModel.isQuerying {
                thinkingView
            } else {
                vitaResponseView
            }
        }
    }

    // MARK: - Thinking Indicator

    private var thinkingView: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            // VITA avatar + thinking bubble
            HStack(alignment: .top, spacing: VITASpacing.sm) {
                vitaAvatar

                VStack(alignment: .leading, spacing: VITASpacing.xs) {
                    ThinkingDots()
                    .padding(.horizontal, VITASpacing.md)
                    .padding(.vertical, VITASpacing.sm)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(viewModel.currentLoadingPhase)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                        .padding(.leading, VITASpacing.xs)
                        .animation(.easeInOut, value: viewModel.loadingPhase)
                }
            }
            .padding(.horizontal, VITASpacing.lg)
        }
    }

    // MARK: - VITA Response

    private var vitaResponseView: some View {
        VStack(alignment: .leading, spacing: VITASpacing.xl) {
            // VITA avatar + source badges
            HStack(alignment: .center, spacing: VITASpacing.sm) {
                vitaAvatar

                VStack(alignment: .leading, spacing: 3) {
                    Text("VITA")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(VITAColors.textSecondary)

                    if !viewModel.activatedSources.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(viewModel.activatedSources.sorted()), id: \.self) { source in
                                dataSourcePill(source)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, VITASpacing.lg)

            // Causal explanation cards
            if viewModel.explanations.isEmpty {
                noResultsCard
                    .padding(.horizontal, VITASpacing.lg)
            } else {
                VStack(spacing: VITASpacing.md) {
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
                }
            }

            // What You Can Change
            if !viewModel.counterfactuals.isEmpty {
                VStack(alignment: .leading, spacing: VITASpacing.md) {
                    sectionHeader(
                        icon: "arrow.triangle.2.circlepath",
                        title: "What You Can Change",
                        color: VITAColors.success
                    )
                    .padding(.horizontal, VITASpacing.lg)

                    ForEach(Array(viewModel.counterfactuals.enumerated()), id: \.offset) { _, cf in
                        CounterfactualCard(counterfactual: cf)
                            .padding(.horizontal, VITASpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // Clinical Report (PDF) section — always visible after a query
            reportSection
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxxl)
        }
    }

    // MARK: - No Results

    private var noResultsCard: some View {
        HStack(spacing: VITASpacing.md) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(VITAColors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not enough data yet")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textPrimary)
                Text("VITA needs a few more days of health data to trace this causal chain.")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    // MARK: - Report Section

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            // Header row
            HStack(spacing: VITASpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VITAColors.teal.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(VITAColors.teal)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clinical Report")
                        .font(VITATypography.headline)
                        .foregroundStyle(VITAColors.textPrimary)
                    Text("Provider-ready PDF · Powered by Foxit")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }

                Spacer()

                if viewModel.reportState == .complete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(VITAColors.success)
                }
            }

            // What's included
            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                reportFeatureRow("Causal chain analysis with confidence scores")
                reportFeatureRow("Glucose & meal patterns (last 6 hours)")
                reportFeatureRow("Evidence-based intervention recommendations")
                reportFeatureRow("AI-generated clinical narrative")
            }

            // Foxit not configured warning
            if !FoxitConfig.current.isConfigured {
                HStack(spacing: VITASpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                    Text("Configure Foxit API keys in Settings to enable report generation.")
                        .font(VITATypography.caption)
                }
                .foregroundStyle(VITAColors.amber)
                .padding(.top, 2)
            }

            // Progress states
            switch viewModel.reportState {
            case .idle:
                EmptyView()
            case .generatingDocument:
                reportProgressRow("Generating document structure…", progress: 0.45)
            case .optimizingPDF:
                reportProgressRow("Optimizing PDF…", progress: 0.85)
            case .complete:
                HStack(spacing: VITASpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VITAColors.success)
                    Text("Report ready — \(viewModel.formattedReportFileSize)")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                }
            case .error(let message):
                HStack(alignment: .top, spacing: VITASpacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VITAColors.error)
                    Text(message)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.error)
                }
            }

            // Action buttons
            HStack(spacing: VITASpacing.sm) {
                Button {
                    Task { await viewModel.generateReport(appState: appState) }
                } label: {
                    HStack(spacing: VITASpacing.xs) {
                        Image(systemName: viewModel.reportState == .complete ? "arrow.clockwise" : "doc.text")
                            .font(.system(size: 14, weight: .medium))
                        Text(viewModel.reportState == .complete ? "Regenerate" : "Generate Report")
                            .font(VITATypography.callout)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(VITAColors.teal)
                .disabled(!viewModel.canGenerateReport || !FoxitConfig.current.isConfigured)

                if viewModel.reportState == .complete && viewModel.reportPDFData != nil {
                    Button {
                        viewModel.isShowingReportShareSheet = true
                    } label: {
                        HStack(spacing: VITASpacing.xs) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                            Text("Share")
                                .font(VITATypography.callout)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                    .tint(VITAColors.teal)
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                .strokeBorder(VITAColors.teal.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var vitaAvatar: some View {
        ZStack {
            Circle()
                .fill(VITAColors.teal.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(VITAColors.teal)
        }
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(title)
                .font(VITATypography.title3)
                .foregroundStyle(VITAColors.textPrimary)
        }
    }

    private func reportFeatureRow(_ text: String) -> some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VITAColors.teal)
                .frame(width: 16)
            Text(text)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
        }
    }

    private func reportProgressRow(_ label: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressView()
                    .tint(VITAColors.teal)
                    .scaleEffect(0.8)
                Text(label)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .tint(VITAColors.teal)
        }
    }
}

// MARK: - Thinking Dots Animation

private struct ThinkingDots: View {
    @State private var activeIndex: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(VITAColors.teal)
                    .frame(width: 7, height: 7)
                    .opacity(activeIndex == index ? 1.0 : 0.3)
                    .scaleEffect(activeIndex == index ? 1.1 : 0.7)
                    .animation(.easeInOut(duration: 0.35), value: activeIndex)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                activeIndex = (activeIndex + 1) % 3
            }
        }
    }
}

// MARK: - Flow Layout

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

// MARK: - Share Sheet

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
