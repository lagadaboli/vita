import Foundation
import GRDB
import VITACore

/// Persists HKQueryAnchor per metric type for incremental sync.
/// Each HealthKit metric maintains its own anchor so we only process new samples.
public struct HealthKitSyncState: Codable, Sendable {
    public var metricType: String
    public var anchorData: Data?
    public var lastSyncDate: Date

    public init(metricType: String, anchorData: Data? = nil, lastSyncDate: Date = Date()) {
        self.metricType = metricType
        self.anchorData = anchorData
        self.lastSyncDate = lastSyncDate
    }
}

// MARK: - GRDB Record

extension HealthKitSyncState: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "sync_state"

    enum Columns: String, ColumnExpression {
        case metricType, anchorData, lastSyncDate
    }
}

// MARK: - Database Operations

extension HealthKitSyncState {
    /// Load the persisted sync state for a metric type.
    public static func load(for metricType: String, from database: VITADatabase) throws -> HealthKitSyncState? {
        try database.read { db in
            try HealthKitSyncState
                .filter(Columns.metricType == metricType)
                .fetchOne(db)
        }
    }

    /// Save or update the sync state for a metric type.
    public func save(to database: VITADatabase) throws {
        try database.write { db in
            try self.save(db)
        }
    }
}
