import SwiftUI
import VITADesignSystem

struct FaceHeatmapView: View {
    let conditions: [PerfectCorpService.SkinCondition]

    // Highest intensity per zone across all conditions
    private var zoneIntensities: [PerfectCorpService.FaceZone: Double] {
        var result: [PerfectCorpService.FaceZone: Double] = [:]
        for condition in conditions {
            for (zone, intensity) in condition.heatmapIntensity {
                result[zone] = max(result[zone] ?? 0, intensity)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: VITASpacing.xs) {
            Text("Skin Heatmap")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Face silhouette
                    Ellipse()
                        .fill(VITAColors.tertiaryBackground)
                        .frame(width: w * 0.80, height: h * 0.95)
                        .position(x: w / 2, y: h / 2)

                    Ellipse()
                        .stroke(VITAColors.textTertiary.opacity(0.35), lineWidth: 1)
                        .frame(width: w * 0.80, height: h * 0.95)
                        .position(x: w / 2, y: h / 2)

                    // Zone overlays — ellipses clipped to face area
                    heatZone(.forehead,   x: w * 0.50, y: h * 0.14, width: w * 0.54, height: h * 0.22)
                    heatZone(.underEyes,  x: w * 0.50, y: h * 0.38, width: w * 0.62, height: h * 0.13)
                    heatZone(.nose,       x: w * 0.50, y: h * 0.52, width: w * 0.22, height: h * 0.25)
                    heatZone(.leftCheek,  x: w * 0.20, y: h * 0.52, width: w * 0.28, height: h * 0.27)
                    heatZone(.rightCheek, x: w * 0.80, y: h * 0.52, width: w * 0.28, height: h * 0.27)
                    heatZone(.chin,       x: w * 0.50, y: h * 0.80, width: w * 0.38, height: h * 0.17)

                    // Zone labels (small)
                    if !conditions.isEmpty {
                        zoneLabels(w: w, h: h)
                    }
                }
            }

            // Legend
            HStack(spacing: VITASpacing.md) {
                legendDot(color: VITAColors.coral,   label: "High")
                legendDot(color: VITAColors.amber,   label: "Mod")
                legendDot(color: Color.yellow.opacity(0.8), label: "Low")
            }
            .font(VITATypography.caption2)
            .foregroundStyle(VITAColors.textTertiary)
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    @ViewBuilder
    private func heatZone(
        _ zone: PerfectCorpService.FaceZone,
        x: CGFloat, y: CGFloat,
        width: CGFloat, height: CGFloat
    ) -> some View {
        if let intensity = zoneIntensities[zone] {
            Ellipse()
                .fill(heatColor(intensity).opacity(intensity * 0.60))
                .frame(width: width, height: height)
                .position(x: x, y: y)
        }
    }

    @ViewBuilder
    private func zoneLabels(w: CGFloat, h: CGFloat) -> some View {
        // Only label zones that are active
        ForEach(conditions.flatMap(\.affectedZones).uniqued(), id: \.self) { zone in
            Text(zone.rawValue)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(VITAColors.textTertiary)
                .position(labelPosition(for: zone, w: w, h: h))
        }
    }

    private func labelPosition(for zone: PerfectCorpService.FaceZone, w: CGFloat, h: CGFloat) -> CGPoint {
        switch zone {
        case .forehead:   return CGPoint(x: w * 0.50, y: h * 0.08)
        case .underEyes:  return CGPoint(x: w * 0.50, y: h * 0.33)
        case .nose:       return CGPoint(x: w * 0.50, y: h * 0.50)
        case .leftCheek:  return CGPoint(x: w * 0.18, y: h * 0.47)
        case .rightCheek: return CGPoint(x: w * 0.82, y: h * 0.47)
        case .chin:       return CGPoint(x: w * 0.50, y: h * 0.76)
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity > 0.65 { return VITAColors.coral }
        if intensity > 0.35 { return VITAColors.amber }
        return Color.yellow
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }
}

// Simple unique helper for arrays of Hashable
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
