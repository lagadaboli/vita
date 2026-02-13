import Foundation
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class DashboardViewModel {
    var healthScore: Double = 0
    var glucoseReadings: [GlucoseDataPoint] = []
    var currentGlucose: Double = 0
    var currentHRV: Double = 0
    var currentHR: Double = 0
    var sleepHours: Double = 0
    var steps: Int = 0
    var dopamineDebt: Double = 0
    var glucoseTrend: TrendDirection = .stable
    var hrvTrend: TrendDirection = .stable
    var insights: [InsightData] = []

    struct InsightData: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let message: String
        let severity: InsightSeverity
        let timestamp: Date
    }

    func load(from appState: AppState) {
        let calendar = Calendar.current
        let now = Date()
        let sixHoursAgo = calendar.date(byAdding: .hour, value: -6, to: now) ?? now
        let dayStart = calendar.startOfDay(for: now)

        // Load glucose data
        if let readings = try? appState.healthGraph.queryGlucose(from: sixHoursAgo, to: now) {
            glucoseReadings = readings.map { GlucoseDataPoint(timestamp: $0.timestamp, value: $0.glucoseMgDL) }
            if let last = readings.last {
                currentGlucose = last.glucoseMgDL
                switch last.trend {
                case .rapidlyRising, .rising: glucoseTrend = .up
                case .falling, .rapidlyFalling: glucoseTrend = .down
                case .stable: glucoseTrend = .stable
                }
            }
        }

        // Load HRV
        if let samples = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: dayStart, to: now) {
            if let last = samples.last {
                currentHRV = last.value
                if samples.count >= 2 {
                    let prev = samples[samples.count - 2].value
                    hrvTrend = last.value > prev + 3 ? .up : (last.value < prev - 3 ? .down : .stable)
                }
            }
        }

        // Load HR
        if let samples = try? appState.healthGraph.querySamples(type: .restingHeartRate, from: dayStart, to: now),
           let last = samples.last {
            currentHR = last.value
        }

        // Load sleep
        if let samples = try? appState.healthGraph.querySamples(type: .sleepAnalysis, from: dayStart.addingTimeInterval(-3600), to: dayStart.addingTimeInterval(4 * 3600)),
           let first = samples.first {
            sleepHours = first.value / 60.0
        }

        // Load steps
        if let samples = try? appState.healthGraph.querySamples(type: .stepCount, from: dayStart, to: now),
           let last = samples.last {
            steps = Int(last.value)
        }

        // Load dopamine debt from behaviors
        let dayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        if (try? appState.healthGraph.queryMeals(from: dayAgo, to: now)) != nil {
            dopamineDebt = 35
        }

        // Calculate health score
        computeHealthScore()

        // Generate insights
        generateInsights()
    }

    private func computeHealthScore() {
        var score: Double = 100

        // Glucose penalty
        if currentGlucose > 140 { score -= (currentGlucose - 140) * 0.5 }
        if currentGlucose < 70 { score -= (70 - currentGlucose) * 0.8 }

        // HRV bonus/penalty (baseline ~55ms)
        if currentHRV < 40 { score -= (40 - currentHRV) * 0.8 }
        else if currentHRV > 60 { score += min((currentHRV - 60) * 0.3, 5) }

        // Sleep penalty
        if sleepHours < 7.0 { score -= (7.0 - sleepHours) * 8 }

        // Dopamine debt penalty
        score -= dopamineDebt * 0.15

        // HR penalty
        if currentHR > 72 { score -= (currentHR - 72) * 0.5 }

        healthScore = max(min(score, 100), 0)
    }

    private func generateInsights() {
        insights = []

        if currentGlucose > 160 {
            insights.append(InsightData(
                icon: "chart.line.uptrend.xyaxis",
                title: "Glucose Spike",
                message: "Your glucose hit \(Int(currentGlucose)) mg/dL. This may cause an energy crash in 30-60 minutes.",
                severity: .alert,
                timestamp: Date()
            ))
        } else if currentGlucose < 72 {
            insights.append(InsightData(
                icon: "chart.line.downtrend.xyaxis",
                title: "Low Glucose",
                message: "Glucose at \(Int(currentGlucose)) mg/dL — reactive hypoglycemia detected. Consider a small protein snack.",
                severity: .warning,
                timestamp: Date()
            ))
        }

        if currentHRV < 40 {
            insights.append(InsightData(
                icon: "waveform.path.ecg",
                title: "Low HRV",
                message: "HRV at \(Int(currentHRV))ms is below your baseline. Your recovery is compromised.",
                severity: .warning,
                timestamp: Date().addingTimeInterval(-1800)
            ))
        }

        if sleepHours < 7.0 && sleepHours > 0 {
            insights.append(InsightData(
                icon: "moon.zzz",
                title: "Sleep Deficit",
                message: "Only \(String(format: "%.1f", sleepHours))h of sleep last night. Aim for 7.5+ hours.",
                severity: .warning,
                timestamp: Date().addingTimeInterval(-3600)
            ))
        }

        if dopamineDebt > 60 {
            insights.append(InsightData(
                icon: "brain.head.profile",
                title: "High Dopamine Debt",
                message: "Excessive passive screen time detected. Consider a focus mode block.",
                severity: .alert,
                timestamp: Date().addingTimeInterval(-900)
            ))
        }

        if insights.isEmpty {
            insights.append(InsightData(
                icon: "checkmark.seal",
                title: "Looking Good",
                message: "Your metrics are within healthy ranges. Keep it up!",
                severity: .positive,
                timestamp: Date()
            ))
        }
    }
}
