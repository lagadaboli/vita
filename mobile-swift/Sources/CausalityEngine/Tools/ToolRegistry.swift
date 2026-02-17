import Foundation
import VITACore

/// Registry of all available analysis tools.
/// Selects the most informative uninvestigated tool for the current agent state.
public struct ToolRegistry: Sendable {
    private let tools: [any AnalysisTool]

    public init() {
        tools = [
            MetabolicScanner(),
            InflammationTracker(),
            DigitalFrictionAnalyzer(),
            SleepQualityAnalyzer(),
            EnvironmentalStressAnalyzer(),
        ]
    }

    /// Select the most informative tool that hasn't been run yet.
    /// Prioritizes tools targeting the highest-confidence hypothesis.
    public func selectTool(for state: AgentState) -> (any AnalysisTool)? {
        let investigatedTools = Set(state.observations.map(\.toolName))
        let uninvestigated = tools.filter { !investigatedTools.contains($0.name) }

        guard !uninvestigated.isEmpty else { return nil }

        // Target the highest-prior hypothesis that hasn't been fully investigated
        if let topHypothesis = state.hypotheses.first {
            if let targeted = uninvestigated.first(where: { $0.targetDebtTypes.contains(topHypothesis.debtType) }) {
                return targeted
            }
        }

        return uninvestigated.first
    }

    /// Returns all available tools.
    public var allTools: [any AnalysisTool] { tools }
}
