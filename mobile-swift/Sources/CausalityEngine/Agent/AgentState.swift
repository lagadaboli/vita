import Foundation

/// Tracks the state of a single ReAct reasoning session.
public struct AgentState: Sendable {
    public let symptom: String
    public var hypotheses: [Hypothesis]
    public var observations: [ToolObservation]
    public var isResolved: Bool
    public let analysisWindow: ClosedRange<Date>

    public init(symptom: String, windowHours: Double = 6) {
        self.symptom = symptom
        self.hypotheses = []
        self.observations = []
        self.isResolved = false
        let now = Date()
        self.analysisWindow = now.addingTimeInterval(-windowHours * 3600)...now
    }
}
