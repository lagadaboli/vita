import Testing
import Foundation
@testable import VITACore

@Suite("BehavioralEvent Tests")
struct BehavioralEventTests {

    // MARK: - Zombie Scrolling Category

    @Test("zombieScrolling raw value is correct")
    func zombieScrollingRawValue() {
        let category = BehavioralEvent.BehaviorCategory.zombieScrolling
        #expect(category.rawValue == "zombie_scrolling")
    }

    @Test("zombieScrolling roundtrips through Codable")
    func zombieScrollingCodableRoundtrip() throws {
        let event = BehavioralEvent(
            timestamp: Date(),
            duration: 1200,
            category: .zombieScrolling,
            appName: "Instacart",
            metadata: ["source": "screen_time"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BehavioralEvent.self, from: data)

        #expect(decoded.category == .zombieScrolling)
        #expect(decoded.appName == "Instacart")
        #expect(decoded.duration == 1200)
        #expect(decoded.metadata?["source"] == "screen_time")
    }

    @Test("zombieScrolling persists to and reads from database")
    func zombieScrollingDatabaseRoundtrip() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)

        var event = BehavioralEvent(
            timestamp: Date(),
            duration: 900,
            category: .zombieScrolling,
            appName: "Instacart",
            dopamineDebtScore: 65.0
        )
        try graph.ingest(&event)

        let now = Date()
        let results = try graph.queryBehaviors(
            from: now.addingTimeInterval(-60),
            to: now.addingTimeInterval(60)
        )

        #expect(results.count == 1)
        #expect(results[0].category == .zombieScrolling)
        #expect(results[0].appName == "Instacart")
        #expect(results[0].dopamineDebtScore == 65.0)
    }

    // MARK: - Dopamine Debt with Zombie Scrolling

    @Test("Dopamine debt with zombie scrolling inputs")
    func dopamineDebtWithZombieScrolling() {
        // 30 minutes of zombie scrolling in last 3 hours
        let score = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: 30,
            appSwitchFrequencyZScore: 0.5,
            focusModeRatio: 0.0,   // Not in focus mode during zombie scroll
            lateNightPenalty: 0.0
        )

        // 0.4 * (30/60) + 0.3 * 0.5 + 0.2 * (1-0) + 0.1 * 0 = 0.2 + 0.15 + 0.2 + 0 = 0.55
        // * 100 = 55.0
        #expect(abs(score - 55.0) < 0.001)
    }

    @Test("Dopamine debt with zombie scrolling at night")
    func dopamineDebtZombieAtNight() {
        // 45 minutes zombie + late night penalty
        let score = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: 45,
            appSwitchFrequencyZScore: 0.7,
            focusModeRatio: 0.0,
            lateNightPenalty: 0.8
        )

        // 0.4 * (45/60=0.75) + 0.3 * 0.7 + 0.2 * 1.0 + 0.1 * 0.8
        // = 0.3 + 0.21 + 0.2 + 0.08 = 0.79 * 100 = 79.0
        #expect(score == 79.0)
    }

    @Test("Dopamine debt clamped at 100")
    func dopamineDebtClamped() {
        let score = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: 180,  // 3 hours straight
            appSwitchFrequencyZScore: 1.0,
            focusModeRatio: 0.0,
            lateNightPenalty: 1.0
        )
        #expect(abs(score - 100.0) < 0.001)
    }

    // MARK: - All Categories Exist

    @Test("All behavior categories decode correctly")
    func allCategoriesDecodable() throws {
        let categories: [BehavioralEvent.BehaviorCategory] = [
            .activeWork, .passiveConsumption, .stressSignal,
            .zombieScrolling, .exercise, .rest,
        ]

        for category in categories {
            let json = "\"\(category.rawValue)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(BehavioralEvent.BehaviorCategory.self, from: json)
            #expect(decoded == category)
        }
    }
}
