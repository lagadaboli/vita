import SwiftUI
import VITADesignSystem

struct IntegrationStatusRow: View {
    let watchStatus: ConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            Text("Integrations")
                .font(VITATypography.title3)

            VStack(spacing: 0) {
                ConnectionStatusBadge(name: "Apple Watch", icon: "applewatch", status: watchStatus)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "DoorDash", icon: "bag", status: .connected)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "Rotimatic", icon: "circle.grid.3x3", status: .connected)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "Instant Pot", icon: "flame", status: .connected)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "Instacart", icon: "cart", status: .connected)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "Body Scale", icon: "scalemass", status: .connected)
                Divider().padding(.leading, 44)
                ConnectionStatusBadge(name: "Environment", icon: "cloud.sun", status: .connected)
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        }
    }
}
