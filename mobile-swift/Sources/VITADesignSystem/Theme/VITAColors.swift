import SwiftUI

public enum VITAColors {
    // MARK: - Primary
    public static let teal = Color(red: 0.0, green: 0.71, blue: 0.70)
    public static let tealDark = Color(red: 0.0, green: 0.55, blue: 0.55)
    public static let tealLight = Color(red: 0.6, green: 0.9, blue: 0.89)

    // MARK: - Accent
    public static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    public static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)
    public static let amberLight = Color(red: 1.0, green: 0.87, blue: 0.4)

    // MARK: - Glucose Semantic
    public static let glucoseLow = Color(red: 0.35, green: 0.55, blue: 0.95)
    public static let glucoseNormal = Color(red: 0.2, green: 0.78, blue: 0.45)
    public static let glucoseElevated = amber
    public static let glucoseHigh = Color(red: 1.0, green: 0.55, blue: 0.0)
    public static let glucoseSpike = coral

    // MARK: - Backgrounds
    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemBackground)
    public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    public static let cardBackground = Color(uiColor: .secondarySystemBackground)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    public static let cardBackground = Color(nsColor: .controlBackgroundColor)
    #endif

    // MARK: - Text
    #if canImport(UIKit)
    public static let textPrimary = Color(uiColor: .label)
    public static let textSecondary = Color(uiColor: .secondaryLabel)
    public static let textTertiary = Color(uiColor: .tertiaryLabel)
    #else
    public static let textPrimary = Color(nsColor: .labelColor)
    public static let textSecondary = Color(nsColor: .secondaryLabelColor)
    public static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    #endif

    // MARK: - Status
    public static let success = Color(red: 0.2, green: 0.78, blue: 0.45)
    public static let warning = amber
    public static let error = coral
    public static let info = Color(red: 0.35, green: 0.55, blue: 0.95)

    // MARK: - Causal Chain
    public static let causalNode = teal
    public static let causalEdge = Color(red: 0.6, green: 0.6, blue: 0.65)
    public static let causalHighlight = coral

    public static func glucoseColor(mgDL: Double) -> Color {
        switch mgDL {
        case ..<70: return glucoseLow
        case 70..<120: return glucoseNormal
        case 120..<150: return glucoseElevated
        case 150..<180: return glucoseHigh
        default: return glucoseSpike
        }
    }

    public static func healthScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return success
        case 60..<80: return teal
        case 40..<60: return amber
        default: return coral
        }
    }
}
