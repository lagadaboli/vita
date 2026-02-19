import SwiftUI
import VITADesignSystem

struct QueryInputView: View {
    @Bindable var viewModel: AskVITAViewModel
    var appState: AppState

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        appState.isLoaded && !viewModel.queryText.isEmpty && !viewModel.isQuerying
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(alignment: .bottom, spacing: VITASpacing.sm) {
                // Input field
                HStack(spacing: VITASpacing.sm) {
                    TextField(
                        appState.isLoaded ? "Ask VITA anything..." : "Loading health context...",
                        text: $viewModel.queryText,
                        axis: .vertical
                    )
                    .font(VITATypography.body)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .focused($isFocused)
                    .onSubmit {
                        guard canSend else { return }
                        Task { await viewModel.query(appState: appState) }
                    }
                    .disabled(!appState.isLoaded || viewModel.isQuerying)
                }
                .padding(.horizontal, VITASpacing.md)
                .padding(.vertical, 10)
                .background(VITAColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22))

                // Send / Loading button
                Button {
                    guard canSend else { return }
                    isFocused = false
                    Task { await viewModel.query(appState: appState) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? VITAColors.teal : VITAColors.secondaryBackground)
                            .frame(width: 36, height: 36)

                        if viewModel.isQuerying {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(canSend ? .white : VITAColors.textTertiary)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: canSend)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isQuerying)
                }
                .disabled(!canSend && !viewModel.isQuerying)
            }
            .padding(.horizontal, VITASpacing.md)
            .padding(.vertical, VITASpacing.sm)
        }
        .background(.ultraThinMaterial)
    }
}
