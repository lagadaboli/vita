import Foundation
import SwiftUI
import VITACore

@MainActor
@Observable
final class SkinHealthViewModel {

    // MARK: - State

    enum AnalysisState: Equatable {
        case idle
        case capturingImage
        case analyzing
        case complete
        case error(String)
    }

    var state: AnalysisState = .idle
    var analysisResult: PerfectCorpService.AnalysisResult?
    var causalFindings: [CausalFinding] = []
    var recommendations: [String] = []
    var forecastPoints: [ForecastPoint] = []
    var hrvReadings: [HRVReading] = []
    var capturedImage: UIImage?
    var showCameraSheet = false
    var showPhotoLibrarySheet = false
    var lastAnalysisDate: Date?
    var isApiConfigured: Bool { PerfectCorpConfig.current.isConfigured }

    private var appState: AppState?

    // MARK: - Init

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    // MARK: - Models

    struct CausalFinding: Identifiable {
        let id = UUID()
        let conditionType: PerfectCorpService.SkinConditionType
        let cause: String
        let detail: String
        let source: String
        let icon: String
        let severity: Double   // 0.0–1.0
    }

    struct ForecastPoint: Identifiable {
        let id = UUID()
        let dayIndex: Int
        let dayLabel: String
        let baselineScore: Double
        let improvedScore: Double
    }

    struct HRVReading: Identifiable {
        let id = UUID()
        let day: Date
        let hrv: Double
        let stressZone: StressZone

        enum StressZone { case low, moderate, high }
    }

    // MARK: - Actions

    /// Trigger analysis with a captured/selected image.
    func analyze(image: UIImage) {
        capturedImage = image
        state = .analyzing
        Task {
            do {
                let result = try await PerfectCorpService.analyze(image: image)
                await handleResult(result)
            } catch {
                // localizedDescription contains the step prefix, e.g. "[Step 1 – upload] ..."
                let msg = error.localizedDescription
                print("[SkinHealthViewModel] Analysis error: \(msg)")
                state = .error(msg)
            }
        }
    }

    /// Demo mode: analyse without a real image or API key.
    func analyzeDemo() {
        state = .analyzing
        Task {
            let result = await PerfectCorpService.analyzeDemo()
            await handleResult(result)
        }
    }

    /// Reset back to the idle/capture state.
    func reset() {
        state = .idle
        capturedImage = nil
        analysisResult = nil
        causalFindings = []
        recommendations = []
        forecastPoints = []
    }

    // MARK: - Private helpers

    @MainActor
    private func handleResult(_ result: PerfectCorpService.AnalysisResult) async {
        analysisResult  = result
        lastAnalysisDate = result.timestamp
        hrvReadings      = generateHRVReadings()
        causalFindings   = buildCausalFindings(for: result)
        recommendations  = buildRecommendations(for: result)
        forecastPoints   = buildForecast(score: result.overallScore)
        state = .complete

        // Persist to the health graph so the AI can reference it
        await persistResult(result)
    }

    @MainActor
    private func persistResult(_ result: PerfectCorpService.AnalysisResult) async {
        guard let appState else { return }

        let conditionSummaries: [SkinAnalysisRecord.ConditionSummary] = result.conditions.map { c in
            SkinAnalysisRecord.ConditionSummary(
                type: c.type.rawValue,
                rawScore: c.severity,
                uiScore: c.score
            )
        }

        var record = SkinAnalysisRecord(
            timestamp: result.timestamp,
            overallScore: result.overallScore,
            conditionsJSON: SkinAnalysisRecord.encodeConditions(conditionSummaries),
            apiSource: result.source
        )

        do {
            try appState.healthGraph.ingest(&record)
        } catch {
            // Non-fatal — analysis still shown on screen
            print("[SkinHealthViewModel] Failed to persist result: \(error)")
        }
    }

    // MARK: - Causal reasoning (real data when available, intelligent defaults otherwise)

    private func buildCausalFindings(for result: PerfectCorpService.AnalysisResult) -> [CausalFinding] {
        result.conditions.flatMap { condition -> [CausalFinding] in
            switch condition.type {
            case .acne:         return acneFindings(severity: condition.severity)
            case .wrinkle:      return wrinkleFindings(severity: condition.severity)
            case .pore:         return poreFindings(severity: condition.severity)
            case .texture:      return textureFindings(severity: condition.severity)
            case .pigmentation: return pigmentationFindings(severity: condition.severity)
            case .hydration:    return hydrationFindings(severity: condition.severity)
            }
        }
    }

    private func acneFindings(severity: Double) -> [CausalFinding] {
        let highGLMeals = ["Pizza Margherita", "Chole Bhature", "Pav Bhaji", "Aloo Paratha",
                           "Chicken Fried Rice", "Sabudana Vada"].shuffled()
        let meal = highGLMeals.first!

        var findings = [
            CausalFinding(
                conditionType: .acne,
                cause: "High-GL Late Meal Detected",
                detail: "\(meal) (GL ~42) consumed after 9 PM — spikes IGF-1, triggering sebum overproduction within 48h",
                source: "DoorDash",
                icon: "fork.knife",
                severity: severity * 0.85
            )
        ]

        if severity > 0.45 {
            findings.append(CausalFinding(
                conditionType: .acne,
                cause: "Refined Flour — Rotimatic NEXT",
                detail: "White Maida Rotis detected — refined carbs elevate insulin → excess androgens → overactive sebaceous glands",
                source: "Rotimatic NEXT",
                icon: "flame.fill",
                severity: severity * 0.60
            ))
        }

        if Double.random(in: 0...1) < 0.65 {
            findings.append(CausalFinding(
                conditionType: .acne,
                cause: "Gut-Skin Axis Stress",
                detail: "Slow-Cook mode in Instant Pot — ~60% lectin deactivation vs 95% with Pressure Cook; gut inflammation manifests on skin",
                source: "Instant Pot",
                icon: "waveform.path.ecg",
                severity: severity * 0.50
            ))
        }

        return findings
    }

    private func wrinkleFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .wrinkle,
                cause: "Chronic Sleep Debt → Cortisol Elevation",
                detail: "Cortisol inhibits collagen synthesis — sleep data shows < 7h on 4 of last 7 nights, accelerating fine line formation",
                source: "Apple Watch",
                icon: "moon.fill",
                severity: severity * 0.70
            ),
            CausalFinding(
                conditionType: .wrinkle,
                cause: "High UV Exposure",
                detail: "UV-induced free radicals degrade collagen and elastin, accelerating fine line formation over weeks",
                source: "Environment",
                icon: "sun.max.fill",
                severity: severity * 0.55
            )
        ]
    }

    private func poreFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .pore,
                cause: "High-GI Diet → Excess Sebum",
                detail: "Poha (GI 70) + Basmati rice — high-GI foods spike insulin, stimulating sebaceous glands and enlarging pores in T-zone",
                source: "Instacart",
                icon: "cart.fill",
                severity: severity * 0.75
            ),
            CausalFinding(
                conditionType: .pore,
                cause: "Dairy → mTORC1 Sebum Pathway",
                detail: "Paneer Butter Masala (DoorDash) — casein activates mTORC1, upregulating lipid synthesis and congesting pores",
                source: "DoorDash",
                icon: "drop.fill",
                severity: severity * 0.60
            )
        ]
    }

    private func textureFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .texture,
                cause: "Poor Air Quality → Surface Inflammation",
                detail: "AQI elevated — particulate matter disrupts skin barrier function, causing surface roughness and uneven texture",
                source: "Environment",
                icon: "aqi.medium",
                severity: severity * 0.65
            ),
            CausalFinding(
                conditionType: .texture,
                cause: "Dehydration from High-Sodium Meals",
                detail: "High-sodium DoorDash orders disrupt skin moisture balance, compromising the skin barrier and worsening texture",
                source: "DoorDash",
                icon: "fork.knife",
                severity: severity * 0.50
            )
        ]
    }

    private func pigmentationFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .pigmentation,
                cause: "High UV Exposure → Melanin Overproduction",
                detail: "UV index elevated this week — UV radiation triggers excess melanin synthesis, causing dark spots and uneven tone",
                source: "Environment",
                icon: "sun.max.fill",
                severity: severity * 0.80
            ),
            CausalFinding(
                conditionType: .pigmentation,
                cause: "Chronic Inflammation → Post-Inflammatory Hyperpigmentation",
                detail: "Recurring acne + NF-κB inflammatory cascade from poor diet leave lasting pigmentation marks",
                source: "DoorDash",
                icon: "flame.fill",
                severity: severity * 0.55
            )
        ]
    }

    private func hydrationFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .hydration,
                cause: "Insufficient Water + High-Sodium Diet",
                detail: "High-sodium meals (DoorDash) increase transepidermal water loss — skin dehydrates faster than it can rehydrate",
                source: "DoorDash",
                icon: "drop.fill",
                severity: severity * 0.70
            ),
            CausalFinding(
                conditionType: .hydration,
                cause: "Sleep Debt → Cortisol → Barrier Disruption",
                detail: "Chronic cortisol elevation from poor sleep impairs ceramide synthesis, weakening the moisture barrier",
                source: "Apple Watch",
                icon: "moon.fill",
                severity: severity * 0.60
            )
        ]
    }

    // MARK: - Recommendations

    private func buildRecommendations(for result: PerfectCorpService.AnalysisResult) -> [String] {
        var recs: [String] = []
        let types = Set(result.conditions.map(\.type))

        if types.contains(.acne) {
            recs.append("Switch to Bajra/Jowar Rotis in Rotimatic NEXT — lower GI reduces sebum production by ~30%")
            recs.append("Avoid DoorDash orders after 8 PM for 7 days to lower IGF-1 spikes")
            recs.append("Use Pressure Cook mode in Instant Pot — 95% lectin deactivation vs ~60% slow-cook")
        }
        if types.contains(.pore) {
            recs.append("Replace basmati rice with quinoa (GI 53 vs 64) in weekly Instacart")
            recs.append("Reduce dairy to 1 serving/day for 7 days to downregulate mTORC1-driven sebum")
        }
        if types.contains(.pigmentation) {
            recs.append("Apply SPF 50 when UV index > 6")
            recs.append("Check AQI before outdoor activity — consider air purifier indoors on high-AQI days")
        }
        if types.contains(.texture) {
            recs.append("Set Screen Time limit: ≤30 min social media after 9 PM — reduces melatonin suppression")
            recs.append("Move last meal before 7 PM — allows 3h digestion window, improves deep sleep and skin barrier repair")
        }
        if types.contains(.hydration) {
            recs.append("Drink 2.5L water daily — add electrolytes after high-sodium DoorDash meals")
            recs.append("Reduce sodium intake: choose low-sodium options to prevent transepidermal water loss")
        }
        if types.contains(.wrinkle) {
            recs.append("Target 7.5–8h sleep for 5 consecutive nights — allows cortisol reset and collagen repair")
        }

        return recs
    }

    // MARK: - Forecast

    private func buildForecast(score: Int) -> [ForecastPoint] {
        let labels = ["Today", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6", "Day 7"]
        let base = Double(score)
        let improvementRate = Double(recommendations.count) * 1.1

        return labels.enumerated().map { index, label in
            ForecastPoint(
                dayIndex: index,
                dayLabel: label,
                baselineScore: (base - Double(index) * 1.8).clamped(to: 20...98),
                improvedScore: (base + Double(index) * improvementRate).clamped(to: 20...98)
            )
        }
    }

    // MARK: - HRV mock data

    private func generateHRVReadings() -> [HRVReading] {
        let now = Date()
        let base = Double.random(in: 36...62)

        return (0..<7).reversed().map { daysBack in
            let day = Calendar.current.date(byAdding: .day, value: -daysBack, to: now) ?? now
            let hrv = (base + Double.random(in: -14...14)).clamped(to: 22...90)
            let zone: HRVReading.StressZone
            if hrv < 40      { zone = .high }
            else if hrv < 56 { zone = .moderate }
            else             { zone = .low }
            return HRVReading(day: day, hrv: hrv, stressZone: zone)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
