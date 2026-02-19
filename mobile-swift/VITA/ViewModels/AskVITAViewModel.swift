import Foundation
import VITACore
import CausalityEngine
import VITADesignSystem

@MainActor
@Observable
final class AskVITAViewModel {
    var queryText = ""
    var isQuerying = false
    var explanations: [CausalExplanation] = []
    var counterfactuals: [Counterfactual] = []
    var hasQueried = false
    var glucoseDataPoints: [GlucoseDataPoint] = []
    var mealAnnotations: [MealAnnotationPoint] = []

    let suggestions = [
        "Why am I tired?",
        "Why can't I focus?",
        "Why is my stomach upset?",
        "Why am I sleeping poorly?"
    ]

    func query(appState: AppState) async {
        let text = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isQuerying = true
        defer { isQuerying = false }

        do {
            explanations = try await appState.causalityEngine.querySymptom(text)
            hasQueried = true

            // Generate context-aware counterfactuals from the explanations
            counterfactuals = try await appState.causalityEngine.generateCounterfactual(
                forSymptom: text,
                explanations: explanations
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
            glucoseDataPoints = readings.map {
                GlucoseDataPoint(timestamp: $0.timestamp, value: $0.glucoseMgDL)
            }

            let meals = try appState.healthGraph.queryMeals(from: sixHoursAgo, to: now)
            mealAnnotations = meals.map { meal in
                let label = meal.ingredients.first?.name ?? meal.source.rawValue
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                return MealAnnotationPoint(timestamp: meal.timestamp, label: label, glycemicLoad: gl)
            }
        } catch {
            #if DEBUG
            print("[AskVITAViewModel] Chart data load failed: \(error)")
            #endif
        }
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
}
