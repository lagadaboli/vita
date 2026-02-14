import Testing
import Foundation
@testable import EnvironmentBridge
import VITACore

@Suite("OpenMeteoClient Tests")
struct OpenMeteoClientTests {

    // MARK: - Weather Response Decoding

    @Test("Weather response decodes correctly")
    func weatherResponseDecoding() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 22.5,
                "relative_humidity_2m": 65.0,
                "uv_index": 6.2,
                "weather_code": 3
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherResponse.self, from: json)
        #expect(response.current.temperature2m == 22.5)
        #expect(response.current.relativeHumidity2m == 65.0)
        #expect(response.current.uvIndex == 6.2)
        #expect(response.current.weatherCode == 3)
    }

    // MARK: - Air Quality Response Decoding

    @Test("Air quality response decodes correctly")
    func airQualityResponseDecoding() throws {
        let json = """
        {
            "current": {
                "us_aqi": 42
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AirQualityResponse.self, from: json)
        #expect(response.current.usAqi == 42)
    }

    @Test("Air quality response with null AQI")
    func airQualityResponseNullAQI() throws {
        let json = """
        {
            "current": {
                "us_aqi": null
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AirQualityResponse.self, from: json)
        #expect(response.current.usAqi == nil)
    }

    // MARK: - Pollen Response Decoding

    @Test("Pollen response decodes correctly")
    func pollenResponseDecoding() throws {
        let json = """
        {
            "current": {
                "grass_pollen": 25.0,
                "birch_pollen": 10.0,
                "ragweed_pollen": 45.0
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PollenResponse.self, from: json)
        #expect(response.current.grassPollen == 25.0)
        #expect(response.current.birchPollen == 10.0)
        #expect(response.current.ragweedPollen == 45.0)
    }

    @Test("Pollen response with null values")
    func pollenResponseNulls() throws {
        let json = """
        {
            "current": {
                "grass_pollen": null,
                "birch_pollen": null,
                "ragweed_pollen": null
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PollenResponse.self, from: json)
        #expect(response.current.grassPollen == nil)
        #expect(response.current.birchPollen == nil)
        #expect(response.current.ragweedPollen == nil)
    }

    // MARK: - Weather Code Mapping

    @Test("Weather code maps clear")
    func weatherCodeClear() {
        #expect(OpenMeteoClient.mapWeatherCode(0) == .clear)
        #expect(OpenMeteoClient.mapWeatherCode(1) == .clear)
    }

    @Test("Weather code maps cloudy")
    func weatherCodeCloudy() {
        #expect(OpenMeteoClient.mapWeatherCode(2) == .cloudy)
        #expect(OpenMeteoClient.mapWeatherCode(3) == .cloudy)
        #expect(OpenMeteoClient.mapWeatherCode(45) == .cloudy)
    }

    @Test("Weather code maps rainy")
    func weatherCodeRainy() {
        #expect(OpenMeteoClient.mapWeatherCode(51) == .rainy)
        #expect(OpenMeteoClient.mapWeatherCode(61) == .rainy)
        #expect(OpenMeteoClient.mapWeatherCode(80) == .rainy)
    }

    @Test("Weather code maps snow to cold")
    func weatherCodeSnow() {
        #expect(OpenMeteoClient.mapWeatherCode(71) == .cold)
        #expect(OpenMeteoClient.mapWeatherCode(85) == .cold)
    }

    // MARK: - Pollen Index Mapping

    @Test("Pollen index zero for zero input")
    func pollenIndexZero() {
        #expect(OpenMeteoClient.mapPollenIndex(grass: 0, birch: 0, ragweed: 0) == 0)
    }

    @Test("Pollen index max at 12")
    func pollenIndexMax() {
        #expect(OpenMeteoClient.mapPollenIndex(grass: 50, birch: 0, ragweed: 0) == 12)
        #expect(OpenMeteoClient.mapPollenIndex(grass: 100, birch: 0, ragweed: 0) == 12)
    }

    @Test("Pollen index uses max of three types")
    func pollenIndexUsesMax() {
        // 25/50 * 12 = 6
        let index = OpenMeteoClient.mapPollenIndex(grass: 10, birch: 5, ragweed: 25)
        #expect(index == 6)
    }

    @Test("Pollen index returns zero for all nil")
    func pollenIndexAllNil() {
        #expect(OpenMeteoClient.mapPollenIndex(grass: nil, birch: nil, ragweed: nil) == 0)
    }

    @Test("Pollen index handles partial nil")
    func pollenIndexPartialNil() {
        // 25/50 * 12 = 6
        #expect(OpenMeteoClient.mapPollenIndex(grass: 25, birch: nil, ragweed: nil) == 6)
    }

    // MARK: - Static Location Provider

    @Test("Static location provider returns San Francisco by default")
    func staticLocationDefaults() async throws {
        let provider = StaticLocationProvider()
        let loc = try await provider.currentLocation()
        #expect(abs(loc.latitude - 37.7749) < 0.001)
        #expect(abs(loc.longitude - (-122.4194)) < 0.001)
    }

    @Test("Static location provider returns custom coordinates")
    func staticLocationCustom() async throws {
        let provider = StaticLocationProvider(latitude: 40.7128, longitude: -74.0060)
        let loc = try await provider.currentLocation()
        #expect(abs(loc.latitude - 40.7128) < 0.001)
        #expect(abs(loc.longitude - (-74.0060)) < 0.001)
    }
}
