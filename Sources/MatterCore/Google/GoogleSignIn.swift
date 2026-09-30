import CryptoKit
import Foundation
import Security

/// Signing in with Google instead of an app password: the owner allows Matterbee on Google's own
/// page, and Gmail is then opened with a token, never a password. OAuth 2.0 for a native app, with
/// PKCE, as Google describes it for iOS and macOS: no client secret, a redirect to the app's own
/// address, and a refresh token that stays in the Keychain.
///
/// The token is only ever sent to Google — to Gmail's IMAP server and to Google's token address.
/// The scope is the one Gmail's IMAP takes, `https://mail.google.com/`; Matterbee's IMAP clients
/// still only read, and write nothing but a draft on a click.
public enum GoogleSignIn {
    /// The OAuth client for Matterbee, of the type "iOS" in the Google Cloud console, made for the
    /// bundle ID `de.chille.matterbee`. Not a secret: a native app carries it, and without its
    /// redirect it is worth nothing. Empty until the owner has made one; then sign-in is offered.
    public static let clientID = ""

    public static var isConfigured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    /// `com.googleusercontent.apps.<id>`: the client ID backwards, the scheme Google redirects to.
    public static var redirectScheme: String {
        "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }
    public static var redirectURI: String { redirectScheme + ":/oauth2redirect" }

    static let scope = "https://mail.google.com/ email"
    static let authorizeURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    public static let imapHost = "imap.gmail.com"

    public enum Failure: Error, CustomStringConvertible {
        case notConfigured
        case refused(String)
        case noCode
        case wrongState
        /// The refresh token no longer works: revoked, or out of date — in Google's testing mode after seven days.
        case signInAgain(String)
        case noEmail

        public var description: String {
            switch self {
            case .notConfigured: "Google sign-in is not set up in this build yet."
            case .refused(let why): "Google said no: \(why)"
            case .noCode: "Google's answer had no code in it."
            case .wrongState: "The answer did not belong to this sign-in. Please try again."
            case .signInAgain(let user): "Google asks you to sign in again for \(user): Matterbee → Set Up Matterbee …"
            case .noEmail: "Google did not say which address was signed in."
            }
        }
    }

    // MARK: One sign-in

    /// What one sign-in needs to remember between opening Google's page and getting its answer.
    public struct Attempt: Sendable {
        public let url: URL
        let verifier: String
        let state: String
    }

    /// Google's page to open, with the PKCE challenge. `hint` fills in the address if it is known.
    public static func start(hint: String? = nil) throws -> Attempt {
        guard isConfigured else { throw Failure.notConfigured }
        let verifier = random(32)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = random(16)
        var parts = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            // Asked every time, so a second sign-in brings a new refresh token too.
            .init(name: "prompt", value: "consent"),
        ] + (hint.map { [.init(name: "login_hint", value: $0)] } ?? [])
        return Attempt(url: parts.url!, verifier: verifier, state: state)
    }

    /// Google came back to the app's address: the code becomes tokens, the refresh token goes into
    /// the Keychain, and the signed-in address comes back as a mail account.
    public static func finish(_ attempt: Attempt, callback: URL, keep: Bool = true) async throws -> (account: MailAccount, accessToken: String) {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value { throw Failure.refused(error) }
        guard items.first(where: { $0.name == "state" })?.value == attempt.state else { throw Failure.wrongState }
        guard let code = items.first(where: { $0.name == "code" })?.value else { throw Failure.noCode }
        let answer = try await token([
            "grant_type": "authorization_code", "code": code, "code_verifier": attempt.verifier,
            "client_id": clientID, "redirect_uri": redirectURI,
        ])
        guard let email = answer.email else { throw Failure.noEmail }
        let account = MailAccount(user: email, host: imapHost, google: true)
        if keep, let refresh = answer.refreshToken { try saveRefreshToken(refresh, for: email) }
        await Cache.shared.put(answer.accessToken, for: email, expiring: answer.expiresIn)
        return (account, answer.accessToken)
    }

    /// A token Gmail takes now: the one in hand while it lasts, else a new one from the refresh token.
    public static func accessToken(for user: String) async throws -> String {
        if let cached = await Cache.shared.get(user) { return cached }
        guard let refresh = refreshToken(for: user) else { throw Failure.signInAgain(user) }
        let answer: Answer
        do {
            answer = try await token(["grant_type": "refresh_token", "refresh_token": refresh, "client_id": clientID])
        } catch Failure.refused(let why) where why.contains("invalid_grant") {
            throw Failure.signInAgain(user)
        }
        await Cache.shared.put(answer.accessToken, for: user, expiring: answer.expiresIn)
        return answer.accessToken
    }

    // MARK: Google's token address

    struct Answer {
        var accessToken: String
        var expiresIn: Int
        var refreshToken: String?
        var email: String?
    }

    static func token(_ form: [String: String]) async throws -> Answer {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(form.map { "\($0.key)=\(escape($0.value))" }.sorted().joined(separator: "&").utf8)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200, let access = json["access_token"] as? String else {
            let why = [json["error"] as? String, json["error_description"] as? String].compactMap { $0 }.joined(separator: ": ")
            throw Failure.refused(why.isEmpty ? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)" : why)
        }
        return Answer(accessToken: access, expiresIn: json["expires_in"] as? Int ?? 3600,
                      refreshToken: json["refresh_token"] as? String,
                      email: (json["id_token"] as? String).flatMap(email(inIDToken:)))
    }

    /// The address in the ID token. Not checked for Google's signature: it came straight from
    /// Google's token address over TLS, in answer to this app's own request.
    static func email(inIDToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var text = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text += "=" }
        guard let data = Data(base64Encoded: text),
              let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return claims["email"] as? String
    }

    // MARK: The Keychain

    static let service = "Matterbee Google"

    public static func refreshToken(for user: String) -> String? {
        var query = base(user)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveRefreshToken(_ token: String, for user: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(base(user) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base(user)
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Matterbee — Google sign-in for \(user)"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw Keychain.Failure.status(added) }
        } else if status != errSecSuccess {
            throw Keychain.Failure.status(status)
        }
    }

    /// Signs out on this Mac: the refresh token goes. Google's own list of apps still shows
    /// Matterbee until it is removed there.
    public static func signOut(_ user: String) async {
        SecItemDelete(base(user) as CFDictionary)
        await Cache.shared.put(nil, for: user, expiring: 0)
    }

    /// Every address signed in with Google, as mail accounts on Gmail's server.
    public static func accounts() -> [MailAccount] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var items: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess, let list = items as? [[String: Any]] else { return [] }
        return list.compactMap { ($0[kSecAttrAccount as String] as? String).map { MailAccount(user: $0, host: imapHost, google: true) } }
            .sorted { $0.user < $1.user }
    }

    private static func base(_ user: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: user]
    }

    // MARK: Small things

    /// Access tokens last an hour; one in hand is used until a minute before it runs out.
    actor Cache {
        static let shared = Cache()
        private var tokens: [String: (String, Date)] = [:]
        func get(_ user: String) -> String? {
            guard let (token, until) = tokens[user], until > Date() else { return nil }
            return token
        }
        func put(_ token: String?, for user: String, expiring seconds: Int) {
            tokens[user] = token.map { ($0, Date().addingTimeInterval(TimeInterval(seconds - 60))) }
        }
    }

    static func random(_ bytes: Int) -> String {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return base64URL(data)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? value
    }

    /// Gmail's SASL XOAUTH2 answer: the address and the token, in the form Google gives.
    static func xoauth2(user: String, token: String) -> String {
        Data("user=\(user)\u{1}auth=Bearer \(token)\u{1}\u{1}".utf8).base64EncodedString()
    }
}

/// What opens a mail account: the app password from the Keychain, or — for an address signed in
/// with Google — a fresh token. Everything that reads mail asks here, and hands the answer on as
/// the "password"; the IMAP clients use it as a token when the account says so.
public enum MailSecret {
    public static func secret(for account: MailAccount) async throws -> String? {
        account.usesGoogle ? try await GoogleSignIn.accessToken(for: account.user) : try Keychain.password(for: account.user)
    }
}
