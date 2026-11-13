import Foundation

/// F006: what the plan shows of Pro — this month's bar, and the top-ups' in a bar of their own under
/// it, both on the month's scale: a full bar is one Pro month. Drawn from what the beeserver says of
/// the account, shares and never money; the same on every device.
public struct ProMeter: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case month, topUps }

    public struct Bar: Equatable, Sendable {
        public var kind: Kind
        /// What is left, in Pro months: 0.4 of the month, 1.333 of four top-ups.
        public var left: Double
        /// In the warning colour: what is left together is running out, and this is the bar in use.
        public var low: Bool
        /// F008: the top-ups' bar holds only the start credit — it is named so.
        public var start = false
        /// F007: "Use Pro" is on. Off, the bar stays, greyed, and says it is not in use.
        public var inUse = true
        /// F007: the beeserver has said what is left. Not yet: an empty bar, never none.
        public var counted = true

        /// How long it is drawn, 0…1 of the bar: more than a Pro month fills it.
        public var length: Double { min(1, max(0, left)) }
        var percent: Int { Int((max(0, left) * 100).rounded()) }
        /// "40 %", "133 %".
        public var number: String { counted ? "\(percent) %" : "–" }
        public var words: String {
            guard counted else { return String(localized: "not counted yet", bundle: .module) }
            return (kind == .month ? String(localized: "left", bundle: .module) : start ? String(localized: "of a Pro month in your start credit", bundle: .module) : String(localized: "of a Pro month in top-ups", bundle: .module)) + (inUse ? "" : String(localized: " · not in use", bundle: .module))
        }
        public var spoken: String {
            let name = kind == .month ? String(localized: "This month's Pro", bundle: .module) : start ? Welcome.startName : String(localized: "Top-ups", bundle: .module)
            guard counted else { return "\(name): " + String(localized: "not counted yet", bundle: .module) }
            return (kind == .month ? "\(name): \(percent) " + String(localized: "percent left", bundle: .module) : "\(name): \(percent) " + String(localized: "percent of a Pro month left", bundle: .module)) + (inUse ? "" : String(localized: ", not in use", bundle: .module))
        }
    }

    /// Below this share, the month's and the top-ups' together, Pro runs low.
    public static let lowShare = 0.2

    public private(set) var bars: [Bar] = []
    /// Under the bars: "Starts anew on 1 December · top-ups carry over".
    public private(set) var line: String?
    /// When all is used: what goes on instead.
    public private(set) var note: String?
    public private(set) var runsLow = false
    /// The bar now being used: the month's while any of it is left, then the top-ups'.
    public private(set) var using: Kind?

    /// `monthUsed` 0…1 of this month's Pro, nil when there is none; `extraShare` the top-ups left,
    /// in Pro months; `kind` the account's — "credit" is top-ups without Pro; `renewsOn` "2026-12-01";
    /// `pro` whether Pro is bought, as the App Store says: without it there is no month to show, whatever
    /// the server still counts of one (the owner's Mac, 12 November: Pro ended, "0 % left" above the top-ups).
    /// `inUse`: "Use Pro" is on (F007). `counted`: the beeserver has answered — until then Pro or a
    /// top-up known shows an empty bar, never none.
    /// `startCredit` (F008): what is left beyond the month is only the start credit.
    public init(monthUsed: Double?, extraShare: Double, kind: String, renewsOn: String?, pro: Bool, inUse: Bool = true, counted: Bool = true,
                startCredit: Bool = false) {
        defer {
            if startCredit { for index in bars.indices where bars[index].kind == .topUps { bars[index].start = true } }
        }
        let extra = max(0, extraShare)
        if !counted {
            if pro { bars = [Bar(kind: .month, left: 0, low: false, inUse: inUse, counted: false)] }
            else if kind == "credit" { bars = [Bar(kind: .topUps, left: 0, low: false, inUse: inUse, counted: false)] }
            line = bars.isEmpty ? nil : String(localized: "Shown once Causabee reaches its server.", bundle: .module)
            return
        }
        if kind == "credit" || (!pro && (monthUsed != nil || extra > 0)) {
            bars = [Bar(kind: .topUps, left: extra, low: false)]
            using = .topUps
            runsLow = extra <= Self.lowShare
            line = extra > 0 ? (startCredit ? String(localized: "Kept until it is used.", bundle: .module) : String(localized: "Top-ups carry over from month to month.", bundle: .module)) : nil
            note = extra > 0 ? nil : startCredit ? String(localized: "Used. Apple's model on this device reads what comes in — or buy a top-up.", bundle: .module)
                : String(localized: "Used. Apple's model on this device reads what comes in — or buy another top-up.", bundle: .module)
        } else if pro, let monthUsed {
            let month = max(0, 1 - monthUsed)
            bars = [Bar(kind: .month, left: month, low: false)]
            if extra > 0 { bars.append(Bar(kind: .topUps, left: extra, low: false)) }
            using = month > 0 || extra <= 0 ? .month : .topUps
            runsLow = month + extra <= Self.lowShare
            let anew = renewsOn.flatMap(MatterStatus.date(of:))
                .map { String(format: String(localized: "Starts anew on %@", bundle: .module), Self.long($0)) }
            let carries = extra > 0 ? String(localized: "top-ups carry over", bundle: .module) : nil
            line = anew.map { [$0, carries].compactMap { $0 }.joined(separator: " · ") } ?? carries.map { $0.prefix(1).uppercased() + $0.dropFirst() }
            note = month + extra > 0 ? nil
                : String(localized: "Used for this month. Causabee goes on with Apple's model on this device until it starts anew — or with a top-up.", bundle: .module)
        }
        if runsLow { for index in bars.indices where bars[index].kind == using { bars[index].low = true } }
        for index in bars.indices { bars[index].inUse = inUse }
    }

    /// "1 December", "1. Dezember": the day as the device writes it (F009 AC-3).
    static func long(_ date: Date) -> String { date.formatted(.dateTime.day().month(.wide)) }
}
