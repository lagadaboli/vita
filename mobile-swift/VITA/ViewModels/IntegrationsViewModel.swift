import Foundation
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class IntegrationsViewModel {
    // Apple Watch
    var watchSyncDate = Date.distantPast
    var watchHRV: Double = 0
    var watchHR: Double = 0
    var watchSteps: Int = 0
    var watchConnectionStatus: ConnectionStatus = .syncing
    var watchConnectionDetail: String = "Checking status..."
    var screenTimeStatusMessage: String = ""
    var isScreenTimeAuthorized = false

    // DoorDash orders
    var doordashOrders: [DoorDashOrder] = []

    // Rotimatic sessions
    var rotimaticSessions: [RotimaticSession] = []

    // Instant Pot programs
    var instantPotPrograms: [InstantPotProgram] = []

    // Instacart orders
    var instacartOrders: [InstacartOrder] = []

    // Body scale / weight
    var weightReadings: [WeightReading] = []

    // Zombie scrolling sessions
    var zombieScrollSessions: [ZombieScrollSession] = []

    // Environment readings
    var environmentReadings: [EnvironmentReading] = []

    struct DoorDashOrder: Identifiable {
        let id = UUID()
        let name: String
        let timestamp: Date
        let glycemicLoad: Double
        let ingredients: [String]
        let glucoseImpact: String
    }

    struct RotimaticSession: Identifiable {
        let id = UUID()
        let flourType: String
        let count: Int
        let timestamp: Date
        let glycemicLoad: Double
        let glucoseImpact: String
    }

    struct InstantPotProgram: Identifiable {
        let id = UUID()
        let recipe: String
        let mode: String
        let timestamp: Date
        let bioavailability: Double
        let note: String
    }

    struct InstacartOrder: Identifiable {
        let id = UUID()
        let label: String
        let timestamp: Date
        let items: [InstacartItem]
        let totalGL: Double
        let healthScore: Int
    }

    struct InstacartItem: Identifiable {
        let id = UUID()
        let name: String
        let glycemicIndex: Double?
    }

    struct WeightReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let weightKg: Double
        let delta: Double?
    }

    struct ZombieScrollSession: Identifiable {
        let id = UUID()
        let timestamp: Date
        let appName: String
        let context: String
        let source: String
        let durationMinutes: Double
        let dopamineDebtScore: Double
        var zombieScore: Int {
            Int(min(max(dopamineDebtScore, 0.0), 100.0))
        }
    }

    struct EnvironmentReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let temperatureCelsius: Double
        let humidity: Double
        let aqiUS: Int
        let uvIndex: Double
        let pollenIndex: Int
        let healthImpact: String
    }

    func load(from appState: AppState) {
        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        switch appState.screenTimeStatus {
        case .authorized:
            isScreenTimeAuthorized = true
            screenTimeStatusMessage = "Screen Time monitoring is active."
        case .unavailable(let reason):
            isScreenTimeAuthorized = false
            screenTimeStatusMessage = "Screen Time access unavailable: \(reason). Check Screen Time + Family Controls permissions."
        case .notConfigured:
            isScreenTimeAuthorized = false
            screenTimeStatusMessage = "Screen Time monitoring is not configured."
        }

        // Apple Watch connectivity status.
        #if canImport(WatchConnectivity)
        let watchStatus = WatchConnectivityBridge.shared.connectionStatus()
        if watchStatus.isSupported {
            if watchStatus.isPaired {
                if watchStatus.isWatchAppInstalled {
                    watchConnectionStatus = watchStatus.isReachable ? .connected : .syncing
                    watchConnectionDetail = watchStatus.isReachable
                        ? "Paired and reachable"
                        : "Paired, app installed"
                } else {
                    watchConnectionStatus = .notConfigured
                    watchConnectionDetail = "Watch app not installed"
                }
            } else {
                watchConnectionStatus = .disconnected
                watchConnectionDetail = "No paired Apple Watch"
            }
        } else {
            watchConnectionStatus = .notConfigured
            watchConnectionDetail = "Watch connectivity unavailable"
        }
        #else
        watchConnectionStatus = .notConfigured
        watchConnectionDetail = "Watch connectivity unavailable"
        #endif

        // Apple Watch / HealthKit-backed metrics.
        var latestWatchSync: Date?

        if let hrvSamples = try? appState.healthGraph.querySamples(type: .hrvSDNN, from: weekAgo, to: now) {
            let preferredSamples = preferredWatchSamples(from: hrvSamples)
            if let latest = preferredSamples.last {
                watchHRV = latest.value
                latestWatchSync = maxDate(latestWatchSync, latest.timestamp)
            }
        }

        if let hrSamples = fetchHeartRateSamples(from: appState, from: weekAgo, to: now) {
            let preferredSamples = preferredWatchSamples(from: hrSamples)
            if let latest = preferredSamples.last {
                watchHR = latest.value
                latestWatchSync = maxDate(latestWatchSync, latest.timestamp)
            }
        }

        if let stepSamples = try? appState.healthGraph.querySamples(type: .stepCount, from: dayStart, to: now),
           !stepSamples.isEmpty {
            let preferredSamples = preferredWatchSamples(from: stepSamples)
            watchSteps = Int(preferredSamples.reduce(0.0) { $0 + $1.value }.rounded())
            latestWatchSync = maxDate(latestWatchSync, preferredSamples.last?.timestamp)
        }

        if let latestWatchSync {
            watchSyncDate = latestWatchSync
        }

        if let meals = try? appState.healthGraph.queryMeals(from: weekAgo, to: now) {
            doordashOrders = meals.filter { $0.source == .doordash }.prefix(5).map { meal in
                let ingredientNames = meal.ingredients.map(\.name)
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                let impact: String
                if gl > 35 { impact = "High spike expected" }
                else if gl > 20 { impact = "Moderate spike" }
                else { impact = "Minimal impact" }

                return DoorDashOrder(
                    name: ingredientNames.first ?? "Order",
                    timestamp: meal.timestamp,
                    glycemicLoad: gl,
                    ingredients: ingredientNames,
                    glucoseImpact: impact
                )
            }

            rotimaticSessions = meals.filter { $0.source == .rotimaticNext }.prefix(5).map { meal in
                let isWholeWheat = meal.cookingMethod?.contains("whole_wheat") ?? false
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                return RotimaticSession(
                    flourType: isWholeWheat ? "Whole Wheat" : "White (Maida)",
                    count: max(1, Int(meal.ingredients.first(where: { $0.type == "grain" })?.quantityGrams ?? 100) / 30),
                    timestamp: meal.timestamp,
                    glycemicLoad: gl,
                    glucoseImpact: isWholeWheat ? "Moderate, steady curve" : "Sharp spike + crash"
                )
            }

            instantPotPrograms = meals.filter { $0.source == .instantPot }.prefix(5).map { meal in
                let isPressure = meal.cookingMethod?.contains("pressure") ?? false
                return InstantPotProgram(
                    recipe: meal.ingredients.first?.name ?? "Recipe",
                    mode: isPressure ? "Pressure Cook" : "Slow Cook",
                    timestamp: meal.timestamp,
                    bioavailability: meal.bioavailabilityModifier ?? 1.0,
                    note: isPressure ? "95% lectin deactivation" : "~60% lectin deactivation — consider pressure cook"
                )
            }

            // Instacart orders
            instacartOrders = meals.filter { $0.source == .instacart }.prefix(5).map { meal in
                let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
                let score: Int
                if gl < 20 { score = 85 }
                else if gl < 35 { score = 60 }
                else { score = 35 }

                return InstacartOrder(
                    label: meal.ingredients.first?.name ?? "Grocery Order",
                    timestamp: meal.timestamp,
                    items: meal.ingredients.map { ing in
                        InstacartItem(name: ing.name, glycemicIndex: ing.glycemicIndex)
                    },
                    totalGL: gl,
                    healthScore: score
                )
            }
        }

        // Weight readings
        if let samples = try? appState.healthGraph.querySamples(type: .bodyWeight, from: weekAgo, to: now) {
            var readings: [WeightReading] = []
            for (index, sample) in samples.enumerated() {
                let delta: Double? = index > 0 ? sample.value - samples[index - 1].value : nil
                readings.append(WeightReading(
                    timestamp: sample.timestamp,
                    weightKg: sample.value,
                    delta: delta
                ))
            }
            weightReadings = readings
        }

        // Zombie scrolling sessions from Screen Time and behavior classifier.
        if let behaviors = try? appState.healthGraph.queryBehaviors(from: weekAgo, to: now) {
            zombieScrollSessions = behaviors
                .filter { event in
                    if event.category == .zombieScrolling {
                        return true
                    }
                    return event.metadata?["zombieScroll"] == "true"
                }
                .suffix(5)
                .map { event in
                    let durationMinutes = max(
                        event.duration / 60.0,
                        Double(event.metadata?["duration_minutes"] ?? "") ?? 0.0
                    )
                    let appName = event.appName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedApp = (appName?.isEmpty == false) ? appName! : "Unknown App"
                    let context = event.metadata?["context"]
                        ?? event.metadata?["category"]
                        ?? "Cross-app Screen Time"
                    let source = event.metadata?["source"] == "screen_time"
                        ? "Screen Time"
                        : "Behavioral Pattern"
                    let score = event.dopamineDebtScore ?? BehavioralEvent.computeDopamineDebt(
                        passiveMinutesLast3Hours: durationMinutes,
                        appSwitchFrequencyZScore: 0.4,
                        focusModeRatio: 0.0,
                        lateNightPenalty: isLateNight(event.timestamp) ? 1.0 : 0.0
                    )

                    return ZombieScrollSession(
                        timestamp: event.timestamp,
                        appName: resolvedApp,
                        context: context,
                        source: source,
                        durationMinutes: durationMinutes,
                        dopamineDebtScore: score
                    )
                }
                .sorted(by: { $0.timestamp > $1.timestamp })
        }

        // Environment readings
        if let conditions = try? appState.healthGraph.queryEnvironment(from: weekAgo, to: now) {
            environmentReadings = conditions.suffix(7).map { condition in
                let risks = condition.healthRisks
                let impact: String
                if risks.isEmpty {
                    impact = "No significant health risks"
                } else {
                    let riskLabels = risks.map { risk -> String in
                        switch risk {
                        case .highAQI: return "Poor air quality"
                        case .extremeHeat: return "Extreme heat"
                        case .extremeCold: return "Cold stress"
                        case .highPollen: return "High pollen"
                        case .highHumidity: return "High humidity"
                        case .highUV: return "High UV exposure"
                        }
                    }
                    impact = riskLabels.joined(separator: ", ")
                }

                return EnvironmentReading(
                    timestamp: condition.timestamp,
                    temperatureCelsius: condition.temperatureCelsius,
                    humidity: condition.humidity,
                    aqiUS: condition.aqiUS,
                    uvIndex: condition.uvIndex,
                    pollenIndex: condition.pollenIndex,
                    healthImpact: impact
                )
            }
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

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return max(l, r)
        case (nil, let r?):
            return r
        case (let l?, nil):
            return l
        default:
            return nil
        }
    }

    private func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 5
    }
}
