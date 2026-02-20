import Foundation
import CausalityEngine
import VITACore

struct HealthReportService {

    // MARK: - Document value models

    struct DocumentValues: Encodable {
        let reportDate: String
        let reportId: String
        let aiGeneratedLabel: String
        let aiSummaryTitle: String
        let aiSummaryBody: String
        let confidenceBand: String
        let likelyReason: String
        let supportingEvidence: String
        let nextBestAction: String
        let primaryConcern: String
        let sleepQuality: String
        let digestiveIssues: String
        let exerciseFrequency: String
        let providerGoal: String
        let healthScore: String
        let hrv: String
        let heartRate: String
        let glucose: String
        let sleepHours: String
        let steps: String
        let skinScore: String
        let topSignal1: String
        let topSignal2: String
        let topSignal3: String
        let mealInsight1: String
        let mealInsight2: String
        let mealInsight3: String
        let skinInsight1: String
        let skinInsight2: String
        let causalInsight1: String
        let causalInsight2: String
        let causalInsight3: String
        let recommendation1: String
        let recommendation2: String
        let recommendation3: String

        struct MealRow: Encodable {
            let meal: String
            let source: String
            let glycemicLoad: String
            let impact: String
        }

        struct SkinConditionRow: Encodable {
            let condition: String
            let severity: String
            let zone: String
            let confidence: String
        }

        struct TopSignalRow: Encodable {
            let signal: String
            let insight: String
        }

        struct CausalFindingRow: Encodable {
            let finding: String
            let detail: String
            let source: String
        }

        struct RecommendationRow: Encodable {
            let rec: String
        }
    }

    struct AskVITAContext {
        let question: String
        let explanations: [CausalExplanation]
        let counterfactuals: [Counterfactual]
    }

    // MARK: - Build document values

    @MainActor
    static func buildDocumentValues(
        appState: AppState,
        dashVM: DashboardViewModel,
        skinVM: SkinHealthViewModel,
        answers: ReportAnswers
    ) -> DocumentValues {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyyMMdd-HHmmss"

        let now = Date()

        let skinScoreRaw = skinVM.analysisResult.map { "\($0.overallScore)" } ?? "72"
        let meals = mockRecentMeals()

        let skinConditionRows: [DocumentValues.SkinConditionRow]
        if let result = skinVM.analysisResult {
            skinConditionRows = result.conditions.map { condition in
                DocumentValues.SkinConditionRow(
                    condition: condition.type.rawValue.capitalized,
                    severity: String(format: "%.0f%%", condition.severity * 100),
                    zone: condition.affectedZones.map(\.rawValue).joined(separator: ", "),
                    confidence: String(format: "%.0f%%", condition.confidence * 100)
                )
            }
        } else {
            skinConditionRows = defaultSkinConditions()
        }

        let causalFindingRows: [DocumentValues.CausalFindingRow]
        if !skinVM.causalFindings.isEmpty {
            causalFindingRows = skinVM.causalFindings.map { finding in
                DocumentValues.CausalFindingRow(
                    finding: finding.cause,
                    detail: finding.detail,
                    source: finding.source
                )
            }
        } else {
            causalFindingRows = defaultCausalFindings()
        }

        let recommendationRows: [DocumentValues.RecommendationRow]
        if !skinVM.recommendations.isEmpty {
            recommendationRows = skinVM.recommendations.map { DocumentValues.RecommendationRow(rec: $0) }
        } else {
            recommendationRows = defaultRecommendations()
        }

        let topSignals = topSignals(
            causalFindings: causalFindingRows,
            mealRows: meals,
            digestSignal: answers.digestiveIssues
        )

        let likelyReason = causalFindingRows.first?.finding ?? "No dominant reason identified yet"
        let summaryBody = "Patterns suggest \(likelyReason.lowercased()). Verify with your provider using meal timing, sleep quality, and glucose response trends in this report."
        let confidenceBand = confidenceBand(from: causalFindingRows.first?.detail)
        let topSignalLines = paddedLines(
            from: topSignals.map { "\($0.signal): \($0.insight)" },
            count: 3,
            fallback: "No strong signal available yet."
        )
        let mealLines = paddedLines(
            from: meals.map { "\($0.meal) (\($0.source)) - GL \($0.glycemicLoad), \($0.impact)" },
            count: 3,
            fallback: "No meal insight available."
        )
        let skinLines = paddedLines(
            from: skinConditionRows.map { "\($0.condition): severity \($0.severity), zone \($0.zone), confidence \($0.confidence)" },
            count: 2,
            fallback: "No skin analysis available."
        )
        let causalLines = paddedLines(
            from: causalFindingRows.map { "\($0.finding): \($0.detail)" },
            count: 3,
            fallback: "No causal finding available."
        )
        let recommendationLines = paddedLines(
            from: recommendationRows.map(\.rec),
            count: 3,
            fallback: "No recommendation available."
        )

        return DocumentValues(
            reportDate: dateFormatter.string(from: now),
            reportId: "VITA-\(idFormatter.string(from: now))",
            aiGeneratedLabel: "AI GENERATED",
            aiSummaryTitle: "AI-Generated Health Summary",
            aiSummaryBody: summaryBody,
            confidenceBand: confidenceBand,
            likelyReason: likelyReason,
            supportingEvidence: topSignals.first?.insight ?? "No high-confidence signal available yet.",
            nextBestAction: recommendationRows.first?.rec ?? "Track symptoms with meals and sleep for 7 days, then regenerate this report.",
            primaryConcern: answers.primaryConcern,
            sleepQuality: answers.sleepQuality,
            digestiveIssues: answers.digestiveIssues,
            exerciseFrequency: answers.exerciseFrequency,
            providerGoal: answers.providerGoal,
            healthScore: String(format: "%.0f", dashVM.healthScore),
            hrv: "\(Int(dashVM.currentHRV.rounded())) ms",
            heartRate: "\(Int(dashVM.currentHR.rounded())) bpm",
            glucose: "\(Int(dashVM.currentGlucose.rounded())) mg/dL",
            sleepHours: String(format: "%.1f hrs", dashVM.sleepHours),
            steps: formattedSteps(dashVM.steps),
            skinScore: "\(skinScoreRaw)/100",
            topSignal1: topSignalLines[0],
            topSignal2: topSignalLines[1],
            topSignal3: topSignalLines[2],
            mealInsight1: mealLines[0],
            mealInsight2: mealLines[1],
            mealInsight3: mealLines[2],
            skinInsight1: skinLines[0],
            skinInsight2: skinLines[1],
            causalInsight1: causalLines[0],
            causalInsight2: causalLines[1],
            causalInsight3: causalLines[2],
            recommendation1: recommendationLines[0],
            recommendation2: recommendationLines[1],
            recommendation3: recommendationLines[2]
        )
    }

    @MainActor
    static func buildAskVITADocumentValues(
        appState: AppState,
        context: AskVITAContext
    ) -> DocumentValues {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyyMMdd-HHmmss"

        let now = Date()
        let dashboard = DashboardViewModel()
        dashboard.load(from: appState)
        let meals = recentMealRows(appState: appState, now: now)
        let causalRows = causalFindingRows(from: context.explanations)
        let recommendationRows = recommendationRows(from: context.counterfactuals)

        let sanitizedQuestion = context.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let topExplanation = context.explanations.max(by: { $0.confidence < $1.confidence })

        // Use the full causal chain joined with arrows as the likely driver
        let likelyDriver: String
        if let top = topExplanation, !top.causalChain.isEmpty {
            likelyDriver = top.causalChain.joined(separator: " → ")
        } else {
            likelyDriver = topExplanation?.symptom ?? "No dominant root cause detected yet"
        }

        // Load skin data for the PDF — don't leave it as "Not analyzed" if we have a scan
        let skinAnalysis = try? appState.healthGraph.queryLatestSkinAnalysis()
        let skinScoreValue: String
        let skinConditionSummary: [String]
        if let skin = skinAnalysis {
            skinScoreValue = "\(skin.overallScore)/100"
            skinConditionSummary = skin.conditions.map { c in
                let sev = c.rawScore > 0.65 ? "Severe" : c.rawScore > 0.35 ? "Moderate" : "Mild"
                return "\(c.type.replacingOccurrences(of: "_", with: " ").capitalized): \(sev) (\(c.uiScore)/100)"
            }
        } else {
            skinScoreValue = "No scan available"
            skinConditionSummary = ["Run a Skin Audit scan to include dermatology signals in future reports."]
        }

        let summary = buildAskVITASummary(
            question: sanitizedQuestion,
            dashboard: dashboard,
            explanations: context.explanations,
            counterfactuals: context.counterfactuals,
            mealRows: meals,
            likelyDriver: likelyDriver
        )
        let topSignals = topSignals(
            causalFindings: causalRows,
            mealRows: meals,
            digestSignal: digestiveSummary(question: sanitizedQuestion, explanations: context.explanations)
        )

        let topSignalLines = paddedLines(
            from: topSignals.map { "\($0.signal): \($0.insight)" },
            count: 3,
            fallback: "No strong signal available yet."
        )
        let mealLines = paddedLines(
            from: meals.map { "\($0.meal) (\($0.source))  ·  GL \($0.glycemicLoad)  ·  \($0.impact)" },
            count: 3,
            fallback: "No meal insight available."
        )
        let skinLines = paddedLines(
            from: skinConditionSummary,
            count: 2,
            fallback: "No skin data available."
        )
        let causalLines = paddedLines(
            from: causalRows.map { "\($0.finding)  ·  \($0.detail)  [Source: \($0.source)]" },
            count: 3,
            fallback: "No causal finding available."
        )
        let recommendationLines = paddedLines(
            from: recommendationRows.map(\.rec),
            count: 3,
            fallback: "No recommendation available."
        )

        return DocumentValues(
            reportDate: dateFormatter.string(from: now),
            reportId: "VITA-\(idFormatter.string(from: now))",
            aiGeneratedLabel: "AI GENERATED",
            aiSummaryTitle: summary.title,
            aiSummaryBody: summary.body,
            confidenceBand: summary.confidenceBand,
            likelyReason: likelyDriver,
            supportingEvidence: summary.supportingEvidence,
            nextBestAction: summary.nextBestAction,
            primaryConcern: sanitizedQuestion.isEmpty ? "Root-cause analysis" : sanitizedQuestion,
            sleepQuality: sleepQuality(hours: dashboard.sleepHours),
            digestiveIssues: digestiveSummary(question: sanitizedQuestion, explanations: context.explanations),
            exerciseFrequency: exerciseFrequency(steps: dashboard.steps),
            providerGoal: "Likely driver: \(topExplanation?.causalChain.first ?? likelyDriver)",
            healthScore: String(format: "%.0f", dashboard.healthScore),
            hrv: "\(Int(dashboard.currentHRV.rounded())) ms",
            heartRate: "\(Int(dashboard.currentHR.rounded())) bpm",
            glucose: "\(Int(dashboard.currentGlucose.rounded())) mg/dL",
            sleepHours: String(format: "%.1f hrs", dashboard.sleepHours),
            steps: formattedSteps(dashboard.steps),
            skinScore: skinScoreValue,
            topSignal1: topSignalLines[0],
            topSignal2: topSignalLines[1],
            topSignal3: topSignalLines[2],
            mealInsight1: mealLines[0],
            mealInsight2: mealLines[1],
            mealInsight3: mealLines[2],
            skinInsight1: skinLines[0],
            skinInsight2: skinLines[1],
            causalInsight1: causalLines[0],
            causalInsight2: causalLines[1],
            causalInsight3: causalLines[2],
            recommendation1: recommendationLines[0],
            recommendation2: recommendationLines[1],
            recommendation3: recommendationLines[2]
        )
    }

    // MARK: - Full generation pipeline

    @MainActor
    static func generateReport(
        appState: AppState,
        dashVM: DashboardViewModel,
        skinVM: SkinHealthViewModel,
        answers: ReportAnswers,
        config: FoxitConfig
    ) async throws -> Data {
        let values = buildDocumentValues(appState: appState, dashVM: dashVM, skinVM: skinVM, answers: answers)
        let templateBase64 = DocxTemplateBuilder.build().base64EncodedString()
        let rawPDF = try await FoxitDocumentGenerationService.generate(
            templateBase64: templateBase64,
            values: values,
            config: config
        )
        return try await FoxitPDFServicesService.optimize(pdfData: rawPDF, config: config)
    }

    @MainActor
    static func generateAskVITAReport(
        appState: AppState,
        context: AskVITAContext,
        config: FoxitConfig
    ) async throws -> Data {
        let values = buildAskVITADocumentValues(appState: appState, context: context)
        let templateBase64 = DocxTemplateBuilder.build().base64EncodedString()
        let rawPDF = try await FoxitDocumentGenerationService.generate(
            templateBase64: templateBase64,
            values: values,
            config: config
        )
        return try await FoxitPDFServicesService.optimize(pdfData: rawPDF, config: config)
    }

    // MARK: - Mock / fallback data

    private static func mockRecentMeals() -> [DocumentValues.MealRow] {
        [
            DocumentValues.MealRow(
                meal: "Chole Bhature",
                source: "DoorDash",
                glycemicLoad: "42",
                impact: "High spike (+48 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Aloo Paratha",
                source: "Rotimatic NEXT",
                glycemicLoad: "38",
                impact: "Moderate spike (+32 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Paneer Butter Masala",
                source: "DoorDash",
                glycemicLoad: "28",
                impact: "Moderate spike (+25 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Poha",
                source: "Home",
                glycemicLoad: "18",
                impact: "Low spike (+12 mg/dL)"
            ),
        ]
    }

    private static func defaultSkinConditions() -> [DocumentValues.SkinConditionRow] {
        [
            DocumentValues.SkinConditionRow(
                condition: "Acne",
                severity: "65%",
                zone: "Forehead, Chin",
                confidence: "87%"
            ),
            DocumentValues.SkinConditionRow(
                condition: "Dark Circles",
                severity: "48%",
                zone: "Under Eyes",
                confidence: "79%"
            ),
        ]
    }

    private static func defaultCausalFindings() -> [DocumentValues.CausalFindingRow] {
        [
            DocumentValues.CausalFindingRow(
                finding: "High-GL Late Meal",
                detail: "Late DoorDash order elevated IGF-1, triggering sebum overproduction within 48h",
                source: "DoorDash"
            ),
            DocumentValues.CausalFindingRow(
                finding: "Zombie Scroll Session",
                detail: "45-min blue-light exposure suppressed melatonin by ~50%, increasing periorbital fluid retention",
                source: "Screen Time"
            ),
            DocumentValues.CausalFindingRow(
                finding: "HRV Suppression",
                detail: "HRV averaged below 40 ms over 3 days — impaired lymphatic drainage correlates with skin inflammation",
                source: "Apple Watch"
            ),
        ]
    }

    private static func defaultRecommendations() -> [DocumentValues.RecommendationRow] {
        [
            DocumentValues.RecommendationRow(rec: "Avoid DoorDash orders after 8 PM for 7 days"),
            DocumentValues.RecommendationRow(rec: "Set Screen Time limit: ≤30 min social media after 9 PM"),
            DocumentValues.RecommendationRow(rec: "Switch to Bajra/Jowar Rotis — lower GI reduces sebum by ~30%"),
            DocumentValues.RecommendationRow(rec: "Use Pressure Cook mode in Instant Pot — 95% lectin deactivation"),
        ]
    }

    private static func sleepQuality(hours: Double) -> String {
        if hours <= 0 { return "Unknown" }
        if hours < 6 { return "Poor" }
        if hours < 7.5 { return "Fair" }
        if hours < 9 { return "Good" }
        return "Excellent"
    }

    private static func exerciseFrequency(steps: Int) -> String {
        if steps >= 10_000 { return "5+ days pattern" }
        if steps >= 7_000 { return "3–4 days pattern" }
        if steps >= 4_000 { return "1–2 days pattern" }
        return "Low activity pattern"
    }

    private static func digestiveSummary(
        question: String,
        explanations: [CausalExplanation]
    ) -> String {
        let haystack = ([question] + explanations.map(\.symptom) + explanations.map(\.narrative))
            .joined(separator: " ")
            .lowercased()
        let digestiveKeywords = ["stomach", "gut", "digest", "bloat", "nausea", "acid", "reflux", "upset"]
        let hasDigestiveSignal = digestiveKeywords.contains(where: haystack.contains)
        return hasDigestiveSignal ? "Digestive symptom signal present in query/chain" : "No dominant digestive signal"
    }

    private struct AISummaryContent {
        let title: String
        let body: String
        let confidenceBand: String
        let likelyReason: String
        let supportingEvidence: String
        let nextBestAction: String
    }

    @MainActor
    private static func buildAskVITASummary(
        question: String,
        dashboard: DashboardViewModel,
        explanations: [CausalExplanation],
        counterfactuals: [Counterfactual],
        mealRows: [DocumentValues.MealRow],
        likelyDriver: String
    ) -> AISummaryContent {
        let safeQuestion = question.isEmpty ? "your recent symptom" : question
        let topExplanation = explanations.max(by: { $0.confidence < $1.confidence })
        let topNarrative = topExplanation?.narrative.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let confidence = Int(((topExplanation?.confidence ?? 0.42) * 100).rounded())

        // Derive confidence band directly from the Double — no string parsing
        let band: String
        if confidence >= 75 { band = "High confidence (\(confidence)%)" }
        else if confidence >= 55 { band = "Moderate confidence (\(confidence)%)" }
        else { band = "Early signal — more data needed (\(confidence)%)" }

        let sleepBand = sleepQuality(hours: dashboard.sleepHours)
        let hrvStr = "\(Int(dashboard.currentHRV.rounded())) ms"
        let glucoseStr = "\(Int(dashboard.currentGlucose.rounded())) mg/dL"

        // Summary body: narrative + brief vitals context
        let narrativeClip = topNarrative.isEmpty ? "Causal analysis identified \(likelyDriver) as the primary driver." : clipped(topNarrative, limit: 280)
        let bodyText = "\(narrativeClip) Sleep quality is \(sleepBand.lowercased()) at \(String(format: "%.1f", dashboard.sleepHours)) hours. HRV: \(hrvStr). Glucose: \(glucoseStr)."

        let nextAction: String
        if let strongest = counterfactuals.sorted(by: { $0.impact > $1.impact }).first {
            let impact = Int((strongest.impact * 100).rounded())
            let conf = Int((strongest.confidence * 100).rounded())
            nextAction = "\(strongest.description)  ·  \(impact)% estimated impact  ·  \(conf)% confidence  ·  Effort: \(strongest.effort.rawValue)"
        } else {
            nextAction = "Track meals, sleep, and symptom timing for 7 days, then rerun Ask VITA."
        }

        let supportingEvidence = "Confidence: \(confidence)%  ·  Sleep: \(String(format: "%.1f", dashboard.sleepHours)) hrs (\(sleepBand))  ·  HRV: \(hrvStr)  ·  Glucose: \(glucoseStr)  ·  Health Score: \(Int(dashboard.healthScore.rounded()))/100"

        return AISummaryContent(
            title: "VITA Analysis: \"\(safeQuestion)\"",
            body: bodyText,
            confidenceBand: band,
            likelyReason: likelyDriver,
            supportingEvidence: supportingEvidence,
            nextBestAction: nextAction
        )
    }

    private static func topSignals(
        causalFindings: [DocumentValues.CausalFindingRow],
        mealRows: [DocumentValues.MealRow],
        digestSignal: String
    ) -> [DocumentValues.TopSignalRow] {
        var rows: [DocumentValues.TopSignalRow] = []

        if let firstFinding = causalFindings.first {
            rows.append(
                DocumentValues.TopSignalRow(
                    signal: firstFinding.finding,
                    insight: clipped("\(firstFinding.detail) [\(firstFinding.source)]", limit: 140)
                )
            )
        }

        if let highMeal = mealRows.first(where: { $0.impact.lowercased().contains("high spike") }) ?? mealRows.first {
            rows.append(
                DocumentValues.TopSignalRow(
                    signal: "Meal-Glucose Pattern",
                    insight: "\(highMeal.meal) from \(highMeal.source): \(highMeal.impact)"
                )
            )
        }

        rows.append(
            DocumentValues.TopSignalRow(
                signal: "Digestive Signal",
                insight: digestSignal
            )
        )

        if rows.count < 3 {
            rows.append(
                DocumentValues.TopSignalRow(
                    signal: "Data Coverage",
                    insight: "Limited records were available, so confidence is conservative."
                )
            )
        }

        return Array(rows.prefix(4))
    }

    private static func confidenceBand(from detail: String?) -> String {
        guard let detail else { return "Moderate confidence" }
        let lower = detail.lowercased()

        if let extracted = extractConfidencePercent(from: lower) {
            if extracted >= 80 { return "High confidence" }
            if extracted >= 60 { return "Moderate confidence" }
            return "Early signal - needs more data"
        }

        if lower.contains("confidence 8") || lower.contains("confidence 9") || lower.contains("confidence 100") {
            return "High confidence"
        }
        if lower.contains("confidence 6") || lower.contains("confidence 7") {
            return "Moderate confidence"
        }
        return "Early signal - needs more data"
    }

    private static func extractConfidencePercent(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        let candidate = String(digits.prefix(3))
        guard let value = Int(candidate), (0...100).contains(value) else { return nil }
        return value
    }

    private static func clipped(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return "\(trimmed.prefix(limit))..."
    }

    private static func paddedLines(from source: [String], count: Int, fallback: String) -> [String] {
        let cleaned = source
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return Array(repeating: fallback, count: count) }
        if cleaned.count >= count { return Array(cleaned.prefix(count)) }
        return cleaned + Array(repeating: fallback, count: count - cleaned.count)
    }

    private static func formattedSteps(_ steps: Int) -> String {
        steps > 0 ? "\(steps)" : "0 (sync pending)"
    }

    @MainActor
    private static func recentMealRows(appState: AppState, now: Date) -> [DocumentValues.MealRow] {
        let windowStart = now.addingTimeInterval(-7 * 24 * 3600)
        guard
            let meals = try? appState.healthGraph.queryMeals(from: windowStart, to: now),
            !meals.isEmpty
        else {
            return mockRecentMeals()
        }

        let latestMeals = Array(meals.suffix(6).reversed())
        return latestMeals.map { meal in
            let mealName = meal.ingredients.first?.name ?? "Logged meal"
            let glycemicLoad = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
            return DocumentValues.MealRow(
                meal: mealName,
                source: mealSourceLabel(meal.source),
                glycemicLoad: String(format: "%.0f", glycemicLoad),
                impact: glucoseImpactSummary(appState: appState, meal: meal)
            )
        }
    }

    private static func mealSourceLabel(_ source: MealEvent.MealSource) -> String {
        switch source {
        case .rotimaticNext: return "Rotimatic NEXT"
        case .instantPot: return "Instant Pot"
        case .instacart: return "Instacart"
        case .doordash: return "DoorDash"
        case .manual: return "Manual Log"
        }
    }

    @MainActor
    private static func glucoseImpactSummary(appState: AppState, meal: MealEvent) -> String {
        let windowEnd = meal.timestamp.addingTimeInterval(2 * 3600)
        guard
            let readings = try? appState.healthGraph.queryGlucose(from: meal.timestamp, to: windowEnd),
            let baseline = readings.first?.glucoseMgDL
        else {
            return "Insufficient CGM window"
        }

        let peak = readings.map(\.glucoseMgDL).max() ?? baseline
        let delta = peak - baseline

        if delta >= 40 {
            return "High spike (+\(Int(delta.rounded())) mg/dL)"
        }
        if delta >= 20 {
            return "Moderate spike (+\(Int(delta.rounded())) mg/dL)"
        }
        if delta >= 10 {
            return "Mild rise (+\(Int(delta.rounded())) mg/dL)"
        }
        return "Flat response (+\(Int(delta.rounded())) mg/dL)"
    }

    private static func causalFindingRows(from explanations: [CausalExplanation]) -> [DocumentValues.CausalFindingRow] {
        guard !explanations.isEmpty else {
            return [
                DocumentValues.CausalFindingRow(
                    finding: "No strong causal chain returned",
                    detail: "Ask VITA another symptom question to generate evidence-backed findings.",
                    source: "Causality Engine"
                ),
            ]
        }

        return explanations.prefix(3).map { explanation in
            // Show the full causal chain as "A → B → C" — matches what the chat displays
            let chain = explanation.causalChain.isEmpty
                ? explanation.symptom
                : explanation.causalChain.joined(separator: " → ")
            let confidence = Int((explanation.confidence * 100).rounded())
            let source = inferSource(from: explanation)

            // Use the engine narrative as the detail; clip to 240 chars to fit comfortably
            let narrative = explanation.narrative.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = narrative.isEmpty
                ? "Confidence: \(confidence)%"
                : (narrative.count > 240 ? "\(narrative.prefix(240))…" : narrative) + "  [\(confidence)% confidence]"

            return DocumentValues.CausalFindingRow(
                finding: chain,
                detail: detail,
                source: source
            )
        }
    }

    private static func inferSource(from explanation: CausalExplanation) -> String {
        let haystack = ([explanation.symptom, explanation.narrative] + explanation.causalChain)
            .joined(separator: " ")
            .lowercased()

        if haystack.contains("doordash") { return "DoorDash" }
        if haystack.contains("instacart") { return "Instacart" }
        if haystack.contains("rotimatic") { return "Rotimatic NEXT" }
        if haystack.contains("instant pot") { return "Instant Pot" }
        if haystack.contains("screen") || haystack.contains("scroll") || haystack.contains("dopamine") {
            return "Screen Time"
        }
        if haystack.contains("sleep") { return "Sleep Analysis" }
        if haystack.contains("hrv") || haystack.contains("heart rate") { return "Apple Watch" }
        if haystack.contains("glucose") || haystack.contains("cgm") || haystack.contains("glycemic") {
            return "CGM"
        }
        if haystack.contains("aqi") || haystack.contains("pollen") || haystack.contains("environment") {
            return "Environment"
        }
        return "Causality Engine"
    }

    private static func recommendationRows(from counterfactuals: [Counterfactual]) -> [DocumentValues.RecommendationRow] {
        guard !counterfactuals.isEmpty else {
            return [
                DocumentValues.RecommendationRow(
                    rec: "Ask a more specific symptom question to generate targeted interventions."
                ),
            ]
        }

        return counterfactuals
            .sorted(by: { $0.impact > $1.impact })
            .prefix(3)
            .map { item in
                let impact = Int((item.impact * 100).rounded())
                let conf   = Int((item.confidence * 100).rounded())
                // Format exactly like the chat UI counterfactual card: description + impact + effort + confidence
                return DocumentValues.RecommendationRow(
                    rec: "\(item.description)  ·  Impact: \(impact)%  ·  Effort: \(item.effort.rawValue)  ·  Confidence: \(conf)%"
                )
            }
    }
}
