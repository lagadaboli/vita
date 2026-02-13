import SwiftUI
import VITADesignSystem

struct IntegrationsView: View {
    var appState: AppState
    @State private var viewModel = IntegrationsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    AppleWatchSection(viewModel: viewModel)
                    DoorDashSection(viewModel: viewModel)
                    RotimaticSection(viewModel: viewModel)
                    InstantPotSection(viewModel: viewModel)
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("Integrations")
            .onAppear {
                viewModel.load(from: appState)
            }
        }
    }
}
