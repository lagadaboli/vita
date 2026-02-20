import Foundation

/// Pre-defined day scenarios with realistic meal/metric/behavior data.
public enum SampleDataScenarios {

    // MARK: - Data Templates

    public struct MealTemplate {
        let hourOffset: Double
        let source: MealEvent.MealSource
        let eventType: MealEvent.MealEventType
        let ingredients: [MealEvent.Ingredient]
        let cookingMethod: String?
        let glycemicLoad: Double
        let bioavailabilityModifier: Double?
        let confidence: Double
        let label: String

        func toMealEvent(dayStart: Date) -> MealEvent {
            MealEvent(
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                source: source,
                eventType: eventType,
                ingredients: ingredients,
                cookingMethod: cookingMethod,
                estimatedGlycemicLoad: glycemicLoad,
                bioavailabilityModifier: bioavailabilityModifier,
                confidence: confidence
            )
        }
    }

    public struct MetricTemplate {
        let hourOffset: Double
        let metricType: PhysiologicalSample.MetricType
        let value: Double
        let unit: String

        func toPhysiologicalSample(dayStart: Date) -> PhysiologicalSample {
            PhysiologicalSample(
                metricType: metricType,
                value: value,
                unit: unit,
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                source: .appleWatch
            )
        }
    }

    public struct BehaviorTemplate {
        let hourOffset: Double
        let durationMinutes: Double
        let category: BehavioralEvent.BehaviorCategory
        let appName: String
        let dopamineDebt: Double?

        func toBehavioralEvent(dayStart: Date) -> BehavioralEvent {
            BehavioralEvent(
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                duration: durationMinutes * 60,
                category: category,
                appName: appName,
                dopamineDebtScore: dopamineDebt
            )
        }
    }

    public struct InstacartOrderTemplate {
        let hourOffset: Double
        let items: [MealEvent.Ingredient]
        let glycemicLoad: Double
        let healthScore: Int
        let label: String

        func toMealEvent(dayStart: Date) -> MealEvent {
            MealEvent(
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                source: .instacart,
                eventType: .groceryPurchase,
                ingredients: items,
                cookingMethod: nil,
                estimatedGlycemicLoad: glycemicLoad,
                confidence: 0.8
            )
        }
    }

    public struct WeightTemplate {
        let hourOffset: Double
        let weightKg: Double

        func toPhysiologicalSample(dayStart: Date) -> PhysiologicalSample {
            PhysiologicalSample(
                metricType: .bodyWeight,
                value: weightKg,
                unit: "kg",
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                source: .smartScale
            )
        }
    }

    public struct ZombieScrollTemplate {
        let hourOffset: Double
        let durationMinutes: Double
        let itemsViewed: Int
        let itemsPurchased: Int
        let impulseRatio: Double

        func toBehavioralEvent(dayStart: Date) -> BehavioralEvent {
            BehavioralEvent(
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                duration: durationMinutes * 60,
                category: .passiveConsumption,
                appName: "Instacart",
                dopamineDebtScore: impulseRatio * 100,
                metadata: [
                    "itemsViewed": "\(itemsViewed)",
                    "itemsPurchased": "\(itemsPurchased)",
                    "impulseRatio": String(format: "%.2f", impulseRatio),
                    "zombieScroll": "true"
                ]
            )
        }
    }

    public struct EnvironmentTemplate {
        let hourOffset: Double
        let temperatureCelsius: Double
        let humidity: Double
        let aqiUS: Int
        let uvIndex: Double
        let pollenIndex: Int
        let condition: EnvironmentalCondition.WeatherCondition

        func toEnvironmentalCondition(dayStart: Date) -> EnvironmentalCondition {
            EnvironmentalCondition(
                timestamp: dayStart.addingTimeInterval(hourOffset * 3600),
                temperatureCelsius: temperatureCelsius,
                humidity: humidity,
                aqiUS: aqiUS,
                uvIndex: uvIndex,
                pollenIndex: pollenIndex,
                condition: condition
            )
        }
    }

    public struct DayScenario {
        public let meals: [MealTemplate]
        public let hrvSamples: [MetricTemplate]
        public let heartRateSamples: [MetricTemplate]
        public let sleepSamples: [MetricTemplate]
        public let stepSamples: [MetricTemplate]
        public let behaviors: [BehaviorTemplate]
        public let instacartOrders: [InstacartOrderTemplate]
        public let weightReadings: [WeightTemplate]
        public let zombieScrollSessions: [ZombieScrollTemplate]
        public let environmentReadings: [EnvironmentTemplate]

        public init(
            meals: [MealTemplate],
            hrvSamples: [MetricTemplate],
            heartRateSamples: [MetricTemplate],
            sleepSamples: [MetricTemplate],
            stepSamples: [MetricTemplate],
            behaviors: [BehaviorTemplate],
            instacartOrders: [InstacartOrderTemplate] = [],
            weightReadings: [WeightTemplate] = [],
            zombieScrollSessions: [ZombieScrollTemplate] = [],
            environmentReadings: [EnvironmentTemplate] = []
        ) {
            self.meals = meals
            self.hrvSamples = hrvSamples
            self.heartRateSamples = heartRateSamples
            self.sleepSamples = sleepSamples
            self.stepSamples = stepSamples
            self.behaviors = behaviors
            self.instacartOrders = instacartOrders
            self.weightReadings = weightReadings
            self.zombieScrollSessions = zombieScrollSessions
            self.environmentReadings = environmentReadings
        }
    }

    // MARK: - Scenario Selection

    public static func scenario(for dayOffset: Int) -> DayScenario {
        switch dayOffset {
        case -6: return dayMinus6_HealthyDay()
        case -5: return dayMinus5_DoorDashDay()
        case -4: return dayMinus4_WhiteFlourDay()
        case -3: return dayMinus3_SlowCookDay()
        case -2: return dayMinus2_LateMealDay()
        case -1: return dayMinus1_ScreenHeavyDay()
        case 0:  return day0_Today()
        default: return dayMinus6_HealthyDay()
        }
    }

    // MARK: - Day Scenarios

    /// Day -6: Healthy baseline — whole wheat rotis, salad, exercise + healthy Instacart order
    private static func dayMinus6_HealthyDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.0, source: .rotimaticNext, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Whole Wheat Flour", quantityGrams: 120, glycemicIndex: 45, type: "grain"),
                        .init(name: "Ghee", quantityGrams: 10, glycemicIndex: 0, type: "fat"),
                        .init(name: "Dal", quantityGrams: 100, glycemicIndex: 28, type: "legume"),
                    ],
                    cookingMethod: "rotimatic_whole_wheat", glycemicLoad: 22,
                    bioavailabilityModifier: 1.0, confidence: 0.95, label: "Whole Wheat Rotis + Dal"
                ),
                MealTemplate(
                    hourOffset: 13.0, source: .manual, eventType: .manualLog,
                    ingredients: [
                        .init(name: "Mixed Greens", quantityGrams: 150, glycemicIndex: 15, type: "vegetable"),
                        .init(name: "Chicken Breast", quantityGrams: 120, glycemicIndex: 0, type: "protein"),
                        .init(name: "Olive Oil", quantityGrams: 15, glycemicIndex: 0, type: "fat"),
                        .init(name: "Quinoa", quantityGrams: 80, glycemicIndex: 53, type: "grain"),
                    ],
                    cookingMethod: "grilled", glycemicLoad: 18,
                    bioavailabilityModifier: 1.0, confidence: 0.8, label: "Grilled Chicken Salad"
                ),
                MealTemplate(
                    hourOffset: 19.0, source: .instantPot, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Chickpeas", quantityGrams: 150, glycemicIndex: 28, type: "legume"),
                        .init(name: "Tomatoes", quantityGrams: 100, glycemicIndex: 15, type: "vegetable"),
                        .init(name: "Onion", quantityGrams: 50, glycemicIndex: 10, type: "vegetable"),
                        .init(name: "Spices", quantityGrams: 10, type: "spice"),
                    ],
                    cookingMethod: "pressure_cook", glycemicLoad: 16,
                    bioavailabilityModifier: 1.3, confidence: 0.9, label: "Pressure-Cooked Chana Masala"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 58, stressHours: [], suppressionPercent: 0),
            heartRateSamples: generateHRSamples(resting: 62),
            sleepSamples: generateSleepSamples(totalHours: 7.8, deepPercent: 0.22, remPercent: 0.25),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 9200, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 120, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 17, durationMinutes: 45, category: .exercise, appName: "Peloton", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 20, durationMinutes: 20, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 25),
            ],
            instacartOrders: [
                InstacartOrderTemplate(
                    hourOffset: 10.0,
                    items: [
                        .init(name: "Organic Spinach", quantityGrams: 200, glycemicIndex: 15, type: "vegetable"),
                        .init(name: "Red Lentils", quantityGrams: 500, glycemicIndex: 26, type: "legume"),
                        .init(name: "Brown Rice", quantityGrams: 1000, glycemicIndex: 50, type: "grain"),
                        .init(name: "Chicken Breast", quantityGrams: 500, glycemicIndex: 0, type: "protein"),
                        .init(name: "Olive Oil", quantityGrams: 500, glycemicIndex: 0, type: "fat"),
                    ],
                    glycemicLoad: 15, healthScore: 85, label: "Healthy Weekly Groceries"
                ),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.5),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 24, humidity: 50, aqiUS: 42, uvIndex: 5, pollenIndex: 3, condition: .clear),
            ]
        )
    }

    /// Day -5: DoorDash day — Chicken Tikka Masala, Pizza
    private static func dayMinus5_DoorDashDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.5, source: .manual, eventType: .manualLog,
                    ingredients: [
                        .init(name: "Oatmeal", quantityGrams: 60, glycemicIndex: 55, type: "grain"),
                        .init(name: "Blueberries", quantityGrams: 50, glycemicIndex: 25, type: "fruit"),
                    ],
                    cookingMethod: "boiled", glycemicLoad: 15,
                    bioavailabilityModifier: 1.0, confidence: 0.7, label: "Oatmeal & Berries"
                ),
                MealTemplate(
                    hourOffset: 12.5, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Chicken Tikka", quantityGrams: 200, glycemicIndex: 0, type: "protein"),
                        .init(name: "Masala Sauce", quantityGrams: 150, glycemicIndex: 20, type: "sauce"),
                        .init(name: "Basmati Rice", quantityGrams: 200, glycemicIndex: 65, type: "grain"),
                        .init(name: "Naan Bread", quantityGrams: 100, glycemicIndex: 71, type: "grain"),
                    ],
                    cookingMethod: "restaurant", glycemicLoad: 42,
                    bioavailabilityModifier: 1.0, confidence: 0.6, label: "Chicken Tikka Masala"
                ),
                MealTemplate(
                    hourOffset: 19.5, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Pizza Dough", quantityGrams: 180, glycemicIndex: 80, type: "grain"),
                        .init(name: "Mozzarella", quantityGrams: 100, glycemicIndex: 0, type: "dairy"),
                        .init(name: "Tomato Sauce", quantityGrams: 60, glycemicIndex: 15, type: "sauce"),
                        .init(name: "Pepperoni", quantityGrams: 50, glycemicIndex: 0, type: "protein"),
                    ],
                    cookingMethod: "restaurant", glycemicLoad: 38,
                    bioavailabilityModifier: 1.0, confidence: 0.55, label: "Pepperoni Pizza"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 52, stressHours: [14, 15, 21], suppressionPercent: 18),
            heartRateSamples: generateHRSamples(resting: 66),
            sleepSamples: generateSleepSamples(totalHours: 7.2, deepPercent: 0.18, remPercent: 0.22),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 6100, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 180, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 14, durationMinutes: 30, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 35),
                BehaviorTemplate(hourOffset: 15, durationMinutes: 60, category: .stressSignal, appName: "Slack", dopamineDebt: 40),
                BehaviorTemplate(hourOffset: 21, durationMinutes: 90, category: .passiveConsumption, appName: "Netflix", dopamineDebt: 45),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.3),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 26, humidity: 55, aqiUS: 55, uvIndex: 6, pollenIndex: 4, condition: .clear),
            ]
        )
    }

    /// Day -4: White flour roti day — high GL, glucose spike + crash + fatigue
    private static func dayMinus4_WhiteFlourDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.0, source: .rotimaticNext, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "White Flour (Maida)", quantityGrams: 150, glycemicIndex: 75, type: "grain"),
                        .init(name: "Butter", quantityGrams: 15, glycemicIndex: 0, type: "fat"),
                        .init(name: "Potato Curry", quantityGrams: 200, glycemicIndex: 78, type: "vegetable"),
                    ],
                    cookingMethod: "rotimatic_white_flour", glycemicLoad: 48,
                    bioavailabilityModifier: 1.0, confidence: 0.95, label: "White Flour Rotis + Potato Curry"
                ),
                MealTemplate(
                    hourOffset: 13.0, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Pad Thai Noodles", quantityGrams: 250, glycemicIndex: 72, type: "grain"),
                        .init(name: "Shrimp", quantityGrams: 100, glycemicIndex: 0, type: "protein"),
                        .init(name: "Peanuts", quantityGrams: 30, glycemicIndex: 14, type: "nut"),
                        .init(name: "Tamarind Sauce", quantityGrams: 50, glycemicIndex: 30, type: "sauce"),
                    ],
                    cookingMethod: "stir_fried", glycemicLoad: 44,
                    bioavailabilityModifier: 1.0, confidence: 0.55, label: "Pad Thai"
                ),
                MealTemplate(
                    hourOffset: 19.0, source: .rotimaticNext, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Whole Wheat Flour", quantityGrams: 100, glycemicIndex: 45, type: "grain"),
                        .init(name: "Palak Paneer", quantityGrams: 200, glycemicIndex: 15, type: "vegetable"),
                    ],
                    cookingMethod: "rotimatic_whole_wheat", glycemicLoad: 20,
                    bioavailabilityModifier: 1.0, confidence: 0.9, label: "Whole Wheat Rotis + Palak Paneer"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 45, stressHours: [9, 10, 14, 15], suppressionPercent: 22),
            heartRateSamples: generateHRSamples(resting: 68),
            sleepSamples: generateSleepSamples(totalHours: 7.0, deepPercent: 0.16, remPercent: 0.20),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 5400, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 90, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 11, durationMinutes: 60, category: .stressSignal, appName: "Zoom", dopamineDebt: 30),
                BehaviorTemplate(hourOffset: 14, durationMinutes: 45, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 55),
                BehaviorTemplate(hourOffset: 20, durationMinutes: 60, category: .passiveConsumption, appName: "Netflix", dopamineDebt: 40),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.8),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 35, humidity: 40, aqiUS: 155, uvIndex: 9, pollenIndex: 5, condition: .hot),
            ]
        )
    }

    /// Day -3: Slow cook day — beans with lectin retention, GI issues
    private static func dayMinus3_SlowCookDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.0, source: .manual, eventType: .manualLog,
                    ingredients: [
                        .init(name: "Eggs", quantityGrams: 120, glycemicIndex: 0, type: "protein"),
                        .init(name: "Avocado", quantityGrams: 80, glycemicIndex: 10, type: "fruit"),
                        .init(name: "Sourdough Toast", quantityGrams: 60, glycemicIndex: 54, type: "grain"),
                    ],
                    cookingMethod: "scrambled", glycemicLoad: 14,
                    bioavailabilityModifier: 1.0, confidence: 0.8, label: "Eggs & Avocado Toast"
                ),
                MealTemplate(
                    hourOffset: 13.5, source: .instantPot, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Kidney Beans", quantityGrams: 200, glycemicIndex: 24, type: "legume"),
                        .init(name: "Tomatoes", quantityGrams: 150, glycemicIndex: 15, type: "vegetable"),
                        .init(name: "Onion", quantityGrams: 80, glycemicIndex: 10, type: "vegetable"),
                        .init(name: "Rice", quantityGrams: 150, glycemicIndex: 65, type: "grain"),
                    ],
                    cookingMethod: "slow_cook", glycemicLoad: 30,
                    bioavailabilityModifier: 0.7, confidence: 0.85, label: "Slow-Cooked Rajma Rice"
                ),
                MealTemplate(
                    hourOffset: 19.5, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Sushi Rice", quantityGrams: 200, glycemicIndex: 73, type: "grain"),
                        .init(name: "Salmon", quantityGrams: 120, glycemicIndex: 0, type: "protein"),
                        .init(name: "Nori", quantityGrams: 10, glycemicIndex: 0, type: "vegetable"),
                        .init(name: "Soy Sauce", quantityGrams: 15, glycemicIndex: 5, type: "sauce"),
                    ],
                    cookingMethod: "raw", glycemicLoad: 34,
                    bioavailabilityModifier: 1.0, confidence: 0.5, label: "Salmon Sushi Platter"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 48, stressHours: [15, 16, 17], suppressionPercent: 15),
            heartRateSamples: generateHRSamples(resting: 65),
            sleepSamples: generateSleepSamples(totalHours: 7.5, deepPercent: 0.19, remPercent: 0.23),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 7300, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 150, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 15, durationMinutes: 30, category: .stressSignal, appName: "Slack", dopamineDebt: 35),
                BehaviorTemplate(hourOffset: 20, durationMinutes: 30, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 30),
            ],
            instacartOrders: [
                InstacartOrderTemplate(
                    hourOffset: 11.0,
                    items: [
                        .init(name: "White Bread", quantityGrams: 500, glycemicIndex: 75, type: "grain"),
                        .init(name: "Potato Chips", quantityGrams: 300, glycemicIndex: 70, type: "snack"),
                        .init(name: "Cola (2L)", quantityML: 2000, glycemicIndex: 63, type: "beverage"),
                        .init(name: "Frozen Pizza", quantityGrams: 400, glycemicIndex: 80, type: "processed"),
                        .init(name: "Ice Cream", quantityGrams: 500, glycemicIndex: 62, type: "dairy"),
                    ],
                    glycemicLoad: 55, healthScore: 35, label: "Impulse Grocery Run"
                ),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.6),
            ],
            zombieScrollSessions: [
                ZombieScrollTemplate(hourOffset: 10.5, durationMinutes: 25, itemsViewed: 47, itemsPurchased: 12, impulseRatio: 0.74),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 28, humidity: 60, aqiUS: 72, uvIndex: 5, pollenIndex: 9, condition: .cloudy),
            ]
        )
    }

    /// Day -2: Late meal day — 9PM high-GL burrito, poor sleep
    private static func dayMinus2_LateMealDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 9.0, source: .manual, eventType: .manualLog,
                    ingredients: [
                        .init(name: "Greek Yogurt", quantityGrams: 200, glycemicIndex: 11, type: "dairy"),
                        .init(name: "Granola", quantityGrams: 40, glycemicIndex: 56, type: "grain"),
                        .init(name: "Honey", quantityGrams: 15, glycemicIndex: 61, type: "sweetener"),
                    ],
                    cookingMethod: nil, glycemicLoad: 13,
                    bioavailabilityModifier: 1.0, confidence: 0.75, label: "Yogurt & Granola"
                ),
                MealTemplate(
                    hourOffset: 13.0, source: .manual, eventType: .manualLog,
                    ingredients: [
                        .init(name: "Turkey", quantityGrams: 100, glycemicIndex: 0, type: "protein"),
                        .init(name: "Whole Wheat Bread", quantityGrams: 60, glycemicIndex: 45, type: "grain"),
                        .init(name: "Lettuce", quantityGrams: 50, glycemicIndex: 10, type: "vegetable"),
                    ],
                    cookingMethod: nil, glycemicLoad: 12,
                    bioavailabilityModifier: 1.0, confidence: 0.7, label: "Turkey Sandwich"
                ),
                MealTemplate(
                    hourOffset: 21.0, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Flour Tortilla", quantityGrams: 100, glycemicIndex: 72, type: "grain"),
                        .init(name: "Rice", quantityGrams: 150, glycemicIndex: 65, type: "grain"),
                        .init(name: "Beef", quantityGrams: 150, glycemicIndex: 0, type: "protein"),
                        .init(name: "Black Beans", quantityGrams: 100, glycemicIndex: 30, type: "legume"),
                        .init(name: "Cheese", quantityGrams: 50, glycemicIndex: 0, type: "dairy"),
                        .init(name: "Sour Cream", quantityGrams: 30, glycemicIndex: 0, type: "dairy"),
                    ],
                    cookingMethod: "restaurant", glycemicLoad: 45,
                    bioavailabilityModifier: 1.0, confidence: 0.5, label: "Burrito Bowl"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 50, stressHours: [22, 23], suppressionPercent: 20),
            heartRateSamples: generateHRSamples(resting: 67),
            sleepSamples: generateSleepSamples(totalHours: 6.5, deepPercent: 0.12, remPercent: 0.18),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 6800, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 180, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 14, durationMinutes: 60, category: .stressSignal, appName: "Zoom", dopamineDebt: 25),
                BehaviorTemplate(hourOffset: 20, durationMinutes: 120, category: .passiveConsumption, appName: "Netflix", dopamineDebt: 50),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 79.0),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 22, humidity: 80, aqiUS: 48, uvIndex: 3, pollenIndex: 4, condition: .humid),
            ]
        )
    }

    /// Day -1: Screen-heavy day — 45min Instagram, high dopamine debt
    private static func dayMinus1_ScreenHeavyDay() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.0, source: .rotimaticNext, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Whole Wheat Flour", quantityGrams: 100, glycemicIndex: 45, type: "grain"),
                        .init(name: "Paneer Bhurji", quantityGrams: 150, glycemicIndex: 0, type: "protein"),
                    ],
                    cookingMethod: "rotimatic_whole_wheat", glycemicLoad: 18,
                    bioavailabilityModifier: 1.0, confidence: 0.9, label: "Whole Wheat Rotis + Paneer"
                ),
                MealTemplate(
                    hourOffset: 12.5, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Rice", quantityGrams: 250, glycemicIndex: 65, type: "grain"),
                        .init(name: "Teriyaki Chicken", quantityGrams: 150, glycemicIndex: 0, type: "protein"),
                        .init(name: "Teriyaki Sauce", quantityGrams: 50, glycemicIndex: 45, type: "sauce"),
                        .init(name: "Edamame", quantityGrams: 50, glycemicIndex: 15, type: "legume"),
                    ],
                    cookingMethod: "restaurant", glycemicLoad: 36,
                    bioavailabilityModifier: 1.0, confidence: 0.55, label: "Teriyaki Bowl"
                ),
                MealTemplate(
                    hourOffset: 19.0, source: .instantPot, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Lentils", quantityGrams: 150, glycemicIndex: 26, type: "legume"),
                        .init(name: "Spinach", quantityGrams: 100, glycemicIndex: 15, type: "vegetable"),
                        .init(name: "Brown Rice", quantityGrams: 100, glycemicIndex: 50, type: "grain"),
                    ],
                    cookingMethod: "pressure_cook", glycemicLoad: 20,
                    bioavailabilityModifier: 1.3, confidence: 0.9, label: "Pressure-Cooked Dal + Brown Rice"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 43, stressHours: [10, 11, 15, 16], suppressionPercent: 25),
            heartRateSamples: generateHRSamples(resting: 70),
            sleepSamples: generateSleepSamples(totalHours: 6.8, deepPercent: 0.14, remPercent: 0.20),
            stepSamples: [MetricTemplate(hourOffset: 18, metricType: .stepCount, value: 4200, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 60, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 10, durationMinutes: 45, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 78),
                BehaviorTemplate(hourOffset: 11, durationMinutes: 30, category: .stressSignal, appName: "Slack", dopamineDebt: 45),
                BehaviorTemplate(hourOffset: 14, durationMinutes: 90, category: .stressSignal, appName: "Zoom", dopamineDebt: 50),
                BehaviorTemplate(hourOffset: 16, durationMinutes: 60, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 82),
                BehaviorTemplate(hourOffset: 21, durationMinutes: 120, category: .passiveConsumption, appName: "Netflix", dopamineDebt: 55),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.7),
            ],
            zombieScrollSessions: [
                ZombieScrollTemplate(hourOffset: 15.0, durationMinutes: 35, itemsViewed: 63, itemsPurchased: 8, impulseRatio: 0.87),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 5, humidity: 45, aqiUS: 38, uvIndex: 2, pollenIndex: 2, condition: .cold),
            ]
        )
    }

    /// Day 0: Today — mixed, data still coming in
    private static func day0_Today() -> DayScenario {
        DayScenario(
            meals: [
                MealTemplate(
                    hourOffset: 8.0, source: .rotimaticNext, eventType: .mealPreparation,
                    ingredients: [
                        .init(name: "Whole Wheat Flour", quantityGrams: 100, glycemicIndex: 45, type: "grain"),
                        .init(name: "Ghee", quantityGrams: 8, glycemicIndex: 0, type: "fat"),
                        .init(name: "Egg Curry", quantityGrams: 200, glycemicIndex: 0, type: "protein"),
                    ],
                    cookingMethod: "rotimatic_whole_wheat", glycemicLoad: 18,
                    bioavailabilityModifier: 1.0, confidence: 0.95, label: "Whole Wheat Rotis + Egg Curry"
                ),
                MealTemplate(
                    hourOffset: 12.5, source: .doordash, eventType: .mealDelivery,
                    ingredients: [
                        .init(name: "Chicken Tikka", quantityGrams: 200, glycemicIndex: 0, type: "protein"),
                        .init(name: "Masala Sauce", quantityGrams: 120, glycemicIndex: 20, type: "sauce"),
                        .init(name: "Basmati Rice", quantityGrams: 180, glycemicIndex: 65, type: "grain"),
                    ],
                    cookingMethod: "restaurant", glycemicLoad: 35,
                    bioavailabilityModifier: 1.0, confidence: 0.6, label: "Chicken Tikka Masala"
                ),
            ],
            hrvSamples: generateHRVSamples(baseline: 50, stressHours: [14], suppressionPercent: 12),
            heartRateSamples: generateHRSamples(resting: 64),
            sleepSamples: generateSleepSamples(totalHours: 7.3, deepPercent: 0.20, remPercent: 0.23),
            stepSamples: [MetricTemplate(hourOffset: 14, metricType: .stepCount, value: 4800, unit: "count")],
            behaviors: [
                BehaviorTemplate(hourOffset: 9, durationMinutes: 120, category: .activeWork, appName: "Xcode", dopamineDebt: nil),
                BehaviorTemplate(hourOffset: 12, durationMinutes: 20, category: .passiveConsumption, appName: "Instagram", dopamineDebt: 22),
            ],
            instacartOrders: [
                InstacartOrderTemplate(
                    hourOffset: 10.0,
                    items: [
                        .init(name: "Greek Yogurt", quantityGrams: 500, glycemicIndex: 11, type: "dairy"),
                        .init(name: "Mixed Nuts", quantityGrams: 300, glycemicIndex: 15, type: "nut"),
                        .init(name: "Whole Wheat Pasta", quantityGrams: 500, glycemicIndex: 42, type: "grain"),
                        .init(name: "Frozen Waffles", quantityGrams: 300, glycemicIndex: 76, type: "processed"),
                    ],
                    glycemicLoad: 30, healthScore: 60, label: "Mixed Weekly Order"
                ),
            ],
            weightReadings: [
                WeightTemplate(hourOffset: 7.0, weightKg: 78.4),
            ],
            environmentReadings: [
                EnvironmentTemplate(hourOffset: 12.0, temperatureCelsius: 27, humidity: 55, aqiUS: 150, uvIndex: 6, pollenIndex: 5, condition: .cloudy),
            ]
        )
    }

    // MARK: - Helpers

    // Fixed per-slot offsets — deterministic so data never shifts on refresh.
    // HRV slots: hours 6,8,10,12,14,16,18,20,22 (9 slots)
    private static let hrvOffsets: [Double] = [+2, -3, +4, +1, -2, +3, -1, +2, -4]
    // HR slots: hours 6,9,12,15,18,21 (6 slots)
    private static let hrOffsets:  [Double] = [+3, +6, +2, +5, +1, +4]

    private static func generateHRVSamples(baseline: Double, stressHours: [Int], suppressionPercent: Double) -> [MetricTemplate] {
        var samples: [MetricTemplate] = []
        var slotIndex = 0
        for hour in stride(from: 6, through: 23, by: 2) {
            let suppressed = stressHours.contains(hour)
            let offset = hrvOffsets[slotIndex % hrvOffsets.count]
            let value = suppressed ? baseline * (1.0 - suppressionPercent / 100.0) : baseline + offset
            samples.append(MetricTemplate(
                hourOffset: Double(hour),
                metricType: .hrvSDNN,
                value: max(value, 20),
                unit: "ms"
            ))
            slotIndex += 1
        }
        return samples
    }

    private static func generateHRSamples(resting: Double) -> [MetricTemplate] {
        var samples: [MetricTemplate] = []
        var slotIndex = 0
        for hour in stride(from: 6, through: 23, by: 3) {
            let variation = hrOffsets[slotIndex % hrOffsets.count]
            samples.append(MetricTemplate(
                hourOffset: Double(hour),
                metricType: .restingHeartRate,
                value: resting + variation,
                unit: "bpm"
            ))
            slotIndex += 1
        }
        return samples
    }

    private static func generateSleepSamples(totalHours: Double, deepPercent: Double, remPercent: Double) -> [MetricTemplate] {
        let deepMinutes = totalHours * 60 * deepPercent
        let remMinutes = totalHours * 60 * remPercent
        let lightMinutes = totalHours * 60 * (1.0 - deepPercent - remPercent - 0.05)
        let awakeMinutes = totalHours * 60 * 0.05

        return [
            MetricTemplate(hourOffset: -1, metricType: .sleepAnalysis, value: totalHours * 60, unit: "min"),
            MetricTemplate(hourOffset: 0, metricType: .sleepAnalysis, value: deepMinutes, unit: "min"),
            MetricTemplate(hourOffset: 1, metricType: .sleepAnalysis, value: remMinutes, unit: "min"),
            MetricTemplate(hourOffset: 2, metricType: .sleepAnalysis, value: lightMinutes, unit: "min"),
            MetricTemplate(hourOffset: 3, metricType: .sleepAnalysis, value: awakeMinutes, unit: "min"),
        ]
    }
}
