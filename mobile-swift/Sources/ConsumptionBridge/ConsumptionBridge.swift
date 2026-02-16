import Foundation
import VITACore

/// Layer 1: The Consumption Bridge.
/// Ingests meal and grocery data from smart appliances (Rotimatic, Instant Pot)
/// and delivery services (Instacart, DoorDash).
///
/// Future implementation will include:
/// - Rotimatic NEXT local API integration
/// - Instant Pot Pro Plus BLE GATT ingestion
/// - Virtual Receipt Parser for Instacart/DoorDash
/// - USDA FoodData Central ingredient resolution
public protocol ConsumptionBridgeProtocol: Sendable {
    /// Ingest a meal event from any consumption source.
    func ingestMeal(_ meal: MealEvent) async throws

    /// Resolve a grocery item name to its nutritional profile.
    func resolveIngredient(name: String) async throws -> MealEvent.Ingredient

    /// Fetch recent orders from a delivery service.
    func fetchRecentOrders(from source: MealEvent.MealSource) async throws -> [MealEvent]
}

/// Stub implementation — returns placeholder data.
public final class ConsumptionBridge: ConsumptionBridgeProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
    }

    public func ingestMeal(_ meal: MealEvent) async throws {
        var meal = meal
        try healthGraph.ingest(&meal)
    }

    public func resolveIngredient(name: String) async throws -> MealEvent.Ingredient {
        // Stub: will integrate USDA FoodData Central API
        MealEvent.Ingredient(name: name)
    }

    public func fetchRecentOrders(from source: MealEvent.MealSource) async throws -> [MealEvent] {
        // Stub: will integrate with Instacart/DoorDash scraping agent
        []
    }
}
