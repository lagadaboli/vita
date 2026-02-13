import SwiftUI

public enum VITATypography {
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    public static let title = Font.system(.title, design: .rounded, weight: .semibold)
    public static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    public static let title3 = Font.system(.title3, design: .rounded, weight: .medium)
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let body = Font.system(.body, design: .default)
    public static let narrative = Font.system(.body, design: .serif)
    public static let callout = Font.system(.callout, design: .default)
    public static let caption = Font.system(.caption, design: .default)
    public static let caption2 = Font.system(.caption2, design: .default)
    public static let metric = Font.system(.title, design: .monospaced, weight: .bold)
    public static let metricSmall = Font.system(.body, design: .monospaced, weight: .semibold)
    public static let metricLarge = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    public static let chip = Font.system(.caption, design: .rounded, weight: .medium)
}
