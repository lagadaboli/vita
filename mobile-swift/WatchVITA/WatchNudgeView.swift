import SwiftUI
import VITACore

#if os(watchOS)
/// Displays a causal nudge on Apple Watch.
/// Shows nudge text + action button. Watch never runs SLM (insufficient RAM).
struct WatchNudgeView: View {
    let nudge: WatchNudgePayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Confidence indicator
                HStack {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(nudge.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Nudge text
                Text(nudge.nudgeText)
                    .font(.body)
                    .lineSpacing(2)

                Divider()

                // Action suggestion
                Button {
                    // Haptic feedback + dismiss
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text(nudge.actionText)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                // Timestamp
                Text(nudge.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle("VITA")
    }

    private var confidenceColor: Color {
        switch nudge.confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .yellow
        }
    }
}
#endif
