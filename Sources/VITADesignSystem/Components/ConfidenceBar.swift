import SwiftUI

public struct ConfidenceBar: View {
    let confidence: Double
    let label: String?

    public init(confidence: Double, label: String? = nil) {
        self.confidence = confidence
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.xs) {
            if let label {
                HStack {
                    Text(label)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                    Spacer()
                    Text("\(Int(confidence * 100))%")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(confidenceColor)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(VITAColors.tertiaryBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 6)
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.7...: return VITAColors.success
        case 0.4..<0.7: return VITAColors.amber
        default: return VITAColors.coral
        }
    }
}
