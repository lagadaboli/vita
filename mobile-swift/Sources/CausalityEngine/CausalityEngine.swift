import Foundation
import VITACore

/// The Brain: Causality Engine.
/// A neuro-symbolic agent using the ReAct framework to identify root causes
/// of symptoms by distinguishing Metabolic Debt, Digital Debt, and Somatic Stress.
///
/// Three-tier graceful degradation:
/// - Tier A: Deterministic Bio-Rule Engine (always available)
/// - Tier B: ReAct Agent with analysis tools (Week 5+)
/// - Tier C: Local LLM narrative generation (Week 9+)
public protocol CausalityEngineProtocol: Sendable {
    /// Query the causal graph to explain a symptom.
    /// e.g., "Why am I tired?" → returns causal chain with confidence.
    func querySymptom(_ symptom: String) async throws -> [CausalExplanation]

    /// Generate counterfactual scenarios for a given event.
    /// e.g., "What if I had pressure-cooked instead of slow-cooking?"
    func generateCounterfactual(for eventNodeID: String) async throws -> [Counterfactual]

    /// Compute the current digestive debt score.
    func digestiveDebtScore(windowHours: Int) async throws -> Double

    /// Ingest new data and update causal edge weights.
    func updateGraph() async throws
}

/// A causal explanation connecting a symptom to its root causes.
public struct CausalExplanation: Sendable {
    public let symptom: String
    public let causalChain: [String]
    public let strength: Double
    public let confidence: Double
    public let narrative: String

    public init(
        symptom: String,
        causalChain: [String],
        strength: Double,
        confidence: Double,
        narrative: String
    ) {
        self.symptom = symptom
        self.causalChain = causalChain
        self.strength = strength
        self.confidence = confidence
        self.narrative = narrative
    }
}

/// A counterfactual scenario — "what if you had done X instead?"
public struct Counterfactual: Sendable {
    public let description: String
    public let impact: Double
    public let effort: Effort
    public let confidence: Double

    public init(description: String, impact: Double, effort: Effort, confidence: Double) {
        self.description = description
        self.impact = impact
        self.effort = effort
        self.confidence = confidence
    }

    public enum Effort: String, Sendable {
        case trivial
        case moderate
        case significant
    }
}

/// The real Causality Engine implementation.
/// Orchestrates the ReAct agent, bio-rule engine, maturity tracker,
/// edge weight learner, and intervention calculator.
public final class CausalityEngine: CausalityEngineProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let agent: ReActAgent
    private let interventionCalculator: InterventionCalculator
    private let metabolicDebtScorer: MetabolicDebtScorer
    private let edgeWeightLearner: EdgeWeightLearner

    public init(database: VITADatabase, healthGraph: HealthGraph, llm: (any LocalLLMService)? = nil) {
        self.database = database
        self.healthGraph = healthGraph
        self.interventionCalculator = InterventionCalculator(healthGraph: healthGraph)
        self.metabolicDebtScorer = MetabolicDebtScorer()
        self.edgeWeightLearner = EdgeWeightLearner()

        let maturityTracker = EngineMaturityTracker(healthGraph: healthGraph)
        let ruleEngine = BioRuleEngine()
        let narrativeGen = NarrativeGenerator(llm: llm)
        let toolRegistry = ToolRegistry()
        let debtClassifier = DebtClassifier()

        self.agent = ReActAgent(
            healthGraph: healthGraph,
            toolRegistry: toolRegistry,
            debtClassifier: debtClassifier,
            ruleEngine: ruleEngine,
            narrativeGenerator: narrativeGen,
            maturityTracker: maturityTracker
        )
    }

    public func querySymptom(_ symptom: String) async throws -> [CausalExplanation] {
        try await agent.reason(about: symptom)
    }

    public func generateCounterfactual(for eventNodeID: String) async throws -> [Counterfactual] {
        try interventionCalculator.generateCounterfactuals(for: eventNodeID)
    }

    /// Generate counterfactuals informed by symptom explanations.
    public func generateCounterfactual(
        forSymptom symptom: String,
        explanations: [CausalExplanation]
    ) async throws -> [Counterfactual] {
        try interventionCalculator.generateCounterfactualsForSymptom(symptom, explanations: explanations)
    }

    public func digestiveDebtScore(windowHours: Int = 6) async throws -> Double {
        try metabolicDebtScorer.score(healthGraph: healthGraph, windowHours: windowHours)
    }

    public func updateGraph() async throws {
        let now = Date()
        let window = now.addingTimeInterval(-24 * 3600)...now
        try edgeWeightLearner.batchUpdate(healthGraph: healthGraph, window: window)
    }
}
