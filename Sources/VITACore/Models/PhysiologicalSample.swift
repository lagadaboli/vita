import Foundation
import GRDB

/// Generic wrapper for any HealthKit quantity sample.
/// Serves as the base representation for all physiological data ingested from HealthKit.
public struct PhysiologicalSample: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var metricType: MetricType
    public var value: Double
    public var unit: String
    public var timestamp: Date
    public var source: DataSource
    public var metadata: [String: String]?

    public init(
        id: Int64? = nil,
        metricType: MetricType,
        value: Double,
        unit: String,
        timestamp: Date,
        source: DataSource = .appleWatch,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
    }
}

// MARK: - Enums

extension PhysiologicalSample {
    public enum MetricType: String, Codable, Sendable, DatabaseValueConvertible {
        case hrvSDNN = "hrv_sdnn"
        case restingHeartRate = "resting_hr"
        case sleepAnalysis = "sleep_analysis"
        case bloodGlucose = "blood_glucose"
        case bloodOxygen = "blood_oxygen"
        case respiratoryRate = "respiratory_rate"
        case activeEnergy = "active_energy"
        case stepCount = "step_count"
    }

    public enum DataSource: String, Codable, Sendable, DatabaseValueConvertible {
        case appleWatch
        case cgmDexcom
        case cgmLibre
        case manual
    }
}

// MARK: - GRDB Record

extension PhysiologicalSample: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "physiological_samples"

    enum Columns: String, ColumnExpression {
        case id, metricType, value, unit, timestamp, source, metadata
    }
}
