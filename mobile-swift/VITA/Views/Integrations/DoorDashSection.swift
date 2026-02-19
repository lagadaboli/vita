import SwiftUI
import VITADesignSystem

struct DoorDashSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "bag")
                    .font(.title2)
                    .foregroundStyle(VITAColors.coral)
                Text("DoorDash")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.doordashOrders.count) orders")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            if isLoading {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonCard(lines: [120, 230, 150], lineHeight: 12)
                }
            } else if viewModel.doordashOrders.isEmpty {
                EmptyDataStateView(
                    title: "No DoorDash Orders Yet",
                    message: "Orders will appear here once DoorDash data syncs."
                )
            } else {
                ForEach(viewModel.doordashOrders) { order in
                    VStack(alignment: .leading, spacing: VITASpacing.sm) {
                        HStack {
                            Text(order.name)
                                .font(VITATypography.headline)
                            Spacer()
                            Text(order.timestamp, style: .date)
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.textTertiary)
                        }

                        Text(order.ingredients.joined(separator: ", "))
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                            .lineLimit(2)

                        HStack {
                            GLBar(glycemicLoad: order.glycemicLoad)
                            Spacer()
                            Text(order.glucoseImpact)
                                .font(VITATypography.caption)
                                .foregroundStyle(glColor(order.glycemicLoad))
                        }
                    }
                    .padding(VITASpacing.cardPadding)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
                }
            }
        }
    }

    private func glColor(_ gl: Double) -> Color {
        switch gl {
        case ..<20: return VITAColors.success
        case 20..<35: return VITAColors.amber
        default: return VITAColors.coral
        }
    }
}

struct GLBar: View {
    let glycemicLoad: Double

    var body: some View {
        HStack(spacing: VITASpacing.sm) {
            Text("GL")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VITAColors.tertiaryBackground)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(glycemicLoad / 60.0, 1.0))
                }
            }
            .frame(height: 8)
            .frame(maxWidth: 100)

            Text("\(Int(glycemicLoad))")
                .font(VITATypography.metricSmall)
                .foregroundStyle(barColor)
        }
    }

    private var barColor: Color {
        switch glycemicLoad {
        case ..<20: return VITAColors.success
        case 20..<35: return VITAColors.amber
        default: return VITAColors.coral
        }
    }
}
