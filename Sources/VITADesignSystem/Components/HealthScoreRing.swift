import SwiftUI

public struct HealthScoreRing: View {
    let score: Double
    let lineWidth: CGFloat
    let size: CGFloat

    public init(score: Double, lineWidth: CGFloat = 14, size: CGFloat = 180) {
        self.score = score
        self.lineWidth = lineWidth
        self.size = size
    }

    @State private var animatedScore: Double = 0

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(VITAColors.tertiaryBackground, lineWidth: lineWidth)

            // Score arc
            Circle()
                .trim(from: 0, to: animatedScore / 100)
                .stroke(
                    AngularGradient(
                        colors: [scoreColor.opacity(0.7), scoreColor],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedScore / 100)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center label
            VStack(spacing: VITASpacing.xs) {
                Text("\(Int(animatedScore))")
                    .font(VITATypography.metricLarge)
                    .foregroundStyle(scoreColor)

                Text("Health Score")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedScore = newValue
            }
        }
    }

    private var scoreColor: Color {
        VITAColors.healthScoreColor(score)
    }
}
