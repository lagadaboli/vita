import SwiftUI
import VITADesignSystem

struct InstacartSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "cart")
                    .font(.title2)
                    .foregroundStyle(VITAColors.success)
                Text("Instacart")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.instacartOrders.count) orders")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            if isLoading {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonCard(lines: [120, 240, 160], lineHeight: 12)
                }
            } else if viewModel.instacartOrders.isEmpty {
                EmptyDataStateView(
                    title: "No Instacart Orders Yet",
                    message: "Orders will appear here once Instacart data syncs."
                )
            } else {
                ForEach(viewModel.instacartOrders) { order in
                    VStack(alignment: .leading, spacing: VITASpacing.sm) {
                        HStack {
                            Text(order.label)
                                .font(VITATypography.headline)
                            Spacer()
                            Text(order.timestamp, style: .date)
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textTertiary)
                        }

                        Text(order.items.map(\.name).joined(separator: ", "))
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                            .lineLimit(2)

                        HStack {
                            GLBar(glycemicLoad: order.totalGL)
                            Spacer()
                            HealthScoreBadge(score: order.healthScore)
                        }
                    }
                    .padding(VITASpacing.cardPadding)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
                }
            }
        }
    }
}

struct HealthScoreBadge: View {
    let score: Int

    var body: some View {
        HStack(spacing: VITASpacing.xs) {
            Circle()
                .fill(scoreColor)
                .frame(width: 8, height: 8)
            Text("\(score)")
                .font(VITATypography.metricSmall)
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, VITASpacing.sm)
        .padding(.vertical, VITASpacing.xs)
        .background(scoreColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var scoreColor: Color {
        switch score {
        case 70...: return VITAColors.success
        case 50..<70: return VITAColors.amber
        default: return VITAColors.coral
        }
    }
}
