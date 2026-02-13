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

    func load(from appState: AppState) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        if let meals = try? appState.healthGraph.queryMeals(from: weekAgo, to: Date()) {
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
        }
    }
}
