import Foundation

/// How far Causabee reaches here: the plan and the device together. Pro thinks it through; Apple's
/// model on the device keeps things organized; without either, the rules alone hold everything.
/// A control that cannot work here says so before it is tried, in these words.
public enum Reach: Sendable, Equatable {
    /// Pro is on, or a key of the owner's own: a whole matter can be read.
    case pro
    /// Pro is bought and the bolt is off.
    case proOff
    /// Pro is bought and this month's is used up.
    case proUsedUp
    /// No Pro: Apple's model on this device.
    case device
    /// No Pro and no Apple Intelligence: rules only.
    case rules

    public static func of(asks: Bool, holdsPro: Bool, usedUp: Bool, onDevice: Bool) -> Reach {
        if asks { return .pro }
        if holdsPro { return usedUp ? .proUsedUp : .proOff }
        return onDevice ? .device : .rules
    }

    public enum Action: Sendable, Equatable {
        case seePro, turnOn, topUp

        public var title: String {
            switch self {
            case .seePro: "See Pro"
            case .turnOn: "Turn On"
            case .topUp: "Top Up"
            }
        }
    }

    /// What is said, and what can be done about it. Nil when nothing is out of reach.
    /// `anew`: the day this month's Pro starts anew, as the app writes it.
    public func line(mails: Int, anew: String? = nil) -> (words: String, action: Action)? {
        let all = mails > 1 ? "all \(mails) mails" : "every mail"
        switch self {
        case .pro: return nil
        case .device: return ("Pro reads \(all) for this.", .seePro)
        case .rules: return ("Turn on Apple Intelligence in Settings, or use Pro.", .seePro)
        case .proOff: return ("Pro is off. Turn it on to read \(all).", .turnOn)
        case .proUsedUp: return (anew.map { "This month's Pro starts anew on \($0)." } ?? "This month's Pro is used up.", .topUp)
        }
    }
}
