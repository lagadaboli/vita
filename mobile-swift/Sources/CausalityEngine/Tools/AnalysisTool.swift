import Foundation
import VITACore

/// Protocol for on-device analysis tools invoked during the Act stage of ReAct.
public protocol AnalysisTool: Sendable {
    var name: String { get }
    var targetDebtTypes: Set<DebtType> { get }

    /// Run the tool against the HealthGraph and return an observation.
    func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation
}
