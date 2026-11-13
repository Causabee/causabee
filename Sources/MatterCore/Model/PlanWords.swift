import Foundation

/// F007: what the switch waits for once Pro has nothing left — the month used up, or Pro ended. The
/// switch keeps the owner's setting; while it waits, nothing goes to the beeserver that it would refuse.
/// Kept on this device (UserDefaults), not synced: each device hears it from the beeserver itself.
public struct ProWait: Codable, Equatable, Sendable {
    /// The month's new start, when the month is used up.
    public var until: Date?
    /// Pro ended: only a top-up — or Pro bought again — ends the wait.
    public var ended: Bool

    public static let none = ProWait(until: nil, ended: false)
    public static let key = "pro.waits"

    public init(until: Date?, ended: Bool) {
        self.until = until
        self.ended = ended
    }

    public func holds(now: Date = Date()) -> Bool { ended || (until.map { now < $0 } ?? false) }

    /// What the beeserver's refusal says: "subscription_ended", or the month used up until `renewsOn`.
    public static func after(_ why: String, renewsOn: String?) -> ProWait {
        if why == "subscription_ended" { return ProWait(until: nil, ended: true) }
        let next = renewsOn.flatMap(MatterStatus.date(of:)) ?? Date().addingTimeInterval(86_400)
        return ProWait(until: next, ended: false)
    }

    /// The beeserver says something is left again. An ended Pro still counts a month there, so for
    /// it only a top-up counts.
    public func over(monthUsed: Double?, extraShare: Double) -> Bool {
        extraShare > 0 || (!ended && (monthUsed ?? 1) < 1)
    }

    public static var stored: ProWait {
        guard let data = UserDefaults.standard.data(forKey: key), let wait = try? JSONDecoder().decode(ProWait.self, from: data) else { return .none }
        return wait
    }

    public static func store(_ wait: ProWait) {
        if wait == .none { UserDefaults.standard.removeObject(forKey: key) }
        else if let data = try? JSONEncoder().encode(wait) { UserDefaults.standard.set(data, forKey: key) }
    }

    public static func clear() { store(.none) }
}

/// F007: every word of the plan — its row in Settings, its page and the "Use Pro" switch — from what
/// is bought, what is left and whether it is used. One for the Mac, the iPhone and the iPad.
public struct PlanWords: Equatable, Sendable {
    /// What the App Store says of the subscription's period.
    public enum Renewal: Equatable, Sendable {
        case renews(Date)
        case ends(Date)
        case changes(to: Plan, on: Date)
        case billingProblem(Date?)
    }

    public private(set) var name: String
    public private(set) var corner: String
    /// The row's line in Settings: "Causabee Pro · 59 % left · 33 % in top-ups".
    public private(set) var row: String
    public private(set) var switchLine: String
    /// Pro or a top-up to use.
    public private(set) var canUse: Bool
    /// The switch as drawn: on while it is used, or while it waits.
    public private(set) var switchShownOn: Bool
    /// The top-up's button: "Add a top-up" with Pro, "Pro, now and then" without; nil when the plans come first.
    public private(set) var topUp: String?
    /// Nothing bought and no top-up: "See the plans".
    public private(set) var seesPlans: Bool

    /// `until`: how long another device's purchase lasts, when this one has none of its own;
    /// `proEnded`: when Pro ended, said while top-ups are left; `credit`: a top-up is left;
    /// `reader`: the model that reads with Pro, by its short name.
    public init(plan: Plan, renewal: Renewal? = nil, until: Date? = nil, proEnded: Date? = nil, meter: ProMeter, credit: Bool,
                useOn: Bool, wait: ProWait = .none, reader: String, now: Date = Date()) {
        name = switch plan {
        case .free: "Causabee"
        case .matters: "Causabee Plus"
        case .pro: "Causabee Pro"
        }
        corner = switch renewal {
        case .renews(let date): String(format: String(localized: "renews %@", bundle: .module), Self.long(date))
        case .ends(let date): String(format: String(localized: "ends %@", bundle: .module), Self.long(date))
        case .changes(let to, let date):
            String(format: String(localized: "%@ from %@", bundle: .module), to == .pro ? "Pro" : "Plus", Self.long(date))
        case .billingProblem: String(localized: "payment problem", bundle: .module)
        case nil:
            if plan != .pro, credit, let proEnded { String(format: String(localized: "Pro ended %@", bundle: .module), Self.long(proEnded)) }
            else if plan == .free { String(localized: "Free", bundle: .module) }
            else { until.flatMap { $0 > now ? String(format: String(localized: "until %@", bundle: .module), Self.long($0)) : nil } ?? "" }
        }

        canUse = plan == .pro || credit
        let waiting = useOn && wait.holds(now: now)
        switchShownOn = useOn && (canUse || waiting)
        topUp = plan == .pro ? String(localized: "Add a top-up", bundle: .module)
            : plan == .matters || credit ? String(localized: "Pro, now and then", bundle: .module) : nil
        seesPlans = topUp == nil

        if !canUse {
            row = plan == .free ? String(localized: "Causabee · Free", bundle: .module) : name
        } else if meter.bars.contains(where: { !$0.counted }) {
            row = name + String(localized: " · not counted yet", bundle: .module)
        } else {
            var parts = [name]
            for bar in meter.bars {
                switch bar.kind {
                case .month: parts.append(bar.left <= 0 ? String(localized: "used for this month", bundle: .module)
                                          : String(format: String(localized: "%@ left", bundle: .module), bar.number))
                case .topUps: parts.append(String(format: String(localized: "%@ in top-ups", bundle: .module), bar.number))
                }
            }
            if !useOn { parts.append(String(localized: "not in use", bundle: .module)) }
            row = parts.joined(separator: " · ")
        }

        if waiting {
            switchLine = wait.ended
                ? String(localized: "On, waiting: Pro has ended. A top-up goes on at once.", bundle: .module)
                : String(format: String(localized: "On, waiting: nothing left to use until %@.", bundle: .module),
                         wait.until.map(Self.long) ?? String(localized: "it starts anew", bundle: .module))
        } else if !canUse {
            switchLine = String(localized: "Needs Pro or a top-up.", bundle: .module)
        } else if useOn {
            switchLine = String(format: String(localized: "%@ reads what comes in, as it comes, names disguised first.", bundle: .module), reader)
        } else {
            switchLine = String(localized: "Off: Apple's model on this device reads what comes in. Nothing leaves it.", bundle: .module)
        }
    }

    /// "28 November", as the plan's other dates.
    static func long(_ date: Date) -> String { ProMeter.long(date) }
}
