import Foundation
import GRDB

/// Environmental data from weather/air quality APIs.
/// Used by the Causality Engine to correlate ambient conditions with health outcomes.
public struct EnvironmentalCondition: Codable, Identifiable, Sendable {
    public var id: Int64?
    public var timestamp: Date
    public var temperatureCelsius: Double
    public var humidity: Double
    public var aqiUS: Int
    public var uvIndex: Double
    public var pollenIndex: Int
    public var condition: WeatherCondition

    public init(
        id: Int64? = nil,
        timestamp: Date,
        temperatureCelsius: Double,
        humidity: Double,
        aqiUS: Int,
        uvIndex: Double,
        pollenIndex: Int,
        condition: WeatherCondition
    ) {
        self.id = id
        self.timestamp = timestamp
        self.temperatureCelsius = temperatureCelsius
        self.humidity = humidity
        self.aqiUS = aqiUS
        self.uvIndex = uvIndex
        self.pollenIndex = pollenIndex
        self.condition = condition
    }
}

// MARK: - Enums & Computed Properties

extension EnvironmentalCondition {
    public enum WeatherCondition: String, Codable, Sendable, DatabaseValueConvertible {
        case clear
        case cloudy
        case rainy
        case hot
        case cold
        case humid
    }

    public enum HealthRisk: String, Sendable {
        case highAQI
        case extremeHeat
        case extremeCold
        case highPollen
        case highHumidity
        case highUV
    }

    /// Computed health risk factors based on current conditions.
    public var healthRisks: [HealthRisk] {
        var risks: [HealthRisk] = []
        if aqiUS > 100 { risks.append(.highAQI) }
        if temperatureCelsius > 33 { risks.append(.extremeHeat) }
        if temperatureCelsius < 5 { risks.append(.extremeCold) }
        if pollenIndex >= 8 { risks.append(.highPollen) }
        if humidity > 75 { risks.append(.highHumidity) }
        if uvIndex > 7 { risks.append(.highUV) }
        return risks
    }
}

// MARK: - GRDB Record

extension EnvironmentalCondition: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "environmental_conditions"

    enum Columns: String, ColumnExpression {
        case id, timestamp, temperatureCelsius, humidity, aqiUS, uvIndex, pollenIndex, condition
    }
}
