import Foundation

/// The built-in deterministic bio-rules.
/// These fire when AI confidence is low or during cold start.
public enum DefaultRuleSet {
    public static let rules: [BioRule] = [
        // Rule 1: Metabolic fatigue from glucose crash
        BioRule(
            id: "metabolic_crash_fatigue",
            name: "Glucose Crash Fatigue",
            conditions: [
                RuleCondition(.glucoseCrashDelta(40)),
                RuleCondition(.hrvDropPercent(15)),
            ],
            conclusion: .metabolic,
            explanation: "Post-meal glucose crash with HRV suppression indicates metabolic fatigue.",
            recommendation: "Add protein or fat before carbs to flatten the glucose curve.",
            confidence: 0.75
        ),

        // Rule 2: Low protein + low HRV
        BioRule(
            id: "low_protein_recovery",
            name: "Low Protein Recovery Deficit",
            conditions: [
                RuleCondition(.hrvBelow(40)),
                RuleCondition(.proteinBelow(grams: 20)),
            ],
            conclusion: .metabolic,
            explanation: "Low HRV combined with insufficient protein intake impairs recovery.",
            recommendation: "Include 20-30g protein in your next meal for recovery support.",
            confidence: 0.70
        ),

        // Rule 3: Digital debt
        BioRule(
            id: "digital_dopamine_debt",
            name: "Dopamine Debt Fatigue",
            conditions: [
                RuleCondition(.dopamineDebtAbove(60)),
                RuleCondition(.passiveMinutesAbove(40)),
            ],
            conclusion: .digital,
            explanation: "Extended passive screen time has depleted dopamine reserves.",
            recommendation: "Take a 10-minute walk or engage in a focus-mode work block.",
            confidence: 0.70
        ),

        // Rule 4: Late meal sleep disruption
        BioRule(
            id: "late_meal_sleep",
            name: "Late Meal Sleep Impact",
            conditions: [
                RuleCondition(.lateMealAfter(hour: 21)),
                RuleCondition(.glAbove(30)),
            ],
            conclusion: .metabolic,
            explanation: "High-GL meal after 9 PM disrupts sleep architecture.",
            recommendation: "Eat dinner at least 2 hours before bed, keeping GL below 25.",
            confidence: 0.72
        ),

        // Rule 5: Environmental stress
        BioRule(
            id: "aqi_stress",
            name: "Air Quality Stress",
            conditions: [
                RuleCondition(.aqiAbove(100)),
                RuleCondition(.hrvDropPercent(10)),
            ],
            conclusion: .somatic,
            explanation: "Poor air quality is causing oxidative stress and HRV suppression.",
            recommendation: "Stay indoors and use an air purifier when AQI exceeds 100.",
            confidence: 0.65
        ),

        // Rule 6: Sleep deprivation
        BioRule(
            id: "sleep_deprivation",
            name: "Sleep Deprivation",
            conditions: [
                RuleCondition(.sleepBelow(hours: 6.5)),
                RuleCondition(.hrvBelow(45)),
            ],
            conclusion: .somatic,
            explanation: "Insufficient sleep combined with low HRV indicates recovery deficit.",
            recommendation: "Prioritize 7.5+ hours tonight. Avoid screens 1 hour before bed.",
            confidence: 0.75
        ),

        // Rule 7: Reactive scrolling (SCM-aware: root cause is metabolic, not digital)
        BioRule(
            id: "reactive_scrolling",
            name: "Reactive Scrolling Pattern",
            conditions: [
                RuleCondition(.glucoseCrashDelta(30)),
                RuleCondition(.passiveMinutesAbove(20)),
            ],
            conclusion: .metabolic,
            explanation: "Zombie scrolling occurred after a glucose crash — the fatigue caused the scrolling, not the other way around.",
            recommendation: "Address the glucose crash with better meal composition. The scrolling will resolve.",
            confidence: 0.70
        ),

        // Rule 8: Pollen sensitivity
        BioRule(
            id: "pollen_fatigue",
            name: "Pollen Sensitivity Fatigue",
            conditions: [
                RuleCondition(.pollenAbove(8)),
                RuleCondition(.sleepBelow(hours: 7.0)),
            ],
            conclusion: .somatic,
            explanation: "High pollen is triggering a histamine response, disrupting sleep and causing fatigue.",
            recommendation: "Consider an antihistamine and keep windows closed on high-pollen days.",
            confidence: 0.60
        ),

        // Rule 9: Chronic high GL
        BioRule(
            id: "chronic_high_gl",
            name: "Chronic High Glycemic Load",
            conditions: [
                RuleCondition(.glAbove(35)),
            ],
            conclusion: .metabolic,
            explanation: "Consistently high glycemic load meals are driving glucose volatility.",
            recommendation: "Aim for GL below 25 per meal. Switch to whole grains and add protein/fat.",
            confidence: 0.68
        ),
    ]
}
