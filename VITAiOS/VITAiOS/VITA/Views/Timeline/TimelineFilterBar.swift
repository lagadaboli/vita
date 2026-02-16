import SwiftUI
import VITADesignSystem

struct TimelineFilterBar: View {
    let filters: [String]
    @Binding var selected: String

    var body: some View {
        ChipGroup(chips: filters, selected: $selected)
            .padding(.vertical, VITASpacing.sm)
    }
}
