import Foundation
import Security

/// The mail password, kept where Apple keeps passwords. Never in a file, never in `.env`,
/// never in a log: it is read from here, handed to the server, and forgotten. The server it
/// belongs to is kept beside it, so the password only ever goes to that one.
///
/// Two places. **iCloud Keychain**, shared by Matterbee on the owner's Macs and iPhone — typed
/// once, there on every device, end-to-end encrypted, and readable by no other app: the item is
/// in Matterbee's own access group (`2F7QR8NL2D.de.chille.matterbee`), which only a build signed
/// for it has. And, on a Mac, the **login keychain**, as before: the command line and a build
/// without that signing still find the password there. Saving writes both; reading tries the
/// shared one first.
public enum Keychain {
    static let service = "Matterbee IMAP"

    public enum Failure: Error, CustomStringConvertible {
        case status(OSStatus)
        public var description: String {
            let message = SecCopyErrorMessageString(statusCode, nil) as String? ?? "error \(statusCode)"
            return "the Keychain said: \(message)"
        }
        var statusCode: OSStatus { switch self { case .status(let code): code } }
    }

    /// A password found only in this device's own place — saved before it was shared — is shared
    /// right then, so the other devices have it from now on without typing it again.
    public static func password(for account: String) throws -> String? {
        for place in Place.allCases {
            var query = place.base(account)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) {
                if place == .own, let saved = Place.own.accounts().first(where: { $0.user == account }) {
                    _ = Place.shared.write(password, for: saved)
                }
                return password
            }
            // A build that may not use the shared place is told so; it looks in the next one.
            guard status == errSecItemNotFound || status == errSecMissingEntitlement else { throw Failure.status(status) }
        }
        return nil
    }

    /// Into iCloud Keychain, so every device has it; on a Mac into the login keychain too. Fails
    /// only when no place took it.
    public static func save(_ password: String, for account: MailAccount) throws {
        var failure: OSStatus?
        var saved = false
        for place in Place.allCases {
            let status = place.write(password, for: account)
            if status == errSecSuccess { saved = true } else if status != errSecMissingEntitlement { failure = failure ?? status }
        }
        if !saved { throw Failure.status(failure ?? errSecMissingEntitlement) }
    }

    /// From every device: the shared item goes, and this Mac's own.
    public static func delete(account: String) throws {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: GoogleSignIn.service,
                       kSecAttrAccount as String: account] as CFDictionary)
        for place in Place.allCases {
            let status = SecItemDelete(place.base(account) as CFDictionary)
            guard [errSecSuccess, errSecItemNotFound, errSecMissingEntitlement].contains(status) else { throw Failure.status(status) }
        }
    }

    /// Every account a password was saved for, with its server, so one saved account needs no
    /// `--account`. A password saved before the server was kept beside it was only ever used
    /// with Gmail's server for any domain but iCloud's, so that is its server.
    /// Addresses signed in with Google come first: they need no password.
    public static func accounts() -> [MailAccount] {
        let google = GoogleSignIn.accounts()
        return google + passwordAccounts().filter { saved in !google.contains { $0.user == saved.user } }
    }

    static func passwordAccounts() -> [MailAccount] {
        var byUser: [String: MailAccount] = [:]
        for place in Place.allCases.reversed() {
            for account in place.accounts() { byUser[account.user] = account }
        }
        return byUser.values.sorted { $0.user < $1.user }
    }

    /// Where a password is kept: shared through iCloud Keychain, or only on this device.
    enum Place: CaseIterable {
        case shared, own

        func base(_ account: String? = nil) -> [String: Any] {
            var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Keychain.service]
            if let account { query[kSecAttrAccount as String] = account }
            switch self {
            case .shared:
                query[kSecAttrSynchronizable as String] = true
                query[kSecUseDataProtectionKeychain as String] = true
            case .own:
                // As it always was: on a Mac the login keychain, on an iPhone its own items only —
                // a query that does not ask for shared items never gets them.
                break
            }
            return query
        }

        func write(_ password: String, for account: MailAccount) -> OSStatus {
            let data = Data(password.utf8)
            let server = Data("\(account.host):\(account.port)".utf8)
            #if os(iOS)
            // The iPhone keeps only the shared one.
            if self == .own { return errSecMissingEntitlement }
            #endif
            let status = SecItemUpdate(base(account.user) as CFDictionary,
                                       [kSecValueData as String: data, kSecAttrGeneric as String: server] as CFDictionary)
            guard status == errSecItemNotFound else { return status }
            var item = base(account.user)
            item[kSecValueData as String] = data
            item[kSecAttrGeneric as String] = server
            item[kSecAttrLabel as String] = "Matterbee — \(account.user)"
            return SecItemAdd(item as CFDictionary, nil)
        }

        func accounts() -> [MailAccount] {
            var query = base()
            query[kSecReturnAttributes as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitAll
            var items: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
                  let list = items as? [[String: Any]] else { return [] }
            return list.compactMap { item -> MailAccount? in
                guard let user = item[kSecAttrAccount as String] as? String else { return nil }
                guard let data = item[kSecAttrGeneric as String] as? Data,
                      let server = String(data: data, encoding: .utf8), let colon = server.lastIndex(of: ":"),
                      let port = UInt16(server[server.index(after: colon)...]) else {
                    return MailAccount(user: user) ?? MailAccount(user: user, host: "imap.gmail.com")
                }
                return MailAccount(user: user, host: String(server[..<colon]), port: port)
            }
        }
    }
}

/// The AI services' keys — Anthropic's, Mistral's — in the Keychain, as the owner pasted them in
/// the app's settings. The app is started from the Dock, where no `.env` is at hand.
public enum APIKeys {
    static let service = "Matterbee API"

    public static func get(_ name: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: name, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    public static func save(_ key: String, as name: String) throws {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: name]
        let data = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Matterbee — \(name)"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw Keychain.Failure.status(added) }
        } else if status != errSecSuccess {
            throw Keychain.Failure.status(status)
        }
    }

    public static func delete(_ name: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: name]
        SecItemDelete(base as CFDictionary)
    }
}
