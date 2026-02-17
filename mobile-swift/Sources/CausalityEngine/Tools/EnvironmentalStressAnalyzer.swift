import Foundation
import VITACore

/// Tool E: Evaluates environmental conditions (AQI, pollen, heat) and their
/// impact on HRV and overall physiological stress.
///
/// Algorithm:
/// 1. Query environmental conditions in window
/// 2. Score AQI impact: AQI >100 suppresses HRV ~15% (known dose-response)
/// 3. Score pollen impact: high pollen (>8) triggers histamine response
/// 4. Score heat stress: >33C increases metabolic demand
/// 5. Cross-validate with HRV data
public struct EnvironmentalStressAnalyzer: AnalysisTool {
    public let name = "EnvironmentalStressAnalyzer"
    public let targetDebtTypes: Set<DebtType> = [.somatic]

    public init() {}

    public func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation {
        let environment = try healthGraph.queryEnvironment(from: window.lowerBound, to: window.upperBound)

        guard !environment.isEmpty else {
            return ToolObservation(
                toolName: name,
                evidence: [.somatic: 0.0],
                confidence: 0.3,
                detail: "No environmental data available"
            )
        }

        // AQI impact
        let maxAQI = environment.map(\.aqiUS).max() ?? 0
        let aqiScore: Double
        if maxAQI > 150 {
            aqiScore = 0.8
        } else if maxAQI > 100 {
            aqiScore = 0.5
        } else if maxAQI > 50 {
            aqiScore = 0.2
        } else {
            aqiScore = 0.0
        }

        // Pollen impact
        let maxPollen = environment.map(\.pollenIndex).max() ?? 0
        let pollenScore: Double
        if maxPollen >= 10 {
            pollenScore = 0.7
        } else if maxPollen >= 8 {
            pollenScore = 0.5
        } else if maxPollen >= 5 {
            pollenScore = 0.2
        } else {
            pollenScore = 0.0
        }

        // Heat stress
        let maxTemp = environment.map(\.temperatureCelsius).max() ?? 20
        let heatScore: Double
        if maxTemp > 38 {
            heatScore = 0.7
        } else if maxTemp > 33 {
            heatScore = 0.4
        } else if maxTemp < 5 {
            heatScore = 0.3
        } else {
            heatScore = 0.0
        }

        // UV stress (suppresses immune function at high levels)
        let maxUV = environment.map(\.uvIndex).max() ?? 0
        let uvScore = maxUV > 7 ? 0.2 : 0.0

        let environmentalScore = max(aqiScore, pollenScore, heatScore) * 0.6
            + min(aqiScore + pollenScore + heatScore + uvScore, 1.0) * 0.4

        // Cross-validate with HRV
        let hrv = try healthGraph.querySamples(type: .hrvSDNN, from: window.lowerBound, to: window.upperBound)
        let baselineStart = window.lowerBound.addingTimeInterval(-7 * 24 * 3600)
        let baselineHRV = try healthGraph.querySamples(type: .hrvSDNN, from: baselineStart, to: window.lowerBound)

        var hrvConfirmation = 0.0
        if !hrv.isEmpty && !baselineHRV.isEmpty {
            let avgCurrent = hrv.map(\.value).reduce(0, +) / Double(hrv.count)
            let avgBaseline = baselineHRV.map(\.value).reduce(0, +) / Double(baselineHRV.count)
            if avgBaseline > 0 {
                let drop = (avgBaseline - avgCurrent) / avgBaseline
                if drop > 0.1 { hrvConfirmation = min(drop, 0.3) }
            }
        }

        let finalScore = min(environmentalScore + hrvConfirmation, 1.0)

        return ToolObservation(
            toolName: name,
            evidence: [.somatic: finalScore],
            confidence: 0.7,
            detail: "AQI: \(maxAQI) (\(String(format: "%.0f", aqiScore * 100))%), Pollen: \(maxPollen), Temp: \(String(format: "%.0f", maxTemp))C"
        )
    }
}
