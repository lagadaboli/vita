import SwiftUI
import VITADesignSystem
import CausalityEngine
#if canImport(UIKit)
import UIKit
#endif

struct AskVITAView: View {
    var appState: AppState
    @State private var viewModel = AskVITAViewModel()
    @State private var isShowingReportPreview = false
    @Namespace private var composerNamespace

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

                            if !viewModel.hasConversation {
                                emptyState
                                    .frame(minHeight: proxy.size.height - 80)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                conversationThread
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .frame(width: proxy.size.width, alignment: .topLeading)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in
                                dismissKeyboard()
                            }
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if viewModel.hasConversation {
                            QueryInputView(
                                viewModel: viewModel,
                                appState: appState,
                                placement: .docked,
                                composerNamespace: composerNamespace
                            )
                        }
                    }
                    .animation(.spring(response: 0.48, dampingFraction: 0.88), value: viewModel.hasConversation)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scrollProxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Ask VITA")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                dismissKeyboard()
                consumeDraftQuestionIfNeeded()
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                if newTab == .askVITA {
                    dismissKeyboard()
                    consumeDraftQuestionIfNeeded()
                }
            }
            .toolbar {
                if viewModel.hasConversation {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.clearConversation()
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
            .sheet(isPresented: $isShowingReportPreview) {
                if let data = viewModel.reportPDFData {
                    PDFPreviewSheet(
                        data: data,
                        title: "Clinical Report",
                        suggestedFileName: "VITA-Clinical-Report.pdf"
                    )
                }
            }
        }
    }

    private func consumeDraftQuestionIfNeeded() {
        let text = (appState.askVITADraftQuestion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.queryText = text
        appState.askVITADraftQuestion = nil
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    // MARK: - Syncing Banner

    private var syncingBanner: some View {
        HStack(spacing: VITASpacing.sm) {
            ProgressView().tint(VITAColors.amber).scaleEffect(0.8)
            Text("Syncing health data — analysis improves as data accumulates.")
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
            Spacer(minLength: VITASpacing.lg)

            AnimatedBrainHero()

            VStack(spacing: VITASpacing.xs) {
                Text("Ask anything about your health")
                    .font(VITATypography.title3)
                    .foregroundStyle(VITAColors.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Data source pills
            HStack(spacing: VITASpacing.xs) {
                ForEach(["Glucose", "HRV", "Meals", "Sleep", "Behavior"], id: \.self) { dataSourcePill($0) }
            }

            // Gemini status
            if !GeminiConfig.current.isConfigured {
                HStack(spacing: VITASpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("Add a Gemini API key in Settings for AI-powered responses")
                        .font(VITATypography.caption)
                }
                .foregroundStyle(VITAColors.amber)
                .padding(.horizontal, VITASpacing.lg)
                .multilineTextAlignment(.center)
            }

            QueryInputView(
                viewModel: viewModel,
                appState: appState,
                placement: .centered,
                composerNamespace: composerNamespace
            )

            VStack(alignment: .center, spacing: VITASpacing.sm) {
                FlowLayout(spacing: VITASpacing.sm) {
                    ForEach(Array(viewModel.suggestions.prefix(4)), id: \.self) { suggestion in
                        ChipView(label: suggestion) {
                            viewModel.queryText = suggestion
                            Task { await viewModel.sendMessage(appState: appState) }
                        }
                    }
                }
                .padding(.horizontal, VITASpacing.lg)
            }

            Spacer(minLength: VITASpacing.xl)
        }
        .padding(.horizontal, VITASpacing.lg)
    }

    // MARK: - Conversation Thread

    private var conversationThread: some View {
        VStack(alignment: .leading, spacing: VITASpacing.lg) {
            ForEach(viewModel.messages) { message in
                Group {
                    if message.role == .user {
                        userBubble(message)
                    } else {
                        vitaResponseBubble(message)
                    }
                }
                .id(message.id)
            }

            // Thinking indicator appears after last user message while querying
            if viewModel.isQuerying {
                thinkingBubble
                    .id("thinking")
            }

            // PDF Report section — always at the bottom, uses latest analysis
            if !viewModel.isQuerying && viewModel.hasConversation {
                reportSection
                    .padding(.horizontal, VITASpacing.lg)
                    .padding(.bottom, VITASpacing.xxxl)
            }
        }
        .padding(.top, VITASpacing.lg)
    }

    // MARK: - User Bubble

    private func userBubble(_ message: ChatMessage) -> some View {
        HStack {
            Spacer(minLength: 56)
            Text(message.content)
                .font(VITATypography.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, VITASpacing.md)
                .padding(.vertical, VITASpacing.sm)
                .background(VITAColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, VITASpacing.lg)
    }

    // MARK: - VITA Response Bubble

    private func vitaResponseBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: VITASpacing.sm) {
            vitaAvatar

            VStack(alignment: .leading, spacing: VITASpacing.sm) {
                // Sender label + sources
                HStack(spacing: VITASpacing.xs) {
                    Text("VITA")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(VITAColors.textSecondary)

                    if message.hasStructuredInsights {
                        let sources = sourcesFor(message)
                        ForEach(Array(sources.sorted()), id: \.self) { dataSourcePill($0) }
                    }
                }

                // AI narrative text
                Text(message.content)
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(VITASpacing.md)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Expandable causal analysis (only if there's structured data)
                if message.hasStructuredInsights {
                    AnalysisDisclosureGroup(
                        message: message,
                        causalNodes: { viewModel.causalNodes(for: $0) }
                    )
                } else {
                    noStructuredInsightsCard
                }
            }
        }
        .padding(.horizontal, VITASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Thinking Bubble

    private var thinkingBubble: some View {
        HStack(alignment: .top, spacing: VITASpacing.sm) {
            vitaAvatar

            VStack(alignment: .leading, spacing: 4) {
                ThinkingDots()
                    .padding(.horizontal, VITASpacing.md)
                    .padding(.vertical, 11)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(viewModel.currentLoadingPhase)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)
                    .animation(.easeInOut, value: viewModel.loadingPhase)
            }
        }
        .padding(.horizontal, VITASpacing.lg)
    }

    // MARK: - Report Section

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
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
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(VITAColors.success)
                }
            }

            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                reportFeatureRow("Causal chain analysis with confidence scores")
                reportFeatureRow("Glucose & meal patterns (last 6 hours)")
                reportFeatureRow("Evidence-based intervention recommendations")
                reportFeatureRow("AI-generated clinical narrative")
            }

            if !FoxitConfig.current.isConfigured {
                HStack(spacing: VITASpacing.xs) {
                    Image(systemName: "exclamationmark.triangle").font(.caption)
                    Text("Configure Foxit API keys in Settings to enable report generation.")
                        .font(VITATypography.caption)
                }
                .foregroundStyle(VITAColors.amber)
            }

            switch viewModel.reportState {
            case .idle:
                EmptyView()
            case .generatingDocument:
                reportProgressRow("Generating document structure…", progress: 0.45)
            case .optimizingPDF:
                reportProgressRow("Optimizing PDF…", progress: 0.85)
            case .complete:
                HStack(spacing: VITASpacing.xs) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(VITAColors.success)
                    Text("Report ready — \(viewModel.formattedReportFileSize)")
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                }
            case .error(let message):
                HStack(alignment: .top, spacing: VITASpacing.xs) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(VITAColors.error)
                    Text(message).font(VITATypography.caption).foregroundStyle(VITAColors.error)
                }
            }

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
                        isShowingReportPreview = true
                    } label: {
                        HStack(spacing: VITASpacing.xs) {
                            Image(systemName: "doc.viewfinder").font(.system(size: 14, weight: .medium))
                            Text("Preview").font(VITATypography.callout)
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

    private func dataSourcePill(_ label: String) -> some View {
        Text(label)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(VITAColors.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(VITAColors.teal.opacity(0.1))
            .clipShape(Capsule())
    }

    private func sourcesFor(_ message: ChatMessage) -> Set<String> {
        var s = Set<String>()
        if !message.glucoseDataPoints.isEmpty { s.insert("Glucose") }
        if !message.mealAnnotations.isEmpty { s.insert("Meals") }
        let chain = message.causalExplanations.flatMap(\.causalChain).joined().lowercased()
        if chain.contains("hrv") { s.insert("HRV") }
        if chain.contains("sleep") { s.insert("Sleep") }
        if chain.contains("screen") || chain.contains("dopamine") { s.insert("Behavior") }
        if s.isEmpty && !message.causalExplanations.isEmpty { s.insert("Health Graph") }
        return s
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
                ProgressView().tint(VITAColors.teal).scaleEffect(0.8)
                Text(label).font(VITATypography.caption).foregroundStyle(VITAColors.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(VITATypography.caption).foregroundStyle(VITAColors.textTertiary).monospacedDigit()
            }
            ProgressView(value: progress).tint(VITAColors.teal)
        }
    }

    private var noStructuredInsightsCard: some View {
        HStack(alignment: .top, spacing: VITASpacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VITAColors.teal)
            Text("Insights are still loading for this reply. Ask a follow-up question to refine the causal breakdown.")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, VITASpacing.sm)
        .padding(.vertical, 8)
        .background(VITAColors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Analysis Disclosure Group

private struct AnalysisDisclosureGroup: View {
    let message: ChatMessage
    let causalNodes: (CausalExplanation) -> [CausalChainNode]
    @State private var isExpanded = false

    private var hasCausalChains: Bool {
        !message.causalExplanations.isEmpty
    }

    private var disclosureTitle: String {
        if hasCausalChains {
            return isExpanded ? "Hide analysis" : "View causal analysis"
        }
        return isExpanded ? "Hide insights" : "View insights"
    }

    private var disclosureCount: String {
        if hasCausalChains {
            let count = message.causalExplanations.count
            return "\(count) chain\(count == 1 ? "" : "s")"
        }

        if !message.counterfactuals.isEmpty {
            let count = message.counterfactuals.count
            return "\(count) lever\(count == 1 ? "" : "s")"
        }

        let dataPoints = message.glucoseDataPoints.count + message.mealAnnotations.count
        return "\(dataPoints) signal\(dataPoints == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(disclosureTitle)
                        .font(VITATypography.caption)
                    Spacer()
                    Text(disclosureCount)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }
                .foregroundStyle(VITAColors.teal)
                .padding(.horizontal, VITASpacing.sm)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: VITASpacing.md) {
                    if hasCausalChains {
                        ForEach(Array(message.causalExplanations.enumerated()), id: \.offset) { _, exp in
                            CausalExplanationCard(
                                explanation: exp,
                                nodes: causalNodes(exp),
                                glucoseDataPoints: message.glucoseDataPoints,
                                mealAnnotations: message.mealAnnotations,
                                counterfactuals: message.counterfactuals
                            )
                        }
                    } else {
                        HStack(alignment: .top, spacing: VITASpacing.xs) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(VITAColors.teal)
                            Text("No causal chain was returned for this reply, but you can still use recommendations and generate a report.")
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !message.counterfactuals.isEmpty {
                        VStack(alignment: .leading, spacing: VITASpacing.sm) {
                            HStack(spacing: VITASpacing.sm) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(VITAColors.success)
                                Text("What You Can Change")
                                    .font(VITATypography.headline)
                                    .foregroundStyle(VITAColors.textPrimary)
                            }
                            ForEach(Array(message.counterfactuals.prefix(4).enumerated()), id: \.offset) { _, cf in
                                CounterfactualCard(counterfactual: cf)
                            }
                        }
                    }
                }
                .padding(.top, VITASpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Thinking Dots

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

private struct AnimatedBrainHero: View {
    @State private var isPulsing = false
    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VITAColors.teal.opacity(0.18),
                            VITAColors.teal.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 70
                    )
                )
                .frame(width: 132, height: 132)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            VITAColors.teal.opacity(0.12),
                            VITAColors.teal.opacity(0.8),
                            VITAColors.teal.opacity(0.12)
                        ],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 106, height: 106)
                .rotationEffect(.degrees(isRotating ? 360 : 0))

            Circle()
                .stroke(
                    VITAColors.teal.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 8])
                )
                .frame(width: 122, height: 122)
                .rotationEffect(.degrees(isRotating ? -360 : 0))

            Circle()
                .fill(VITAColors.teal.opacity(0.12))
                .frame(width: 88, height: 88)

            Image(systemName: "brain.head.profile")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(VITAColors.teal)
        }
        .scaleEffect(isPulsing ? 1.04 : 0.95)
        .shadow(color: VITAColors.teal.opacity(0.25), radius: isPulsing ? 24 : 10, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layoutSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
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
