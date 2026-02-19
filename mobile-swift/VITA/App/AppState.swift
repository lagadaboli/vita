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

    enum ScreenTimeStatus: Equatable {
        case notConfigured
        case authorized
        case unavailable(String)
    }

    let database: VITADatabase
    let healthGraph: HealthGraph
    let causalityEngine: CausalityEngine
    var isLoaded = false
    var isHealthSyncing = false
    var loadError: String?
    var dataMode: DataMode = .live
    var lastHealthRefreshAt: Date?
    var screenTimeStatus: ScreenTimeStatus = .notConfigured

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

    /// Toggle Rotimatic mock sessions from Info.plist (default: enabled for dev).
    private static let rotimaticMockEnabled: Bool = {
        if let configured = Bundle.main.object(
            forInfoDictionaryKey: "VITAMockRotimaticEnabled"
        ) as? Bool {
            return configured
        }
        return true
    }()

    /// Toggle Instant Pot mock sessions from Info.plist (default: enabled for dev).
    private static let instantPotMockEnabled: Bool = {
        if let configured = Bundle.main.object(
            forInfoDictionaryKey: "VITAMockInstantPotEnabled"
        ) as? Bool {
            return configured
        }
        return true
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
        isHealthSyncing = true

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
                lastHealthRefreshAt = Date()

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
            screenTimeStatus = .authorized
            ingestPendingScreenTimeData()
        } catch {
            screenTimeStatus = .unavailable(error.localizedDescription)
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

        if Self.rotimaticMockEnabled {
            seedMockRotimaticSessionsIfNeeded()
        }
        if Self.instantPotMockEnabled {
            seedMockInstantPotProgramsIfNeeded()
        }

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

        isHealthSyncing = false
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

    private func seedMockRotimaticSessionsIfNeeded() {
        let now = Date()
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -7, to: now)
            ?? now.addingTimeInterval(-7 * 24 * 60 * 60)

        let hasRotimaticData = (try? healthGraph.queryMeals(from: lookbackStart, to: now)
            .contains(where: { $0.source == .rotimaticNext })) ?? false
        guard !hasRotimaticData else { return }

        let mockSessions: [MealEvent] = [
            MealEvent(
                timestamp: now.addingTimeInterval(-2.0 * 60 * 60),
                source: .rotimaticNext,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Whole Wheat Flour",
                        quantityGrams: 150,
                        glycemicIndex: 62,
                        type: "grain"
                    ),
                    MealEvent.Ingredient(name: "Water", quantityML: 95, type: "liquid")
                ],
                cookingMethod: "rotimatic_whole_wheat_standard",
                estimatedGlycemicLoad: 24,
                confidence: 0.92
            ),
            MealEvent(
                timestamp: now.addingTimeInterval(-27.0 * 60 * 60),
                source: .rotimaticNext,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Maida Flour",
                        quantityGrams: 120,
                        glycemicIndex: 78,
                        type: "grain"
                    ),
                    MealEvent.Ingredient(name: "Water", quantityML: 80, type: "liquid")
                ],
                cookingMethod: "rotimatic_maida_fast",
                estimatedGlycemicLoad: 38,
                confidence: 0.90
            ),
            MealEvent(
                timestamp: now.addingTimeInterval(-3.0 * 24 * 60 * 60),
                source: .rotimaticNext,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Multigrain Flour",
                        quantityGrams: 90,
                        glycemicIndex: 54,
                        type: "grain"
                    ),
                    MealEvent.Ingredient(name: "Water", quantityML: 60, type: "liquid")
                ],
                cookingMethod: "rotimatic_whole_wheat_multigrain",
                estimatedGlycemicLoad: 18,
                confidence: 0.93
            )
        ]

        for var session in mockSessions {
            try? healthGraph.ingest(&session)
        }
    }

    private func seedMockInstantPotProgramsIfNeeded() {
        let now = Date()
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -7, to: now)
            ?? now.addingTimeInterval(-7 * 24 * 60 * 60)

        let hasInstantPotData = (try? healthGraph.queryMeals(from: lookbackStart, to: now)
            .contains(where: { $0.source == .instantPot })) ?? false
        guard !hasInstantPotData else { return }

        let mockPrograms: [MealEvent] = [
            MealEvent(
                timestamp: now.addingTimeInterval(-4.0 * 60 * 60),
                source: .instantPot,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Chickpeas",
                        quantityGrams: 220,
                        glycemicIndex: 28,
                        type: "legume"
                    ),
                    MealEvent.Ingredient(
                        name: "Tomato",
                        quantityGrams: 120,
                        glycemicIndex: 15,
                        type: "vegetable"
                    )
                ],
                cookingMethod: "pressure_cook_high",
                estimatedGlycemicLoad: 16,
                bioavailabilityModifier: 1.24,
                confidence: 0.91
            ),
            MealEvent(
                timestamp: now.addingTimeInterval(-30.0 * 60 * 60),
                source: .instantPot,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Chicken Thigh",
                        quantityGrams: 260,
                        glycemicIndex: 0,
                        type: "protein"
                    ),
                    MealEvent.Ingredient(
                        name: "Brown Rice",
                        quantityGrams: 150,
                        glycemicIndex: 50,
                        type: "grain"
                    )
                ],
                cookingMethod: "slow_cook_low",
                estimatedGlycemicLoad: 21,
                bioavailabilityModifier: 1.06,
                confidence: 0.89
            ),
            MealEvent(
                timestamp: now.addingTimeInterval(-4.0 * 24 * 60 * 60),
                source: .instantPot,
                eventType: .mealPreparation,
                ingredients: [
                    MealEvent.Ingredient(
                        name: "Masoor Dal",
                        quantityGrams: 180,
                        glycemicIndex: 32,
                        type: "legume"
                    ),
                    MealEvent.Ingredient(
                        name: "Spinach",
                        quantityGrams: 90,
                        glycemicIndex: 15,
                        type: "vegetable"
                    )
                ],
                cookingMethod: "pressure_cook_medium",
                estimatedGlycemicLoad: 14,
                bioavailabilityModifier: 1.19,
                confidence: 0.93
            )
        ]

        for var program in mockPrograms {
            try? healthGraph.ingest(&program)
        }
    }

    func refreshDeliveryOrders() async {
        ingestPendingScreenTimeData()
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

    /// Force a foreground HealthKit sync so dashboard metrics match Apple Health as closely as possible.
    func refreshHealthData() async {
        isHealthSyncing = true
        defer { isHealthSyncing = false }

        #if canImport(HealthKit)
        guard healthKitManager != nil else {
            ingestPendingScreenTimeData()
            return
        }

        try? await hrvCollector?.performIncrementalSync()
        try? await heartRateCollector?.performIncrementalSync()
        try? await glucoseCollector?.performIncrementalSync()
        try? await sleepCollector?.performIncrementalSync()
        try? await stepCountCollector?.performIncrementalSync()
        lastHealthRefreshAt = Date()
        #endif

        ingestPendingScreenTimeData()
    }

    private func ingestPendingScreenTimeData() {
        guard let tracker = screenTimeTracker else { return }
        do {
            try tracker.ingestZombieData()
        } catch {
            #if DEBUG
            print("[AppState] Screen Time ingest failed: \(error.localizedDescription)")
            #endif
        }
    }
}
