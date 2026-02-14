import Foundation
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class IntegrationsViewModel {
    // Apple Watch
    var watchSyncDate = Date().addingTimeInterval(-300)
    var watchHRV: Double = 52
    var watchHR: Double = 64
    var watchSteps: Int = 4800

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
        let durationMinutes: Double
        let itemsViewed: Int
        let itemsPurchased: Int
        let impulseRatio: Double
        var zombieScore: Int {
            Int(impulseRatio * 100)
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
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let now = Date()

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

        // Zombie scroll sessions (behavioral events with zombieScroll metadata)
        if let behaviors = try? appState.healthGraph.queryBehaviors(from: weekAgo, to: now) {
            zombieScrollSessions = behaviors
                .filter { $0.appName == "Instacart" && $0.metadata?["zombieScroll"] == "true" }
                .prefix(5)
                .map { event in
                    ZombieScrollSession(
                        timestamp: event.timestamp,
                        durationMinutes: event.duration / 60,
                        itemsViewed: Int(event.metadata?["itemsViewed"] ?? "0") ?? 0,
                        itemsPurchased: Int(event.metadata?["itemsPurchased"] ?? "0") ?? 0,
                        impulseRatio: Double(event.metadata?["impulseRatio"] ?? "0") ?? 0
                    )
                }
        }

        // Environment readings
        if let conditions = try? appState.healthGraph.queryEnvironment(from: weekAgo, to: now) {
            environmentReadings = conditions.prefix(7).map { condition in
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
}
