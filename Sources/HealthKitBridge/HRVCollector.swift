#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Collects HRV (SDNN) data from HealthKit using anchored object queries.
/// HRV is a CRITICAL metric — it's the primary signal for autonomic nervous system stress,
/// and correlates strongly with digestive debt and sleep quality.
public final class HRVCollector: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let metricKey = "hrv_sdnn"

    #if canImport(HealthKit)
    private let healthStore: HKHealthStore
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
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
    /// Start observing HRV samples with background delivery.
    public func startObserving() throws {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let observer = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
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

    /// Perform an incremental sync using the persisted anchor.
    public func performIncrementalSync() async throws {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        // Load persisted anchor
        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: hrvType,
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
                    try self.processSamples(samples ?? [], newAnchor: newAnchor)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            healthStore.execute(query)
        }
    }

    /// Process new HRV samples and persist the updated anchor.
    private func processSamples(_ samples: [HKSample], newAnchor: HKQueryAnchor?) throws {
        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            let sdnn = quantitySample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

            var physiologicalSample = PhysiologicalSample(
                metricType: .hrvSDNN,
                value: sdnn,
                unit: "ms",
                timestamp: quantitySample.startDate,
                source: .appleWatch
            )
            try healthGraph.ingest(&physiologicalSample)
        }

        // Persist the new anchor
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

    /// Stop observing HRV samples.
    public func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
    #endif
}
