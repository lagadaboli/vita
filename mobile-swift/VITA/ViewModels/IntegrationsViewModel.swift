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

    // DoorDash orders
    var doordashOrders: [DoorDashOrder] = []

    // Rotimatic sessions
    var rotimaticSessions: [RotimaticSession] = []

    // Instant Pot programs
    var instantPotPrograms: [InstantPotProgram] = []

    // Instacart orders
    var instacartOrders: [InstacartOrder] = []

    // Body scale / weight
    var weightReadings: [WeightReading] = []

    // Zombie scrolling sessions
    var zombieScrollSessions: [ZombieScrollSession] = []

    // Environment readings
    var environmentReadings: [EnvironmentReading] = []

    // MARK: - Structs

    struct DoorDashOrder: Identifiable {
        let id = UUID()
        let name: String
        let timestamp: Date
        let glycemicLoad: Double
        let ingredients: [String]
        let glucoseImpact: String
    }

    struct RotimaticSession: Identifiable {
        let id = UUID()
        let flourType: String
        let count: Int
        let timestamp: Date
        let glycemicLoad: Double
        let glucoseImpact: String
    }

    struct InstantPotProgram: Identifiable {
        let id = UUID()
        let recipe: String
        let mode: String
        let timestamp: Date
        let bioavailability: Double
        let note: String
    }

    struct InstacartOrder: Identifiable {
        let id = UUID()
        let label: String
        let timestamp: Date
        let items: [InstacartItem]
        let totalGL: Double
        let healthScore: Int
    }

    struct InstacartItem: Identifiable {
        let id = UUID()
        let name: String
        let glycemicIndex: Double?
    }

    struct WeightReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let weightKg: Double
        let delta: Double?
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

    struct EnvironmentReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let temperatureCelsius: Double
        let humidity: Double
        let aqiUS: Int
        let uvIndex: Double
        let pollenIndex: Int
        let healthImpact: String
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

    // MARK: - Load / Refresh

    func load(from appState: AppState) {
        refresh()
    }

    func refresh() {
        let now = Date()

        // Apple Watch — randomised each refresh
        watchHRV = (Double.random(in: 34...82) * 10).rounded() / 10
        watchHR = (Double.random(in: 54...91) * 10).rounded() / 10
        watchSteps = Int.random(in: 1800...13500)
        watchSyncDate = now.addingTimeInterval(-Double.random(in: 90...900))

        // DoorDash — pick 4–5 random orders
        let ddCount = Int.random(in: 4...5)
        doordashOrders = Self.doordashPool.shuffled().prefix(ddCount).enumerated().map { index, item in
            let daysBack = Double(index) * Double.random(in: 1.2...2.8) + Double.random(in: 0...0.5)
            let gl = (item.gl + Double.random(in: -3...3)).clamped(to: 5...60)
            return DoorDashOrder(
                name: item.name,
                timestamp: now.addingTimeInterval(-daysBack * 86400),
                glycemicLoad: gl,
                ingredients: item.ingredients,
                glucoseImpact: impactLabel(for: gl)
            )
        }

        // Rotimatic — pick 2
        rotimaticSessions = Self.rotimatics.shuffled().prefix(2).enumerated().map { index, r in
            let gl = Double.random(in: r.glRange)
            return RotimaticSession(
                flourType: r.flourType,
                count: Int.random(in: 4...10),
                timestamp: now.addingTimeInterval(-Double(index + 1) * 86400 * Double.random(in: 1...3)),
                glycemicLoad: gl,
                glucoseImpact: r.isWholegrain ? "Moderate, steady curve" : "Sharp spike + crash"
            )
        }

        // Instant Pot — pick 2
        instantPotPrograms = Self.ipRecipes.shuffled().prefix(2).enumerated().map { index, r in
            let bio = Double.random(in: r.bioavailability)
            return InstantPotProgram(
                recipe: r.recipe,
                mode: r.isPressure ? "Pressure Cook" : "Slow Cook",
                timestamp: now.addingTimeInterval(-Double(index + 1) * 86400 * Double.random(in: 0.5...2.5)),
                bioavailability: (bio * 100).rounded() / 100,
                note: r.isPressure ? "95% lectin deactivation" : "~60% lectin deactivation — consider pressure cook"
            )
        }

        // Instacart — pick 2–3 orders
        let icCount = Int.random(in: 2...3)
        instacartOrders = Self.instacartPool.shuffled().prefix(icCount).enumerated().map { index, item in
            let gl = (item.gl + Double.random(in: -2...2)).clamped(to: 2...60)
            let score: Int
            if gl < 12      { score = Int.random(in: 82...95) }
            else if gl < 25 { score = Int.random(in: 60...80) }
            else            { score = Int.random(in: 35...58) }
            return InstacartOrder(
                label: item.label,
                timestamp: now.addingTimeInterval(-Double(index) * 86400 * Double.random(in: 1...4)),
                items: item.items.map { InstacartItem(name: $0.name, glycemicIndex: $0.gi) },
                totalGL: gl,
                healthScore: score
            )
        }

        // Weight — 7 days with slight variation
        let baseWeight = Double.random(in: 68.5...73.5)
        weightReadings = (0..<7).map { daysBack in
            let w = (baseWeight + Double.random(in: -0.4...0.4) - Double(daysBack) * 0.04)
            let rounded = (w * 10).rounded() / 10
            return WeightReading(
                timestamp: now.addingTimeInterval(-Double(daysBack) * 86400),
                weightKg: rounded,
                delta: daysBack < 6 ? (Double.random(in: -0.35...0.35) * 10).rounded() / 10 : nil
            )
        }

        // Zombie scrolling — present ~40% of the time
        if Double.random(in: 0...1) < 0.4 {
            let duration = Double.random(in: 10...50)
            let viewed = Int.random(in: 20...90)
            let purchased = Int.random(in: 2...max(2, min(15, viewed / 4)))
            zombieScrollSessions = [
                ZombieScrollSession(
                    timestamp: now.addingTimeInterval(-Double.random(in: 1800...72000)),
                    durationMinutes: (duration * 10).rounded() / 10,
                    itemsViewed: viewed,
                    itemsPurchased: purchased,
                    impulseRatio: (Double(purchased) / Double(viewed) * 100).rounded() / 100
                )
            ]
        } else {
            zombieScrollSessions = []
        }

        // Environment — pick 3 different days
        environmentReadings = Self.envConditions.shuffled().prefix(3).enumerated().map { index, c in
            EnvironmentReading(
                timestamp: now.addingTimeInterval(-Double(index) * 86400),
                temperatureCelsius: (c.temp + Double.random(in: -1.5...1.5) * 10).rounded() / 10,
                humidity: (c.humidity + Double.random(in: -4...4)).clamped(to: 10...100),
                aqiUS: (c.aqi + Int.random(in: -8...8)).clamped(to: 5...200),
                uvIndex: (c.uv + Double.random(in: -0.4...0.4)).clamped(to: 0...11),
                pollenIndex: c.pollen,
                healthImpact: c.impact
            )
        }
    }

    // MARK: - Helpers

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
