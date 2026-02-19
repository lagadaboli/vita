#if os(iOS)
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif
import Foundation
import VITACore

/// Tracks screen time using Apple's DeviceActivity/FamilyControls framework.
/// Monitors Screen Time threshold breaches for zombie scrolling detection across apps.
public final class ScreenTimeTracker: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph

    /// App Group identifier for sharing data with the DeviceActivityMonitor extension.
    public static let appGroupID = "group.com.vita.shared"

    /// UserDefaults keys written by the extension.
    public enum UserDefaultsKeys {
        public static let lastZombieDuration = "vita_zombie_duration_seconds"
        public static let lastZombieCategory = "vita_zombie_category_name"
        public static let lastZombieTimestamp = "vita_zombie_timestamp"
    }

    /// Threshold durations for zombie scrolling alerts.
    public enum Threshold {
        public static let warn: TimeInterval = 10 * 60       // 10 minutes
        public static let alert: TimeInterval = 20 * 60      // 20 minutes
        public static let critical: TimeInterval = 30 * 60   // 30 minutes
    }

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
    }

    #if os(iOS)
    /// Request Screen Time authorization.
    public func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    /// Start monitoring Screen Time with threshold events.
    public func startMonitoring() throws {
        let center = DeviceActivityCenter()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let warnEvent = DeviceActivityEvent(
            threshold: DateComponents(minute: 10)
        )
        let alertEvent = DeviceActivityEvent(
            threshold: DateComponents(minute: 20)
        )
        let criticalEvent = DeviceActivityEvent(
            threshold: DateComponents(minute: 30)
        )

        try center.startMonitoring(
            .init("vita.zombie.all_apps"),
            during: schedule,
            events: [
                .init("vita.zombie.warn"): warnEvent,
                .init("vita.zombie.alert"): alertEvent,
                .init("vita.zombie.critical"): criticalEvent,
            ]
        )
    }
    #endif

    /// Read zombie scrolling data written by the extension to shared UserDefaults.
    /// Returns a BehavioralEvent if data is available, nil otherwise.
    public func readZombieData() -> BehavioralEvent? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return nil }

        let duration = defaults.double(forKey: UserDefaultsKeys.lastZombieDuration)
        guard duration > 0 else { return nil }

        let categoryName = defaults.string(forKey: UserDefaultsKeys.lastZombieCategory) ?? "Screen Time"
        let timestamp: Date
        if let storedTimestamp = defaults.object(forKey: UserDefaultsKeys.lastZombieTimestamp) as? Date {
            timestamp = storedTimestamp
        } else {
            timestamp = Date()
        }

        return BehavioralEvent(
            timestamp: timestamp,
            duration: duration,
            category: .zombieScrolling,
            appName: categoryName,
            metadata: [
                "source": "screen_time",
                "context": categoryName,
                "category": categoryName,
                "duration_minutes": String(format: "%.1f", duration / 60.0),
            ]
        )
    }

    /// Read and ingest zombie scrolling data, clearing it afterwards.
    public func ingestZombieData() throws {
        guard var event = readZombieData() else { return }

        // Compute dopamine debt for this event
        let durationMinutes = event.duration / 60.0
        event.dopamineDebtScore = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: durationMinutes,
            appSwitchFrequencyZScore: 0.5, // Default moderate
            focusModeRatio: 0.0,           // Not in focus mode during zombie scroll
            lateNightPenalty: 0.0
        )

        try healthGraph.ingest(&event)

        // Clear the shared defaults
        if let defaults = UserDefaults(suiteName: Self.appGroupID) {
            defaults.removeObject(forKey: UserDefaultsKeys.lastZombieDuration)
            defaults.removeObject(forKey: UserDefaultsKeys.lastZombieCategory)
            defaults.removeObject(forKey: UserDefaultsKeys.lastZombieTimestamp)
        }
    }
}
