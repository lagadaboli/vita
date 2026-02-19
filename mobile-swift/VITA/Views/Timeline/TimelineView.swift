import SwiftUI
import VITADesignSystem

struct TimelineView: View {
    var appState: AppState
    @State private var viewModel = TimelineViewModel()
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isLoaded || isRefreshing {
                    LoadingStateView(
                        title: "Loading Timeline",
                        message: "Building your timeline from recent health and behavior events."
                    )
                } else {
                    VStack(spacing: 0) {
                        TimelineFilterBar(
                            filters: viewModel.filters,
                            selected: $viewModel.selectedFilter
                        )

                        ScrollView {
                            LazyVStack(spacing: VITASpacing.md) {
                                if viewModel.filteredEvents.isEmpty {
                                    EmptyDataStateView(
                                        title: "No Timeline Data Yet",
                                        message: "Once HealthKit and integrations sync, your events will appear here."
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
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Timeline")
            .task(id: appState.isLoaded) {
                await refreshTimeline()
            }
            .refreshable {
                await refreshTimeline()
            }
        }
    }

    @MainActor
    private func refreshTimeline() async {
        guard appState.isLoaded else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await appState.refreshHealthData()
        viewModel.load(from: appState)
    }
}
