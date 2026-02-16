import Foundation
import GRDB

/// CGM-specific glucose reading with spike/crash classification.
/// Enriched beyond a raw PhysiologicalSample with feature extraction for the Causality Engine.
public struct GlucoseReading: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var glucoseMgDL: Double
    public var timestamp: Date
    public var trend: GlucoseTrend
    public var energyState: EnergyState
    public var source: PhysiologicalSample.DataSource
    public var relatedMealEventID: Int64?

    public init(
        id: Int64? = nil,
        glucoseMgDL: Double,
        timestamp: Date,
        trend: GlucoseTrend = .stable,
        energyState: EnergyState = .stable,
        source: PhysiologicalSample.DataSource = .cgmDexcom,
        relatedMealEventID: Int64? = nil
    ) {
        self.id = id
        self.glucoseMgDL = glucoseMgDL
        self.timestamp = timestamp
        self.trend = trend
        self.energyState = energyState
        self.source = source
        self.relatedMealEventID = relatedMealEventID
    }
}

// MARK: - Classification

extension GlucoseReading {
    /// Direction and magnitude of glucose change.
    public enum GlucoseTrend: String, Codable, Sendable, DatabaseValueConvertible {
        case rapidlyRising = "rapidly_rising"   // > +3 mg/dL/min
        case rising                              // +1 to +3 mg/dL/min
        case stable                              // -1 to +1 mg/dL/min
        case falling                             // -1 to -3 mg/dL/min
        case rapidlyFalling = "rapidly_falling"  // < -3 mg/dL/min
    }

    /// Metabolic energy state derived from glucose dynamics.
    /// Fed directly into the Causality Engine as ground truth.
    public enum EnergyState: String, Codable, Sendable, DatabaseValueConvertible {
        case stable         // Glucose 70-120 mg/dL, flat curve
        case rising         // Post-meal spike in progress
        case crashing       // Rapid decline >30 mg/dL from peak
        case reactiveLow    // Below baseline after a spike (reactive hypoglycemia)
    }

    /// Classify energy state from a glucose value and its recent delta.
    public static func classifyEnergyState(
        currentMgDL: Double,
        deltaFromPeak: Double,
        baselineMgDL: Double = 90.0
    ) -> EnergyState {
        if currentMgDL < baselineMgDL - 10 && deltaFromPeak < -30 {
            return .reactiveLow
        } else if deltaFromPeak < -30 {
            return .crashing
        } else if currentMgDL > 140 || deltaFromPeak > 20 {
            return .rising
        } else {
            return .stable
        }
    }
}

// MARK: - GRDB Record

extension GlucoseReading: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "glucose_readings"

    enum Columns: String, ColumnExpression {
        case id, glucoseMgDL, timestamp, trend, energyState, source, relatedMealEventID
    }
}
