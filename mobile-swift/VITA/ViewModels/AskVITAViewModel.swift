import Foundation
import VITACore
import CausalityEngine
import VITADesignSystem

@MainActor
@Observable
final class AskVITAViewModel {
    private let maxExplanations = 5
    private let maxCounterfactuals = 8
    private let maxChartPoints = 180

    enum ReportGenerationState: Equatable {
        case idle
        case generatingDocument
        case optimizingPDF
        case complete
        case error(String)
    }

    var queryText = ""
    var isQuerying = false
    var explanations: [CausalExplanation] = []
    var counterfactuals: [Counterfactual] = []
    var hasQueried = false
    var lastSubmittedQuery = ""
    var glucoseDataPoints: [GlucoseDataPoint] = []
    var mealAnnotations: [MealAnnotationPoint] = []
    var reportState: ReportGenerationState = .idle
    var reportPDFData: Data?
    var isShowingReportShareSheet = false

    // Loading phase for animated thinking state
    var loadingPhase: Int = 0
    private var loadingTask: Task<Void, Never>?

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

    var canGenerateReport: Bool {
        hasQueried && !explanations.isEmpty && !isQuerying
    }

    var formattedReportFileSize: String {
        guard let data = reportPDFData else { return "" }
        let bytes = data.count
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_024 * 1_024 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / (1_024 * 1_024))
    }

    // Smart suggestions spanning all three debt types
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

    // Data sources actively used by the last explanation (for UI badges)
    var activatedSources: Set<String> = []

    func query(appState: AppState) async {
        let text = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Clear the input immediately — fix: text was not clearing after submit
        queryText = ""

        resetReport()
        explanations = []
        counterfactuals = []
        glucoseDataPoints = []
        mealAnnotations = []
        activatedSources = []
        lastSubmittedQuery = text
        hasQueried = true   // switch to chat view immediately
        isQuerying = true
        loadingPhase = 0

        // Rotate loading phase messages while the agent reasons
        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000) // 1.4s
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
            let rawExplanations = try await appState.causalityEngine.querySymptom(text)
            explanations = Array(rawExplanations.prefix(maxExplanations))

            // Infer which data sources were active from the causal chains
            activatedSources = inferActiveSources(from: explanations)

            // Generate context-aware counterfactuals from the explanations
            let generatedCounterfactuals = try await appState.causalityEngine.generateCounterfactual(
                forSymptom: text,
                explanations: explanations
            )
            counterfactuals = Array(
                generatedCounterfactuals
                    .sorted(by: { $0.impact > $1.impact })
                    .prefix(maxCounterfactuals)
            )

            // Fetch glucose + meal data for annotated chart
            loadChartData(appState: appState)

            // Tier 4: SMS escalation check
            await checkEscalation(appState: appState)
        } catch {
            explanations = []
            counterfactuals = []
        }
    }

    func generateReport(appState: AppState) async {
        guard hasQueried else {
            reportState = .error("Ask VITA a question before generating a report.")
            return
        }

        let question = lastSubmittedQuery.isEmpty ? queryText.trimmingCharacters(in: .whitespacesAndNewlines) : lastSubmittedQuery
        guard !question.isEmpty else {
            reportState = .error("Missing question context. Ask VITA again and retry.")
            return
        }

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
                explanations: explanations,
                counterfactuals: counterfactuals
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

    // MARK: - Chart Data

    private func loadChartData(appState: AppState) {
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)

        do {
            let readings = try appState.healthGraph.queryGlucose(from: sixHoursAgo, to: now)
            let mappedReadings = readings.map {
                GlucoseDataPoint(timestamp: $0.timestamp, value: $0.glucoseMgDL)
            }
            glucoseDataPoints = downsample(mappedReadings, to: maxChartPoints)

            let meals = try appState.healthGraph.queryMeals(from: sixHoursAgo, to: now)
            let mappedMeals = meals.map { meal in
                let label = meal.ingredients.first?.name ?? meal.source.rawValue
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                return MealAnnotationPoint(timestamp: meal.timestamp, label: label, glycemicLoad: gl)
            }
            mealAnnotations = downsample(mappedMeals, to: maxCounterfactuals)
        } catch {
            #if DEBUG
            print("[AskVITAViewModel] Chart data load failed: \(error)")
            #endif
        }
    }

    // MARK: - Source Inference

    /// Infer which health data streams contributed by scanning the causal chains.
    private func inferActiveSources(from explanations: [CausalExplanation]) -> Set<String> {
        var sources: Set<String> = []
        let allChainText = explanations.flatMap(\.causalChain).joined(separator: " ").lowercased()

        if allChainText.contains("glucose") || allChainText.contains("spike") || allChainText.contains("crash") {
            sources.insert("Glucose")
        }
        if allChainText.contains("meal") || allChainText.contains("glycemic") || allChainText.contains("rotimatic") || allChainText.contains("instant pot") {
            sources.insert("Meals")
        }
        if allChainText.contains("hrv") || allChainText.contains("heart") {
            sources.insert("HRV")
        }
        if allChainText.contains("sleep") {
            sources.insert("Sleep")
        }
        if allChainText.contains("screen") || allChainText.contains("dopamine") || allChainText.contains("passive") {
            sources.insert("Behavior")
        }
        if allChainText.contains("aqi") || allChainText.contains("pollen") || allChainText.contains("temp") {
            sources.insert("Environment")
        }

        // Always show at least the primary source
        if sources.isEmpty { sources.insert("Health Graph") }
        return sources
    }

    // MARK: - SMS Escalation (Tier 4)

    private func checkEscalation(appState: AppState) async {
        guard let top = explanations.first else { return }

        let classifier = HighPainClassifier()
        let score = classifier.score(
            explanation: top,
            healthGraph: appState.healthGraph
        )

        if score >= 0.75 {
            let client = EscalationClient()
            await client.escalate(
                symptom: top.symptom,
                reason: top.narrative,
                confidence: score
            )
        }
    }

    private func downsample<T>(_ items: [T], to target: Int) -> [T] {
        guard target > 0, items.count > target else { return items }
        let strideValue = max(1, items.count / target)
        return Array(items.enumerated().compactMap { index, element in
            index % strideValue == 0 ? element : nil
        }.prefix(target))
    }
}
