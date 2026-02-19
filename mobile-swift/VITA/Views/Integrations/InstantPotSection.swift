import SwiftUI
import VITADesignSystem

struct InstantPotSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "flame")
                    .font(.title2)
                    .foregroundStyle(VITAColors.info)
                Text("Instant Pot")
                    .font(VITATypography.title3)
                Spacer()
                Text("\(viewModel.instantPotPrograms.count) programs")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }

            if isLoading {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonCard(lines: [130, 150, 220], lineHeight: 12)
                }
            } else if viewModel.instantPotPrograms.isEmpty {
                EmptyDataStateView(
                    title: "No Instant Pot Programs Yet",
                    message: "Programs will appear once your Instant Pot data syncs."
                )
            } else {
                ForEach(viewModel.instantPotPrograms) { program in
                    VStack(alignment: .leading, spacing: VITASpacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.recipe)
                                    .font(VITATypography.headline)
                                Text(program.mode)
                                    .font(VITATypography.caption)
                                    .foregroundStyle(VITAColors.textSecondary)
                            }

                            Spacer()

                            CookModeBadge(isPressure: program.mode == "Pressure Cook")
                        }

                        HStack(spacing: VITASpacing.md) {
                            HStack(spacing: VITASpacing.xs) {
                                Text("Bioavailability:")
                                    .font(VITATypography.caption)
                                    .foregroundStyle(VITAColors.textSecondary)
                                Text(String(format: "%.1fx", program.bioavailability))
                                    .font(VITATypography.metricSmall)
                                    .foregroundStyle(program.bioavailability > 1.0 ? VITAColors.success : VITAColors.textPrimary)
                            }
                            Spacer()
                        }

                        Text(program.note)
                            .font(VITATypography.caption)
                            .foregroundStyle(program.mode == "Pressure Cook" ? VITAColors.success : VITAColors.amber)
                    }
                    .padding(VITASpacing.cardPadding)
                    .background(VITAColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
                }
            }
        }
    }
}

struct CookModeBadge: View {
    let isPressure: Bool

    var body: some View {
        HStack(spacing: VITASpacing.xs) {
            Image(systemName: isPressure ? "gauge.with.dots.needle.33percent" : "timer")
                .font(.caption)
            Text(isPressure ? "Pressure" : "Slow Cook")
                .font(VITATypography.chip)
        }
        .padding(.horizontal, VITASpacing.sm)
        .padding(.vertical, 3)
        .background(isPressure ? VITAColors.success.opacity(0.15) : VITAColors.amber.opacity(0.15))
        .foregroundStyle(isPressure ? VITAColors.success : VITAColors.amber)
        .clipShape(Capsule())
    }
}
