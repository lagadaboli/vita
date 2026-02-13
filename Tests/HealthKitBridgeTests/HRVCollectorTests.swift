import Testing
import Foundation
@testable import VITACore
@testable import HealthKitBridge

@Suite("HRV Collector Tests")
struct HRVCollectorTests {

    // MARK: - Sync State Persistence

    @Test("Persist and load sync state")
    func syncStatePersistence() throws {
        let db = try VITADatabase.inMemory()

        let state = HealthKitSyncState(
            metricType: "hrv_sdnn",
            anchorData: Data([0x01, 0x02, 0x03]),
            lastSyncDate: Date()
        )
        try state.save(to: db)

        let loaded = try HealthKitSyncState.load(for: "hrv_sdnn", from: db)
        #expect(loaded != nil)
        #expect(loaded?.metricType == "hrv_sdnn")
        #expect(loaded?.anchorData == Data([0x01, 0x02, 0x03]))
    }

    @Test("Load nonexistent sync state returns nil")
    func syncStateNotFound() throws {
        let db = try VITADatabase.inMemory()

        let loaded = try HealthKitSyncState.load(for: "nonexistent", from: db)
        #expect(loaded == nil)
    }

    @Test("Update existing sync state")
    func syncStateUpdate() throws {
        let db = try VITADatabase.inMemory()

        let state1 = HealthKitSyncState(
            metricType: "hrv_sdnn",
            anchorData: Data([0x01]),
            lastSyncDate: Date().addingTimeInterval(-3600)
        )
        try state1.save(to: db)

        let state2 = HealthKitSyncState(
            metricType: "hrv_sdnn",
            anchorData: Data([0x01, 0x02, 0x03]),
            lastSyncDate: Date()
        )
        try state2.save(to: db)

        let loaded = try HealthKitSyncState.load(for: "hrv_sdnn", from: db)
        #expect(loaded?.anchorData == Data([0x01, 0x02, 0x03]))
    }

    // MARK: - Glucose Classification

    @Test("Glucose trend classification via GlucoseCollector")
    func glucoseClassification() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)
        let collector = GlucoseCollector(database: db, healthGraph: graph)

        let baseTime = Date()
        var readings: [GlucoseReading] = [
            GlucoseReading(glucoseMgDL: 90, timestamp: baseTime),
            GlucoseReading(glucoseMgDL: 93, timestamp: baseTime.addingTimeInterval(300)),
            GlucoseReading(glucoseMgDL: 130, timestamp: baseTime.addingTimeInterval(600)),
            GlucoseReading(glucoseMgDL: 165, timestamp: baseTime.addingTimeInterval(900)),
            GlucoseReading(glucoseMgDL: 140, timestamp: baseTime.addingTimeInterval(1200)),
            GlucoseReading(glucoseMgDL: 100, timestamp: baseTime.addingTimeInterval(1500)),
            GlucoseReading(glucoseMgDL: 72, timestamp: baseTime.addingTimeInterval(1800)),
        ]

        collector.classifyReadings(&readings)

        // First reading has no classification (no previous)
        // Second should be stable (small change)
        #expect(readings[1].trend == .stable)

        // Third and fourth should show rising (large positive delta)
        #expect(readings[2].trend == .rapidlyRising || readings[2].trend == .rising)

        // Sixth and seventh should show falling/crashing
        #expect(readings[5].trend == .rapidlyFalling || readings[5].trend == .falling)

        // Last reading should be crashing or reactive low energy state
        let lastState = readings[6].energyState
        #expect(lastState == .crashing || lastState == .reactiveLow)
    }

    @Test("Empty readings classification is safe")
    func emptyReadingsClassification() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)
        let collector = GlucoseCollector(database: db, healthGraph: graph)

        var readings: [GlucoseReading] = []
        collector.classifyReadings(&readings)
        #expect(readings.isEmpty)
    }

    @Test("Single reading classification is safe")
    func singleReadingClassification() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)
        let collector = GlucoseCollector(database: db, healthGraph: graph)

        var readings = [GlucoseReading(glucoseMgDL: 90, timestamp: Date())]
        collector.classifyReadings(&readings)
        #expect(readings.count == 1)
    }
}
