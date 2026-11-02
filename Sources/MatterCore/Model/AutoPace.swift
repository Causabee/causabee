import Foundation

/// When Auto writes a matter again, once its record has changed. A rewrite costs several cents, and
/// a change to one task is seldom the last: while the owner works in a matter it waits until they
/// leave it, or asks for it, or the matter has stood still for a while. New mail for a matter
/// nobody has open is written soon: it changes what the owner should do, and nobody is working there.
public enum AutoPace {
    /// How long a matter stands still before it is written all the same.
    public static let quiet: TimeInterval = 180
    /// How long new mail settles: a round of mail that brings three things is one update.
    public static let settle: TimeInterval = 2

    /// From when on a matter that last changed at `changed` is written, unless it is asked for.
    public static func due(changed: Date, open: Bool, newMail: Bool) -> Date {
        changed.addingTimeInterval(newMail && !open ? settle : quiet)
    }

    public static func isDue(changed: Date, now: Date, open: Bool, newMail: Bool, asked: Bool) -> Bool {
        asked || now >= due(changed: changed, open: open, newMail: newMail)
    }
}
