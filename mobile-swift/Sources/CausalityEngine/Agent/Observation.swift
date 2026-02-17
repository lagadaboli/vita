import Foundation

/// The result of running an analysis tool against the HealthGraph.
/// Contains per-debt-type evidence scores that update hypothesis confidences.
///
/// Named `ToolObservation` to avoid collision with the Swift Observation framework.
public struct ToolObservation: Sendable {
    public let toolName: String
    /// Evidence scores per debt type. Positive = supports, negative = contradicts.
    public let evidence: [DebtType: Double]
    /// How confident the tool is in its own output (0-1).
    public let confidence: Double
    /// Human-readable detail string for debugging and narrative generation.
    public let detail: String

    public init(
        toolName: String,
        evidence: [DebtType: Double],
        confidence: Double,
        detail: String
    ) {
        self.toolName = toolName
        self.evidence = evidence
        self.confidence = confidence
        self.detail = detail
    }
}
