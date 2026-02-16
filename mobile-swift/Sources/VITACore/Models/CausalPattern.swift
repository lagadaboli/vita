import Foundation
import GRDB

/// A cloud-safe, anonymized causality pattern.
/// This is the ONLY data that may leave the device — contains no PII,
/// no raw values, no timestamps, and no food names.
public struct CausalPattern: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var pattern: String
    public var strength: Double
    public var observationCount: Int
    public var demographicBucket: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: Int64? = nil,
        pattern: String,
        strength: Double,
        observationCount: Int = 1,
        demographicBucket: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pattern = pattern
        self.strength = strength
        self.observationCount = observationCount
        self.demographicBucket = demographicBucket
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns true if this pattern meets the threshold for cloud sync.
    /// Requires sufficient observations to prevent de-anonymization via uniqueness.
    public var isCloudSyncEligible: Bool {
        observationCount >= 5 && strength >= 0.6
    }
}

// MARK: - GRDB Record

extension CausalPattern: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "causal_patterns"

    enum Columns: String, ColumnExpression {
        case id, pattern, strength, observationCount
        case demographicBucket, createdAt, updatedAt
    }
}
