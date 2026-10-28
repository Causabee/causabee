import Foundation

/// The mail providers Causabee knows by name — their server, what kind of password they want,
/// and the one catch some have — so the setup can say "Found: GMX" and show the right steps,
/// instead of asking for a server.
public struct MailProvider: Sendable, Equatable, Identifiable {
    public enum Password: Sendable, Equatable {
        /// Google's app password: 16 letters, shown in four groups.
        case google
        /// Apple's app-specific password: four groups of four letters with dashes.
        case apple
        /// A password made for apps, in the provider's own form.
        case appPassword
        /// The usual password of the account.
        case usual
    }

    /// What has to happen at the provider before Causabee can read: GMX and Web.de let apps in
    /// only once IMAP is allowed in their settings.
    public enum Catch: Sendable, Equatable {
        case allowIMAP(settings: URL)
        /// T-Online: a separate mail password, not the one of the Telekom login.
        case mailPassword(settings: URL)
    }

    public var id: String
    public var name: String
    public var domains: [String]
    public var host: String
    public var port: UInt16 = 993
    public var kind: MailDiscovery.Kind = .other
    public var password: Password = .usual
    public var `catch`: Catch? = nil
    /// Where the password for apps is made, when the provider wants one.
    public var passwordPage: URL? = nil

    public init(id: String, name: String, domains: [String], host: String, port: UInt16 = 993, kind: MailDiscovery.Kind = .other,
                password: Password = .usual, catch: Catch? = nil, passwordPage: URL? = nil) {
        self.id = id; self.name = name; self.domains = domains; self.host = host; self.port = port
        self.kind = kind; self.password = password; self.catch = `catch`; self.passwordPage = passwordPage
    }

    public static let gmail = MailProvider(id: "gmail", name: "Gmail", domains: ["gmail.com", "googlemail.com"], host: "imap.gmail.com",
                                           kind: .gmail, password: .google, passwordPage: URL(string: "https://myaccount.google.com/apppasswords"))
    public static let icloud = MailProvider(id: "icloud", name: "iCloud Mail", domains: ["icloud.com", "me.com", "mac.com"], host: "imap.mail.me.com",
                                            kind: .icloud, password: .apple, passwordPage: URL(string: "https://account.apple.com/account/manage"))

    /// The others, in the order the setup lists them when a provider was not found by itself.
    public static let others: [MailProvider] = [
        MailProvider(id: "gmx", name: "GMX", domains: ["gmx.de", "gmx.net", "gmx.at", "gmx.ch", "gmx.com"], host: "imap.gmx.net",
                     catch: .allowIMAP(settings: URL(string: "https://www.gmx.net/")!)),
        MailProvider(id: "webde", name: "Web.de", domains: ["web.de"], host: "imap.web.de",
                     catch: .allowIMAP(settings: URL(string: "https://web.de/")!)),
        MailProvider(id: "tonline", name: "T-Online", domains: ["t-online.de", "magenta.de"], host: "secureimap.t-online.de",
                     catch: .mailPassword(settings: URL(string: "https://www.t-online.de/email/")!)),
        MailProvider(id: "posteo", name: "Posteo", domains: ["posteo.de", "posteo.net", "posteo.org", "posteo.eu"], host: "posteo.de"),
        MailProvider(id: "mailboxorg", name: "mailbox.org", domains: ["mailbox.org"], host: "imap.mailbox.org"),
        MailProvider(id: "ionos", name: "IONOS (1&1)", domains: ["online.de", "onlinehome.de"], host: "imap.ionos.de"),
        MailProvider(id: "freenet", name: "freenet", domains: ["freenet.de"], host: "mx.freenet.de"),
        MailProvider(id: "yahoo", name: "Yahoo Mail", domains: ["yahoo.com", "yahoo.de", "ymail.com", "rocketmail.com"], host: "imap.mail.yahoo.com",
                     password: .appPassword, passwordPage: URL(string: "https://login.yahoo.com/account/security/app-passwords")),
        MailProvider(id: "aol", name: "AOL Mail", domains: ["aol.com", "aol.de"], host: "imap.aol.com",
                     password: .appPassword, passwordPage: URL(string: "https://login.aol.com/account/security/app-passwords")),
    ]

    public static let all: [MailProvider] = [gmail, icloud] + others

    /// Microsoft lets only its own apps read Outlook and Hotmail with a password: said at once.
    static let outlookDomains = ["outlook.com", "outlook.de", "hotmail.com", "hotmail.de", "live.com", "live.de", "msn.com"]

    public static func isOutlook(_ address: String) -> Bool {
        MailDiscovery.domain(of: address).map(outlookDomains.contains) ?? false
    }

    /// By the address's domain.
    public static func by(address: String) -> MailProvider? {
        guard let domain = MailDiscovery.domain(of: address) else { return nil }
        return all.first { $0.domains.contains(domain) }
    }

    /// By the server found for an own domain: Google Workspace is Gmail, iCloud+ is iCloud.
    public static func by(host: String) -> MailProvider? {
        all.first { $0.host.caseInsensitiveCompare(host) == .orderedSame }
    }
}

/// A pasted password, looked at before it is ever sent: the right kind for the provider, only
/// part of it, or — the usual mistake — the account's own password where an app password belongs.
public enum PasswordCheck: Sendable, Equatable {
    case empty
    case right
    case partial
    case wrongKind

    public static func of(_ typed: String, for kind: MailProvider.Password) -> PasswordCheck {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .empty }
        switch kind {
        case .google:
            let letters = text.replacingOccurrences(of: " ", with: "")
            let onlyLetters = letters.allSatisfy { $0.isASCII && $0.isLetter }
            if onlyLetters && letters.count == 16 { return .right }
            return onlyLetters && letters.count < 16 ? .partial : .wrongKind
        case .apple:
            let letters = text.replacingOccurrences(of: "-", with: "")
            let onlyLetters = letters.allSatisfy { $0.isASCII && $0.isLetter }
            if onlyLetters && letters.count == 16 { return .right }
            return onlyLetters && letters.count < 16 ? .partial : .wrongKind
        case .appPassword, .usual:
            return .right
        }
    }

    /// As the provider takes it: Google's without its spaces, Apple's with its dashes.
    public static func cleaned(_ typed: String, for kind: MailProvider.Password) -> String {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .google:
            return text.replacingOccurrences(of: " ", with: "").lowercased()
        case .apple:
            let letters = text.replacingOccurrences(of: "-", with: "").lowercased()
            guard letters.count == 16 else { return text }
            return stride(from: 0, to: 16, by: 4).map { start in
                String(letters[letters.index(letters.startIndex, offsetBy: start)..<letters.index(letters.startIndex, offsetBy: start + 4)])
            }.joined(separator: "-")
        case .appPassword, .usual:
            return text
        }
    }
}
