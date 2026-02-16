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
    private let metricKey = "resting_hr"

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
        let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!

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
        let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: hrType,
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

            var physiologicalSample = PhysiologicalSample(
                metricType: .restingHeartRate,
                value: bpm,
                unit: "bpm",
                timestamp: quantitySample.startDate,
                source: .appleWatch
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
    #endif
}
