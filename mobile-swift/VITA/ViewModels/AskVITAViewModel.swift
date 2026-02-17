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
}
