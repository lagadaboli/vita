#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Collects sleep stage data from HealthKit.
/// Sleep quality is a CRITICAL signal — correlates with meal timing, HRV, and cognitive performance.
public final class SleepCollector: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let metricKey = "sleep_analysis"

    #if canImport(HealthKit)
    private let healthStore: HKHealthStore
    #endif

    #if canImport(HealthKit)
    public init(healthStore: HKHealthStore, database: VITADatabase, healthGraph: HealthGraph) {
        self.healthStore = healthStore
        self.database = database
        self.healthGraph = healthGraph
    }
    #endif

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
        #if canImport(HealthKit)
        self.healthStore = HKHealthStore()
        #endif
    }

    #if canImport(HealthKit)
    /// Fetch and process sleep data since last sync.
    public func performIncrementalSync() async throws {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: sleepType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, error in
                guard let self else {
                    continuation.resume()
                    return
                }

                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                do {
                    try self.processSleepSamples(samples ?? [], newAnchor: newAnchor)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            healthStore.execute(query)
        }
    }

    private func processSleepSamples(_ samples: [HKSample], newAnchor: HKQueryAnchor?) throws {
        for sample in samples {
            guard let categorySample = sample as? HKCategorySample else { continue }

            let stageLabel = sleepStageLabel(for: categorySample.value)
            let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate)

            var physiologicalSample = PhysiologicalSample(
                metricType: .sleepAnalysis,
                value: duration / 60.0, // Store as minutes
                unit: "min",
                timestamp: categorySample.startDate,
                source: .appleWatch,
                metadata: ["stage": stageLabel]
            )
            try healthGraph.ingest(&physiologicalSample)
        }

        if let newAnchor {
            let anchorData = try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
            let state = HealthKitSyncState(
                metricType: metricKey,
                anchorData: anchorData,
                lastSyncDate: Date()
            )
            try state.save(to: database)
        }
    }

    private func sleepStageLabel(for value: Int) -> String {
        if #available(iOS 16.0, *) {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .asleepCore: return "core"
            case .asleepDeep: return "deep"
            case .asleepREM: return "rem"
            case .awake: return "awake"
            case .inBed: return "in_bed"
            default: return "unknown"
            }
        } else {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .inBed: return "in_bed"
            case .asleep: return "asleep"
            case .awake: return "awake"
            default: return "unknown"
            }
        }
    }
    #endif
}
