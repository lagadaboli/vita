import SwiftUI
import VITADesignSystem
import VITACore

struct DashboardView: View {
    var appState: AppState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    // Health Score Ring
                    HealthScoreGauge(score: viewModel.healthScore)
                        .padding(.top, VITASpacing.md)

                    // Mini Glucose Chart
                    MiniGlucoseChart(dataPoints: viewModel.glucoseReadings)

                    // Metric Cards Row
                    MetricCardRow(viewModel: viewModel)

                    // Insights
                    VStack(alignment: .leading, spacing: VITASpacing.md) {
                        Text("Insights")
                            .font(VITATypography.title3)
                            .padding(.horizontal, VITASpacing.lg)

                        ForEach(viewModel.insights) { insight in
                            InsightAlertCard(insight: insight)
                                .padding(.horizontal, VITASpacing.lg)
                        }
                    }

                    // Integration Status
                    IntegrationStatusRow(watchStatus: viewModel.watchStatus)
                        .padding(.horizontal, VITASpacing.lg)
                }
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("VITA")
            .onAppear {
                viewModel.load(from: appState)
            }
        }
    }
}
