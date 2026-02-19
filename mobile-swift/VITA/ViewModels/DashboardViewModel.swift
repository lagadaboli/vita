import Foundation
import VITACore
import VITADesignSystem

enum DashboardMetric: String, CaseIterable, Hashable, Identifiable {
    case hrv
    case heartRate
    case sleep
    case glucose
    case weight
    case steps
    case dopamineDebt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hrv: return "HRV"
        case .heartRate: return "Heart Rate"
        case .sleep: return "Sleep"
        case .glucose: return "Glucose"
        case .weight: return "Weight"
        case .steps: return "Steps"
        case .dopamineDebt: return "Dopamine Debt"
        }
    }

    var unit: String {
        switch self {
        case .hrv: return "ms"
        case .heartRate: return "bpm"
        case .sleep: return "hrs"
        case .glucose: return "mg/dL"
        case .weight: return "kg"
        case .steps: return ""
        case .dopamineDebt: return "/100"
        }
    }

    var historyWindowLabel: String {
        switch self {
        case .glucose:
            return "Last 24 hours"
        case .weight:
            return "Last 14 days"
        default:
            return "Last 7 days"
        }
    }
}

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
    var currentWeight: Double = 0
    var weightTrend: TrendDirection = .stable
    var currentAQI: Int = 0

    var hrvHistory: [MetricHistoryPoint] = []
    var heartRateHistory: [MetricHistoryPoint] = []
    var sleepHistory: [MetricHistoryPoint] = []
    var glucoseHistory: [MetricHistoryPoint] = []
    var weightHistory: [MetricHistoryPoint] = []
    var stepsHistory: [MetricHistoryPoint] = []
    var dopamineDebtHistory: [MetricHistoryPoint] = []

    struct MetricHistoryPoint: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let value: Double
    }

    struct InsightData: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let message: String
        let severity: InsightSeverity
        let timestamp: Date
    }

    var hasAnyData: Bool {
        !glucoseReadings.isEmpty
            || currentHRV > 0
            || currentHR > 0
            || sleepHours > 0
            || steps > 0
            || currentWeight > 0
            || dopamineDebt > 0
    }

    func load(from appState: AppState) {
        let calendar = Calendar.current
        let now = Date()
        let sixHoursAgo = calendar.date(byAdding: .hour, value: -6, to: now) ?? now
        let dayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let dayStart = calendar.startOfDay(for: now)

        // Load glucose data (live values + chart history).
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
        } else {
            glucoseReadings = []
            currentGlucose = 0
            glucoseTrend = .stable
        }

        if let readings = try? appState.healthGraph.queryGlucose(from: dayAgo, to: now) {
            glucoseHistory = readings.map {
                MetricHistoryPoint(timestamp: $0.timestamp, value: $0.glucoseMgDL)
            }
        } else {
            glucoseHistory = []
        }

        // Load HRV (prefer watch-source samples when available).
        if let samples = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: weekAgo, to: now) {
            let preferredSamples = preferredWatchSamples(from: samples)
            hrvHistory = preferredSamples.map {
                MetricHistoryPoint(timestamp: $0.timestamp, value: $0.value)
            }

            if let last = preferredSamples.last {
                currentHRV = last.value
                if preferredSamples.count >= 2 {
                    let prev = preferredSamples[preferredSamples.count - 2].value
                    hrvTrend = last.value > prev + 3 ? .up : (last.value < prev - 3 ? .down : .stable)
                }
            } else {
                currentHRV = 0
                hrvTrend = .stable
            }
        } else {
            hrvHistory = []
            currentHRV = 0
            hrvTrend = .stable
        }

        // Load heart rate with fallback to resting heart rate.
        if let samples = fetchHeartRateSamples(from: appState, from: weekAgo, to: now) {
            let preferredSamples = preferredWatchSamples(from: samples)
            heartRateHistory = preferredSamples.map {
                MetricHistoryPoint(timestamp: $0.timestamp, value: $0.value)
            }
            currentHR = preferredSamples.last?.value ?? 0
        } else {
            heartRateHistory = []
            currentHR = 0
        }

        // Load sleep (sum asleep stages, not just one sample).
        let sleepLookbackStart = calendar.date(byAdding: .day, value: -8, to: now) ?? weekAgo
        if let samples = try? appState.healthGraph.querySamples(type: .sleepAnalysis, from: sleepLookbackStart, to: now) {
            let preferredSamples = preferredWatchSamples(from: samples)
            sleepHistory = buildDailySleepHistory(from: preferredSamples, from: weekAgo, to: now)
            sleepHours = sleepHistory.last(where: { $0.value > 0 })?.value ?? 0
        } else {
            sleepHistory = []
            sleepHours = 0
        }

        // Load steps (sum all today's samples to match Apple Health totals).
        if let samples = try? appState.healthGraph.querySamples(type: .stepCount, from: weekAgo, to: now) {
            let preferredSamples = preferredWatchSamples(from: samples)
            let todaySamples = preferredSamples.filter { $0.timestamp >= dayStart }
            steps = Int(todaySamples.reduce(0.0) { $0 + $1.value }.rounded())
            stepsHistory = buildDailyTotalHistory(from: preferredSamples, from: weekAgo, to: now)
        } else {
            steps = 0
            stepsHistory = []
        }

        // Load dopamine debt from behavior data.
        if let behaviors = try? appState.healthGraph.queryBehaviors(from: weekAgo, to: now), !behaviors.isEmpty {
            let sortedBehaviors = behaviors.sorted(by: { $0.timestamp < $1.timestamp })
            if let latest = sortedBehaviors.last {
                dopamineDebt = latest.dopamineDebtScore ?? BehavioralEvent.computeDopamineDebt(
                    passiveMinutesLast3Hours: latest.duration / 60.0,
                    appSwitchFrequencyZScore: 0.3,
                    focusModeRatio: 0.0,
                    lateNightPenalty: isLateNight(latest.timestamp) ? 1.0 : 0.0
                )
            }
            dopamineDebtHistory = buildDailyDopamineHistory(from: sortedBehaviors, from: weekAgo, to: now)
        } else {
            dopamineDebt = 0
            dopamineDebtHistory = []
        }

        // Load weight.
        if let weightSamples = try? appState.healthGraph.querySamples(type: .bodyWeight, from: twoWeeksAgo, to: now) {
            weightHistory = weightSamples.map {
                MetricHistoryPoint(timestamp: $0.timestamp, value: $0.value)
            }

            if let last = weightSamples.last {
                currentWeight = last.value
                if weightSamples.count >= 2 {
                    let prev = weightSamples[weightSamples.count - 2].value
                    if last.value > prev + 0.2 { weightTrend = .up }
                    else if last.value < prev - 0.2 { weightTrend = .down }
                    else { weightTrend = .stable }
                }
            } else {
                currentWeight = 0
                weightTrend = .stable
            }
        } else {
            weightHistory = []
            currentWeight = 0
            weightTrend = .stable
        }

        // Load environment (most recent AQI).
        if let conditions = try? appState.healthGraph.queryEnvironment(from: dayStart, to: now),
           let latest = conditions.last {
            currentAQI = latest.aqiUS
        } else {
            currentAQI = 0
        }

        computeHealthScore()
        generateInsights()
    }

    func history(for metric: DashboardMetric) -> [MetricHistoryPoint] {
        switch metric {
        case .hrv: return hrvHistory
        case .heartRate: return heartRateHistory
        case .sleep: return sleepHistory
        case .glucose: return glucoseHistory
        case .weight: return weightHistory
        case .steps: return stepsHistory
        case .dopamineDebt: return dopamineDebtHistory
        }
    }

    func formattedCurrentValue(for metric: DashboardMetric) -> String {
        switch metric {
        case .hrv:
            return "\(Int(currentHRV.rounded()))"
        case .heartRate:
            return "\(Int(currentHR.rounded()))"
        case .sleep:
            return String(format: "%.1f", sleepHours)
        case .glucose:
            return "\(Int(currentGlucose.rounded()))"
        case .weight:
            guard currentWeight > 0 else { return "--" }
            return String(format: "%.1f", currentWeight)
        case .steps:
            return "\(steps)"
        case .dopamineDebt:
            return "\(Int(dopamineDebt.rounded()))"
        }
    }

    func sourceLabel(for metric: DashboardMetric) -> String {
        switch metric {
        case .dopamineDebt:
            return "Apple Screen Time"
        case .glucose:
            return "Apple Health"
        default:
            return "Apple Health (Apple Watch preferred)"
        }
    }

    private func fetchHeartRateSamples(
        from appState: AppState,
        from startDate: Date,
        to endDate: Date
    ) -> [PhysiologicalSample]? {
        if let heartRate = try? appState.healthGraph.querySamples(type: .heartRate, from: startDate, to: endDate),
           !heartRate.isEmpty {
            return heartRate
        }

        if let resting = try? appState.healthGraph.querySamples(type: .restingHeartRate, from: startDate, to: endDate),
           !resting.isEmpty {
            return resting
        }

        return nil
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

        // AQI penalty
        if currentAQI > 100 { score -= Double(currentAQI - 100) * 0.1 }

        // Weight trend penalty (if trending up)
        if weightTrend == .up { score -= 3 }

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
        } else if currentGlucose < 72 && currentGlucose > 0 {
            insights.append(InsightData(
                icon: "chart.line.downtrend.xyaxis",
                title: "Low Glucose",
                message: "Glucose at \(Int(currentGlucose)) mg/dL — reactive hypoglycemia detected. Consider a small protein snack.",
                severity: .warning,
                timestamp: Date()
            ))
        }

        if currentHRV > 0, currentHRV < 40 {
            insights.append(InsightData(
                icon: "waveform.path.ecg",
                title: "Low HRV",
                message: "HRV at \(Int(currentHRV))ms is below your baseline. Your recovery is compromised.",
                severity: .warning,
                timestamp: Date().addingTimeInterval(-1800)
            ))
        }

        if sleepHours > 0, sleepHours < 7.0 {
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

        if currentAQI > 100 {
            insights.append(InsightData(
                icon: "aqi.medium",
                title: "Poor Air Quality",
                message: "AQI is \(currentAQI). Consider staying indoors and using an air purifier.",
                severity: currentAQI > 150 ? .alert : .warning,
                timestamp: Date()
            ))
        }

        if weightTrend == .up && currentWeight > 0 {
            insights.append(InsightData(
                icon: "scalemass",
                title: "Weight Trending Up",
                message: "Your weight is trending up at \(String(format: "%.1f", currentWeight)) kg. High GL meals may be contributing.",
                severity: .info,
                timestamp: Date().addingTimeInterval(-7200)
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

    private func preferredWatchSamples(from samples: [PhysiologicalSample]) -> [PhysiologicalSample] {
        let watchSamples = samples.filter(isWatchSample)
        return watchSamples.isEmpty ? samples : watchSamples
    }

    private func isWatchSample(_ sample: PhysiologicalSample) -> Bool {
        if sample.source == .appleWatch {
            return true
        }
        if sample.metadata?["is_watch_sample"] == "true" {
            return true
        }
        return false
    }

    private func isAsleepSample(_ sample: PhysiologicalSample) -> Bool {
        guard sample.metricType == .sleepAnalysis else { return false }
        guard let stage = sample.metadata?["stage"]?.lowercased() else {
            return true
        }

        switch stage {
        case "asleep", "core", "deep", "rem":
            return true
        default:
            return false
        }
    }

    private func buildDailyTotalHistory(
        from samples: [PhysiologicalSample],
        from startDate: Date,
        to endDate: Date
    ) -> [MetricHistoryPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.timestamp)
        }

        return dailyRange(from: startDate, to: endDate).map { day in
            let total = grouped[day, default: []].reduce(0.0) { $0 + $1.value }
            return MetricHistoryPoint(timestamp: day, value: total)
        }
    }

    private func buildDailySleepHistory(
        from samples: [PhysiologicalSample],
        from startDate: Date,
        to endDate: Date
    ) -> [MetricHistoryPoint] {
        let asleepSamples = samples.filter(isAsleepSample)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: asleepSamples) { sample in
            calendar.startOfDay(for: sample.timestamp)
        }

        return dailyRange(from: startDate, to: endDate).map { day in
            let minutes = grouped[day, default: []].reduce(0.0) { $0 + $1.value }
            return MetricHistoryPoint(timestamp: day, value: minutes / 60.0)
        }
    }

    private func buildDailyDopamineHistory(
        from behaviors: [BehavioralEvent],
        from startDate: Date,
        to endDate: Date
    ) -> [MetricHistoryPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: behaviors) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        return dailyRange(from: startDate, to: endDate).map { day in
            let events = grouped[day, default: []]
            let values = events.map { event in
                event.dopamineDebtScore ?? BehavioralEvent.computeDopamineDebt(
                    passiveMinutesLast3Hours: event.duration / 60.0,
                    appSwitchFrequencyZScore: 0.3,
                    focusModeRatio: 0.0,
                    lateNightPenalty: isLateNight(event.timestamp) ? 1.0 : 0.0
                )
            }
            let average = values.isEmpty ? 0.0 : values.reduce(0.0, +) / Double(values.count)
            return MetricHistoryPoint(timestamp: day, value: average)
        }
    }

    private func dailyRange(from startDate: Date, to endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        var dates: [Date] = []
        var cursor = start

        while cursor <= end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return dates
    }

    private func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 5
    }
}
