import Foundation
import VITACore
import VITADesignSystem

@MainActor
@Observable
final class IntegrationsViewModel {
    // Apple Watch
    var watchSyncDate = Date().addingTimeInterval(-300)
    var watchHRV: Double = 52
    var watchHR: Double = 64
    var watchSteps: Int = 4800

    // DoorDash orders (24h slice for UI)
    var doordashOrders: [DoorDashOrder] = []

    // Rotimatic sessions (24h slice for UI)
    var rotimaticSessions: [RotimaticSession] = []

    // Instant Pot programs (24h slice for UI)
    var instantPotPrograms: [InstantPotProgram] = []

    // Instacart orders (24h slice for UI)
    var instacartOrders: [InstacartOrder] = []

    // Body scale / weight (24h slice for UI)
    var weightReadings: [WeightReading] = []

    // Zombie scrolling sessions (24h slice for UI)
    var zombieScrollSessions: [ZombieScrollSession] = []

    // Screen Time sessions (24h slice for UI)
    var screenTimeSessions: [ScreenTimeSession] = []

    // Latest skin scan (real-time from Skin Audit)
    var latestSkinSnapshot: SkinSnapshot?

    // Environment readings (24h slice for UI)
    var environmentReadings: [EnvironmentReading] = []
    private var appState: AppState?

    // MARK: - Structs

    struct DoorDashOrder: Identifiable {
        let id = UUID()
        let name: String
        let classification: String
        let timestamp: Date
        let glycemicLoad: Double
        let ingredients: [String]
        let glucoseImpact: String
    }

    struct RotimaticSession: Identifiable {
        let id = UUID()
        let flourType: String
        let classification: String
        let count: Int
        let timestamp: Date
        let glycemicLoad: Double
        let glucoseImpact: String
    }

    struct InstantPotProgram: Identifiable {
        let id = UUID()
        let recipe: String
        let classification: String
        let mode: String
        let timestamp: Date
        let bioavailability: Double
        let note: String
    }

    struct InstacartOrder: Identifiable {
        let id = UUID()
        let label: String
        let classification: String
        let timestamp: Date
        let items: [InstacartItem]
        let totalGL: Double
        let healthScore: Int
    }

    struct InstacartItem: Identifiable {
        let id = UUID()
        let name: String
        let classification: String
        let glycemicIndex: Double?
    }

    struct WeightReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let weightKg: Double
        let delta: Double?
        let classification: String
    }

    struct ZombieScrollSession: Identifiable {
        let id = UUID()
        let timestamp: Date
        let durationMinutes: Double
        let itemsViewed: Int
        let itemsPurchased: Int
        let impulseRatio: Double
        var zombieScore: Int {
            Int(impulseRatio * 100)
        }
    }

    struct ScreenTimeSession: Identifiable {
        let id = UUID()
        let timestamp: Date
        let appName: String
        let category: String
        let minutes: Int
        let pickups: Int
    }

    struct SkinConditionSnapshot: Identifiable {
        let id = UUID()
        let type: String
        let uiScore: Int
        let severity: Double
    }

    struct SkinSnapshot {
        let timestamp: Date
        let overallScore: Int
        let source: String
        let conditions: [SkinConditionSnapshot]
    }

    struct EnvironmentReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let temperatureCelsius: Double
        let humidity: Double
        let aqiUS: Int
        let uvIndex: Double
        let pollenIndex: Int
        let healthImpact: String
        let classification: String
    }

    // MARK: - Mock Data Pools

    private typealias DDEntry = (name: String, ingredients: [String], gl: Double)
    private static let doordashPool: [DDEntry] = [
        ("Paneer Methi Garlic",   ["paneer", "methi leaves", "garlic", "cream", "spices"],              32),
        ("Sabudana Vada",         ["sabudana", "peanuts", "potato", "cumin", "green chilli"],            45),
        ("Pizza Margherita",      ["pizza dough", "mozzarella", "tomato sauce", "basil"],               38),
        ("Prawns Biryani",        ["basmati rice", "prawns", "fried onions", "saffron", "spices"],      28),
        ("Pav Bhaji",             ["pav bread", "potato", "tomato", "butter", "peas", "spices"],        41),
        ("Chicken Tikka Masala",  ["chicken", "tomato gravy", "cream", "spices", "naan"],               29),
        ("Pad Thai",              ["rice noodles", "tofu", "peanuts", "egg", "tamarind"],               31),
        ("Caesar Salad",          ["romaine", "croutons", "parmesan", "caesar dressing"],                8),
        ("Dal Makhani",           ["black lentils", "kidney beans", "butter", "cream", "spices"],       18),
        ("Chole Bhature",         ["chickpeas", "refined flour", "spices", "onions", "tamarind"],       48),
        ("Paneer Butter Masala",  ["paneer", "butter", "tomato", "cream", "cashews"],                   22),
        ("Chicken Fried Rice",    ["rice", "chicken", "egg", "soy sauce", "spring onion"],              35),
        ("Masala Dosa",           ["fermented rice batter", "potato masala", "sambar", "coconut chutney"], 30),
        ("Aloo Paratha",          ["whole wheat flour", "potato", "butter", "spices"],                  38),
        ("Veg Biryani",           ["basmati rice", "mixed vegetables", "saffron", "fried onions"],      27),
        ("Mango Lassi",           ["yogurt", "mango pulp", "sugar", "cardamom"],                        15),
        ("Butter Chicken",        ["chicken", "butter", "tomato", "cream", "fenugreek"],                26),
        ("Poha",                  ["flattened rice", "peanuts", "onion", "turmeric", "mustard seeds"],  24),
    ]

    private typealias ICItem = (name: String, gi: Double?)
    private typealias ICEntry = (label: String, items: [ICItem], gl: Double)
    private static let instacartPool: [ICEntry] = [
        ("Fresh Vegetables Pack",
         [("spinach", 15), ("tomatoes", 30), ("onions", 10), ("garlic", nil), ("cilantro", nil)],
         5),
        ("Indian Grocery Basics",
         [("moong daal", 25), ("toor daal", 22), ("basmati rice", 64), ("ghee", nil)],
         22),
        ("Dairy & Coconut",
         [("milk", 32), ("coconut", 45), ("paneer", nil), ("curd", 36)],
         12),
        ("Snack Basket",
         [("oats", 55), ("almonds", 15), ("dates", 42), ("honey", 58)],
         20),
        ("Weekly Staples",
         [("garlic", nil), ("ginger", nil), ("cilantro", nil), ("green chillies", nil), ("lemon", 20)],
         3),
        ("Grain Pack",
         [("brown rice", 50), ("quinoa", 53), ("atta flour", 54), ("poha", 70)],
         25),
        ("Protein Pack",
         [("eggs", nil), ("tofu", 15), ("moong sprouts", 25), ("peanuts", 14)],
         8),
        ("South Indian Essentials",
         [("coconut", 45), ("curry leaves", nil), ("mustard seeds", nil), ("urad daal", 43), ("tamarind", nil)],
         10),
        ("Baking & Sweets",
         [("whole wheat flour", 54), ("jaggery", 55), ("coconut milk", 40), ("cardamom", nil)],
         18),
        ("Healthy Breakfast Kit",
         [("rolled oats", 55), ("chia seeds", 1), ("flax seeds", 35), ("milk", 32), ("banana", 51)],
         16),
    ]

    private static let rotimatics: [(flourType: String, isWholegrain: Bool, glRange: ClosedRange<Double>)] = [
        ("Whole Wheat Rotis",       true,  18...24),
        ("Multigrain Rotis",        true,  14...20),
        ("White Maida Rotis",       false, 28...36),
        ("Bajra (Millet) Rotis",    true,  12...18),
        ("Jowar (Sorghum) Rotis",   true,  15...21),
    ]

    private static let ipRecipes: [(recipe: String, isPressure: Bool, bioavailability: ClosedRange<Double>)] = [
        ("Rajma Masala",   true,  0.90...0.95),
        ("Chicken Curry",  true,  0.92...0.97),
        ("Dal Tadka",      true,  0.86...0.92),
        ("Khichdi",        false, 0.72...0.78),
        ("Palak Paneer",   true,  0.89...0.94),
        ("Mutton Stew",    false, 0.70...0.76),
        ("Kadhi Pakora",   false, 0.68...0.75),
        ("Chana Masala",   true,  0.88...0.93),
    ]

    private static let envConditions: [(temp: Double, humidity: Double, aqi: Int, uv: Double, pollen: Int, impact: String)] = [
        (23, 45,  28, 4.5, 2, "No significant health risks"),
        (18, 78,  42, 2.1, 3, "High humidity, moderate pollen"),
        (26, 55,  95, 6.8, 1, "Poor air quality, High UV"),
        (15, 40,  18, 1.2, 4, "High pollen"),
        (34, 30,  35, 8.5, 1, "Extreme heat, High UV"),
        (21, 60,  22, 0.5, 2, "No significant health risks"),
        (29, 38,  15, 7.2, 1, "High UV exposure"),
        (12, 85,  12, 0.3, 5, "High humidity, high pollen"),
    ]

    private static let screenTimeApps: [(name: String, category: String)] = [
        ("Instagram", "social"),
        ("YouTube", "video"),
        ("Reddit", "community"),
        ("Safari", "browsing"),
        ("WhatsApp", "messaging"),
        ("Slack", "work"),
        ("LinkedIn", "career"),
        ("Netflix", "video"),
    ]

    // MARK: - Load / Refresh

    func load(from appState: AppState) {
        self.appState = appState
        refresh(from: appState)
    }

    func refresh(from appState: AppState? = nil) {
        if let appState {
            self.appState = appState
        }

        let now = Date()
        let cutoff24h = now.addingTimeInterval(-24 * 3_600)

        let generated = generate30DayData(now: now)
        var historyEvents = generated.historyEvents
        if let skinSync = syncedSkinData(now: now) {
            latestSkinSnapshot = skinSync.snapshot
            historyEvents.append(contentsOf: skinSync.historyEvents)
        } else {
            latestSkinSnapshot = nil
        }

        // Persist full 30-day dataset for Ask VITA context.
        IntegrationHistoryStore.save(events: historyEvents, generatedAt: now)

        // UI must remain 24h only.
        doordashOrders = generated.doordashOrders.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        rotimaticSessions = generated.rotimaticSessions.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        instantPotPrograms = generated.instantPotPrograms.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        instacartOrders = generated.instacartOrders.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        weightReadings = generated.weightReadings.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        zombieScrollSessions = generated.zombieScrollSessions.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        screenTimeSessions = generated.screenTimeSessions.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }

        if let syncedEnvironment = syncedEnvironmentReadings(now: now) {
            environmentReadings = syncedEnvironment.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        } else {
            environmentReadings = generated.environmentReadings.filter { $0.timestamp >= cutoff24h }.sorted { $0.timestamp > $1.timestamp }
        }

        if let latestWatch = generated.watchSnapshots.max(by: { $0.timestamp < $1.timestamp }) {
            watchSyncDate = latestWatch.timestamp
            watchHRV = latestWatch.hrv
            watchHR = latestWatch.hr
            watchSteps = latestWatch.steps
        }
    }

    private func syncedEnvironmentReadings(now: Date) -> [EnvironmentReading]? {
        guard let appState else { return nil }

        let calendar = Calendar.current
        let lookback = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        guard let conditions = try? appState.healthGraph.queryEnvironment(from: lookback, to: now),
              !conditions.isEmpty else {
            return nil
        }

        return conditions.suffix(24).map { condition in
            EnvironmentReading(
                timestamp: condition.timestamp,
                temperatureCelsius: condition.temperatureCelsius,
                humidity: condition.humidity,
                aqiUS: condition.aqiUS,
                uvIndex: condition.uvIndex,
                pollenIndex: condition.pollenIndex,
                healthImpact: healthImpact(for: condition),
                classification: "environment: AQI \(condition.aqiUS), UV \(Int(condition.uvIndex))"
            )
        }
    }

    private struct SyncedSkinData {
        let snapshot: SkinSnapshot
        let historyEvents: [IntegrationHistoryEvent]
    }

    private func syncedSkinData(now: Date) -> SyncedSkinData? {
        guard let appState else { return nil }
        let lookback = now.addingTimeInterval(-365 * 86_400)
        let records = (try? appState.healthGraph.querySkinAnalyses(from: lookback, to: now)) ?? []
        let realRecords = records.filter { $0.apiSource.lowercased() != "demo" }
        guard let latest = realRecords.first else { return nil }

        let snapshot = SkinSnapshot(
            timestamp: latest.timestamp,
            overallScore: latest.overallScore,
            source: latest.apiSource,
            conditions: latest.conditions.map {
                SkinConditionSnapshot(
                    type: $0.type,
                    uiScore: $0.uiScore,
                    severity: $0.severity
                )
            }
        )

        let historyEvents = realRecords.flatMap { record in
            record.conditions.map { condition in
                IntegrationHistoryEvent(
                    source: "skin_scan",
                    category: "skin",
                    item: condition.type,
                    timestamp: record.timestamp,
                    notes: [
                        "ui \(condition.uiScore)",
                        "sev \(String(format: "%.2f", condition.severity))"
                    ]
                )
            }
        }

        return SyncedSkinData(snapshot: snapshot, historyEvents: historyEvents)
    }

    // MARK: - 30 Day Mock Generation

    private struct WatchSnapshot {
        let timestamp: Date
        let hrv: Double
        let hr: Double
        let steps: Int
    }

    private struct GeneratedData {
        let doordashOrders: [DoorDashOrder]
        let rotimaticSessions: [RotimaticSession]
        let instantPotPrograms: [InstantPotProgram]
        let instacartOrders: [InstacartOrder]
        let weightReadings: [WeightReading]
        let zombieScrollSessions: [ZombieScrollSession]
        let screenTimeSessions: [ScreenTimeSession]
        let environmentReadings: [EnvironmentReading]
        let watchSnapshots: [WatchSnapshot]
        let historyEvents: [IntegrationHistoryEvent]
    }

    private func generate30DayData(now: Date) -> GeneratedData {
        var dd: [DoorDashOrder] = []
        var roti: [RotimaticSession] = []
        var ip: [InstantPotProgram] = []
        var ic: [InstacartOrder] = []
        var weight: [WeightReading] = []
        var zombie: [ZombieScrollSession] = []
        var screenTime: [ScreenTimeSession] = []
        var env: [EnvironmentReading] = []
        var watch: [WatchSnapshot] = []
        var events: [IntegrationHistoryEvent] = []

        let baseWeight = Double.random(in: 68.5...73.5)

        for day in 0..<30 {
            let dayBase = now.addingTimeInterval(-Double(day) * 86_400)

            // DoorDash 0-2/day
            for _ in 0..<Int.random(in: 0...2) {
                guard let item = Self.doordashPool.randomElement() else { continue }
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let gl = (item.gl + Double.random(in: -3...3)).clamped(to: 5...60)
                let order = DoorDashOrder(
                    name: item.name,
                    classification: "meal: \(item.name)",
                    timestamp: t,
                    glycemicLoad: gl,
                    ingredients: item.ingredients,
                    glucoseImpact: impactLabel(for: gl)
                )
                dd.append(order)
                events.append(IntegrationHistoryEvent(
                    source: "doordash",
                    category: "meal",
                    item: item.name,
                    timestamp: t,
                    notes: ["GL \(Int(gl))", order.glucoseImpact]
                ))
            }

            // Rotimatic 0-1/day
            if Bool.random(), let r = Self.rotimatics.randomElement() {
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let gl = Double.random(in: r.glRange)
                let session = RotimaticSession(
                    flourType: r.flourType,
                    classification: "meal prep: \(r.flourType)",
                    count: Int.random(in: 4...10),
                    timestamp: t,
                    glycemicLoad: gl,
                    glucoseImpact: r.isWholegrain ? "Moderate, steady curve" : "Sharp spike + crash"
                )
                roti.append(session)
                events.append(IntegrationHistoryEvent(
                    source: "rotimatic",
                    category: "meal_prep",
                    item: r.flourType,
                    timestamp: t,
                    notes: ["count \(session.count)", "GL \(Int(gl))"]
                ))
            }

            // Instant Pot 0-1/day
            if Bool.random(), let r = Self.ipRecipes.randomElement() {
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let bio = Double.random(in: r.bioavailability)
                let program = InstantPotProgram(
                    recipe: r.recipe,
                    classification: "cooked meal: \(r.recipe)",
                    mode: r.isPressure ? "Pressure Cook" : "Slow Cook",
                    timestamp: t,
                    bioavailability: (bio * 100).rounded() / 100,
                    note: r.isPressure ? "95% lectin deactivation" : "~60% lectin deactivation — consider pressure cook"
                )
                ip.append(program)
                events.append(IntegrationHistoryEvent(
                    source: "instant_pot",
                    category: "cooked_meal",
                    item: r.recipe,
                    timestamp: t,
                    notes: [program.mode, "bio \(String(format: "%.2f", bio))"]
                ))
            }

            // Instacart every ~2 days
            if day % 2 == 0, let entry = Self.instacartPool.randomElement() {
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let gl = (entry.gl + Double.random(in: -2...2)).clamped(to: 2...60)
                let score: Int = gl < 12 ? Int.random(in: 82...95) : (gl < 25 ? Int.random(in: 60...80) : Int.random(in: 35...58))
                let order = InstacartOrder(
                    label: entry.label,
                    classification: "grocery basket: \(entry.label)",
                    timestamp: t,
                    items: entry.items.map { InstacartItem(name: $0.name, classification: "grocery: \($0.name)", glycemicIndex: $0.gi) },
                    totalGL: gl,
                    healthScore: score
                )
                ic.append(order)
                for item in order.items {
                    events.append(IntegrationHistoryEvent(
                        source: "instacart",
                        category: "grocery",
                        item: item.name,
                        timestamp: t,
                        notes: item.glycemicIndex.map { ["GI \(Int($0))"] } ?? []
                    ))
                }
            }

            // Weight daily
            let tWeight = dayBase.addingTimeInterval(-Double.random(in: 0...7_200))
            let w = (baseWeight + Double.random(in: -0.4...0.4) - Double(day) * 0.03)
            let roundedW = (w * 10).rounded() / 10
            let reading = WeightReading(
                timestamp: tWeight,
                weightKg: roundedW,
                delta: day == 29 ? nil : (Double.random(in: -0.35...0.35) * 10).rounded() / 10,
                classification: "body metric: weight \(String(format: "%.1f", roundedW))kg"
            )
            weight.append(reading)
            events.append(IntegrationHistoryEvent(
                source: "body_scale",
                category: "body_metric",
                item: "weight",
                timestamp: tWeight,
                notes: [String(format: "%.1fkg", roundedW)]
            ))

            // Zombie scrolling ~40%
            if Double.random(in: 0...1) < 0.4 {
                let viewed = Int.random(in: 20...90)
                let purchased = Int.random(in: 2...max(2, min(15, viewed / 4)))
                let duration = Double.random(in: 10...50)
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let z = ZombieScrollSession(
                    timestamp: t,
                    durationMinutes: (duration * 10).rounded() / 10,
                    itemsViewed: viewed,
                    itemsPurchased: purchased,
                    impulseRatio: (Double(purchased) / Double(viewed) * 100).rounded() / 100
                )
                zombie.append(z)
                events.append(IntegrationHistoryEvent(
                    source: "behavior",
                    category: "scrolling",
                    item: "impulse_browsing",
                    timestamp: t,
                    notes: ["\(Int(z.durationMinutes))min", "ratio \(Int(z.impulseRatio * 100))%"]
                ))
            }

            // Screen Time sessions 2–5/day
            let sessionCount = Int.random(in: 2...5)
            for _ in 0..<sessionCount {
                guard let app = Self.screenTimeApps.randomElement() else { continue }
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let minutes = Int.random(in: 8...96)
                let pickups = Int.random(in: 2...24)
                let session = ScreenTimeSession(
                    timestamp: t,
                    appName: app.name,
                    category: app.category,
                    minutes: minutes,
                    pickups: pickups
                )
                screenTime.append(session)
                events.append(IntegrationHistoryEvent(
                    source: "screen_time",
                    category: "screen_time",
                    item: app.name,
                    timestamp: t,
                    notes: ["\(minutes)min", "\(pickups) pickups", app.category]
                ))
            }

            // Environment daily
            if let c = Self.envConditions.randomElement() {
                let t = dayBase.addingTimeInterval(-Double.random(in: 0...82_800))
                let e = EnvironmentReading(
                    timestamp: t,
                    temperatureCelsius: (c.temp + Double.random(in: -1.5...1.5) * 10).rounded() / 10,
                    humidity: (c.humidity + Double.random(in: -4...4)).clamped(to: 10...100),
                    aqiUS: (c.aqi + Int.random(in: -8...8)).clamped(to: 5...200),
                    uvIndex: (c.uv + Double.random(in: -0.4...0.4)).clamped(to: 0...11),
                    pollenIndex: c.pollen,
                    healthImpact: c.impact,
                    classification: "environment: AQI \((c.aqi + Int.random(in: -8...8)).clamped(to: 5...200)), UV \(String(format: "%.1f", c.uv))"
                )
                env.append(e)
                events.append(IntegrationHistoryEvent(
                    source: "environment",
                    category: "environment",
                    item: "aqi_uv_pollen",
                    timestamp: t,
                    notes: ["AQI \(e.aqiUS)", "UV \(String(format: "%.1f", e.uvIndex))", "Pollen \(e.pollenIndex)"]
                ))
            }

            // Watch daily snapshot
            let tWatch = dayBase.addingTimeInterval(-Double.random(in: 0...3_600))
            let snapshot = WatchSnapshot(
                timestamp: tWatch,
                hrv: (Double.random(in: 34...82) * 10).rounded() / 10,
                hr: (Double.random(in: 54...91) * 10).rounded() / 10,
                steps: Int.random(in: 1800...13_500)
            )
            watch.append(snapshot)
            events.append(IntegrationHistoryEvent(
                source: "apple_watch",
                category: "wearable_metric",
                item: "hr_hrv_steps",
                timestamp: tWatch,
                notes: ["HR \(Int(snapshot.hr))", "HRV \(Int(snapshot.hrv))", "steps \(snapshot.steps)"]
            ))
        }

        return GeneratedData(
            doordashOrders: dd,
            rotimaticSessions: roti,
            instantPotPrograms: ip,
            instacartOrders: ic,
            weightReadings: weight,
            zombieScrollSessions: zombie,
            screenTimeSessions: screenTime,
            environmentReadings: env,
            watchSnapshots: watch,
            historyEvents: events
        )
    }

    // MARK: - Helpers

    private func healthImpact(for condition: EnvironmentalCondition) -> String {
        let risks = condition.healthRisks
        guard !risks.isEmpty else { return "No significant health risks" }

        var labels: [String] = []
        if risks.contains(.highAQI) { labels.append("Poor air quality") }
        if risks.contains(.highUV) { labels.append("High UV") }
        if risks.contains(.highPollen) { labels.append("High pollen") }
        if risks.contains(.highHumidity) { labels.append("High humidity") }
        if risks.contains(.extremeHeat) { labels.append("Extreme heat") }
        if risks.contains(.extremeCold) { labels.append("Extreme cold") }
        return labels.joined(separator: ", ")
    }

    private func impactLabel(for gl: Double) -> String {
        if gl > 35 { return "High spike expected" }
        if gl > 20 { return "Moderate spike" }
        return "Minimal impact"
    }
}

// MARK: - Clamping

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
