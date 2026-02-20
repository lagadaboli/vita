import Foundation
import GRDB

/// A persisted skin analysis result from the PerfectCorp YouCam API.
/// Each record represents one selfie scan and its detected conditions.
public struct SkinAnalysisRecord: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var timestamp: Date
    public var overallScore: Int          // 0–100, higher = better
    public var conditionsJSON: String     // JSON-encoded [SkinConditionSummary]
    public var apiSource: String          // "perfectcorp" or "demo"

    public init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        overallScore: Int,
        conditionsJSON: String,
        apiSource: String = "perfectcorp"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.overallScore = overallScore
        self.conditionsJSON = conditionsJSON
        self.apiSource = apiSource
    }
}

// MARK: - Embedded Condition Summary (Codable, no UIKit dependency)

extension SkinAnalysisRecord {
    /// Lightweight summary of a single skin condition — persisted as JSON.
    public struct ConditionSummary: Codable, Sendable {
        public let type: String       // e.g. "acne", "dark_circle_v2"
        public let rawScore: Double   // 0.0–1.0 from API
        public let uiScore: Int       // 0–100 from API
        public let severity: Double   // derived: rawScore clamped to 0–1

        public init(type: String, rawScore: Double, uiScore: Int) {
            self.type = type
            self.rawScore = rawScore
            self.uiScore = uiScore
            self.severity = min(max(rawScore, 0), 1)
        }
    }

    /// Decode conditions from stored JSON.
    public var conditions: [ConditionSummary] {
        let data = conditionsJSON.data(using: .utf8) ?? Data()
        return (try? JSONDecoder().decode([ConditionSummary].self, from: data)) ?? []
    }

    /// Encode a conditions array into JSON for storage.
    public static func encodeConditions(_ conditions: [ConditionSummary]) -> String {
        let data = (try? JSONEncoder().encode(conditions)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - GRDB Record

extension SkinAnalysisRecord: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "skin_analysis_results"

    enum Columns: String, ColumnExpression {
        case id, timestamp, overallScore, conditionsJSON, apiSource
    }
}
