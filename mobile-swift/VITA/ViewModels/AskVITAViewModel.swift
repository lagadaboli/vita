import Foundation
import VITACore
import CausalityEngine
import VITADesignSystem

@MainActor
@Observable
final class AskVITAViewModel {
    private let maxChartPoints = 180

    enum ReportGenerationState: Equatable {
        case idle
        case generatingDocument
        case optimizingPDF
        case complete
        case error(String)
    }

    // MARK: - Conversation

    /// Full conversation history — this is the primary source of truth.
    var messages: [ChatMessage] = []

    /// Text currently in the input field.
    var queryText = ""

    /// Whether the engine is processing a query right now.
    var isQuerying = false

    /// Rotating loading phase label.
    var loadingPhase: Int = 0

    static let loadingPhases = [
        "Scanning glucose patterns...",
        "Cross-referencing meal data...",
        "Analyzing HRV & sleep...",
        "Tracing causal chains...",
        "Generating insights..."
    ]

    var currentLoadingPhase: String {
        Self.loadingPhases[loadingPhase % Self.loadingPhases.count]
    }

    private var loadingTask: Task<Void, Never>?

    // MARK: - Report

    var reportState: ReportGenerationState = .idle
    var reportPDFData: Data?
    var isShowingReportShareSheet = false

    // MARK: - Computed

    var hasConversation: Bool { !messages.isEmpty }

    /// The last VITA message — for fallback display and PDF.
    var lastVITAMessage: ChatMessage? {
        messages.last(where: { $0.role == .vita })
    }

    /// Structured data from the latest VITA response (for the PDF pipeline).
    var latestExplanations: [CausalExplanation] {
        lastVITAMessage?.causalExplanations ?? []
    }

    var latestCounterfactuals: [Counterfactual] {
        lastVITAMessage?.counterfactuals ?? []
    }

    var latestGlucoseDataPoints: [GlucoseDataPoint] {
        lastVITAMessage?.glucoseDataPoints ?? []
    }

    var latestMealAnnotations: [MealAnnotationPoint] {
        lastVITAMessage?.mealAnnotations ?? []
    }

    var latestActivatedSources: Set<String> {
        // Infer from last VITA message's causal chains
        guard let msg = lastVITAMessage, msg.hasAnalysis else { return [] }
        var sources = Set<String>()
        if !msg.glucoseDataPoints.isEmpty { sources.insert("Glucose") }
        if !msg.mealAnnotations.isEmpty { sources.insert("Meals") }
        let chain = msg.causalExplanations.flatMap(\.causalChain).joined(separator: " ").lowercased()
        if chain.contains("hrv") { sources.insert("HRV") }
        if chain.contains("sleep") { sources.insert("Sleep") }
        if chain.contains("screen") || chain.contains("dopamine") { sources.insert("Behavior") }
        if chain.contains("aqi") || chain.contains("pollen") { sources.insert("Environment") }
        return sources
    }

    var canGenerateReport: Bool {
        !messages.isEmpty && !latestExplanations.isEmpty && !isQuerying
    }

    var formattedReportFileSize: String {
        guard let data = reportPDFData else { return "" }
        let bytes = data.count
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_024 * 1_024 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / (1_024 * 1_024))
    }

    // MARK: - Suggestions

    let suggestions = [
        "Why am I tired?",
        "Why can't I focus?",
        "Why is my stomach upset?",
        "Why am I sleeping poorly?",
        "Why is my HRV low?",
        "Why did my glucose spike?",
        "Why do I feel anxious?",
        "Why am I crashing after meals?"
    ]

    // MARK: - Send Message

    func sendMessage(appState: AppState) async {
        let text = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isQuerying else { return }

        // Clear input immediately
        queryText = ""
        isQuerying = true
        loadingPhase = 0

        // Append user message to history
        messages.append(.user(text))

        // Rotate loading phase labels while processing
        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if Task.isCancelled { break }
                self.loadingPhase += 1
            }
        }

        defer {
            isQuerying = false
            loadingTask?.cancel()
            loadingTask = nil
        }

        do {
            // Pass all messages EXCEPT the last one (user message just appended) as history
            let history = Array(messages.dropLast())

            let result = try await VITAChatEngine.processMessage(
                userMessage: text,
                history: history,
                appState: appState
            )

            let vitaMsg = ChatMessage.vita(
                content: result.response,
                explanations: result.explanations,
                counterfactuals: result.counterfactuals,
                glucoseDataPoints: result.glucoseDataPoints,
                mealAnnotations: result.mealAnnotations
            )
            messages.append(vitaMsg)

            // Escalation check
            await checkEscalation(appState: appState, explanations: result.explanations)

        } catch {
            messages.append(.vitaError("Sorry, I ran into an error: \(error.localizedDescription)"))
        }
    }

    // MARK: - Report Generation (PDF pipeline — unchanged)

    func generateReport(appState: AppState) async {
        guard !messages.isEmpty else {
            reportState = .error("Ask VITA a question before generating a report.")
            return
        }

        guard let lastUserMsg = messages.last(where: { $0.role == .user }) else {
            reportState = .error("Missing question context.")
            return
        }

        let question = lastUserMsg.content
        let config = FoxitConfig.current
        guard config.isConfigured else {
            reportState = .error("Foxit credentials are missing. Add both API app keys in Settings.")
            return
        }

        reportState = .generatingDocument
        reportPDFData = nil

        do {
            let context = HealthReportService.AskVITAContext(
                question: question,
                explanations: latestExplanations,
                counterfactuals: latestCounterfactuals
            )
            let values = HealthReportService.buildAskVITADocumentValues(
                appState: appState,
                context: context
            )
            let templateBase64 = DocxTemplateBuilder.build().base64EncodedString()
            let rawPDF = try await FoxitDocumentGenerationService.generate(
                templateBase64: templateBase64,
                values: values,
                config: config
            )

            reportState = .optimizingPDF
            let optimizedPDF = try await FoxitPDFServicesService.optimize(pdfData: rawPDF, config: config)
            reportPDFData = optimizedPDF
            reportState = .complete
        } catch {
            reportState = .error(error.localizedDescription)
        }
    }

    func resetReport() {
        reportState = .idle
        reportPDFData = nil
        isShowingReportShareSheet = false
    }

    func clearConversation() {
        messages = []
        queryText = ""
        resetReport()
    }

    // MARK: - Causal Nodes (for CausalExplanationCard)

    func causalNodes(for explanation: CausalExplanation) -> [CausalChainNode] {
        let icons = ["fork.knife", "chart.line.uptrend.xyaxis", "chart.line.downtrend.xyaxis", "waveform.path.ecg", "person.fill"]
        let colors = [VITAColors.teal, VITAColors.glucoseHigh, VITAColors.coral, VITAColors.amber, VITAColors.causalHighlight]
        let timeOffsets = [nil, "+35min", "+65min", "+90min", "+2h"]

        return explanation.causalChain.enumerated().map { index, step in
            CausalChainNode(
                icon: icons[index % icons.count],
                label: step,
                detail: "",
                timeOffset: index > 0 ? timeOffsets[min(index, timeOffsets.count - 1)] : nil,
                color: colors[index % colors.count]
            )
        }
    }

    // MARK: - Escalation Check (Tier 4)

    private func checkEscalation(appState: AppState, explanations: [CausalExplanation]) async {
        guard let top = explanations.first else { return }
        let classifier = HighPainClassifier()
        let score = classifier.score(explanation: top, healthGraph: appState.healthGraph)
        if score >= 0.75 {
            let client = EscalationClient()
            await client.escalate(symptom: top.symptom, reason: top.narrative, confidence: score)
        }
    }
}
