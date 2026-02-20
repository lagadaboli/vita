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
        let integrationEvents = loadIntegrationEvents(from: lookbackStart, to: now)

        // Meals (prefer integration history to keep timeline aligned with selected mock profile).
        if appendMealsFromIntegrationHistory(integrationEvents) == false,
           let meals = try? appState.healthGraph.queryMeals(from: lookbackStart, to: now) {
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

        // Behavior (prefer integration history so screen-time intensity matches selected profile).
        if appendBehaviorFromIntegrationHistory(integrationEvents) == false,
           let behaviors = try? appState.healthGraph.queryBehaviors(from: lookbackStart, to: now) {
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

        // Cross-source consistency rule:
        // Heavy daily screen-time should cap realistic sleep hours for the same day.
        events = applySleepScreenTimeConsistency(
            to: events,
            integrationEvents: integrationEvents,
            scenario: appState.selectedMockScenario
        )

        // Sort by timestamp descending
        events.sort { $0.timestamp > $1.timestamp }

        hasLoaded = true
    }

    private func loadIntegrationEvents(from start: Date, to end: Date) -> [IntegrationHistoryEvent] {
        guard let payload = IntegrationHistoryStore.load() else { return [] }
        return payload.events
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func appendMealsFromIntegrationHistory(_ integrationEvents: [IntegrationHistoryEvent]) -> Bool {
        let mealEvents = integrationEvents.filter {
            $0.category == "meal" || $0.category == "cooked_meal" || $0.category == "grocery" || $0.category == "meal_prep"
        }
        guard !mealEvents.isEmpty else { return false }

        for event in mealEvents.prefix(24) {
            let gl = event.notes
                .first(where: { $0.lowercased().contains("gl") })
                .flatMap(extractLeadingInt(from:))
            let detailSuffix = event.notes
                .first(where: { $0.lowercased().contains("spike") || $0.lowercased().contains("impact") })

            let detail = [event.item, detailSuffix].compactMap { $0 }.joined(separator: " · ")
            events.append(TimelineEvent(
                timestamp: event.timestamp,
                category: .meal,
                title: mealTitle(for: event),
                detail: detail,
                value: gl.map(String.init),
                unit: gl == nil ? nil : "GL",
                accentColor: mealAccentColor(gl: gl)
            ))
        }
        return true
    }

    private func appendBehaviorFromIntegrationHistory(_ integrationEvents: [IntegrationHistoryEvent]) -> Bool {
        let behaviorEvents = integrationEvents.filter {
            $0.category == "screen_time" || $0.category == "scrolling"
        }
        guard !behaviorEvents.isEmpty else { return false }

        for event in behaviorEvents.prefix(24) {
            if event.category == "screen_time" {
                let minutes = event.notes.first(where: { $0.lowercased().contains("min") }).flatMap(extractLeadingInt(from:))
                let pickups = event.notes.first(where: { $0.lowercased().contains("pickup") }).flatMap(extractLeadingInt(from:))
                let detail = pickups.map { "\(event.item) · \($0) pickups" } ?? event.item
                events.append(TimelineEvent(
                    timestamp: event.timestamp,
                    category: .behavior,
                    title: "Screen Time Session",
                    detail: detail,
                    value: minutes.map(String.init),
                    unit: minutes == nil ? nil : "min",
                    accentColor: (minutes ?? 0) >= 45 ? VITAColors.amber : VITAColors.teal
                ))
            } else {
                let duration = event.notes.first(where: { $0.lowercased().contains("min") }).flatMap(extractLeadingInt(from:))
                let ratio = event.notes.first(where: { $0.lowercased().contains("ratio") }).flatMap(extractLeadingInt(from:))
                let detail = ratio.map { "Impulse ratio \($0)%" } ?? "Passive browsing burst"
                events.append(TimelineEvent(
                    timestamp: event.timestamp,
                    category: .behavior,
                    title: "Zombie Scrolling",
                    detail: detail,
                    value: duration.map(String.init),
                    unit: duration == nil ? nil : "min",
                    accentColor: VITAColors.amber
                ))
            }
        }

        return true
    }

    private func applySleepScreenTimeConsistency(
        to sourceEvents: [TimelineEvent],
        integrationEvents: [IntegrationHistoryEvent],
        scenario: AppState.MockDataScenario
    ) -> [TimelineEvent] {
        let calendar = Calendar.current

        let dailyScreenMinutes = Dictionary(grouping: integrationEvents.filter { $0.category == "screen_time" }) {
            calendar.startOfDay(for: $0.timestamp)
        }.mapValues { dayEvents in
            dayEvents.reduce(0) { total, event in
                total + (event.notes.first(where: { $0.lowercased().contains("min") }).flatMap(extractLeadingInt(from:)) ?? 0)
            }
        }

        return sourceEvents.map { event in
            guard event.category == .sleep,
                  let value = event.value,
                  let originalHours = Double(value) else {
                return event
            }

            let day = calendar.startOfDay(for: event.timestamp)
            let screenHours = Double(dailyScreenMinutes[day, default: 0]) / 60.0
            var adjustedHours = originalHours

            if screenHours > 0 {
                let awakeReserveHours = 7.0
                let maxSleep = max(4.5, 24.0 - screenHours - awakeReserveHours)
                adjustedHours = min(adjustedHours, maxSleep)
            }

            switch scenario {
            case .screenTimeNotGood where screenHours >= 8:
                adjustedHours = min(adjustedHours, 6.0)
            case .allDataLooksGood where screenHours <= 4:
                adjustedHours = max(adjustedHours, 7.2)
            default:
                break
            }

            adjustedHours = min(max(adjustedHours, 4.5), 9.5)
            guard abs(adjustedHours - originalHours) > 0.05 else { return event }

            return TimelineEvent(
                timestamp: event.timestamp,
                category: .sleep,
                title: event.title,
                detail: adjustedHours < 7.0 ? "Below target (aligned to same-day screen load)" : "Within target range",
                value: String(format: "%.1f", adjustedHours),
                unit: "hrs",
                accentColor: adjustedHours < 7.0 ? VITAColors.amber : VITAColors.success
            )
        }
    }

    private func mealTitle(for event: IntegrationHistoryEvent) -> String {
        switch event.source {
        case "doordash":
            return "DoorDash Meal"
        case "instacart":
            return "Instacart Basket"
        case "instant_pot":
            return "Instant Pot Meal"
        case "rotimatic":
            return "Rotimatic Prep"
        default:
            return "Meal Event"
        }
    }

    private func mealAccentColor(gl: Int?) -> Color {
        guard let gl else { return VITAColors.teal }
        if gl < 20 { return VITAColors.success }
        if gl < 35 { return VITAColors.amber }
        return VITAColors.coral
    }

    private func extractLeadingInt(from text: String) -> Int? {
        let numbers = text.split { !$0.isNumber }
        guard let first = numbers.first else { return nil }
        return Int(first)
    }

    private func preferredWatchSamples(from samples: [PhysiologicalSample]) -> [PhysiologicalSample] {
        let watchSamples = samples.filter { sample in
            sample.source == .appleWatch || sample.metadata?["is_watch_sample"] == "true"
        }
        return watchSamples.isEmpty ? samples : watchSamples
    }
}
