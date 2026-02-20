import Foundation
import GRDB

/// A temporal edge connecting two nodes in the Health Graph.
/// Edges carry causal strength and temporal offset, enabling
/// the Causality Engine to reason about time-delayed relationships.
public struct HealthGraphEdge: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var sourceNodeID: String
    public var targetNodeID: String
    public var edgeType: EdgeType
    public var causalStrength: Double
    public var temporalOffsetSeconds: TimeInterval
    public var confidence: Double
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        sourceNodeID: String,
        targetNodeID: String,
        edgeType: EdgeType,
        causalStrength: Double = 0.0,
        temporalOffsetSeconds: TimeInterval = 0,
        confidence: Double = 0.5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.edgeType = edgeType
        self.causalStrength = causalStrength
        self.temporalOffsetSeconds = temporalOffsetSeconds
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

// MARK: - Edge Types

extension HealthGraphEdge {
    public enum EdgeType: String, Codable, Sendable, DatabaseValueConvertible {
        case mealToGlucose = "meal_to_glucose"
        case glucoseToHRV = "glucose_to_hrv"
        case glucoseToEnergy = "glucose_to_energy"
        case behaviorToHRV = "behavior_to_hrv"
        case mealToSleep = "meal_to_sleep"
        case behaviorToSleep = "behavior_to_sleep"
        case environmentToHRV = "environment_to_hrv"
        case environmentToSleep = "environment_to_sleep"
        case environmentToDigestion = "environment_to_digestion"
        case behaviorToMeal = "behavior_to_meal"
        // Skin analysis causal edges
        case mealToSkin = "meal_to_skin"           // High-GL meals → acne/oiliness
        case sleepToSkin = "sleep_to_skin"          // Poor sleep → dark circles
        case behaviorToSkin = "behavior_to_skin"    // Screen time → dark circles / oiliness
        case environmentToSkin = "environment_to_skin" // AQI/UV → redness
        case skinToSymptom = "skin_to_symptom"      // Skin conditions as systemic symptom signals
        case temporal
        case causal
    }

    /// Returns true if this edge represents a strong causal relationship.
    public var isStrongCausal: Bool {
        causalStrength >= 0.7 && confidence >= 0.6
    }

    /// Temporal offset as a human-readable string.
    public var temporalOffsetDescription: String {
        let minutes = Int(temporalOffsetSeconds / 60)
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)min" : "\(hours)h"
        }
    }
}

// MARK: - GRDB Record

extension HealthGraphEdge: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "causal_edges"

    enum Columns: String, ColumnExpression {
        case id, sourceNodeID, targetNodeID, edgeType
        case causalStrength, temporalOffsetSeconds, confidence, createdAt
    }
}
