import Foundation
import VITACore

/// Computes Somatic Stress score from environmental conditions and sleep deficit.
public struct SomaticStressScorer: Sendable {
    public init() {}

    /// Compute somatic stress score (0-100) over a time window.
    public func score(healthGraph: HealthGraph, windowHours: Int) throws -> Double {
        let now = Date()
        let start = now.addingTimeInterval(-Double(windowHours) * 3600)

        // Environment
        let environment = try healthGraph.queryEnvironment(from: start, to: now)
        var envScore = 0.0
        if let worst = environment.max(by: { $0.aqiUS < $1.aqiUS }) {
            if worst.aqiUS > 150 { envScore += 30 }
            else if worst.aqiUS > 100 { envScore += 20 }
            else if worst.aqiUS > 50 { envScore += 10 }

            if worst.pollenIndex >= 10 { envScore += 15 }
            else if worst.pollenIndex >= 8 { envScore += 10 }

            if worst.temperatureCelsius > 38 { envScore += 15 }
            else if worst.temperatureCelsius > 33 { envScore += 10 }
            else if worst.temperatureCelsius < 5 { envScore += 10 }
        }

        // Sleep deficit
        let sleepStart = start.addingTimeInterval(-12 * 3600)
        let sleep = try healthGraph.querySamples(type: .sleepAnalysis, from: sleepStart, to: now)
        let totalSleepHours = sleep.map(\.value).reduce(0, +)
        var sleepScore = 0.0
        if totalSleepHours < 5.0 { sleepScore = 30 }
        else if totalSleepHours < 6.0 { sleepScore = 20 }
        else if totalSleepHours < 6.5 { sleepScore = 15 }
        else if totalSleepHours < 7.0 { sleepScore = 10 }

        // HRV suppression (general stress indicator)
        let hrv = try healthGraph.querySamples(type: .hrvSDNN, from: start, to: now)
        var hrvScore = 0.0
        if !hrv.isEmpty {
            let avg = hrv.map(\.value).reduce(0, +) / Double(hrv.count)
            if avg < 30 { hrvScore = 20 }
            else if avg < 40 { hrvScore = 15 }
            else if avg < 50 { hrvScore = 10 }
        }

        return min(envScore + sleepScore + hrvScore, 100)
    }
}
