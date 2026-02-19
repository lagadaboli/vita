import SwiftUI
import VITADesignSystem

struct QueryInputView: View {
    @Bindable var viewModel: AskVITAViewModel
    var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: VITASpacing.md) {
                TextField(appState.isLoaded ? "Why am I tired?" : "Loading your health context...", text: $viewModel.queryText)
                    .font(VITATypography.body)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await viewModel.query(appState: appState) }
                    }
                    .disabled(!appState.isLoaded)

                Button {
                    Task { await viewModel.query(appState: appState) }
                } label: {
                    if viewModel.isQuerying {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                viewModel.queryText.isEmpty ? VITAColors.textTertiary : VITAColors.teal
                            )
                    }
                }
                .disabled(!appState.isLoaded || viewModel.queryText.isEmpty || viewModel.isQuerying)
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.vertical, VITASpacing.md)
        }
        .background(.ultraThinMaterial)
    }
}
