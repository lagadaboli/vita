import SwiftUI
import VITACore
import CausalityEngine
import HealthKitBridge
import EnvironmentBridge
import IntentionalityTracker

#if canImport(HealthKit)
import HealthKit
#endif

/// Central app state managing database, health graph, and causality engine.
@MainActor
@Observable
final class AppState {
    enum DataMode: String {
        case sampleData
        case live
    }

    let database: VITADatabase
    let healthGraph: HealthGraph
    let causalityEngine: MockCausalityEngine
    var isLoaded = false
    var loadError: String?
    var dataMode: DataMode = .live

    #if canImport(HealthKit)
    private var healthKitManager: HealthKitManager?
    private var hrvCollector: HRVCollector?
    private var heartRateCollector: HeartRateCollector?
    private var glucoseCollector: GlucoseCollector?
    private var sleepCollector: SleepCollector?
    private var stepCountCollector: StepCountCollector?
    #endif

    private var environmentBridge: EnvironmentBridge?
    private var screenTimeTracker: ScreenTimeTracker?

    init() {
        do {
            let db = try VITADatabase.inMemory()
            self.database = db
            self.healthGraph = HealthGraph(database: db)
            self.causalityEngine = MockCausalityEngine(database: db, healthGraph: healthGraph)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    /// Initialize all subsystems, falling back to sample data if unavailable.
    func initialize() async {
        guard !isLoaded else { return }

        var healthKitAvailable = false

        // 1. HealthKit
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            do {
                let manager = HealthKitManager(database: database)
                try await manager.requestAuthorization()
                self.healthKitManager = manager

                let hrv = HRVCollector(healthStore: manager.store, database: database, healthGraph: healthGraph)
                let hr = HeartRateCollector(healthStore: manager.store, database: database, healthGraph: healthGraph)
                let glucose = GlucoseCollector(healthStore: manager.store, database: database, healthGraph: healthGraph)
                let sleep = SleepCollector(healthStore: manager.store, database: database, healthGraph: healthGraph)
                let steps = StepCountCollector(healthStore: manager.store, database: database, healthGraph: healthGraph)

                try hrv.startObserving()
                try hr.startObserving()
                try glucose.startObserving()
                try sleep.startObserving()
                try steps.startObserving()

                // Best-effort background delivery. Live sync still works if this fails.
                try? await manager.enableBackgroundDelivery()

                // Perform initial sync immediately so existing Health data is shown on first launch.
                try? await hrv.performIncrementalSync()
                try? await hr.performIncrementalSync()
                try? await glucose.performIncrementalSync()
                try? await sleep.performIncrementalSync()
                try? await steps.performIncrementalSync()

                self.hrvCollector = hrv
                self.heartRateCollector = hr
                self.glucoseCollector = glucose
                self.sleepCollector = sleep
                self.stepCountCollector = steps

                healthKitAvailable = true
            } catch {
                loadError = "HealthKit setup failed: \(error.localizedDescription)"
            }
        }
        #endif

        // 2. Environment Bridge (always available — uses network + location)
        let envBridge = EnvironmentBridge(database: database, healthGraph: healthGraph)
        envBridge.startMonitoring()
        self.environmentBridge = envBridge

        // 3. Screen Time
        let tracker = ScreenTimeTracker(database: database, healthGraph: healthGraph)
        #if os(iOS)
        do {
            try await tracker.requestAuthorization()
            try tracker.startMonitoring()
        } catch {
            // Screen Time is non-critical; continue without it
            #if DEBUG
            print("[AppState] Screen Time setup failed: \(error.localizedDescription)")
            #endif
        }
        #endif
        self.screenTimeTracker = tracker

        // Fall back to sample data if HealthKit is unavailable
        if !healthKitAvailable {
            dataMode = .sampleData
            loadSampleData()
        }

        isLoaded = true
    }

    func loadSampleData() {
        do {
            let generator = SampleDataGenerator(database: database, healthGraph: healthGraph)
            try generator.generateAll()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
