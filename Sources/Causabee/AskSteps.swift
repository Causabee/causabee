import MatterCore
import SwiftUI

/// What asking is doing, in one line that changes in place: the bee, a few words, and once the
/// question is out, how long it has been. That it goes out pseudonymised is said under the field
/// already, and which AI answered under the answer (8 November: two lines of ticks, device and
/// model names were noise while one waits).
struct AskSteps: View {
    let step: AssistantAsk.Step
    /// When the question went out: the wait counts from there.
    let sentAt: Date?
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 8) {
            BeeLoader(size: size).frame(width: size * BeeLoader.aspect)
            Text(words)
            if step == .waiting, let sentAt {
                TimelineView(.periodic(from: sentAt, by: 1)) { timeline in
                    Text("· \(max(0, Int(timeline.date.timeIntervalSince(sentAt)))) s").monospacedDigit()
                }
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var words: String {
        switch step {
        case .disguising: "Disguising names …"
        case .waiting: "Thinking …"
        case .restoring: "Putting names back …"
        }
    }
}

#Preview("Steps of asking") {
    VStack(alignment: .leading, spacing: 24) {
        AskSteps(step: .disguising, sentAt: nil)
        AskSteps(step: .waiting, sentAt: Date().addingTimeInterval(-7))
        AskSteps(step: .restoring, sentAt: Date().addingTimeInterval(-12))
    }
    .padding(32)
}
