import Foundation
import VITACore

/// Mock implementation of CausalityEngineProtocol that returns pre-computed
/// causal explanations from sample data. Used for demo and testing.
public final class MockCausalityEngine: CausalityEngineProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
    }

    public func querySymptom(_ symptom: String) async throws -> [CausalExplanation] {
        let lowered = symptom.lowercased()

        if lowered.contains("tired") || lowered.contains("fatigue") || lowered.contains("energy") {
            return tiredExplanations()
        } else if lowered.contains("stomach") || lowered.contains("bloat") || lowered.contains("digest") {
            return stomachExplanations()
        } else if lowered.contains("sleep") || lowered.contains("insomnia") || lowered.contains("wake") {
            return sleepExplanations()
        } else if lowered.contains("focus") || lowered.contains("brain fog") || lowered.contains("concentrate") {
            return focusExplanations()
        } else if lowered.contains("weight") || lowered.contains("gain") || lowered.contains("heavy") {
            return weightExplanations()
        } else if lowered.contains("air") || lowered.contains("pollution") || lowered.contains("weather") || lowered.contains("pollen") {
            return environmentExplanations()
        } else {
            return generalExplanations(symptom: symptom)
        }
    }

    public func generateCounterfactual(for eventNodeID: String) async throws -> [Counterfactual] {
        // Return relevant counterfactuals based on event type
        if eventNodeID.contains("meal") || eventNodeID.contains("glucose") {
            return mealCounterfactuals()
        } else if eventNodeID.contains("behavior") || eventNodeID.contains("screen") {
            return behaviorCounterfactuals()
        } else if eventNodeID.contains("weight") || eventNodeID.contains("scale") {
            return counterfactualsForWeight()
        } else if eventNodeID.contains("environment") || eventNodeID.contains("aqi") {
            return counterfactualsForEnvironment()
        } else {
            return generalCounterfactuals()
        }
    }

    public func digestiveDebtScore(windowHours: Int = 6) async throws -> Double {
        42.0
    }

    public func updateGraph() async throws {
        // No-op for mock
    }

    // MARK: - Pre-computed Explanations

    private func tiredExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Fatigue",
                causalChain: [
                    "White Flour Rotis (Maida)",
                    "Glucose spike to 178 mg/dL",
                    "Rapid crash to 72 mg/dL",
                    "HRV dropped 22%",
                    "Afternoon fatigue"
                ],
                strength: 0.85,
                confidence: 0.82,
                narrative: "Your white flour rotis this morning caused a sharp glucose spike to 178 mg/dL followed by a crash to 72 mg/dL. This reactive hypoglycemia triggered a 22% drop in your HRV, which is strongly associated with the fatigue you're feeling. Switching to whole wheat flour would reduce the spike by ~35%."
            ),
            CausalExplanation(
                symptom: "Fatigue",
                causalChain: [
                    "Poor sleep (6.5h, 12% deep)",
                    "Elevated resting HR (67 bpm)",
                    "Reduced recovery capacity",
                    "Afternoon energy dip"
                ],
                strength: 0.68,
                confidence: 0.72,
                narrative: "Last night's sleep was shorter than your baseline (6.5h vs 7.5h average) with significantly reduced deep sleep (12% vs your 20% average). This incomplete recovery is compounding the glucose-driven fatigue."
            ),
            CausalExplanation(
                symptom: "Fatigue",
                causalChain: [
                    "AQI 150 (Unhealthy)",
                    "Oxidative stress",
                    "15% HRV suppression",
                    "Reduced recovery"
                ],
                strength: 0.55,
                confidence: 0.58,
                narrative: "Today's poor air quality (AQI 150) is contributing to your fatigue through oxidative stress, which suppresses HRV by approximately 15% and reduces your body's recovery capacity."
            )
        ]
    }

    private func stomachExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Digestive Discomfort",
                causalChain: [
                    "Slow-cooked kidney beans",
                    "Lectin retention (incomplete deactivation)",
                    "GI inflammation response",
                    "Bloating and discomfort"
                ],
                strength: 0.78,
                confidence: 0.71,
                narrative: "Your Instant Pot rajma was slow-cooked instead of pressure-cooked. Slow cooking doesn't fully deactivate lectins in kidney beans (phytohaemagglutinin), which can cause GI distress. Pressure cooking at 15 PSI for 30 minutes reduces lectin content by ~95%, compared to only ~60% with slow cooking."
            )
        ]
    }

    private func sleepExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Poor Sleep",
                causalChain: [
                    "Late 9PM burrito bowl (GL: 45)",
                    "Elevated glucose during sleep onset",
                    "Increased sympathetic activity",
                    "Reduced deep sleep by 25 min"
                ],
                strength: 0.75,
                confidence: 0.68,
                narrative: "Your 9PM burrito bowl had a glycemic load of 45, causing elevated blood glucose during your sleep onset window. This triggered sympathetic nervous system activation, reducing your deep sleep by approximately 25 minutes compared to nights when you eat dinner before 7PM."
            ),
            CausalExplanation(
                symptom: "Poor Sleep",
                causalChain: [
                    "Netflix until 11PM",
                    "Blue light exposure",
                    "Delayed melatonin onset",
                    "Reduced sleep efficiency"
                ],
                strength: 0.62,
                confidence: 0.58,
                narrative: "2 hours of Netflix before bed may have delayed your melatonin onset by 30-45 minutes, contributing to lighter sleep in the first half of the night."
            )
        ]
    }

    private func focusExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Focus Deficit",
                causalChain: [
                    "45 min Instagram session",
                    "Dopamine debt score: 78/100",
                    "Prefrontal cortex fatigue",
                    "Brain fog and difficulty concentrating"
                ],
                strength: 0.72,
                confidence: 0.65,
                narrative: "Your 45-minute Instagram session this morning drove your dopamine debt to 78/100. The rapid-reward scrolling pattern depletes prefrontal dopamine reserves, making sustained attention on complex tasks (like coding) significantly harder for 2-3 hours afterward."
            ),
            CausalExplanation(
                symptom: "Focus Deficit",
                causalChain: [
                    "Glucose crash to 68 mg/dL",
                    "Cerebral glucose deficit",
                    "Cognitive impairment",
                    "Brain fog"
                ],
                strength: 0.65,
                confidence: 0.70,
                narrative: "Your post-meal glucose crash to 68 mg/dL means your brain is operating with reduced glucose availability. Combined with the high dopamine debt, this creates a compounding focus deficit."
            ),
            CausalExplanation(
                symptom: "Focus Deficit",
                causalChain: [
                    "Zombie scrolling on Instacart (35 min)",
                    "63 items browsed, 8 purchased",
                    "Impulse ratio: 0.87",
                    "Dopamine depletion from rapid-reward browsing"
                ],
                strength: 0.58,
                confidence: 0.55,
                narrative: "Your 35-minute zombie scrolling session on Instacart (viewing 63 items) created a rapid-reward dopamine pattern similar to social media scrolling. This depletes prefrontal dopamine reserves and impairs sustained attention."
            )
        ]
    }

    private func weightExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Weight Gain",
                causalChain: [
                    "High 3-day average GL (~40)",
                    "Elevated insulin response",
                    "Increased water retention",
                    "+0.5 kg over baseline"
                ],
                strength: 0.70,
                confidence: 0.65,
                narrative: "Your 3-day average glycemic load has been ~40 (above the recommended 25). Consistently high GL drives elevated insulin, which promotes water retention and fat storage. Your weight increased by 0.5 kg over the past 3 days, correlating with the high-GL DoorDash orders and Instacart impulse purchases."
            ),
            CausalExplanation(
                symptom: "Weight Gain",
                causalChain: [
                    "Zombie scrolling on Instacart (25-35 min)",
                    "Impulse purchases (high impulse ratio 0.74-0.87)",
                    "High-GL groceries (white bread, chips, soda)",
                    "Elevated dietary GL"
                ],
                strength: 0.62,
                confidence: 0.58,
                narrative: "Mindless browsing on Instacart led to impulse purchases of high-GL items (white bread, chips, cola). The zombie scrolling sessions averaged 30 minutes with an impulse ratio of 0.80, meaning most purchased items were unplanned and skewed toward processed, high-glycemic foods."
            )
        ]
    }

    private func environmentExplanations() -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: "Environmental Health Impact",
                causalChain: [
                    "AQI 150 (Unhealthy)",
                    "Oxidative stress increase",
                    "HRV suppression ~15%",
                    "Fatigue and reduced recovery"
                ],
                strength: 0.72,
                confidence: 0.68,
                narrative: "Today's AQI of 150 is in the 'Unhealthy' range. Exposure to fine particulate matter (PM2.5) triggers oxidative stress, suppressing your HRV by approximately 15%. This reduces your recovery capacity and contributes to fatigue, especially when combined with high-GL meals."
            ),
            CausalExplanation(
                symptom: "Environmental Health Impact",
                causalChain: [
                    "High pollen index (9/12)",
                    "Histamine response",
                    "Sleep disruption",
                    "Reduced deep sleep"
                ],
                strength: 0.65,
                confidence: 0.60,
                narrative: "Pollen levels were high (9/12) recently, triggering a histamine response that can disrupt sleep architecture. Combined with late meals, this further reduced your deep sleep percentage."
            ),
            CausalExplanation(
                symptom: "Environmental Health Impact",
                causalChain: [
                    "Extreme heat (35\u{00B0}C)",
                    "Increased metabolic demand",
                    "Spicy meal + heat",
                    "Digestive discomfort"
                ],
                strength: 0.58,
                confidence: 0.55,
                narrative: "Hot weather (35\u{00B0}C) combined with spicy food increases digestive stress. Heat raises your baseline heart rate and metabolic demand, making glucose regulation less efficient."
            )
        ]
    }

    private func generalExplanations(symptom: String) -> [CausalExplanation] {
        [
            CausalExplanation(
                symptom: symptom,
                causalChain: [
                    "Multiple lifestyle factors detected",
                    "Analyzing meal, glucose, and behavior data",
                    "Building causal model"
                ],
                strength: 0.5,
                confidence: 0.4,
                narrative: "VITA is analyzing your recent data to find causal links related to \"\(symptom)\". With more data points, the causal model will become more precise. Try asking about specific symptoms like fatigue, digestive issues, sleep quality, or focus."
            )
        ]
    }

    // MARK: - Pre-computed Counterfactuals

    public func counterfactualsForTired() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Switch to whole wheat flour rotis (-35% glucose spike)",
                impact: 0.35,
                effort: .trivial,
                confidence: 0.85
            ),
            Counterfactual(
                description: "Add 15g ghee/fat before carbs to flatten the curve",
                impact: 0.20,
                effort: .trivial,
                confidence: 0.72
            ),
            Counterfactual(
                description: "Take a 10-minute walk after meals",
                impact: 0.25,
                effort: .moderate,
                confidence: 0.78
            ),
        ]
    }

    public func counterfactualsForStomach() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Pressure cook beans instead of slow cook (-95% lectin)",
                impact: 0.40,
                effort: .trivial,
                confidence: 0.82
            ),
            Counterfactual(
                description: "Soak beans overnight before cooking",
                impact: 0.25,
                effort: .moderate,
                confidence: 0.70
            ),
        ]
    }

    public func counterfactualsForSleep() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Eat dinner 2 hours earlier (+25 min deep sleep)",
                impact: 0.30,
                effort: .moderate,
                confidence: 0.75
            ),
            Counterfactual(
                description: "Choose lower GL dinner (<20 GL)",
                impact: 0.22,
                effort: .moderate,
                confidence: 0.68
            ),
            Counterfactual(
                description: "Stop screens 1 hour before bed",
                impact: 0.18,
                effort: .significant,
                confidence: 0.60
            ),
        ]
    }

    public func counterfactualsForFocus() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Limit Instagram to 15 min blocks (-60% dopamine debt)",
                impact: 0.45,
                effort: .significant,
                confidence: 0.70
            ),
            Counterfactual(
                description: "Use Focus Mode during deep work blocks",
                impact: 0.30,
                effort: .moderate,
                confidence: 0.65
            ),
            Counterfactual(
                description: "Replace scrolling with a 5-min walk between tasks",
                impact: 0.35,
                effort: .moderate,
                confidence: 0.72
            ),
        ]
    }

    public func counterfactualsForWeight() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Keep daily average GL below 25 (-0.3 kg/week)",
                impact: 0.35,
                effort: .moderate,
                confidence: 0.70
            ),
            Counterfactual(
                description: "Avoid Instacart zombie scrolling — use a pre-made list",
                impact: 0.30,
                effort: .moderate,
                confidence: 0.65
            ),
            Counterfactual(
                description: "Replace processed snacks with nuts and yogurt",
                impact: 0.25,
                effort: .trivial,
                confidence: 0.72
            ),
        ]
    }

    public func counterfactualsForEnvironment() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Exercise indoors when AQI > 100 (preserve HRV)",
                impact: 0.30,
                effort: .trivial,
                confidence: 0.75
            ),
            Counterfactual(
                description: "Use air purifier on high-AQI days (-40% PM2.5 exposure)",
                impact: 0.25,
                effort: .moderate,
                confidence: 0.68
            ),
            Counterfactual(
                description: "Take antihistamine on high-pollen days (improve sleep)",
                impact: 0.20,
                effort: .trivial,
                confidence: 0.62
            ),
        ]
    }

    private func mealCounterfactuals() -> [Counterfactual] {
        counterfactualsForTired()
    }

    private func behaviorCounterfactuals() -> [Counterfactual] {
        counterfactualsForFocus()
    }

    private func generalCounterfactuals() -> [Counterfactual] {
        counterfactualsForTired() + counterfactualsForSleep()
    }
}
