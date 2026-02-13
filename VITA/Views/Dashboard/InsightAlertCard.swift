import SwiftUI
import VITADesignSystem

struct InsightAlertCard: View {
    let insight: DashboardViewModel.InsightData

    var body: some View {
        InsightCard(
            icon: insight.icon,
            title: insight.title,
            message: insight.message,
            severity: insight.severity,
            timestamp: insight.timestamp
        )
    }
}
