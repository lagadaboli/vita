import SwiftUI

public struct ChipView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    public init(label: String, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(VITATypography.chip)
                .padding(.horizontal, VITASpacing.md)
                .padding(.vertical, VITASpacing.sm)
                .background(isSelected ? VITAColors.teal : VITAColors.tertiaryBackground)
                .foregroundStyle(isSelected ? .white : VITAColors.textSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

public struct ChipGroup: View {
    let chips: [String]
    @Binding var selected: String

    public init(chips: [String], selected: Binding<String>) {
        self.chips = chips
        self._selected = selected
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VITASpacing.sm) {
                ForEach(chips, id: \.self) { chip in
                    ChipView(label: chip, isSelected: selected == chip) {
                        selected = chip
                    }
                }
            }
            .padding(.horizontal, VITASpacing.lg)
        }
    }
}
