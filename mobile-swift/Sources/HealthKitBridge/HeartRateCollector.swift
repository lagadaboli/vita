#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Collects heart rate data from HealthKit.
/// Syncs both live heart rate and resting heart rate so the dashboard has usable data
/// even when one stream is sparse for a given user.
public final class HeartRateCollector: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let heartRateMetricKey = "heart_rate"
    private let restingHeartRateMetricKey = "resting_hr"

    #if canImport(HealthKit)
    private let healthStore: HKHealthStore
    private var observerQueries: [HKObserverQuery] = []
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
    /// Start observing both heart-rate sample streams.
    public func startObserving() throws {
        observerQueries = [
            try makeObserverQuery(for: .heartRate),
            try makeObserverQuery(for: .restingHeartRate),
        ]

        for query in observerQueries {
            healthStore.execute(query)
        }
    }

    /// Stop observing heart-rate samples.
    public func stopObserving() {
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries = []
    }

    /// Fetch and process heart-rate data since last sync.
    public func performIncrementalSync() async throws {
        try await sync(
            identifier: .heartRate,
            metricType: .heartRate,
            metricKey: heartRateMetricKey
        )

        try await sync(
            identifier: .restingHeartRate,
            metricType: .restingHeartRate,
            metricKey: restingHeartRateMetricKey
        )
    }

    private func makeObserverQuery(for identifier: HKQuantityTypeIdentifier) throws -> HKObserverQuery {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.queryFailed("Missing quantity type for \(identifier.rawValue)")
        }

        return HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            Task {
                try? await self?.performIncrementalSync()
                completionHandler()
            }
        }
    }

    private func sync(
        identifier: HKQuantityTypeIdentifier,
        metricType: PhysiologicalSample.MetricType,
        metricKey: String
    ) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.queryFailed("Missing quantity type for \(identifier.rawValue)")
        }

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }
        let predicate = incrementalPredicate(anchor: anchor)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: type,
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

                Task {
                    do {
                        var quantitySamples = (samples ?? []).compactMap { $0 as? HKQuantitySample }

                        // Fallback on first sync if anchored query returned nothing.
                        if quantitySamples.isEmpty, anchor == nil {
                            quantitySamples = try await self.fetchSamples(type: type, predicate: predicate)
                        }

                        try self.processHeartRateSamples(quantitySamples, metricType: metricType)
                        try self.persistAnchor(newAnchor, metricKey: metricKey)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchSamples(type: HKQuantityType, predicate: NSPredicate?) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                let quantitySamples = (samples ?? []).compactMap { $0 as? HKQuantitySample }
                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }

    private func processHeartRateSamples(
        _ samples: [HKQuantitySample],
        metricType: PhysiologicalSample.MetricType
    ) throws {
        for quantitySample in samples {
            let bpm = quantitySample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            let sampleMetadata = healthMetadata(for: quantitySample)
            let isWatchSample = sampleMetadata["is_watch_sample"] == "true"

            var physiologicalSample = PhysiologicalSample(
                metricType: metricType,
                value: bpm,
                unit: "bpm",
                timestamp: quantitySample.startDate,
                source: isWatchSample ? .appleWatch : .manual,
                metadata: sampleMetadata
            )
            try healthGraph.ingest(&physiologicalSample)
        }
    }

    private func persistAnchor(_ anchor: HKQueryAnchor?, metricKey: String) throws {
        guard let anchor else { return }

        let anchorData = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        let state = HealthKitSyncState(
            metricType: metricKey,
            anchorData: anchorData,
            lastSyncDate: Date()
        )
        try state.save(to: database)
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
