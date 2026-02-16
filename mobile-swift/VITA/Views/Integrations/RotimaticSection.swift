import SwiftUI
import VITADesignSystem

struct RotimaticSection: View {
    let viewModel: IntegrationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "circle.grid.3x3")
                    .font(.title2)
                    .foregroundStyle(VITAColors.amber)
                Text("Rotimatic")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.rotimaticSessions.count) sessions")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            ForEach(viewModel.rotimaticSessions) { session in
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.flourType)
                                .font(VITATypography.headline)
                            Text("\(session.count) rotis")
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(session.timestamp, style: .date)
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textTertiary)
                            FlourTypeBadge(isWholeWheat: session.flourType == "Whole Wheat")
                        }
                    }

                    HStack {
                        GLBar(glycemicLoad: session.glycemicLoad)
                        Spacer()
                        Text(session.glucoseImpact)
                            .font(VITATypography.caption)
                            .foregroundStyle(session.flourType == "Whole Wheat" ? VITAColors.success : VITAColors.coral)
                    }
                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }
        }
    }
}

struct FlourTypeBadge: View {
    let isWholeWheat: Bool

    var body: some View {
        Text(isWholeWheat ? "Whole Wheat" : "White Flour")
            .font(VITATypography.chip)
            .padding(.horizontal, VITASpacing.sm)
            .padding(.vertical, 2)
            .background(isWholeWheat ? VITAColors.success.opacity(0.15) : VITAColors.coral.opacity(0.15))
            .foregroundStyle(isWholeWheat ? VITAColors.success : VITAColors.coral)
            .clipShape(Capsule())
    }
}
