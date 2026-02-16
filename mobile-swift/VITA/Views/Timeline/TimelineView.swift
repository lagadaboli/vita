import SwiftUI
import VITADesignSystem

struct TimelineView: View {
    var appState: AppState
    @State private var viewModel = TimelineViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineFilterBar(
                    filters: viewModel.filters,
                    selected: $viewModel.selectedFilter
                )

                ScrollView {
                    LazyVStack(spacing: VITASpacing.md) {
                        ForEach(viewModel.filteredEvents) { event in
                            TimelineEventCard(event: event)
                        }
                    }
                    .padding(.horizontal, VITASpacing.lg)
                    .padding(.vertical, VITASpacing.md)
                }
            }
            .background(VITAColors.background)
            .navigationTitle("Timeline")
            .onAppear {
                viewModel.load(from: appState)
            }
        }
    }
}
