import SwiftUI
import VITADesignSystem

struct InstacartSection: View {
    let viewModel: IntegrationsViewModel

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

            // Zombie Scrolling Alert
            if !viewModel.zombieScrollSessions.isEmpty {
                ForEach(viewModel.zombieScrollSessions) { session in
                    ZombieScrollCard(session: session)
                }
            }

            // Order Cards
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

                    // Item list
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

struct ZombieScrollCard: View {
    let session: IntegrationsViewModel.ZombieScrollSession

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            HStack(spacing: VITASpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(VITAColors.amber)
                Text("Zombie Scrolling Detected")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.amber)
                Spacer()
                Text(session.timestamp, style: .date)
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            HStack(spacing: VITASpacing.xl) {
                VStack(spacing: VITASpacing.xs) {
                    Text("\(Int(session.durationMinutes))")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(VITAColors.coral)
                    Text("min browsing")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }

                VStack(spacing: VITASpacing.xs) {
                    Text("\(session.itemsViewed)")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(VITAColors.textPrimary)
                    Text("viewed")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }

                VStack(spacing: VITASpacing.xs) {
                    Text("\(session.itemsPurchased)")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(VITAColors.textPrimary)
                    Text("purchased")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }

                VStack(spacing: VITASpacing.xs) {
                    Text("\(session.zombieScore)")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(zombieScoreColor(session.zombieScore))
                    Text("zombie score")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }

            Text("Impulse ratio: \(String(format: "%.0f%%", session.impulseRatio * 100)) of purchases were unplanned")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.amber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                .stroke(VITAColors.amber.opacity(0.3), lineWidth: 1)
        )
    }

    private func zombieScoreColor(_ score: Int) -> Color {
        switch score {
        case ..<50: return VITAColors.success
        case 50..<75: return VITAColors.amber
        default: return VITAColors.coral
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
