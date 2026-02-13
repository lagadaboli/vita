import Foundation
import VITACore

/// Layer 3: The Intentionality Tracker.
/// Classifies digital behavior into Active Work, Passive Consumption, and Stress Signals.
/// Computes the Dopamine Debt Score that feeds into the Causality Engine.
///
/// Future implementation will include:
/// - Screen Time API integration
/// - Calendar API integration
/// - Focus Mode detection
/// - App switch frequency tracking
public protocol IntentionalityTrackerProtocol: Sendable {
    /// Classify a behavioral event into its category.
    func classifyBehavior(
        appName: String,
        duration: TimeInterval,
        timestamp: Date
    ) async throws -> BehavioralEvent

    /// Compute the current dopamine debt score (0-100).
    func currentDopamineDebt() async throws -> Double

    /// Fetch behavioral events within a time window.
    func queryBehavior(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [BehavioralEvent]
}

/// Stub implementation — returns placeholder classifications.
public final class IntentionalityTracker: IntentionalityTrackerProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
    }

    public func classifyBehavior(
        appName: String,
        duration: TimeInterval,
        timestamp: Date
    ) async throws -> BehavioralEvent {
        // Stub: will use Screen Time API categories
        BehavioralEvent(
            timestamp: timestamp,
            duration: duration,
            category: .activeWork,
            appName: appName
        )
    }

    public func currentDopamineDebt() async throws -> Double {
        // Stub: will compute from real behavioral data
        0.0
    }

    public func queryBehavior(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [BehavioralEvent] {
        // Stub: will query from database
        []
    }
}
