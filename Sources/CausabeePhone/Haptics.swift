import UIKit

/// What the iPhone says to the hand, and only where something happened: a question went out, an
/// answer came, a task is done, something could not be done. Never for a tap that only looks around.
@MainActor
enum Haptics {
    /// Something small was done: sent, copied, dismissed, taken back.
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// Something was cut short: the question on its way was stopped.
    static func stop() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    /// Held long enough: what was under the finger opens its menu.
    static func held() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// Arrived where it was asked to go: the row a source or an overdue line pointed at.
    static func landed() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    /// It worked: the answer is there, a task is done, a suggestion is taken in, the mail is sorted.
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// It did not: no answer, no key, the mail could not be sorted.
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
