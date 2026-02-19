import Foundation
import SwiftUI

@MainActor
@Observable
final class SkinHealthViewModel {

    // MARK: - State

    enum AnalysisState: Equatable {
        case idle
        case analyzing
        case complete
    }

    var state: AnalysisState = .idle
    var analysisResult: PerfectCorpService.AnalysisResult?
    var causalFindings: [CausalFinding] = []
    var recommendations: [String] = []
    var forecastPoints: [ForecastPoint] = []
    var hrvReadings: [HRVReading] = []

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

    func analyze() {
        state = .analyzing
        Task {
            let result = await PerfectCorpService.analyze()
            analysisResult  = result
            hrvReadings     = generateHRVReadings()
            causalFindings  = buildCausalFindings(for: result)
            recommendations = buildRecommendations(for: result)
            forecastPoints  = buildForecast(score: result.overallScore)
            state = .complete
        }
    }

    // MARK: - Causal reasoning

    private func buildCausalFindings(for result: PerfectCorpService.AnalysisResult) -> [CausalFinding] {
        result.conditions.flatMap { condition -> [CausalFinding] in
            switch condition.type {
            case .acne:        return acneFindings(severity: condition.severity)
            case .darkCircles: return darkCircleFindings(severity: condition.severity)
            case .redness:     return rednessFindings(severity: condition.severity)
            case .oiliness:    return oilinessFindings(severity: condition.severity)
            default:           return []
            }
        }
    }

    private func acneFindings(severity: Double) -> [CausalFinding] {
        let highGLMeals = ["Pizza Margherita", "Chole Bhature", "Pav Bhaji", "Sabudana Vada",
                           "Aloo Paratha", "Chicken Fried Rice"].shuffled()
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
                detail: "Slow-Cook mode detected in Instant Pot — ~60% lectin deactivation vs 95% with Pressure Cook; gut inflammation manifests on skin",
                source: "Instant Pot",
                icon: "waveform.path.ecg",
                severity: severity * 0.50
            ))
        }

        return findings
    }

    private func darkCircleFindings(severity: Double) -> [CausalFinding] {
        var findings: [CausalFinding] = []

        if Double.random(in: 0...1) < 0.78 {
            let duration = Int.random(in: 28...55)
            findings.append(CausalFinding(
                conditionType: .darkCircles,
                cause: "Zombie Scroll Session",
                detail: "\(duration)-min blue-light exposure before bed — suppresses melatonin by ~50%, increases periorbital fluid retention",
                source: "Screen Time",
                icon: "iphone.radiowaves.left.and.right",
                severity: severity * 0.90
            ))
        }

        findings.append(CausalFinding(
            conditionType: .darkCircles,
            cause: "Late Heavy Meal",
            detail: "DoorDash order after 10:30 PM — elevated post-meal insulin disrupts slow-wave sleep, reducing lymphatic drainage",
            source: "DoorDash",
            icon: "moon.fill",
            severity: severity * 0.70
        ))

        if Double.random(in: 0...1) < 0.60 {
            let avgHRV = Int.random(in: 32...42)
            findings.append(CausalFinding(
                conditionType: .darkCircles,
                cause: "HRV Suppression",
                detail: "Apple Watch HRV averaged \(avgHRV) ms (last 3 days) — low HRV correlates with impaired lymphatic drainage and periorbital puffiness",
                source: "Apple Watch",
                icon: "heart.fill",
                severity: severity * 0.65
            ))
        }

        return findings
    }

    private func rednessFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .redness,
                cause: "High UV Exposure",
                detail: "UV index 7.2 this week — UV-induced free radicals degrade collagen, increasing capillary visibility and skin reactivity",
                source: "Environment",
                icon: "sun.max.fill",
                severity: severity * 0.80
            ),
            CausalFinding(
                conditionType: .redness,
                cause: "Poor Air Quality",
                detail: "AQI 95 (Unhealthy for Sensitive Groups) — particulate matter triggers NF-κB inflammatory cascade, manifesting as facial redness",
                source: "Environment",
                icon: "aqi.medium",
                severity: severity * 0.55
            )
        ]
    }

    private func oilinessFindings(severity: Double) -> [CausalFinding] {
        [
            CausalFinding(
                conditionType: .oiliness,
                cause: "High-GI Grocery Items",
                detail: "Poha (GI 70) + Basmati rice in recent Instacart order — high-GI foods spike insulin, stimulating sebaceous glands in T-zone",
                source: "Instacart",
                icon: "cart.fill",
                severity: severity * 0.75
            ),
            CausalFinding(
                conditionType: .oiliness,
                cause: "Excess Dairy — mTORC1 Pathway",
                detail: "Paneer Butter Masala (DoorDash) — casein activates mTORC1, upregulating lipid synthesis in skin cells",
                source: "DoorDash",
                icon: "drop.fill",
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
            recs.append("Avoid DoorDash orders after 8 PM for 7 days")
            recs.append("Use Pressure Cook mode in Instant Pot — 95% lectin deactivation vs ~60% slow-cook")
        }
        if types.contains(.darkCircles) {
            recs.append("Set Screen Time limit: ≤30 min social media after 9 PM")
            recs.append("Move last meal before 7 PM — allows 3h digestion window before sleep")
        }
        if types.contains(.redness) {
            recs.append("Apply SPF 50 when UV index > 6 (currently 7.2)")
            recs.append("Check AQI before outdoor activity — current: 95 (Unhealthy)")
        }
        if types.contains(.oiliness) {
            recs.append("Replace basmati rice with quinoa (GI 53 vs 64) in weekly Instacart")
            recs.append("Reduce dairy to 1 serving/day for next 7 days")
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
