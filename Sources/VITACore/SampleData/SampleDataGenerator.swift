import Foundation

/// Generates a realistic 7-day dataset for VITA demo/testing.
/// All data is internally consistent: meals drive glucose curves,
/// glucose crashes suppress HRV, late meals degrade sleep, etc.
public final class SampleDataGenerator: Sendable {
    private let database: VITADatabase
    private let healthGraph: HealthGraph

    public init(database: VITADatabase, healthGraph: HealthGraph) {
        self.database = database
        self.healthGraph = healthGraph
    }

    /// Populate the database with 7 days of sample data.
    public func generateAll() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Generate data for last 7 days
        for dayOffset in (-6...0) {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let scenario = SampleDataScenarios.scenario(for: dayOffset)
            try generateDay(dayStart: dayStart, scenario: scenario)
        }

        try generateCausalEdges()
        try generateCausalPatterns()
    }

    private func generateDay(dayStart: Date, scenario: SampleDataScenarios.DayScenario) throws {
        // Meals
        for meal in scenario.meals {
            var mealEvent = meal.toMealEvent(dayStart: dayStart)
            try healthGraph.ingest(&mealEvent)

            // Generate glucose curve for this meal
            let glucoseReadings = generateGlucoseCurve(
                mealTime: mealEvent.timestamp,
                glycemicLoad: mealEvent.estimatedGlycemicLoad ?? mealEvent.computedGlycemicLoad,
                mealID: mealEvent.id
            )
            for var reading in glucoseReadings {
                try healthGraph.ingest(&reading)
            }
        }

        // Fasting glucose baseline (early morning)
        try generateFastingBaseline(dayStart: dayStart)

        // HRV samples throughout the day
        for hrv in scenario.hrvSamples {
            var sample = hrv.toPhysiologicalSample(dayStart: dayStart)
            try healthGraph.ingest(&sample)
        }

        // Heart rate samples
        for hr in scenario.heartRateSamples {
            var sample = hr.toPhysiologicalSample(dayStart: dayStart)
            try healthGraph.ingest(&sample)
        }

        // Sleep data (from previous night)
        for sleep in scenario.sleepSamples {
            var sample = sleep.toPhysiologicalSample(dayStart: dayStart)
            try healthGraph.ingest(&sample)
        }

        // Step count
        for steps in scenario.stepSamples {
            var sample = steps.toPhysiologicalSample(dayStart: dayStart)
            try healthGraph.ingest(&sample)
        }

        // Behavioral events
        for behavior in scenario.behaviors {
            var event = behavior.toBehavioralEvent(dayStart: dayStart)
            try healthGraph.ingest(&event)
        }
    }

    private func generateGlucoseCurve(mealTime: Date, glycemicLoad: Double, mealID: Int64?) -> [GlucoseReading] {
        var readings: [GlucoseReading] = []
        let baseline: Double = 90
        // Peak proportional to GL: GL 20 → ~140, GL 40 → ~180
        let peakRise = min(glycemicLoad * 2.5, 110)
        let peakGlucose = baseline + peakRise
        let peakTimeMin: Double = 35

        // Generate readings every 5 minutes for 2.5 hours post-meal
        for minuteOffset in stride(from: 0, through: 150, by: 5) {
            let t = Double(minuteOffset)
            let timestamp = mealTime.addingTimeInterval(t * 60)
            let value: Double

            if t <= peakTimeMin {
                // Rising phase: quadratic rise
                let progress = t / peakTimeMin
                value = baseline + peakRise * progress * progress
            } else if t <= peakTimeMin + 30 {
                // Plateau / early decline
                let declineProgress = (t - peakTimeMin) / 30
                value = peakGlucose - peakRise * 0.15 * declineProgress
            } else {
                // Crash phase
                let crashProgress = (t - peakTimeMin - 30) / 85
                let crashDepth = peakRise > 60 ? peakRise * 0.8 : peakRise * 0.5
                value = (peakGlucose - peakRise * 0.15) - crashDepth * min(crashProgress, 1.0)
            }

            let trend: GlucoseReading.GlucoseTrend
            let energyState: GlucoseReading.EnergyState

            if t <= peakTimeMin * 0.5 {
                trend = .rapidlyRising; energyState = .rising
            } else if t <= peakTimeMin {
                trend = .rising; energyState = .rising
            } else if t <= peakTimeMin + 30 {
                trend = .stable; energyState = .stable
            } else if t <= peakTimeMin + 70 {
                trend = .falling; energyState = .crashing
            } else if value < baseline - 10 {
                trend = .rapidlyFalling; energyState = .reactiveLow
            } else {
                trend = .falling; energyState = .crashing
            }

            readings.append(GlucoseReading(
                glucoseMgDL: max(value, 60),
                timestamp: timestamp,
                trend: trend,
                energyState: energyState,
                source: .cgmDexcom,
                relatedMealEventID: mealID
            ))
        }
        return readings
    }

    private func generateFastingBaseline(dayStart: Date) throws {
        // Early morning fasting readings: 5am - 7am, every 15 min
        for minuteOffset in stride(from: 300, through: 420, by: 15) {
            let timestamp = dayStart.addingTimeInterval(TimeInterval(minuteOffset * 60))
            let value = Double.random(in: 82...95)
            var reading = GlucoseReading(
                glucoseMgDL: value,
                timestamp: timestamp,
                trend: .stable,
                energyState: .stable,
                source: .cgmDexcom
            )
            try healthGraph.ingest(&reading)
        }
    }

    private func generateCausalEdges() throws {
        // meal→glucose edges
        var edge1 = HealthGraphEdge(
            sourceNodeID: "meal_1", targetNodeID: "glucose_spike_1",
            edgeType: .mealToGlucose, causalStrength: 0.85,
            temporalOffsetSeconds: 2100, confidence: 0.82
        )
        try healthGraph.addEdge(&edge1)

        // glucose→HRV edges
        var edge2 = HealthGraphEdge(
            sourceNodeID: "glucose_crash_1", targetNodeID: "hrv_drop_1",
            edgeType: .glucoseToHRV, causalStrength: 0.78,
            temporalOffsetSeconds: 3600, confidence: 0.75
        )
        try healthGraph.addEdge(&edge2)

        // behavior→HRV edges
        var edge3 = HealthGraphEdge(
            sourceNodeID: "behavior_instagram_1", targetNodeID: "hrv_suppressed_1",
            edgeType: .behaviorToHRV, causalStrength: 0.65,
            temporalOffsetSeconds: 5400, confidence: 0.60
        )
        try healthGraph.addEdge(&edge3)

        // meal→sleep edges
        var edge4 = HealthGraphEdge(
            sourceNodeID: "meal_late_1", targetNodeID: "sleep_poor_1",
            edgeType: .mealToSleep, causalStrength: 0.72,
            temporalOffsetSeconds: 10800, confidence: 0.68
        )
        try healthGraph.addEdge(&edge4)

        // glucose→energy edges
        var edge5 = HealthGraphEdge(
            sourceNodeID: "glucose_crash_2", targetNodeID: "energy_fatigue_1",
            edgeType: .glucoseToEnergy, causalStrength: 0.88,
            temporalOffsetSeconds: 1800, confidence: 0.85
        )
        try healthGraph.addEdge(&edge5)
    }

    private func generateCausalPatterns() throws {
        let patterns: [(String, Double, Int)] = [
            ("high_gi_meal → glucose_spike > 160 → hrv_suppression > 20%", 0.82, 12),
            ("white_flour → glucose_spike → reactive_hypoglycemia → fatigue", 0.78, 8),
            ("slow_cook_legumes → lectin_retention → gi_distress", 0.71, 6),
            ("late_meal_>21h → reduced_deep_sleep > 25min", 0.75, 9),
            ("passive_screen > 40min → dopamine_debt > 70 → focus_deficit", 0.68, 7),
        ]

        for (pattern, strength, count) in patterns {
            try database.write { db in
                var p = CausalPattern(
                    pattern: pattern,
                    strength: strength,
                    observationCount: count,
                    demographicBucket: "25-35_active"
                )
                try p.save(db)
            }
        }
    }
}
