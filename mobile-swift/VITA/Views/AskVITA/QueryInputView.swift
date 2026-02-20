import SwiftUI
import VITADesignSystem

struct QueryInputView: View {
    enum Placement {
        case centered
        case docked
    }

    @Bindable var viewModel: AskVITAViewModel
    var appState: AppState
    var placement: Placement = .docked
    var composerNamespace: Namespace.ID? = nil

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        appState.isLoaded &&
        !viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.isQuerying
    }

    var body: some View {
        Group {
            if placement == .docked {
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.5)

                    composer
                        .padding(.horizontal, VITASpacing.md)
                        .padding(.vertical, VITASpacing.sm)
                }
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                composer
                    .padding(.horizontal, VITASpacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var composer: some View {
        let row = HStack(alignment: .bottom, spacing: VITASpacing.sm) {
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
                    sendQuery()
                }
                .disabled(!appState.isLoaded || viewModel.isQuerying)
            }
            .padding(.horizontal, VITASpacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VITAColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                sendQuery()
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(placement == .centered ? VITAColors.cardBackground : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    placement == .centered ? VITAColors.teal.opacity(0.22) : Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(
            color: placement == .centered ? VITAColors.teal.opacity(0.16) : .clear,
            radius: 14,
            y: 8
        )

        if let composerNamespace {
            row.matchedGeometryEffect(id: "ask-vita-composer", in: composerNamespace)
        } else {
            row
        }
    }

    private func sendQuery() {
        guard canSend else { return }
        Task { await viewModel.sendMessage(appState: appState) }
    }
}
