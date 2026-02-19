import Foundation
import VITACore

/// Layer 1: The Consumption Bridge.
/// Ingests meal and grocery data from smart appliances (Rotimatic, Instant Pot)
/// and delivery services (Instacart, DoorDash).
public protocol ConsumptionBridgeProtocol: Sendable {
    /// Ingest a meal event from any consumption source.
    func ingestMeal(_ meal: MealEvent) async throws

    /// Resolve a grocery item name to its nutritional profile.
    func resolveIngredient(name: String) async throws -> MealEvent.Ingredient

    /// Fetch recent orders from a delivery service.
    func fetchRecentOrders(from source: MealEvent.MealSource) async throws -> [MealEvent]
}

public final class ConsumptionBridge: ConsumptionBridgeProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    let backendURL: URL

    private static let watermarkKey = "vita_sync_watermark_ms"

    public init(database: VITADatabase, healthGraph: HealthGraph, backendURL: URL) {
        self.database = database
        self.healthGraph = healthGraph
        self.backendURL = backendURL
    }

    public func ingestMeal(_ meal: MealEvent) async throws {
        var meal = meal
        try healthGraph.ingest(&meal)
    }

    public func resolveIngredient(name: String) async throws -> MealEvent.Ingredient {
        MealEvent.Ingredient(name: name)
    }

    public func fetchRecentOrders(from source: MealEvent.MealSource) async throws -> [MealEvent] {
        // Best-effort refresh of MCP-backed grocery sources before pulling sync events.
        await triggerGroceryFetch()

        let watermark = loadSyncWatermark()

        var components = URLComponents(
            url: backendURL.appendingPathComponent("api/v1/sync/pull"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "since_ms", value: "\(watermark)")]

        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SyncPullResponse.self, from: data)

        // Ingest all returned events regardless of source, return only the requested one.
        var matching: [MealEvent] = []
        for event in response.events {
            var meal = event.toMealEvent()
            try? healthGraph.ingest(&meal)
            if meal.source == source {
                matching.append(meal)
            }
        }

        if response.watermarkMs > watermark {
            UserDefaults.standard.set(response.watermarkMs, forKey: Self.watermarkKey)
        }

        return matching
    }

    private func loadSyncWatermark() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Self.watermarkKey)
        guard stored > 0 else { return 0 }

        // Database is currently in-memory; after relaunch the local timeline is empty
        // but UserDefaults persists. In that case, pull from 0 so mock/live events repopulate.
        let hasLocalMeals = (try? database.read { db in
            try MealEvent.fetchCount(db) > 0
        }) ?? false

        return hasLocalMeals ? stored : 0
    }

    private func triggerGroceryFetch() async {
        let url = backendURL.appendingPathComponent("api/v1/grocery/fetch")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            // Non-fatal; sync/pull still returns whatever data already exists server-side.
        }
    }
}

// MARK: - Private response types

private struct SyncPullResponse: Decodable {
    let events: [RemoteMealEvent]
    let watermarkMs: Int
    let hasMore: Bool
}

private struct RemoteMealEvent: Decodable {
    let timestampMs: Int
    let source: String
    let eventType: String
    let ingredients: [RemoteIngredient]
    let cookingMethod: String?
    let estimatedGlycemicLoad: Double?
    let bioavailabilityModifier: Double?
    let confidence: Double

    func toMealEvent() -> MealEvent {
        MealEvent(
            timestamp: Date(timeIntervalSince1970: Double(timestampMs) / 1000.0),
            source: MealEvent.MealSource(rawValue: source) ?? .manual,
            eventType: MealEvent.MealEventType(rawValue: eventType) ?? .mealDelivery,
            ingredients: ingredients.map { $0.toIngredient() },
            cookingMethod: cookingMethod,
            estimatedGlycemicLoad: estimatedGlycemicLoad,
            bioavailabilityModifier: bioavailabilityModifier,
            confidence: confidence
        )
    }
}

private struct RemoteIngredient: Decodable {
    let name: String
    let quantityGrams: Double?
    let quantityMl: Double?
    let glycemicIndex: Double?
    let type: String?

    func toIngredient() -> MealEvent.Ingredient {
        MealEvent.Ingredient(
            name: name,
            quantityGrams: quantityGrams,
            quantityML: quantityMl,
            glycemicIndex: glycemicIndex,
            type: type
        )
    }
}
