import MatterCore
import SwiftUI

/// What asking is doing, step by step, while the answer is on its way: what is done has its tick,
/// what is going on has the bee — and, once the question is out, how long it has been.
struct AskSteps: View {
    let step: AssistantAsk.Step
    /// When the question went out: the wait counts from there.
    let sentAt: Date?
    var size: CGFloat = 10

    #if os(iOS)
    private static let device = "iPhone"
    #else
    private static let device = "Mac"
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AssistantAsk.Step.allCases.filter { $0 <= step }, id: \.self) { one in
                HStack(spacing: 8) {
                    Group {
                        if one == step {
                            BeeLoader(size: size)
                        } else {
                            Image(systemName: "checkmark").font(.caption2.weight(.semibold)).foregroundStyle(Theme.done)
                        }
                    }
                    .frame(width: size * BeeLoader.aspect)
                    Text(words(one, done: one < step))
                    if one == .waiting, one == step, let sentAt {
                        TimelineView(.periodic(from: sentAt, by: 1)) { timeline in
                            Text("· \(max(0, Int(timeline.date.timeIntervalSince(sentAt)))) s").monospacedDigit()
                        }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func words(_ one: AssistantAsk.Step, done: Bool) -> String {
        let model = ModelChoice.assistant.label
        switch one {
        case .disguising: return done ? "Names and numbers disguised on this \(Self.device)" : "Disguising names and numbers on this \(Self.device) …"
        case .waiting: return done ? "\(model) has answered" : "Sent pseudonymised — \(model) is answering …"
        case .restoring: return "Putting the names back …"
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
