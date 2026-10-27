import Foundation

/// What the owner has: Causabee for free — up to three open matters — Plus, every matter, for a small
/// subscription, or Pro, which has the bigger AI and every matter too. Nothing already there is ever
/// locked: only a fourth matter waits, until a matter is closed or the plan has room.
public enum Plan: String, Codable, Sendable, Comparable {
    case free, matters, pro

    /// The plan as last known on this device, where no view is at hand — Pro's switch, the share
    /// sheet. Written by the app's `Store`.
    public static let cacheKey = "plan.current"
    public static var cached: Plan { Plan(rawValue: UserDefaults.standard.string(forKey: cacheKey) ?? "") ?? .free }

    /// Open matters Normal holds for free; closed ones do not count.
    public static let freeMatters = 3

    /// How many more matters may start, nil when there is no limit.
    public func room(open: Int) -> Int? {
        self == .free ? max(0, Self.freeMatters - open) : nil
    }

    public static func < (a: Plan, b: Plan) -> Bool {
        let order: [Plan] = [.free, .matters, .pro]
        return order.firstIndex(of: a)! < order.firstIndex(of: b)!
    }
}

extension Matter {
    /// The open matters, as the plan counts them.
    public static func openCount(in matters: [Matter]) -> Int { matters.filter { !$0.isClosed }.count }
}

extension Judgement {
    /// A mail held for want of room: without a matter, and saying which one it would have started —
    /// so it is offered among the mail without a matter, and placed with a tap once there is room.
    public func waitingForRoom() -> Judgement {
        var waiting = self
        let name = matterTitle ?? matter.map(Matter.readable) ?? ""
        waiting.matter = nil
        waiting.matterTitle = nil
        waiting.matterReason = "Would start the matter “\(name)” — Causabee holds \(Plan.freeMatters) open matters for free"
        return waiting
    }
}
