import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(viewModel: viewModel, isLoading: false)
                    DoorDashSection(viewModel: viewModel, isLoading: false)
                    InstacartSection(viewModel: viewModel, isLoading: false)
                    RotimaticSection(viewModel: viewModel, isLoading: false)
                    InstantPotSection(viewModel: viewModel, isLoading: false)
                    WeighingMachineSection(viewModel: viewModel, isLoading: false)
                    EnvironmentSection(viewModel: viewModel, isLoading: false)
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxl)
            }
            .refreshable {
                viewModel.refresh()
            }
            .background(VITAColors.background)
            .navigationTitle("Integrations")
            .onAppear {
                viewModel.load(from: appState)
            }
        }
    }
}
