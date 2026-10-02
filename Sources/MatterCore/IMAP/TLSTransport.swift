import Foundation
import Network

/// IMAP over TLS on port 993, through the system's own TLS. Certificates are checked the way
/// Safari checks them; there is no switch to turn that off.
public final class TLSTransport: IMAPTransport, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "causabee.imap")
    /// A server that stops answering fails the read rather than hanging the run.
    private let timeout: TimeInterval

    public init(host: String, port: UInt16 = 993, timeout: TimeInterval = 60) {
        let parameters = NWParameters(tls: NWProtocolTLS.Options(), tcp: NWProtocolTCP.Options())
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 993, using: parameters)
        self.timeout = timeout
    }

    public func open() async throws {
        let once = Once()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume() }
                case .failed(let error), .waiting(let error): once.run { continuation.resume(throwing: error) }
                case .cancelled: once.run { continuation.resume(throwing: IMAPError.closed) }
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { [connection] in
                once.run { connection.cancel(); continuation.resume(throwing: IMAPError.closed) }
            }
        }
    }

    public func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    public func receive() async throws -> Data {
        let once = Once()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, _, error in
                once.run {
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: data ?? Data()) }
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) { [connection] in
                once.run { connection.cancel(); continuation.resume(throwing: IMAPError.closed) }
            }
        }
    }

    public func close() async {
        connection.cancel()
    }

    /// A continuation may be resumed once. The connection, the timer and a cancel can all try.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func run(_ body: () -> Void) {
            lock.lock()
            let first = !done
            done = true
            lock.unlock()
            if first { body() }
        }
    }
}

extension IMAPClient {
    /// Connects, reads the greeting and logs in.
    public static func connect(to account: MailAccount, password: String) async throws -> IMAPClient {
        let transport = TLSTransport(host: account.host, port: account.port)
        try await transport.open()
        let client = IMAPClient(transport: transport)
        try await client.start()
        if account.usesGoogle {
            try await client.authenticate(user: account.user, token: password)
        } else {
            try await client.login(user: account.user, password: password)
        }
        return client
    }
}

/// One mail account, as far as reading it needs. No password here: that lives in the Keychain,
/// together with the server it belongs to.
public struct MailAccount: Sendable, Equatable {
    public var user: String
    public var host: String
    public var port: UInt16
    /// Signed in with Google: opened with a token (XOAUTH2), not a password.
    public var usesGoogle: Bool

    public init(user: String, host: String, port: UInt16 = 993, google: Bool = false) {
        self.user = user
        self.host = host
        self.port = port
        self.usesGoogle = google
    }

    /// An address whose server is known from its domain alone: Gmail and iCloud. Any other
    /// address has no account without its server named — a password never goes to a guessed one.
    public init?(user: String) {
        guard let host = Self.knownHost(for: user) else { return nil }
        self.init(user: user, host: host)
    }

    static func knownHost(for user: String) -> String? {
        let domain = user.split(separator: "@").last.map { $0.lowercased() } ?? ""
        switch domain {
        case "gmail.com", "googlemail.com": return "imap.gmail.com"
        case "icloud.com", "me.com", "mac.com": return "imap.mail.me.com"
        default: return nil
        }
    }
}
