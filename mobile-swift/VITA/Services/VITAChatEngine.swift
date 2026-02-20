import Foundation
import VITACore
import CausalityEngine
import VITADesignSystem

/// The central intelligence pipeline for Ask VITA.
///
/// For each user message:
///   1. Run causal analysis via the ReAct agent + Bio-Rule Engine (always runs)
///   2. Load the current health context from the HealthGraph (glucose, meals, HRV, sleep, behavior)
///   3. Build a rich system prompt embedding all real data + causal findings
///   4. Call Gemini with the full conversation history → AI-generated response
///   5. Fall back to the best available template narrative if Gemini is not configured
///
/// The structured causal chain cards are always rendered from the ReAct engine output.
/// Gemini drives the natural language narrative and multi-turn continuity.
struct VITAChatEngine: Sendable {

    // Maximum history messages sent to Gemini (20 = 10 exchanges). Keeps tokens reasonable.
    private static let maxHistoryMessages = 20

    // MARK: - Main Entry Point

    struct TurnResult {
        let response: String
        let explanations: [CausalExplanation]
        let counterfactuals: [Counterfactual]
        let glucoseDataPoints: [GlucoseDataPoint]
        let mealAnnotations: [MealAnnotationPoint]
        let activatedSources: Set<String>
    }

    static func processMessage(
        userMessage: String,
        history: [ChatMessage],
        appState: AppState
    ) async throws -> TurnResult {

        let now = Date()
        let windowStart = now.addingTimeInterval(-6 * 3_600)
        // Skin analysis looks back 7 days (conditions don't change hour-to-hour)
        let skinWindowStart = now.addingTimeInterval(-7 * 24 * 3_600)

        // ── Step 1: Causal Analysis ────────────────────────────────────────────
        var explanations: [CausalExplanation]
        var counterfactuals: [Counterfactual]

        do {
            let raw = try await appState.causalityEngine.querySymptom(userMessage)
            explanations = Array(raw.prefix(5))

            let cfs = try await appState.causalityEngine.generateCounterfactual(
                forSymptom: userMessage,
                explanations: explanations
            )
            counterfactuals = Array(cfs.sorted { $0.impact > $1.impact }.prefix(8))
        } catch {
            explanations = []
            counterfactuals = []
        }

        // ── Step 2: Health Context Data ───────────────────────────────────────
        let glucosePoints = loadGlucose(appState: appState, from: windowStart, to: now)
        let mealPoints = loadMeals(appState: appState, from: windowStart, to: now)
        let latestSkinForSources = try? appState.healthGraph.queryLatestSkinAnalysis()
        let activatedSources = inferSources(
            explanations: explanations,
            glucosePoints: glucosePoints,
            mealPoints: mealPoints,
            skinAnalysis: latestSkinForSources
        )

        // ── Step 3: Gemini or fallback ─────────────────────────────────────────
        let geminiConfig = GeminiConfig.current

        guard geminiConfig.isConfigured else {
            // Graceful fallback: use best narrative from causal engine
            let fallback = buildFallbackResponse(
                userMessage: userMessage,
                explanations: explanations,
                counterfactuals: counterfactuals
            )
            return TurnResult(
                response: fallback,
                explanations: explanations,
                counterfactuals: counterfactuals,
                glucoseDataPoints: glucosePoints,
                mealAnnotations: mealPoints,
                activatedSources: activatedSources
            )
        }

        // ── Step 4: Build system prompt with full health context ───────────────
        let latestSkinAnalysis = try? appState.healthGraph.queryLatestSkinAnalysis()
        let systemPrompt = buildSystemPrompt(
            appState: appState,
            windowStart: windowStart,
            windowEnd: now,
            glucosePoints: glucosePoints,
            mealPoints: mealPoints,
            explanations: explanations,
            counterfactuals: counterfactuals,
            skinAnalysis: latestSkinAnalysis
        )

        // ── Step 5: Map conversation history → Gemini format ──────────────────
        var geminiMessages = buildGeminiHistory(from: history)
        geminiMessages.append(
            GeminiService.Message(role: "user", parts: [.init(text: userMessage)])
        )

        // ── Step 6: Call Gemini ────────────────────────────────────────────────
        let response = try await GeminiService.chat(
            systemPrompt: systemPrompt,
            messages: geminiMessages,
            config: geminiConfig
        )

        return TurnResult(
            response: response,
            explanations: explanations,
            counterfactuals: counterfactuals,
            glucoseDataPoints: glucosePoints,
            mealAnnotations: mealPoints,
            activatedSources: activatedSources
        )
    }

    // MARK: - System Prompt

    private static func buildSystemPrompt(
        appState: AppState,
        windowStart: Date,
        windowEnd: Date,
        glucosePoints: [GlucoseDataPoint],
        mealPoints: [MealAnnotationPoint],
        explanations: [CausalExplanation],
        counterfactuals: [Counterfactual],
        skinAnalysis: SkinAnalysisRecord? = nil
    ) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        let windowFmt = DateFormatter()
        windowFmt.dateStyle = .medium
        windowFmt.timeStyle = .short

        var p = """
        You are VITA, an intelligent personal health causality engine in conversation with your user.

        YOUR ROLE:
        • Trace causal chains through the user's REAL health data (timestamps, values, meal sources, skin scans).
        • Be specific. Use exact numbers from the data (e.g., "glucose spiked to 156mg/dL at 7:45pm", "dark circles score 68/100").
        • Explain root causes clearly and directly. Avoid hedging excessively.
        • CROSS-DOMAIN REASONING: You have access to skin analysis data. Use it to reason across domains.
          - Example: dark circles (skin) + poor sleep (HRV/sleep) + late meals → explains morning headaches or fatigue.
          - Example: acne (skin) + high-GL meals + elevated glucose → same insulin pathway explains both skin and energy issues.
          - Example: redness (skin) + high AQI (environment) → systemic inflammation may cause respiratory symptoms too.
        • Suggest 1-2 concrete, evidence-backed interventions grounded in all data sources.
        • In multi-turn conversations, reference what was said before and build on it.
        • Keep each response to 2-4 focused paragraphs. Never fabricate data — only use what's in the sections below.
        • End responses with a brief follow-up prompt to encourage continued exploration.

        DATA WINDOW: \(windowFmt.string(from: windowStart)) → \(windowFmt.string(from: windowEnd))

        """

        // Glucose
        p += "\n━━ GLUCOSE ━━\n"
        if glucosePoints.isEmpty {
            p += "No CGM readings in window.\n"
        } else {
            // Show last 16 readings (covers ~80 min at 5-min CGM intervals)
            for pt in glucosePoints.suffix(16) {
                p += "  \(timeFmt.string(from: pt.timestamp))  \(Int(pt.value)) mg/dL\n"
            }
        }

        // Meals
        p += "\n━━ MEALS ━━\n"
        if mealPoints.isEmpty {
            p += "No meals recorded in window.\n"
        } else {
            for m in mealPoints {
                p += "  \(timeFmt.string(from: m.timestamp))  \(m.label)  GL=\(String(format: "%.1f", m.glycemicLoad))\n"
            }
        }

        // HRV + sleep
        if let (hrv, sleep) = loadPhysiological(appState: appState, windowStart: windowStart, windowEnd: windowEnd) {
            p += "\n━━ PHYSIOLOGICAL ━━\n"
            if let (avgHRV, latestHRV) = hrv {
                p += "  HRV (SDNN): avg \(Int(avgHRV))ms, latest \(Int(latestHRV))ms\n"
            }
            if let sleepHours = sleep {
                p += "  Sleep (last night): \(String(format: "%.1f", sleepHours))h\n"
            }
        }

        // Behavior
        if let behaviorSummary = loadBehavior(appState: appState, windowStart: windowStart, windowEnd: windowEnd) {
            p += "\n━━ BEHAVIOR ━━\n\(behaviorSummary)\n"
        }

        // Environment
        if let envSummary = loadEnvironment(appState: appState, windowStart: windowStart, windowEnd: windowEnd) {
            p += "\n━━ ENVIRONMENT ━━\n\(envSummary)\n"
        }

        // Skin Analysis (PerfectCorp YouCam — most recent scan)
        p += "\n━━ SKIN ANALYSIS (PerfectCorp YouCam AI) ━━\n"
        if let skin = skinAnalysis {
            let skinFmt = DateFormatter()
            skinFmt.dateStyle = .short
            skinFmt.timeStyle = .short
            p += "  Scan date: \(skinFmt.string(from: skin.timestamp))\n"
            p += "  Overall skin score: \(skin.overallScore)/100\n"
            let conditions = skin.conditions
            if conditions.isEmpty {
                p += "  No significant skin conditions detected.\n"
            } else {
                for c in conditions {
                    let label = c.rawScore > 0.65 ? "Severe" : c.rawScore > 0.35 ? "Moderate" : "Mild"
                    p += "  • \(c.type): \(label) (score \(c.uiScore)/100, raw \(String(format: "%.2f", c.rawScore)))\n"
                }
                // Cross-domain causal hints for the AI
                p += "\n  CROSS-DOMAIN REASONING HINTS:\n"
                let hasAcne       = conditions.contains { $0.type == "acne" }
                let hasDarkCircles = conditions.contains { $0.type == "dark_circle_v2" || $0.type == "eye_bag" }
                let hasRedness    = conditions.contains { $0.type == "redness" }
                let hasOiliness   = conditions.contains { $0.type == "oiliness" }
                if hasDarkCircles {
                    p += "  ▸ Dark circles/eye bags + poor sleep data → may explain fatigue or headaches (shared root: sleep deprivation → cortisol → periorbital inflammation + systemic inflammation).\n"
                    p += "  ▸ Dark circles + late meals + low HRV → headache risk elevated (glycemic crash after late eating → impaired sleep → HRV suppression → tension headache via vascular inflammation).\n"
                }
                if hasAcne {
                    p += "  ▸ Acne + high-GL meals → insulin spike cascade affects both skin (sebum) and energy levels (reactive hypoglycemia).\n"
                    p += "  ▸ Acne + gut inflammation (slow-cook lectin retention) → gut-skin axis; same inflammation may cause bloating or brain fog.\n"
                }
                if hasRedness {
                    p += "  ▸ Skin redness + high AQI → systemic NF-κB inflammation; may also contribute to respiratory symptoms or fatigue.\n"
                }
                if hasOiliness {
                    p += "  ▸ Oiliness + high-GI diet → same insulin/androgen pathway causing energy crashes; look for correlated glucose spikes.\n"
                }
            }
        } else {
            p += "  No skin analysis data available yet. User can run a scan in the Skin Audit tab.\n"
        }

        // Causal Analysis from ReAct engine
        if !explanations.isEmpty {
            p += "\n━━ CAUSAL ANALYSIS (ReAct + Bio-Rule Engine) ━━\n"
            for (i, exp) in explanations.enumerated() {
                p += "\n  [\(i + 1)] \(exp.symptom)\n"
                p += "       Confidence: \(Int(exp.confidence * 100))%  |  Strength: \(String(format: "%.2f", exp.strength))\n"
                p += "       Chain: \(exp.causalChain.joined(separator: " → "))\n"
                if !exp.narrative.isEmpty {
                    p += "       Engine narrative: \(exp.narrative)\n"
                }
            }
        } else {
            p += "\n━━ CAUSAL ANALYSIS ━━\nInsufficient data for a causal chain. The engine is still learning.\n"
        }

        // Counterfactuals
        if !counterfactuals.isEmpty {
            p += "\n━━ COUNTERFACTUAL INTERVENTIONS (SCM) ━━\n"
            for cf in counterfactuals.prefix(4) {
                p += "  • \(cf.description)\n"
                p += "    Impact: \(Int(cf.impact * 100))%  |  Effort: \(cf.effort.rawValue)  |  Confidence: \(Int(cf.confidence * 100))%\n"
            }
        }

        return p
    }

    // MARK: - Fallback (no Gemini key)

    private static func buildFallbackResponse(
        userMessage: String,
        explanations: [CausalExplanation],
        counterfactuals: [Counterfactual]
    ) -> String {
        if let top = explanations.first, !top.narrative.isEmpty {
            var response = top.narrative
            if let cf = counterfactuals.first {
                response += "\n\nTop recommendation: \(cf.description) — estimated \(Int(cf.impact * 100))% impact."
            }
            response += "\n\n(Configure a Gemini API key in Settings to enable richer AI-driven responses.)"
            return response
        }
        return "I've run the causal analysis but don't have enough data to confidently explain '\(userMessage)' yet. As more health data accumulates over the coming days, my answers will become more specific.\n\n(Add a Gemini API key in Settings → Ask VITA AI for richer responses.)"
    }

    // MARK: - History Mapper

    /// Convert ChatMessage history to Gemini alternating user/model format.
    /// Trims to last `maxHistoryMessages` to stay within free-tier token budget.
    private static func buildGeminiHistory(from history: [ChatMessage]) -> [GeminiService.Message] {
        history.suffix(maxHistoryMessages).map { msg in
            let role = msg.role == .user ? "user" : "model"
            return GeminiService.Message(role: role, parts: [.init(text: msg.content)])
        }
    }

    // MARK: - Data Loaders (private helpers, non-throwing)

    private static func loadGlucose(appState: AppState, from start: Date, to end: Date) -> [GlucoseDataPoint] {
        guard let readings = try? appState.healthGraph.queryGlucose(from: start, to: end) else { return [] }
        return readings.map { GlucoseDataPoint(timestamp: $0.timestamp, value: $0.glucoseMgDL) }
    }

    private static func loadMeals(appState: AppState, from start: Date, to end: Date) -> [MealAnnotationPoint] {
        guard let meals = try? appState.healthGraph.queryMeals(from: start, to: end) else { return [] }
        return meals.map { meal in
            let label = meal.ingredients.first?.name ?? meal.source.rawValue
            let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
            return MealAnnotationPoint(timestamp: meal.timestamp, label: label, glycemicLoad: gl)
        }
    }

    private static func loadPhysiological(
        appState: AppState,
        windowStart: Date,
        windowEnd: Date
    ) -> (hrv: (avg: Double, latest: Double)?, sleep: Double?)? {
        let hrv = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: windowStart, to: windowEnd)
        let sleep = try? appState.healthGraph.querySamples(
            type: .sleepAnalysis,
            from: windowStart.addingTimeInterval(-24 * 3_600),
            to: windowEnd
        )

        let hrvResult: (Double, Double)?
        if let hrv, !hrv.isEmpty {
            let avg = hrv.map(\.value).reduce(0, +) / Double(hrv.count)
            let latest = hrv.last?.value ?? avg
            hrvResult = (avg, latest)
        } else {
            hrvResult = nil
        }

        let sleepResult = sleep.flatMap { s -> Double? in
            guard !s.isEmpty else { return nil }
            return s.map(\.value).reduce(0, +)
        }

        guard hrvResult != nil || sleepResult != nil else { return nil }
        return (hrv: hrvResult, sleep: sleepResult)
    }

    private static func loadBehavior(appState: AppState, windowStart: Date, windowEnd: Date) -> String? {
        guard let behaviors = try? appState.healthGraph.queryBehaviors(from: windowStart, to: windowEnd) else { return nil }
        let passive = behaviors.filter { $0.category == .passiveConsumption || $0.category == .zombieScrolling }
        guard !passive.isEmpty else { return nil }
        let totalMin = Int(passive.reduce(0) { $0 + $1.duration / 60 })
        let maxDebt = passive.compactMap(\.dopamineDebtScore).max().map { Int($0) } ?? 0
        return "  Passive screen time: \(totalMin)min  |  Dopamine debt: \(maxDebt)"
    }

    private static func loadEnvironment(appState: AppState, windowStart: Date, windowEnd: Date) -> String? {
        guard let env = try? appState.healthGraph.queryEnvironment(from: windowStart, to: windowEnd),
              let latest = env.last else { return nil }
        return "  AQI: \(latest.aqiUS)  |  Pollen: \(latest.pollenIndex)  |  Temp: \(Int(latest.temperatureCelsius))°C"
    }

    private static func inferSources(
        explanations: [CausalExplanation],
        glucosePoints: [GlucoseDataPoint],
        mealPoints: [MealAnnotationPoint],
        skinAnalysis: SkinAnalysisRecord? = nil
    ) -> Set<String> {
        var sources = Set<String>()
        if !glucosePoints.isEmpty { sources.insert("Glucose") }
        if !mealPoints.isEmpty { sources.insert("Meals") }
        if skinAnalysis != nil { sources.insert("Skin") }

        let chainText = explanations.flatMap(\.causalChain).joined(separator: " ").lowercased()
        if chainText.contains("hrv") || chainText.contains("heart") { sources.insert("HRV") }
        if chainText.contains("sleep") { sources.insert("Sleep") }
        if chainText.contains("screen") || chainText.contains("dopamine") { sources.insert("Behavior") }
        if chainText.contains("aqi") || chainText.contains("pollen") { sources.insert("Environment") }
        if chainText.contains("skin") || chainText.contains("acne") || chainText.contains("dark circle") {
            sources.insert("Skin")
        }
        if sources.isEmpty { sources.insert("Health Graph") }
        return sources
    }
}
