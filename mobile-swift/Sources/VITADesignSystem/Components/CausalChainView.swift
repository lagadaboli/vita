import SwiftUI

public struct CausalChainNode: Identifiable {
    public let id = UUID()
    public let icon: String
    public let label: String
    public let detail: String
    public let timeOffset: String?
    public let color: Color

    public init(icon: String, label: String, detail: String, timeOffset: String? = nil, color: Color = VITAColors.causalNode) {
        self.icon = icon
        self.label = label
        self.detail = detail
        self.timeOffset = timeOffset
        self.color = color
    }
}

public struct CausalChainView: View {
    let nodes: [CausalChainNode]

    public init(nodes: [CausalChainNode]) {
        self.nodes = nodes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                CausalChainNodeView(node: node, isLast: index == nodes.count - 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index < nodes.count - 1 {
                    CausalChainArrow(timeOffset: nodes[index + 1].timeOffset)
                }
            }
        }
    }
}

struct CausalChainNodeView: View {
    let node: CausalChainNode
    let isLast: Bool

    var body: some View {
        HStack(spacing: VITASpacing.md) {
            ZStack {
                Circle()
                    .fill(node.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: node.icon)
                    .font(.callout)
                    .foregroundStyle(node.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if !node.detail.isEmpty {
                    Text(node.detail)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CausalChainArrow: View {
    let timeOffset: String?

    var body: some View {
        HStack(spacing: VITASpacing.sm) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(VITAColors.causalEdge)
                    .frame(width: 2, height: 20)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(VITAColors.causalEdge)
            }
            .frame(width: 40)

            if let timeOffset {
                Text(timeOffset)
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
                    .padding(.horizontal, VITASpacing.sm)
                    .padding(.vertical, 2)
                    .background(VITAColors.tertiaryBackground)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}
