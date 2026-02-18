import SwiftUI
import VITACore
import CausalityEngine
import HealthKitBridge
import ConsumptionBridge
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
    let causalityEngine: CausalityEngine
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
    private var consumptionBridge: ConsumptionBridge?

    /// Backend URL for mobile-to-Mac testing. Override via Info.plist `VITABackendURL`.
    private static let backendURL: URL = {
        if let configured = Bundle.main.object(
            forInfoDictionaryKey: "VITABackendURL"
        ) as? String,
            !configured.isEmpty,
            let url = URL(string: configured)
        {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }()

    /// On-device LLM service for narrative generation (Metal-accelerated).
    #if canImport(MLXLLM) && canImport(Metal)
    let llmService: MLXLLMService
    #endif

    init() {
        do {
            let db = try VITADatabase.inMemory()
            self.database = db
            self.healthGraph = HealthGraph(database: db)

            #if canImport(MLXLLM) && canImport(Metal)
            let llm = MLXLLMService()
            self.llmService = llm
            self.causalityEngine = CausalityEngine(database: db, healthGraph: healthGraph, llm: llm)
            #else
            self.causalityEngine = CausalityEngine(database: db, healthGraph: healthGraph)
            #endif
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

        // 4. Consumption Bridge — pull DoorDash (and other delivery) orders from backend.
        let bridge = ConsumptionBridge(
            database: database,
            healthGraph: healthGraph,
            backendURL: Self.backendURL
        )
        self.consumptionBridge = bridge
        await refreshDeliveryOrders()

        // Background-load the on-device LLM (non-blocking)
        #if canImport(MLXLLM) && canImport(Metal)
        Task.detached(priority: .background) { [llmService] in
            do {
                try await llmService.loadModel()
            } catch {
                #if DEBUG
                print("[AppState] LLM model load failed: \(error.localizedDescription)")
                #endif
            }
        }
        #endif

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

    func refreshDeliveryOrders() async {
        guard let bridge = consumptionBridge else { return }

        do {
            _ = try await bridge.fetchRecentOrders(from: .doordash)
        } catch {
            #if DEBUG
            print("[AppState] DoorDash sync failed: \(error.localizedDescription)")
            #endif
        }

        do {
            _ = try await bridge.fetchRecentOrders(from: .instacart)
        } catch {
            #if DEBUG
            print("[AppState] Instacart sync failed: \(error.localizedDescription)")
            #endif
        }
    }
}
