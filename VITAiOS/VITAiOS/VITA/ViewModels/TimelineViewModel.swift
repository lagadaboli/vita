import SwiftUI
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class TimelineViewModel {
    var events: [TimelineEvent] = []
    var selectedFilter = "All"

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

    func load(from appState: AppState) {
        events = []
        let calendar = Calendar.current
        let now = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        // Meals
        if let meals = try? appState.healthGraph.queryMeals(from: twoDaysAgo, to: now) {
            for meal in meals {
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

        // Glucose spikes
        if let readings = try? appState.healthGraph.queryGlucose(from: twoDaysAgo, to: now) {
            // Find spikes (readings > 150)
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
            // Find crashes (readings < 72)
            for reading in readings where reading.glucoseMgDL < 72 {
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
        }

        // HRV readings
        if let samples = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: twoDaysAgo, to: now) {
            for sample in samples {
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

        // Sleep
        if let samples = try? appState.healthGraph.querySamples(type: .sleepAnalysis, from: twoDaysAgo, to: now) {
            if let first = samples.first {
                let hours = first.value / 60.0
                events.append(TimelineEvent(
                    timestamp: first.timestamp,
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

        // Limit to avoid overwhelming the view
        if events.count > 50 {
            events = Array(events.prefix(50))
        }
    }
}
