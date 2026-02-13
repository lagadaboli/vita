import SwiftUI

public enum ConnectionStatus: Sendable {
    case connected, syncing, disconnected, notConfigured

    public var label: String {
        switch self {
        case .connected: return "Connected"
        case .syncing: return "Syncing"
        case .disconnected: return "Disconnected"
        case .notConfigured: return "Not Set Up"
        }
    }

    public var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .disconnected: return "xmark.circle.fill"
        case .notConfigured: return "questionmark.circle"
        }
    }

    public var color: Color {
        switch self {
        case .connected: return VITAColors.success
        case .syncing: return VITAColors.info
        case .disconnected: return VITAColors.coral
        case .notConfigured: return VITAColors.textTertiary
        }
    }
}

public struct ConnectionStatusBadge: View {
    let name: String
    let icon: String
    let status: ConnectionStatus

    public init(name: String, icon: String, status: ConnectionStatus) {
        self.name = name
        self.icon = icon
        self.status = status
    }

    public var body: some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(status.color)
                .frame(width: 28)

            Text(name)
                .font(VITATypography.callout)
                .foregroundStyle(VITAColors.textPrimary)

            Spacer()

            HStack(spacing: VITASpacing.xs) {
                Image(systemName: status.icon)
                    .font(.caption)
                Text(status.label)
                    .font(VITATypography.caption)
            }
            .foregroundStyle(status.color)
        }
        .padding(.vertical, VITASpacing.sm)
    }
}
