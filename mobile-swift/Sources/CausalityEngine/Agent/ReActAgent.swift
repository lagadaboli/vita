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
    public func reason(about symptom: String) async throws -> [CausalExplanation] {
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

        // Build explanations from ranked hypotheses (async for LLM narrative)
        return await buildExplanations(from: state)
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
        let highGLMeals = meals.filter { ($0.estimatedGlycemicLoad ?? $0.computedGlycemicLoad) > 25 }
        let hasHighGLMeal = !highGLMeals.isEmpty
        let maxGL = highGLMeals.compactMap { $0.estimatedGlycemicLoad ?? $0.computedGlycemicLoad }.max() ?? 0

        if hasCrash || hasHighGLMeal {
            var chain = [String]()
            if let meal = meals.last {
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                let mealName = meal.ingredients.first?.name ?? meal.source.rawValue
                chain.append("\(mealName) (GL \(Int(gl)))")
            }
            if hasCrash { chain.append("Glucose crash detected") }
            if !hrv.isEmpty {
                let avgHRV = hrv.map(\.value).reduce(0, +) / Double(hrv.count)
                chain.append("HRV: \(Int(avgHRV))ms")
            }

            // Confidence reflects signal strength: crash is definitive (0.76),
            // very high GL (>35) is strong (0.68), moderate high GL (>25) is moderate (0.58).
            let metabolicConfidence: Double
            if hasCrash { metabolicConfidence = 0.76 }
            else if maxGL > 35 { metabolicConfidence = 0.68 }
            else { metabolicConfidence = 0.58 }

            hypotheses.append(Hypothesis(
                debtType: .metabolic,
                description: "Post-meal glucose crash or high glycemic load",
                confidence: metabolicConfidence,
                causalChain: chain,
                supportingEvidence: hasCrash ? ["Glucose crash detected in window"] : ["High-GL meal (GL \(Int(maxGL))) detected"],
                priorProbability: 0.45
            ))
        } else if !meals.isEmpty {
            hypotheses.append(Hypothesis(
                debtType: .metabolic,
                description: "Meal-related metabolic impact",
                confidence: 0.40,
                causalChain: ["Meals detected, no crash"],
                priorProbability: 0.30
            ))
        }

        // Digital hypothesis: passive screen time detected
        let passiveEvents = behaviors.filter {
            $0.category == .passiveConsumption || $0.category == .zombieScrolling
        }
        if !passiveEvents.isEmpty {
            let totalMinutes = passiveEvents.reduce(0.0) { $0 + $1.duration / 60.0 }
            let maxDebt = passiveEvents.compactMap(\.dopamineDebtScore).max() ?? 0

            // Scale confidence with screen time: 30min→0.52, 60min→0.62, 120min→0.75 (cap 0.80)
            let digitalConfidence = min(0.45 + totalMinutes / 200.0, 0.80)

            hypotheses.append(Hypothesis(
                debtType: .digital,
                description: "Passive screen time and dopamine debt",
                confidence: digitalConfidence,
                causalChain: ["\(Int(totalMinutes))min passive screen time", "Dopamine debt: \(Int(maxDebt))"],
                supportingEvidence: ["\(passiveEvents.count) passive events, \(Int(totalMinutes)) total minutes"],
                priorProbability: 0.35
            ))
        }

        // Somatic hypothesis: environmental stress, sleep deficit, or calendar overload
        let totalSleep = sleep.map(\.value).reduce(0, +)
        let hasSleepDeficit = sleep.isEmpty || totalSleep < 7.0
        let hasEnvStress = environment.contains { $0.aqiUS > 100 || $0.pollenIndex >= 8 || $0.temperatureCelsius > 33 }
        if hasSleepDeficit || hasEnvStress {
            var chain = [String]()
            if hasSleepDeficit {
                chain.append("Sleep: \(String(format: "%.1f", totalSleep))h")
            }
            if hasEnvStress {
                if let env = environment.last {
                    chain.append("AQI: \(env.aqiUS), Pollen: \(env.pollenIndex)")
                }
            }

            // Both factors → stronger signal (0.70), single factor is still meaningful (0.55)
            let somaticConfidence: Double = (hasSleepDeficit && hasEnvStress) ? 0.70 : 0.55

            hypotheses.append(Hypothesis(
                debtType: .somatic,
                description: "Environmental or sleep-related stress",
                confidence: somaticConfidence,
                causalChain: chain,
                supportingEvidence: hasSleepDeficit ? ["Sleep deficit: \(String(format: "%.1f", totalSleep))h"] : ["Environmental stress detected"],
                priorProbability: 0.35
            ))
        }

        // Skin hypothesis: when the question is about a skin condition, boost the
        // most relevant debt type with a skin-specific chain and high confidence
        // so the causal cards are meaningful and Gemini gets clear direction.
        let skinKeywords = ["skin", "acne", "pimple", "dark circle", "eye bag", "oily", "oiliness",
                            "pore", "wrinkle", "redness", "complexion", "face", "breakout", "pigment",
                            "spot", "texture", "dry skin", "hydration"]
        let symptomLower = symptom.lowercased()
        if skinKeywords.contains(where: { symptomLower.contains($0) }) {
            // Build a skin-specific chain using the data we already have
            var skinChain = [String]()
            if hasHighGLMeal { skinChain.append("High-GL meal (GL \(Int(maxGL))) → IGF-1 spike → sebum overproduction") }
            let totalSleepForSkin = sleep.map(\.value).reduce(0, +)
            if totalSleepForSkin < 7.0 { skinChain.append("Sleep \(String(format: "%.1f", totalSleepForSkin))h → cortisol elevation → skin inflammation") }
            if let env = environment.last, env.aqiUS > 80 { skinChain.append("AQI \(env.aqiUS) → oxidative stress → barrier disruption") }
            if skinChain.isEmpty { skinChain.append("Lifestyle factors → skin condition") }

            // Skin acne/oiliness is metabolic (IGF-1 driven); dark circles are somatic (sleep driven)
            let skinDebt: DebtType
            let darkCircleKeywords = ["dark circle", "eye bag", "dark eye", "puffy eye"]
            if darkCircleKeywords.contains(where: { symptomLower.contains($0) }) {
                skinDebt = .somatic
            } else {
                skinDebt = hasHighGLMeal ? .metabolic : .somatic
            }

            // Only add if not already covered with a higher-confidence hypothesis
            let existingForDebt = hypotheses.first(where: { $0.debtType == skinDebt })
            let skinConfidence: Double = hasHighGLMeal && hasSleepDeficit ? 0.78 : hasHighGLMeal ? 0.72 : 0.62
            if (existingForDebt?.confidence ?? 0) < skinConfidence {
                // Replace or append
                hypotheses.removeAll { $0.debtType == skinDebt }
                hypotheses.append(Hypothesis(
                    debtType: skinDebt,
                    description: "Skin condition driven by \(skinDebt == .metabolic ? "dietary/metabolic" : "sleep/stress") factors",
                    confidence: skinConfidence,
                    causalChain: skinChain,
                    supportingEvidence: ["Skin-related question detected"],
                    priorProbability: 0.45
                ))
            }
        }

        // Ensure we always have at least one hypothesis per debt type
        let coveredTypes = Set(hypotheses.map(\.debtType))
        for type in DebtType.allCases where !coveredTypes.contains(type) {
            hypotheses.append(Hypothesis(
                debtType: type,
                description: "No strong indicators for \(type.rawValue) debt",
                confidence: 0.15,
                priorProbability: 0.15
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

    private func buildExplanations(from state: AgentState) async -> [CausalExplanation] {
        let rankedDebts = debtClassifier.classify(
            hypotheses: state.hypotheses,
            observations: state.observations
        )

        let topHypotheses = state.hypotheses
            .filter { $0.confidence > 0.15 }
            .prefix(3)

        var explanations: [CausalExplanation] = []
        for hypothesis in topHypotheses {
            let score = rankedDebts.first(where: { $0.type == hypothesis.debtType })?.score ?? hypothesis.confidence
            let narrative = await narrativeGenerator.generate(
                symptom: state.symptom,
                hypothesis: hypothesis,
                observations: state.observations
            )

            explanations.append(CausalExplanation(
                symptom: state.symptom,
                causalChain: hypothesis.causalChain,
                strength: score,
                confidence: hypothesis.confidence,
                narrative: narrative
            ))
        }

        return explanations
    }
}
