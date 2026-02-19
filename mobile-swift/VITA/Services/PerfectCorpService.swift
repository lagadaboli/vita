import Foundation

// Mock of the PerfectCorp YouCam Skin Analysis API.
// In production this would be a real POST /analyze endpoint with a selfie JPEG.
enum PerfectCorpService {

    // MARK: - Models

    enum SkinConditionType: String, CaseIterable, Equatable {
        case acne         = "Acne"
        case darkCircles  = "Dark Circles"
        case redness      = "Redness"
        case oiliness     = "Oiliness"
        case dryness      = "Dryness"
        case unevenTone   = "Uneven Tone"

        var icon: String {
            switch self {
            case .acne:        return "circle.fill"
            case .darkCircles: return "moon.fill"
            case .redness:     return "flame.fill"
            case .oiliness:    return "drop.fill"
            case .dryness:     return "sun.max.fill"
            case .unevenTone:  return "paintpalette.fill"
            }
        }
    }

    enum FaceZone: String, CaseIterable, Hashable {
        case forehead   = "Forehead"
        case leftCheek  = "Left Cheek"
        case rightCheek = "Right Cheek"
        case nose       = "Nose"
        case chin       = "Chin"
        case underEyes  = "Under Eyes"
    }

    struct SkinCondition: Identifiable {
        let id = UUID()
        let type: SkinConditionType
        let severity: Double          // 0.0–1.0
        let confidence: Double        // 0.0–1.0
        let affectedZones: [FaceZone]
        let heatmapIntensity: [FaceZone: Double]  // per-zone 0.0–1.0

        var severityLabel: String {
            if severity > 0.65 { return "Severe" }
            if severity > 0.35 { return "Moderate" }
            return "Mild"
        }
    }

    struct AnalysisResult {
        let timestamp: Date
        let overallScore: Int   // 0–100, higher = better
        let conditions: [SkinCondition]
    }

    // MARK: - API simulation (1.5 s mock latency)

    static func analyze() async -> AnalysisResult {
        try? await Task.sleep(for: .seconds(1.5))
        return generateMockResult()
    }

    // MARK: - Mock generator

    private static func generateMockResult() -> AnalysisResult {
        var conditions: [SkinCondition] = []

        let hasPimples     = Double.random(in: 0...1) < 0.72
        let hasDarkCircles = Double.random(in: 0...1) < 0.65
        let hasRedness     = Double.random(in: 0...1) < 0.48
        let hasOiliness    = Double.random(in: 0...1) < 0.55

        if hasPimples {
            let pool: [FaceZone] = [.forehead, .chin, .leftCheek, .rightCheek, .nose]
            let zones = Array(pool.shuffled().prefix(Int.random(in: 1...3)))
            conditions.append(SkinCondition(
                type: .acne,
                severity: Double.random(in: 0.30...0.85),
                confidence: Double.random(in: 0.72...0.95),
                affectedZones: zones,
                heatmapIntensity: Dictionary(uniqueKeysWithValues: zones.map { ($0, Double.random(in: 0.30...0.90)) })
            ))
        }

        if hasDarkCircles {
            conditions.append(SkinCondition(
                type: .darkCircles,
                severity: Double.random(in: 0.25...0.75),
                confidence: Double.random(in: 0.68...0.92),
                affectedZones: [.underEyes],
                heatmapIntensity: [.underEyes: Double.random(in: 0.40...0.85)]
            ))
        }

        if hasRedness {
            let pool: [FaceZone] = [.leftCheek, .rightCheek, .nose]
            let zones = Array(pool.shuffled().prefix(Int.random(in: 1...3)))
            conditions.append(SkinCondition(
                type: .redness,
                severity: Double.random(in: 0.20...0.65),
                confidence: Double.random(in: 0.65...0.88),
                affectedZones: zones,
                heatmapIntensity: Dictionary(uniqueKeysWithValues: zones.map { ($0, Double.random(in: 0.25...0.70)) })
            ))
        }

        if hasOiliness {
            let zones: [FaceZone] = [.forehead, .nose]
            conditions.append(SkinCondition(
                type: .oiliness,
                severity: Double.random(in: 0.30...0.70),
                confidence: Double.random(in: 0.70...0.90),
                affectedZones: zones,
                heatmapIntensity: Dictionary(uniqueKeysWithValues: zones.map { ($0, Double.random(in: 0.35...0.75)) })
            ))
        }

        let penalty = conditions.reduce(0.0) { $0 + $1.severity * 14.0 }
        let raw = (85.0 - penalty + Double.random(in: -4...4)).clamped(to: 25...95)

        return AnalysisResult(timestamp: Date(), overallScore: Int(raw), conditions: conditions)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
