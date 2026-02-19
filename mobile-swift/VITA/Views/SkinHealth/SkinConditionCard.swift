import SwiftUI
import VITADesignSystem

struct SkinConditionCard: View {
    let condition: PerfectCorpService.SkinCondition
    let findings: [SkinHealthViewModel.CausalFinding]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            // Header row — tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: VITASpacing.sm) {
                    Image(systemName: condition.type.icon)
                        .font(.body)
                        .foregroundStyle(severityColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(condition.type.rawValue)
                            .font(VITATypography.headline)
                            .foregroundStyle(VITAColors.textPrimary)
                        Text(zonesLabel)
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(condition.severityLabel)
                            .font(VITATypography.caption)
                            .foregroundStyle(severityColor)
                        Text("\(Int(condition.confidence * 100))% confidence")
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Causal analysis — shown when expanded
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    if findings.isEmpty {
                        Text("No causal data found for this condition.")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    } else {
                        Text("Causal Analysis")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)

                        ForEach(findings) { finding in
                            causalRow(finding)
                        }
                    }
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                .stroke(severityColor.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Causal row

    private func causalRow(_ finding: SkinHealthViewModel.CausalFinding) -> some View {
        HStack(alignment: .top, spacing: VITASpacing.sm) {
            Image(systemName: finding.icon)
                .font(.caption)
                .foregroundStyle(VITAColors.causalHighlight)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(finding.cause)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textPrimary)
                    Spacer()
                    Text(finding.source)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(VITAColors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(VITAColors.tertiaryBackground)
                        .clipShape(Capsule())
                }

                Text(finding.detail)
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, VITASpacing.xs)
    }

    // MARK: - Helpers

    private var severityColor: Color {
        if condition.severity > 0.60 { return VITAColors.coral }
        if condition.severity > 0.35 { return VITAColors.amber }
        return VITAColors.success
    }

    private var zonesLabel: String {
        condition.affectedZones.map(\.rawValue).joined(separator: " · ")
    }
}
