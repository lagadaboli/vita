import Testing
import Foundation
@testable import VITACore

@Suite("Health Graph Tests")
struct HealthGraphTests {

    // MARK: - Node Creation

    @Test("Create physiological sample node")
    func physiologicalSampleNode() {
        let sample = PhysiologicalSample(
            id: 1,
            metricType: .hrvSDNN,
            value: 42.5,
            unit: "ms",
            timestamp: Date()
        )
        let node = AnyHealthGraphNode.from(sample)

        #expect(node.nodeID == "physio_1")
        #expect(node.nodeType == .physiological)
    }

    @Test("Create glucose reading node")
    func glucoseReadingNode() {
        let reading = GlucoseReading(
            id: 5,
            glucoseMgDL: 145.0,
            timestamp: Date(),
            trend: .rising,
            energyState: .rising
        )
        let node = AnyHealthGraphNode.from(reading)

        #expect(node.nodeID == "glucose_5")
        #expect(node.nodeType == .glucose)
    }

    @Test("Create meal event node")
    func mealEventNode() {
        let meal = MealEvent(
            id: 3,
            timestamp: Date(),
            source: .rotimaticNext,
            ingredients: [
                MealEvent.Ingredient(name: "whole_wheat_flour", quantityGrams: 150, glycemicIndex: 69)
            ]
        )
        let node = AnyHealthGraphNode.from(meal)

        #expect(node.nodeID == "meal_3")
        #expect(node.nodeType == .meal)
    }

    @Test("Create behavioral event node")
    func behavioralEventNode() {
        let event = BehavioralEvent(
            id: 7,
            timestamp: Date(),
            duration: 2700,
            category: .passiveConsumption,
            appName: "Instagram"
        )
        let node = AnyHealthGraphNode.from(event)

        #expect(node.nodeID == "behavioral_7")
        #expect(node.nodeType == .behavioral)
    }

    // MARK: - Edge Creation

    @Test("Create temporal edge with causal strength")
    func temporalEdge() {
        let edge = HealthGraphEdge(
            sourceNodeID: "meal_1",
            targetNodeID: "glucose_2",
            edgeType: .mealToGlucose,
            causalStrength: 0.85,
            temporalOffsetSeconds: 5400, // 90 minutes
            confidence: 0.78
        )

        #expect(edge.sourceNodeID == "meal_1")
        #expect(edge.targetNodeID == "glucose_2")
        #expect(edge.edgeType == .mealToGlucose)
        #expect(edge.isStrongCausal)
        #expect(edge.temporalOffsetDescription == "1h 30min")
    }

    @Test("Edge below causal threshold")
    func weakEdge() {
        let edge = HealthGraphEdge(
            sourceNodeID: "behavioral_1",
            targetNodeID: "physio_3",
            edgeType: .behaviorToHRV,
            causalStrength: 0.3,
            confidence: 0.4
        )

        #expect(!edge.isStrongCausal)
    }

    @Test("Temporal offset formatting")
    func temporalOffsetFormat() {
        let minutesOnly = HealthGraphEdge(
            sourceNodeID: "a", targetNodeID: "b",
            edgeType: .temporal,
            temporalOffsetSeconds: 1800
        )
        #expect(minutesOnly.temporalOffsetDescription == "30min")

        let hoursExact = HealthGraphEdge(
            sourceNodeID: "a", targetNodeID: "b",
            edgeType: .temporal,
            temporalOffsetSeconds: 7200
        )
        #expect(hoursExact.temporalOffsetDescription == "2h")

        let hoursAndMinutes = HealthGraphEdge(
            sourceNodeID: "a", targetNodeID: "b",
            edgeType: .temporal,
            temporalOffsetSeconds: 5700
        )
        #expect(hoursAndMinutes.temporalOffsetDescription == "1h 35min")
    }

    // MARK: - Database Integration

    @Test("Ingest and query samples via HealthGraph")
    func ingestAndQuery() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)

        let now = Date()
        var sample1 = PhysiologicalSample(
            metricType: .hrvSDNN,
            value: 45.0,
            unit: "ms",
            timestamp: now.addingTimeInterval(-3600)
        )
        var sample2 = PhysiologicalSample(
            metricType: .hrvSDNN,
            value: 52.0,
            unit: "ms",
            timestamp: now
        )
        var sample3 = PhysiologicalSample(
            metricType: .restingHeartRate,
            value: 62.0,
            unit: "bpm",
            timestamp: now
        )

        try graph.ingest(&sample1)
        try graph.ingest(&sample2)
        try graph.ingest(&sample3)

        let hrvSamples = try graph.querySamples(
            type: .hrvSDNN,
            from: now.addingTimeInterval(-7200),
            to: now.addingTimeInterval(60)
        )

        #expect(hrvSamples.count == 2)
        #expect(hrvSamples[0].value == 45.0)
        #expect(hrvSamples[1].value == 52.0)
    }

    @Test("Ingest and query edges")
    func ingestAndQueryEdges() throws {
        let db = try VITADatabase.inMemory()
        let graph = HealthGraph(database: db)

        var edge = HealthGraphEdge(
            sourceNodeID: "meal_1",
            targetNodeID: "glucose_1",
            edgeType: .mealToGlucose,
            causalStrength: 0.9,
            temporalOffsetSeconds: 5400,
            confidence: 0.85
        )
        try graph.addEdge(&edge)

        let edges = try graph.queryEdges(from: "meal_1")
        #expect(edges.count == 1)
        #expect(edges[0].edgeType == .mealToGlucose)
        #expect(edges[0].causalStrength == 0.9)
    }

    // MARK: - Model Tests

    @Test("Glycemic load computation")
    func glycemicLoadComputation() {
        let meal = MealEvent(
            timestamp: Date(),
            source: .rotimaticNext,
            ingredients: [
                MealEvent.Ingredient(name: "whole_wheat_flour", quantityGrams: 150, glycemicIndex: 69),
                MealEvent.Ingredient(name: "oil", quantityML: 10),
            ]
        )

        // GL = (69 * 150 * 0.7) / 100 = 72.45
        let gl = meal.computedGlycemicLoad
        #expect(gl > 72.0 && gl < 73.0)
    }

    @Test("Glucose energy state classification")
    func glucoseEnergyState() {
        #expect(GlucoseReading.classifyEnergyState(currentMgDL: 95, deltaFromPeak: 0) == .stable)
        #expect(GlucoseReading.classifyEnergyState(currentMgDL: 160, deltaFromPeak: 30) == .rising)
        #expect(GlucoseReading.classifyEnergyState(currentMgDL: 100, deltaFromPeak: -40) == .crashing)
        #expect(GlucoseReading.classifyEnergyState(currentMgDL: 72, deltaFromPeak: -50) == .reactiveLow)
    }

    @Test("Causal pattern cloud sync eligibility")
    func causalPatternEligibility() {
        let eligible = CausalPattern(
            pattern: "high_GL → spike → fatigue",
            strength: 0.8,
            observationCount: 10
        )
        #expect(eligible.isCloudSyncEligible)

        let tooFew = CausalPattern(
            pattern: "test",
            strength: 0.9,
            observationCount: 3
        )
        #expect(!tooFew.isCloudSyncEligible)

        let tooWeak = CausalPattern(
            pattern: "test",
            strength: 0.4,
            observationCount: 20
        )
        #expect(!tooWeak.isCloudSyncEligible)
    }

    @Test("Dopamine debt score computation")
    func dopamineDebtComputation() {
        let score = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: 45,
            appSwitchFrequencyZScore: 0.6,
            focusModeRatio: 0.2,
            lateNightPenalty: 0.5
        )
        #expect(score > 0 && score <= 100)

        let zeroScore = BehavioralEvent.computeDopamineDebt(
            passiveMinutesLast3Hours: 0,
            appSwitchFrequencyZScore: 0,
            focusModeRatio: 1.0,
            lateNightPenalty: 0
        )
        #expect(zeroScore == 0)
    }
}
