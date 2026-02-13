import Foundation
import GRDB

/// Screen time / calendar event classification from Layer 3 (Intentionality Tracker).
/// Feeds into the Causality Engine for dopamine debt detection.
public struct BehavioralEvent: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var timestamp: Date
    public var duration: TimeInterval
    public var category: BehaviorCategory
    public var appName: String?
    public var dopamineDebtScore: Double?
    public var metadata: [String: String]?

    public init(
        id: Int64? = nil,
        timestamp: Date,
        duration: TimeInterval,
        category: BehaviorCategory,
        appName: String? = nil,
        dopamineDebtScore: Double? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.category = category
        self.appName = appName
        self.dopamineDebtScore = dopamineDebtScore
        self.metadata = metadata
    }
}

// MARK: - Classification

extension BehavioralEvent {
    public enum BehaviorCategory: String, Codable, Sendable, DatabaseValueConvertible {
        case activeWork = "active_work"
        case passiveConsumption = "passive_consumption"
        case stressSignal = "stress_signal"
        case exercise
        case rest
    }

    /// Calculate dopamine debt score (0-100) from behavioral metrics.
    ///
    /// Formula:
    /// ```
    /// dopamine_debt = (
    ///     0.4 * passive_screen_minutes_last_3h / 60 +
    ///     0.3 * app_switch_frequency_zscore +
    ///     0.2 * (1 - time_in_focus_mode_ratio) +
    ///     0.1 * late_night_screen_penalty
    /// ) * 100
    /// ```
    public static func computeDopamineDebt(
        passiveMinutesLast3Hours: Double,
        appSwitchFrequencyZScore: Double,
        focusModeRatio: Double,
        lateNightPenalty: Double
    ) -> Double {
        let raw = (
            0.4 * min(passiveMinutesLast3Hours / 60.0, 1.0) +
            0.3 * min(max(appSwitchFrequencyZScore, 0.0), 1.0) +
            0.2 * (1.0 - min(max(focusModeRatio, 0.0), 1.0)) +
            0.1 * min(max(lateNightPenalty, 0.0), 1.0)
        ) * 100.0
        return min(max(raw, 0.0), 100.0)
    }
}

// MARK: - GRDB Record

extension BehavioralEvent: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "behavioral_events"

    enum Columns: String, ColumnExpression {
        case id, timestamp, duration, category, appName, dopamineDebtScore, metadata
    }
}
