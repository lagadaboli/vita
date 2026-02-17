import Foundation
import VITACore

/// The core ReAct (Reasoning + Acting) agent.
/// Implements a bounded Thought→Act→Observe loop to diagnose symptoms.
///
/// - Thought: Generate hypotheses from HealthGraph data
/// - Act: Select and run the most informative analysis tool
/// - Observe: Update hypothesis weights, check for resolution
///
/// Bounded to 3 iterations to stay within on-device latency budget.
public struct ReActAgent: Sendable {
    private let healthGraph: HealthGraph
    private let toolRegistry: ToolRegistry
    private let debtClassifier: DebtClassifier
    private let ruleEngine: BioRuleEngine
    private let narrativeGenerator: NarrativeGenerator
    private let maturityTracker: EngineMaturityTracker

    private static let maxIterations = 3
    private static let resolutionThreshold = 0.7

    public init(
        healthGraph: HealthGraph,
        toolRegistry: ToolRegistry,
        debtClassifier: DebtClassifier,
        ruleEngine: BioRuleEngine,
        narrativeGenerator: NarrativeGenerator,
        maturityTracker: EngineMaturityTracker
    ) {
        self.healthGraph = healthGraph
        self.toolRegistry = toolRegistry
        self.debtClassifier = debtClassifier
        self.ruleEngine = ruleEngine
        self.narrativeGenerator = narrativeGenerator
        self.maturityTracker = maturityTracker
    }

    /// Main entry point: reason about a symptom and return causal explanations.
    public func reason(about symptom: String) throws -> [CausalExplanation] {
        let config = try maturityTracker.phaseConfig()

        // During passive/correlation phase, use rules only
        if !config.useReAct {
            return try ruleEngine.evaluate(symptom: symptom, healthGraph: healthGraph)
        }

        var state = AgentState(symptom: symptom)

        // THOUGHT: Generate initial hypotheses
        state.hypotheses = try generateHypotheses(for: symptom, window: state.analysisWindow)

        // ReAct loop (bounded)
        let iterations = min(Self.maxIterations, config.maxTools)
        for _ in 0..<iterations {
            guard !state.isResolved else { break }

            // ACT: Select and run the most informative tool
            guard let tool = toolRegistry.selectTool(for: state) else { break }
            let observation = try tool.analyze(
                hypotheses: state.hypotheses,
                healthGraph: healthGraph,
                window: state.analysisWindow
            )

            // OBSERVE: Update hypothesis weights
            state.observations.append(observation)
            state.hypotheses = updateHypotheses(state.hypotheses, with: observation)

            // Check for resolution
            if let dominant = state.hypotheses.first, dominant.confidence >= Self.resolutionThreshold {
                state.isResolved = true
            }
        }

        // If still unresolved, merge with rule engine results
        if !state.isResolved {
            let ruleResults = try ruleEngine.evaluate(
                symptom: symptom,
                healthGraph: healthGraph,
                window: state.analysisWindow
            )
            if !ruleResults.isEmpty && (state.hypotheses.isEmpty || state.hypotheses[0].confidence < 0.4) {
                return ruleResults
            }
        }

        // Build explanations from ranked hypotheses
        return buildExplanations(from: state)
    }

    // MARK: - Thought Stage: Hypothesis Generation

    private func generateHypotheses(
        for symptom: String,
        window: ClosedRange<Date>
    ) throws -> [Hypothesis] {
        let glucose = try healthGraph.queryGlucose(from: window.lowerBound, to: window.upperBound)
        let meals = try healthGraph.queryMeals(from: window.lowerBound, to: window.upperBound)
        let behaviors = try healthGraph.queryBehaviors(from: window.lowerBound, to: window.upperBound)
        let environment = try healthGraph.queryEnvironment(from: window.lowerBound, to: window.upperBound)
        let hrv = try healthGraph.querySamples(type: .hrvSDNN, from: window.lowerBound, to: window.upperBound)
        let sleep = try healthGraph.querySamples(type: .sleepAnalysis, from: window.lowerBound, to: window.upperBound)

        var hypotheses: [Hypothesis] = []

        // Metabolic hypothesis: glucose crash or high GL meals detected
        let hasCrash = glucose.contains { $0.energyState == .crashing || $0.energyState == .reactiveLow }
        let hasHighGLMeal = meals.contains {
            ($0.estimatedGlycemicLoad ?? $0.computedGlycemicLoad) > 25
        }
        if hasCrash || hasHighGLMeal {
            var chain = [String]()
            if let meal = meals.last { chain.append("Meal (\(meal.source.rawValue))") }
            if hasCrash { chain.append("Glucose crash detected") }
            if !hrv.isEmpty {
                let avgHRV = hrv.map(\.value).reduce(0, +) / Double(hrv.count)
                chain.append("HRV: \(Int(avgHRV))ms")
            }

            hypotheses.append(Hypothesis(
                debtType: .metabolic,
                description: "Post-meal glucose crash or high glycemic load",
                confidence: hasCrash ? 0.55 : 0.4,
                causalChain: chain,
                supportingEvidence: hasCrash ? ["Glucose crash detected in window"] : ["High-GL meal detected"],
                priorProbability: 0.4
            ))
        } else if !meals.isEmpty {
            hypotheses.append(Hypothesis(
                debtType: .metabolic,
                description: "Meal-related metabolic impact",
                confidence: 0.25,
                causalChain: ["Meals detected, no crash"],
                priorProbability: 0.25
            ))
        }

        // Digital hypothesis: passive screen time detected
        let passiveEvents = behaviors.filter {
            $0.category == .passiveConsumption || $0.category == .zombieScrolling
        }
        if !passiveEvents.isEmpty {
            let totalMinutes = passiveEvents.reduce(0.0) { $0 + $1.duration / 60.0 }
            let maxDebt = passiveEvents.compactMap(\.dopamineDebtScore).max() ?? 0

            hypotheses.append(Hypothesis(
                debtType: .digital,
                description: "Passive screen time and dopamine debt",
                confidence: min(totalMinutes / 60.0, 0.5),
                causalChain: ["\(Int(totalMinutes))min passive screen time", "Dopamine debt: \(Int(maxDebt))"],
                supportingEvidence: ["\(passiveEvents.count) passive events"],
                priorProbability: 0.3
            ))
        }

        // Somatic hypothesis: environmental stress, sleep deficit, or calendar overload
        let hasSleepDeficit = sleep.isEmpty || sleep.map(\.value).reduce(0, +) < 6.5
        let hasEnvStress = environment.contains { $0.aqiUS > 100 || $0.pollenIndex >= 8 || $0.temperatureCelsius > 33 }
        if hasSleepDeficit || hasEnvStress {
            var chain = [String]()
            if hasSleepDeficit {
                let hours = sleep.map(\.value).reduce(0, +)
                chain.append("Sleep: \(String(format: "%.1f", hours))h")
            }
            if hasEnvStress {
                if let env = environment.last {
                    chain.append("AQI: \(env.aqiUS), Pollen: \(env.pollenIndex)")
                }
            }

            hypotheses.append(Hypothesis(
                debtType: .somatic,
                description: "Environmental or sleep-related stress",
                confidence: (hasSleepDeficit && hasEnvStress) ? 0.5 : 0.35,
                causalChain: chain,
                supportingEvidence: hasSleepDeficit ? ["Sleep deficit detected"] : ["Environmental stress detected"],
                priorProbability: 0.3
            ))
        }

        // Ensure we always have at least one hypothesis per debt type
        let coveredTypes = Set(hypotheses.map(\.debtType))
        for type in DebtType.allCases where !coveredTypes.contains(type) {
            hypotheses.append(Hypothesis(
                debtType: type,
                description: "No strong indicators for \(type.rawValue) debt",
                confidence: 0.1,
                priorProbability: 0.1
            ))
        }

        return hypotheses.sorted(by: >)
    }

    // MARK: - Observe Stage: Hypothesis Update

    private func updateHypotheses(_ hypotheses: [Hypothesis], with observation: ToolObservation) -> [Hypothesis] {
        hypotheses.map { hypothesis in
            var updated = hypothesis
            if let evidence = observation.evidence[hypothesis.debtType] {
                // Additive Bayesian update (not multiplicative for robustness)
                updated.confidence = min(max(hypothesis.confidence + evidence * observation.confidence, 0.0), 1.0)

                if evidence > 0 {
                    updated.supportingEvidence.append("\(observation.toolName): +\(String(format: "%.0f", evidence * 100))%")
                } else if evidence < 0 {
                    updated.contradictingEvidence.append("\(observation.toolName): \(String(format: "%.0f", evidence * 100))%")
                }
            }
            return updated
        }.sorted(by: >)
    }

    // MARK: - Build Final Explanations

    private func buildExplanations(from state: AgentState) -> [CausalExplanation] {
        let rankedDebts = debtClassifier.classify(
            hypotheses: state.hypotheses,
            observations: state.observations
        )

        return state.hypotheses
            .filter { $0.confidence > 0.15 }
            .prefix(3)
            .map { hypothesis in
                let score = rankedDebts.first(where: { $0.type == hypothesis.debtType })?.score ?? hypothesis.confidence
                let narrative = narrativeGenerator.generate(
                    symptom: state.symptom,
                    hypothesis: hypothesis,
                    observations: state.observations
                )

                return CausalExplanation(
                    symptom: state.symptom,
                    causalChain: hypothesis.causalChain,
                    strength: score,
                    confidence: hypothesis.confidence,
                    narrative: narrative
                )
            }
    }
}
