import Foundation
import VITACore

/// Layer 3: The Intentionality Tracker.
/// Classifies digital behavior into Active Work, Passive Consumption, Zombie Scrolling, and Stress Signals.
/// Computes the Dopamine Debt Score that feeds into the Causality Engine.
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

/// Real implementation backed by ScreenTimeTracker and the health graph database.
public final class IntentionalityTracker: IntentionalityTrackerProtocol, Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let screenTimeTracker: ScreenTimeTracker

    /// App categories classified as passive consumption (Shopping & Food apps).
    private static let foodShoppingApps: Set<String> = [
        "instacart", "doordash", "ubereats", "grubhub", "postmates",
        "amazon", "walmart", "target", "costco",
    ]

    /// App categories classified as passive social consumption.
    private static let socialApps: Set<String> = [
        "instagram", "tiktok", "twitter", "facebook", "reddit",
        "snapchat", "youtube",
    ]

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
        self.screenTimeTracker = ScreenTimeTracker(database: database, healthGraph: healthGraph)
    }

    public func classifyBehavior(
        appName: String,
        duration: TimeInterval,
        timestamp: Date
    ) async throws -> BehavioralEvent {
        let lowered = appName.lowercased()
        let category: BehavioralEvent.BehaviorCategory

        if Self.foodShoppingApps.contains(lowered) {
            // Food/shopping app browsing beyond 10 min → zombie scrolling
            category = duration > ScreenTimeTracker.Threshold.warn ? .zombieScrolling : .passiveConsumption
        } else if Self.socialApps.contains(lowered) {
            category = .passiveConsumption
        } else {
            category = .activeWork
        }

        return BehavioralEvent(
            timestamp: timestamp,
            duration: duration,
            category: category,
            appName: appName
        )
    }

    /// Compute current dopamine debt from behavioral events in the last 3 hours.
    public func currentDopamineDebt() async throws -> Double {
        let now = Date()
        let threeHoursAgo = now.addingTimeInterval(-3 * 60 * 60)

        let events = try healthGraph.queryBehaviors(from: threeHoursAgo, to: now)

        // Sum passive + zombie scrolling minutes
        let passiveMinutes = events
            .filter { $0.category == .passiveConsumption || $0.category == .zombieScrolling }
            .reduce(0.0) { $0 + $1.duration / 60.0 }

        // Also check for fresh Screen Time data
        if let zombieEvent = screenTimeTracker.readZombieData() {
            let zombieMinutes = zombieEvent.duration / 60.0
            let totalPassive = passiveMinutes + zombieMinutes

            return BehavioralEvent.computeDopamineDebt(
                passiveMinutesLast3Hours: totalPassive,
                appSwitchFrequencyZScore: 0.5,
                focusModeRatio: 0.0,
                lateNightPenalty: isLateNight(now) ? 0.8 : 0.0
            )
        }

        return BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: passiveMinutes,
            appSwitchFrequencyZScore: 0.3,
            focusModeRatio: 0.3,
            lateNightPenalty: isLateNight(now) ? 0.8 : 0.0
        )
    }

    public func queryBehavior(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [BehavioralEvent] {
        try healthGraph.queryBehaviors(from: startDate, to: endDate)
    }

    private func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 5
    }
}
