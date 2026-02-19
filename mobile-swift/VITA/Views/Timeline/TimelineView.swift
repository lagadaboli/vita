import SwiftUI
import VITADesignSystem

struct TimelineView: View {
    var appState: AppState
    @State private var viewModel = TimelineViewModel()
    @State private var isRefreshing = false

    private var isComponentLoading: Bool {
        !appState.isLoaded
            || ((isRefreshing || appState.isHealthSyncing) && viewModel.filteredEvents.isEmpty && !viewModel.hasLoaded)
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
                await refreshTimeline(force: false)
            }
            .task(id: appState.lastHealthRefreshAt) {
                guard appState.isLoaded else { return }
                viewModel.load(from: appState)
            }
            .onAppear {
                Task {
                    await refreshTimeline(force: false)
                }
            }
            .onChange(of: appState.screenTimeStatus) { _, _ in
                Task {
                    await refreshTimeline(force: false)
                }
            }
            .refreshable {
                await refreshTimeline(force: true)
            }
        }
    }

    @MainActor
    private func refreshTimeline(force: Bool) async {
        guard appState.isLoaded else { return }
        viewModel.load(from: appState)
        if force {
            isRefreshing = true
        }

        await appState.refreshHealthDataIfNeeded(maxAge: 150, force: force)
        viewModel.load(from: appState)
        if force {
            isRefreshing = false
        }
    }
}
