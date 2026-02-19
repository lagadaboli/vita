#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Collects resting heart rate data from HealthKit with hourly aggregation.
/// Resting HR is a CRITICAL metric — sustained elevation correlates with stress, poor recovery, and inflammation.
public final class HeartRateCollector: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let metricKey = "heart_rate"

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
    /// Start observing resting heart rate samples with background delivery.
    public func startObserving() throws {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let observer = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] _, completionHandler, error in
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

    /// Stop observing resting heart rate samples.
    public func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }

    /// Fetch and process resting heart rate data since last sync.
    public func performIncrementalSync() async throws {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let predicate = incrementalPredicate(anchor: anchor)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: hrType,
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
                    try self.processHeartRateSamples(samples ?? [], newAnchor: newAnchor)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            healthStore.execute(query)
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample], newAnchor: HKQueryAnchor?) throws {
        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            let bpm = quantitySample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            let sampleMetadata = healthMetadata(for: quantitySample)
            let isWatchSample = sampleMetadata["is_watch_sample"] == "true"

            var physiologicalSample = PhysiologicalSample(
                metricType: .heartRate,
                value: bpm,
                unit: "bpm",
                timestamp: quantitySample.startDate,
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

    private func healthMetadata(for sample: HKSample) -> [String: String] {
        let sourceName = sample.sourceRevision.source.name
        let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier
        let productType = sample.sourceRevision.productType ?? "unknown"
        let deviceModel = sample.device?.model ?? "unknown"
        let isWatch = isAppleWatchSample(sample)

        return [
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
