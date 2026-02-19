import SwiftUI
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class TimelineViewModel {
    var events: [TimelineEvent] = []
    var selectedFilter = "All"
    var hasLoaded = false

    let filters = ["All", "Meals", "Glucose", "HRV", "Behavior", "Sleep"]

    struct TimelineEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: EventCategory
        let title: String
        let detail: String
        let value: String?
        let unit: String?
        let accentColor: Color

        enum EventCategory: String {
            case meal, glucose, hrv, heartRate, behavior, sleep
        }
    }

    var filteredEvents: [TimelineEvent] {
        guard selectedFilter != "All" else { return events }
        return events.filter { event in
            switch selectedFilter {
            case "Meals": return event.category == .meal
            case "Glucose": return event.category == .glucose
            case "HRV": return event.category == .hrv
            case "Behavior": return event.category == .behavior
            case "Sleep": return event.category == .sleep
            default: return true
            }
        }
    }

    var emptyStateTitle: String {
        if selectedFilter == "All" {
            return "No Timeline Data Yet"
        }
        return "No \(selectedFilter) Events Yet"
    }

    var emptyStateMessage: String {
        if selectedFilter == "All" {
            return "Once HealthKit and integrations sync, your events will appear here."
        }
        return "No \(selectedFilter.lowercased()) events were found in the last 30 days."
    }

    func load(from appState: AppState) {
        events = []
        let calendar = Calendar.current
        let now = Date()
        let lookbackStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        // Meals
        if let meals = try? appState.healthGraph.queryMeals(from: lookbackStart, to: now) {
            for meal in meals.suffix(24) {
                let source = meal.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                let ingredientNames = meal.ingredients.prefix(3).map(\.name).joined(separator: ", ")
                events.append(TimelineEvent(
                    timestamp: meal.timestamp,
                    category: .meal,
                    title: "\(source) Meal",
                    detail: ingredientNames,
                    value: "\(Int(gl))",
                    unit: "GL",
                    accentColor: VITAColors.teal
                ))
            }
        }

        // Glucose spikes/lows with fallback to latest readings when no spikes/lows exist.
        if let readings = try? appState.healthGraph.queryGlucose(from: lookbackStart, to: now) {
            let highReadings = readings.filter { $0.glucoseMgDL > 150 }
            let lowReadings = readings.filter { $0.glucoseMgDL < 72 }

            for reading in readings where reading.glucoseMgDL > 150 {
                events.append(TimelineEvent(
                    timestamp: reading.timestamp,
                    category: .glucose,
                    title: "Glucose Spike",
                    detail: reading.energyState == .crashing ? "Crash in progress" : "Post-meal spike",
                    value: "\(Int(reading.glucoseMgDL))",
                    unit: "mg/dL",
                    accentColor: VITAColors.glucoseColor(mgDL: reading.glucoseMgDL)
                ))
            }

            for reading in lowReadings {
                events.append(TimelineEvent(
                    timestamp: reading.timestamp,
                    category: .glucose,
                    title: "Low Glucose",
                    detail: "Reactive hypoglycemia",
                    value: "\(Int(reading.glucoseMgDL))",
                    unit: "mg/dL",
                    accentColor: VITAColors.glucoseLow
                ))
            }

            if highReadings.isEmpty && lowReadings.isEmpty {
                for reading in readings.suffix(12) {
                    events.append(TimelineEvent(
                        timestamp: reading.timestamp,
                        category: .glucose,
                        title: "Glucose Reading",
                        detail: reading.energyState == .stable ? "Stable trend" : "Monitoring trend",
                        value: "\(Int(reading.glucoseMgDL))",
                        unit: "mg/dL",
                        accentColor: VITAColors.glucoseColor(mgDL: reading.glucoseMgDL)
                    ))
                }
            }
        }

        // HRV readings (prefer watch source when available).
        if let samples = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: lookbackStart, to: now) {
            let sourceSamples = preferredWatchSamples(from: samples)
            for sample in sourceSamples.suffix(20) {
                events.append(TimelineEvent(
                    timestamp: sample.timestamp,
                    category: .hrv,
                    title: "HRV Reading",
                    detail: sample.value < 40 ? "Below baseline" : "Normal range",
                    value: "\(Int(sample.value))",
                    unit: "ms",
                    accentColor: sample.value < 40 ? VITAColors.coral : VITAColors.success
                ))
            }
        }

        // Screen Time + behavior events.
        if let behaviors = try? appState.healthGraph.queryBehaviors(from: lookbackStart, to: now) {
            for behavior in behaviors.suffix(20) {
                let durationMinutes = Int((behavior.duration / 60).rounded())
                let title: String
                switch behavior.category {
                case .zombieScrolling:
                    title = "Zombie Scrolling"
                case .passiveConsumption:
                    title = "Passive Consumption"
                case .activeWork:
                    title = "Focus Session"
                case .stressSignal:
                    title = "Stress Signal"
                case .exercise:
                    title = "Exercise Session"
                case .rest:
                    title = "Recovery Session"
                }

                let detail = behavior.appName ?? behavior.metadata?["context"] ?? "Behavioral pattern detected"
                let score = Int((behavior.dopamineDebtScore ?? 0).rounded())
                events.append(TimelineEvent(
                    timestamp: behavior.timestamp,
                    category: .behavior,
                    title: title,
                    detail: detail,
                    value: score > 0 ? "\(score)" : "\(durationMinutes)",
                    unit: score > 0 ? "/100" : "min",
                    accentColor: behavior.category == .zombieScrolling ? VITAColors.amber : VITAColors.teal
                ))
            }
        }

        // Sleep totals by day.
        if let samples = try? appState.healthGraph.querySamples(type: .sleepAnalysis, from: lookbackStart, to: now),
           !samples.isEmpty {
            let grouped = Dictionary(grouping: samples) { sample in
                calendar.startOfDay(for: sample.timestamp)
            }

            for day in grouped.keys.sorted().suffix(14) {
                guard let daySamples = grouped[day] else { continue }
                let totalMinutes = daySamples.reduce(0.0) { $0 + $1.value }
                guard totalMinutes > 0 else { continue }
                let hours = totalMinutes / 60.0
                events.append(TimelineEvent(
                    timestamp: day,
                    category: .sleep,
                    title: "Sleep",
                    detail: hours < 7.0 ? "Below target" : "Within target range",
                    value: String(format: "%.1f", hours),
                    unit: "hrs",
                    accentColor: hours < 7.0 ? VITAColors.amber : VITAColors.success
                ))
            }
        }

        // Sort by timestamp descending
        events.sort { $0.timestamp > $1.timestamp }

        hasLoaded = true
    }

    private func preferredWatchSamples(from samples: [PhysiologicalSample]) -> [PhysiologicalSample] {
        let watchSamples = samples.filter { sample in
            sample.source == .appleWatch || sample.metadata?["is_watch_sample"] == "true"
        }
        return watchSamples.isEmpty ? samples : watchSamples
    }
}
