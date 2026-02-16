import Foundation
import GRDB

/// A consumption event from Layer 1 (Consumption Bridge).
/// Captures meal data with glycemic load calculation for the Causality Engine.
public struct MealEvent: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var timestamp: Date
    public var source: MealSource
    public var eventType: MealEventType
    public var ingredients: [Ingredient]
    public var cookingMethod: String?
    public var estimatedGlycemicLoad: Double?
    public var bioavailabilityModifier: Double?
    public var confidence: Double

    public init(
        id: Int64? = nil,
        timestamp: Date,
        source: MealSource,
        eventType: MealEventType = .mealPreparation,
        ingredients: [Ingredient] = [],
        cookingMethod: String? = nil,
        estimatedGlycemicLoad: Double? = nil,
        bioavailabilityModifier: Double? = nil,
        confidence: Double = 0.5
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.eventType = eventType
        self.ingredients = ingredients
        self.cookingMethod = cookingMethod
        self.estimatedGlycemicLoad = estimatedGlycemicLoad
        self.bioavailabilityModifier = bioavailabilityModifier
        self.confidence = confidence
    }
}

// MARK: - Nested Types

extension MealEvent {
    public enum MealSource: String, Codable, Sendable, DatabaseValueConvertible {
        case rotimaticNext = "rotimatic_next"
        case instantPot = "instant_pot"
        case instacart
        case doordash
        case manual
    }

    public enum MealEventType: String, Codable, Sendable, DatabaseValueConvertible {
        case mealPreparation = "meal_preparation"
        case mealDelivery = "meal_delivery"
        case groceryPurchase = "grocery_purchase"
        case manualLog = "manual_log"
    }

    public struct Ingredient: Codable, Sendable {
        public var name: String
        public var quantityGrams: Double?
        public var quantityML: Double?
        public var glycemicIndex: Double?
        public var type: String?

        public init(
            name: String,
            quantityGrams: Double? = nil,
            quantityML: Double? = nil,
            glycemicIndex: Double? = nil,
            type: String? = nil
        ) {
            self.name = name
            self.quantityGrams = quantityGrams
            self.quantityML = quantityML
            self.glycemicIndex = glycemicIndex
            self.type = type
        }
    }

    /// Compute glycemic load from ingredients.
    /// GL = Σ (GI × carb_g per serving) / 100
    public var computedGlycemicLoad: Double {
        ingredients.reduce(0.0) { total, ingredient in
            guard let gi = ingredient.glycemicIndex,
                  let grams = ingredient.quantityGrams else { return total }
            // Approximate: assume 70% of grain weight is available carbohydrate
            let carbGrams = grams * 0.7
            return total + (gi * carbGrams / 100.0)
        }
    }
}

// MARK: - GRDB Record

extension MealEvent: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "meal_events"

    enum Columns: String, ColumnExpression {
        case id, timestamp, source, eventType, ingredients
        case cookingMethod, estimatedGlycemicLoad, bioavailabilityModifier, confidence
    }
}
