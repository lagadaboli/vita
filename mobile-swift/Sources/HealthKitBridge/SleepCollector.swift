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
    private var observerQuery: HKObserverQuery?
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
    /// Start observing sleep analysis samples with background delivery.
    public func startObserving() throws {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        let observer = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task {
                try? await self?.performIncrementalSync()
                completionHandler()
            }
        }

        healthStore.execute(observer)
        self.observerQuery = observer
    }

    /// Stop observing sleep analysis samples.
    public func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }

    /// Fetch and process sleep data since last sync.
    public func performIncrementalSync() async throws {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let predicate = incrementalPredicate(anchor: anchor)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: sleepType,
                predicate: predicate,
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
            let sampleMetadata = healthMetadata(for: categorySample, stageLabel: stageLabel)
            let isWatchSample = sampleMetadata["is_watch_sample"] == "true"

            var physiologicalSample = PhysiologicalSample(
                metricType: .sleepAnalysis,
                value: duration / 60.0, // Store as minutes
                unit: "min",
                timestamp: categorySample.startDate,
                source: isWatchSample ? .appleWatch : .manual,
                metadata: sampleMetadata
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

    private func healthMetadata(for sample: HKSample, stageLabel: String) -> [String: String] {
        let sourceName = sample.sourceRevision.source.name
        let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier
        let productType = sample.sourceRevision.productType ?? "unknown"
        let deviceModel = sample.device?.model ?? "unknown"
        let isWatch = isAppleWatchSample(sample)

        return [
            "stage": stageLabel,
            "hk_source_name": sourceName,
            "hk_bundle_id": bundleIdentifier,
            "hk_product_type": productType,
            "hk_device_model": deviceModel,
            "is_watch_sample": isWatch ? "true" : "false",
        ]
    }

    private func isAppleWatchSample(_ sample: HKSample) -> Bool {
        let sourceName = sample.sourceRevision.source.name.lowercased()
        let productType = sample.sourceRevision.productType?.lowercased() ?? ""
        let deviceModel = sample.device?.model?.lowercased() ?? ""

        return sourceName.contains("watch")
            || productType.contains("watch")
            || deviceModel.contains("watch")
    }

    private func incrementalPredicate(anchor: HKQueryAnchor?) -> NSPredicate? {
        guard anchor == nil else { return nil }
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return HKQuery.predicateForSamples(withStart: lookbackStart, end: nil, options: .strictStartDate)
    }
    #endif
}
