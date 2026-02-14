import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(viewModel: viewModel)
                    DoorDashSection(viewModel: viewModel)
                    InstacartSection(viewModel: viewModel)
                    RotimaticSection(viewModel: viewModel)
                    InstantPotSection(viewModel: viewModel)
                    WeighingMachineSection(viewModel: viewModel)
                    EnvironmentSection(viewModel: viewModel)
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("Integrations")
            .onAppear {
                viewModel.load(from: appState)
            }
            .onReceive(refreshTimer) { _ in
                viewModel.load(from: appState)
            }
        }
    }
}
