import Foundation

/// How far Causabee reaches here: the plan and the device together. Pro thinks it through; without
/// it the rules hold everything and choose the next step, and Apple's model sorts mail and screenshots.
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

    /// Pro was never bought, or has ended.
    public var isFree: Bool { self == .device || self == .rules }

    public enum Action: Sendable, Equatable {
        case seePro, turnOn, topUp

        public var title: String {
            switch self {
            case .seePro: String(localized: "See Pro", bundle: .module)
            case .turnOn: String(localized: "Turn On", bundle: .module)
            case .topUp: String(localized: "Top Up", bundle: .module)
            }
        }
    }

    /// What is said, and what can be done about it. Nil when nothing is out of reach.
    /// `anew`: the day this month's Pro starts anew, as the app writes it.
    public func line(mails: Int, anew: String? = nil) -> (words: String, action: Action)? {
        let all = mails > 1 ? String(format: String(localized: "all %lld mails", bundle: .module), mails)
                            : String(localized: "every mail", bundle: .module)
        switch self {
        case .pro: return nil
        case .device, .rules: return (String(format: String(localized: "Pro reads %@ for this.", bundle: .module), all), .seePro)
        case .proOff: return (String(format: String(localized: "Pro is off. Turn it on to read %@.", bundle: .module), all), .turnOn)
        case .proUsedUp:
            return (anew.map { String(format: String(localized: "This month's Pro starts anew on %@.", bundle: .module), $0) }
                    ?? String(localized: "This month's Pro is used up.", bundle: .module), .topUp)
        }
    }
}
