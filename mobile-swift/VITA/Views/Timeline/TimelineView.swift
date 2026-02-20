import SwiftUI
import VITADesignSystem

struct TimelineView: View {
    var appState: AppState
    @State private var viewModel = TimelineViewModel()
    private var isComponentLoading: Bool {
        !appState.isLoaded
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineFilterBar(
                    filters: viewModel.filters,
                    selected: $viewModel.selectedFilter
                )

                ScrollView {
                    LazyVStack(spacing: VITASpacing.md) {
                        if isComponentLoading {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonCard(lines: [120, 180, 90], lineHeight: 11)
                            }
                        } else if viewModel.filteredEvents.isEmpty {
                            EmptyDataStateView(
                                title: viewModel.emptyStateTitle,
                                message: viewModel.emptyStateMessage
                            )
                        } else {
                            ForEach(viewModel.filteredEvents) { event in
                                TimelineEventCard(event: event)
                            }
                        }
                    }
                    .padding(.horizontal, VITASpacing.lg)
                    .padding(.vertical, VITASpacing.md)
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Timeline")
            .task(id: appState.isLoaded) {
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .onAppear {
                viewModel.load(from: appState)
            }
            .onChange(of: appState.selectedTab) { _, tab in
                guard tab == .timeline, appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .onChange(of: appState.selectedMockScenario) { _, _ in
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .refreshable {
                viewModel.load(from: appState)
            }
        }
    }

}
