#if canImport(HealthKit)
import HealthKit
#endif
import Foundation
import VITACore

/// Collects CGM blood glucose data from HealthKit with spike/crash feature extraction.
/// CGM data is the metabolic ground truth — turns probabilistic causality into deterministic chains.
public final class GlucoseCollector: @unchecked Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph
    private let metricKey = "blood_glucose"

    /// Baseline glucose for energy state classification (mg/dL).
    public var baselineGlucose: Double = 90.0

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
    /// Fetch and process glucose data since last sync.
    public func performIncrementalSync() async throws {
        let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!

        let syncState = try HealthKitSyncState.load(for: metricKey, from: database)
        let anchor = syncState?.anchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKAnchoredObjectQuery(
                type: glucoseType,
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
                    try self.processGlucoseSamples(samples ?? [], newAnchor: newAnchor)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            healthStore.execute(query)
        }
    }

    private func processGlucoseSamples(_ samples: [HKSample], newAnchor: HKQueryAnchor?) throws {
        // Collect readings for spike/crash detection
        var readings: [GlucoseReading] = []

        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            let mgDL = quantitySample.quantity.doubleValue(
                for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
            )

            let source: PhysiologicalSample.DataSource = {
                let sourceName = quantitySample.sourceRevision.source.name.lowercased()
                if sourceName.contains("dexcom") { return .cgmDexcom }
                if sourceName.contains("libre") { return .cgmLibre }
                return .appleWatch
            }()

            let reading = GlucoseReading(
                glucoseMgDL: mgDL,
                timestamp: quantitySample.startDate,
                source: source
            )
            readings.append(reading)
        }

        // Classify trends and energy states using sliding window
        classifyReadings(&readings)

        // Persist
        for var reading in readings {
            try healthGraph.ingest(&reading)
        }

        // Persist anchor
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

    /// Classify glucose readings with trend and energy state.
    /// Uses a sliding window to compute rate of change.
    func classifyReadings(_ readings: inout [GlucoseReading]) {
        guard readings.count >= 2 else { return }

        // Sort by timestamp
        readings.sort { $0.timestamp < $1.timestamp }

        var peakValue = readings[0].glucoseMgDL

        for i in 1..<readings.count {
            let prev = readings[i - 1]
            let current = readings[i]
            let timeDeltaMinutes = current.timestamp.timeIntervalSince(prev.timestamp) / 60.0

            guard timeDeltaMinutes > 0 else { continue }

            let ratePerMinute = (current.glucoseMgDL - prev.glucoseMgDL) / timeDeltaMinutes

            // Update peak tracking
            if current.glucoseMgDL > peakValue {
                peakValue = current.glucoseMgDL
            }

            // Classify trend
            readings[i].trend = classifyTrend(ratePerMinute: ratePerMinute)

            // Classify energy state
            let deltaFromPeak = current.glucoseMgDL - peakValue
            readings[i].energyState = GlucoseReading.classifyEnergyState(
                currentMgDL: current.glucoseMgDL,
                deltaFromPeak: deltaFromPeak,
                baselineMgDL: baselineGlucose
            )

            // Reset peak tracking after crash recovery
            if readings[i].energyState == .stable && deltaFromPeak < -30 {
                peakValue = current.glucoseMgDL
            }
        }
    }

    private func classifyTrend(ratePerMinute: Double) -> GlucoseReading.GlucoseTrend {
        switch ratePerMinute {
        case 3...: return .rapidlyRising
        case 1..<3: return .rising
        case -1..<1: return .stable
        case -3 ..< -1: return .falling
        default: return .rapidlyFalling
        }
    }
}
