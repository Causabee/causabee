import Foundation

/// When Auto writes a matter again, once its record has changed. A rewrite costs several cents, and
/// a change to one task is seldom the last: while the owner works in a matter it waits until they
/// leave it, or asks for it, or the matter has stood still for a while. Something new that came in —
/// mail, a screenshot, a photo, a scan, a file — for a matter nobody has open is written soon: it changes what the owner should do, and nobody is working there.
public enum AutoPace {
    /// How long a matter stands still before it is written all the same.
    public static let quiet: TimeInterval = 180
    /// How long what came in settles: a round that brings three things is one update.
    public static let settle: TimeInterval = 2

    /// From when on a matter that last changed at `changed` is written, unless it is asked for.
    public static func due(changed: Date, open: Bool, newMail: Bool) -> Date {
        changed.addingTimeInterval(newMail && !open ? settle : quiet)
    }

    public static func isDue(changed: Date, now: Date, open: Bool, newMail: Bool, asked: Bool) -> Bool {
        asked || now >= due(changed: changed, open: open, newMail: newMail)
    }

    /// How long a brief from a build that did not say what it was written for counts as just written.
    public static let justWritten: TimeInterval = 600

    /// Whether the brief the matter holds already stands for its record — whichever device wrote
    /// it. Then no device writes it again: a brief is written once, for all of them, and again only
    /// when the owner changes something or something new comes in.
    /// `stamp`: the record as it stands. `writtenElsewhere`: when another device wrote the step and
    /// the summary since this one last looked, if one did.
    public static func holds(brief: Brief?, stamp: String, writtenElsewhere: Date?, now: Date) -> Bool {
        // The brief says which record it is for: it holds for that one, and for no other.
        if let written = brief?.writtenFor { return written == stamp }
        // One from a build before says nothing: taken as it is only when another device just wrote it.
        guard let writtenElsewhere else { return false }
        return writtenElsewhere > now.addingTimeInterval(-justWritten)
    }
}
