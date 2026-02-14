import Foundation
import VITACore

/// Client for the Open-Meteo free weather/air quality APIs.
/// No API key required. Rate limits are generous (10,000 requests/day).
public struct OpenMeteoClient: Sendable {

    public init() {}

    // MARK: - Weather

    /// Fetch current weather conditions.
    public func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,uv_index,weather_code")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }

    /// Fetch current US EPA air quality index.
    public func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQualityResponse {
        let url = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=us_aqi")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    /// Fetch current pollen indices.
    public func fetchPollen(latitude: Double, longitude: Double) async throws -> PollenResponse {
        let url = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=grass_pollen,birch_pollen,ragweed_pollen")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(PollenResponse.self, from: data)
    }

    /// Fetch all environmental data and combine into an `EnvironmentalCondition`.
    public func fetchAll(latitude: Double, longitude: Double) async throws -> EnvironmentalCondition {
        async let weather = fetchWeather(latitude: latitude, longitude: longitude)
        async let airQuality = fetchAirQuality(latitude: latitude, longitude: longitude)
        async let pollen = fetchPollen(latitude: latitude, longitude: longitude)

        let w = try await weather
        let a = try await airQuality
        let p = try await pollen

        let pollenIndex = mapPollenIndex(grass: p.current.grassPollen, birch: p.current.birchPollen, ragweed: p.current.ragweedPollen)

        return EnvironmentalCondition(
            timestamp: Date(),
            temperatureCelsius: w.current.temperature2m,
            humidity: w.current.relativeHumidity2m,
            aqiUS: a.current.usAqi ?? 0,
            uvIndex: w.current.uvIndex,
            pollenIndex: pollenIndex,
            condition: mapWeatherCode(w.current.weatherCode)
        )
    }

    // MARK: - Mapping

    /// Map Open-Meteo WMO weather code to VITA WeatherCondition.
    public static func mapWeatherCode(_ code: Int) -> EnvironmentalCondition.WeatherCondition {
        switch code {
        case 0, 1:
            return .clear
        case 2, 3:
            return .cloudy
        case 45, 48:
            return .cloudy // Fog
        case 51...67, 80...82:
            return .rainy
        case 71...77, 85, 86:
            return .cold // Snow
        default:
            return .cloudy
        }
    }

    /// Map pollen grains/m3 to a 0-12 index (max of three types).
    /// Open-Meteo returns raw grains/m3; we normalize to a 0-12 scale.
    public static func mapPollenIndex(grass: Double?, birch: Double?, ragweed: Double?) -> Int {
        let values = [grass, birch, ragweed].compactMap { $0 }
        guard let maxValue = values.max() else { return 0 }

        // Approximate mapping: 0 grains = 0, 50+ grains = 12
        let normalized = min(maxValue / 50.0, 1.0) * 12.0
        return Int(normalized.rounded())
    }

    private func mapWeatherCode(_ code: Int) -> EnvironmentalCondition.WeatherCondition {
        Self.mapWeatherCode(code)
    }

    private func mapPollenIndex(grass: Double?, birch: Double?, ragweed: Double?) -> Int {
        Self.mapPollenIndex(grass: grass, birch: birch, ragweed: ragweed)
    }
}

// MARK: - Response Types

public struct WeatherResponse: Codable, Sendable {
    public let current: CurrentWeather

    public struct CurrentWeather: Codable, Sendable {
        public let temperature2m: Double
        public let relativeHumidity2m: Double
        public let uvIndex: Double
        public let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case uvIndex = "uv_index"
            case weatherCode = "weather_code"
        }
    }
}

public struct AirQualityResponse: Codable, Sendable {
    public let current: CurrentAirQuality

    public struct CurrentAirQuality: Codable, Sendable {
        public let usAqi: Int?

        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
        }
    }
}

public struct PollenResponse: Codable, Sendable {
    public let current: CurrentPollen

    public struct CurrentPollen: Codable, Sendable {
        public let grassPollen: Double?
        public let birchPollen: Double?
        public let ragweedPollen: Double?

        enum CodingKeys: String, CodingKey {
            case grassPollen = "grass_pollen"
            case birchPollen = "birch_pollen"
            case ragweedPollen = "ragweed_pollen"
        }
    }
}
