import Foundation

/// Which kind of mail an address is, and where its IMAP server is — found before any password is
/// typed, so the setup can show the right way in: Google's sign-in, iCloud's app-specific
/// password, or a server of its own.
///
/// Asked, in this order: the providers Causabee knows; the domain's own autoconfig file, as mail
/// apps publish it; Thunderbird's public list of providers; and the domain's mail servers (MX), so
/// Google Workspace or iCloud on an own domain is recognised. Only the domain is asked about,
/// never the address — and nothing at all is sent for a provider Causabee knows.
public enum MailDiscovery {
    public enum Kind: String, Sendable, Equatable {
        case gmail, icloud, other
    }

    public struct Found: Sendable, Equatable {
        public var kind: Kind
        public var host: String
        public var port: UInt16
        /// Where it was found, for the setup to say so: "known", "autoconfig", "Thunderbird", "MX".
        public var source: String

        public init(kind: Kind, host: String, port: UInt16 = 993, source: String) {
            self.kind = kind
            self.host = host
            self.port = port
            self.source = source
        }
    }

    public static func domain(of address: String) -> String? {
        let parts = address.trimmingCharacters(in: .whitespaces).lowercased().split(separator: "@")
        guard parts.count == 2, parts[1].contains("."), !parts[0].isEmpty else { return nil }
        return String(parts[1])
    }

    /// Known without asking anyone.
    public static func known(_ address: String) -> Found? {
        guard let domain = domain(of: address) else { return nil }
        switch domain {
        case "gmail.com", "googlemail.com": return Found(kind: .gmail, host: "imap.gmail.com", source: "known")
        case "icloud.com", "me.com", "mac.com": return Found(kind: .icloud, host: "imap.mail.me.com", source: "known")
        default: return nil
        }
    }

    /// The kind a server is: Google's and Apple's IMAP servers serve own domains too.
    static func kind(of host: String) -> Kind {
        let host = host.lowercased()
        if host == "imap.gmail.com" || host.hasSuffix(".googlemail.com") { return .gmail }
        if host == "imap.mail.me.com" { return .icloud }
        return .other
    }

    /// Everything in turn; nil when nothing was found — then the owner types the server.
    public static func find(_ address: String, session: URLSession = .shared) async -> Found? {
        if let known = known(address) { return known }
        guard let domain = domain(of: address) else { return nil }
        for url in autoconfigURLs(for: domain) {
            if let found = await config(at: url, address: address, session: session, source: url.host == "autoconfig.thunderbird.net" ? "Thunderbird" : "autoconfig") {
                return found
            }
        }
        // Google Workspace, iCloud+ or a provider on an own domain: told by where its mail goes.
        if let mx = await mailExchanger(of: domain, session: session) {
            let mx = mx.lowercased()
            if mx.hasSuffix("google.com") || mx.hasSuffix("googlemail.com") { return Found(kind: .gmail, host: "imap.gmail.com", source: "MX") }
            if mx.hasSuffix("icloud.com") || mx.hasSuffix("me.com") { return Found(kind: .icloud, host: "imap.mail.me.com", source: "MX") }
            // The provider behind the server, in Thunderbird's list: mx01.ionos.de → ionos.de.
            let base = mx.split(separator: ".").suffix(2).joined(separator: ".")
            if base != domain, let url = URL(string: "https://autoconfig.thunderbird.net/v1.1/\(base)"),
               let found = await config(at: url, address: address, session: session, source: "MX") {
                return found
            }
        }
        return nil
    }

    static func autoconfigURLs(for domain: String) -> [URL] {
        [
            "https://autoconfig.\(domain)/mail/config-v1.1.xml",
            "https://\(domain)/.well-known/autoconfig/mail/config-v1.1.xml",
            "https://autoconfig.thunderbird.net/v1.1/\(domain)",
        ].compactMap(URL.init(string:))
    }

    static func config(at url: URL, address: String, session: URLSession, source: String) async -> Found? {
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.setValue("application/xml", forHTTPHeaderField: "accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return imap(inConfig: text, source: source)
    }

    /// The first IMAP server over TLS in a Thunderbird autoconfig file.
    static func imap(inConfig xml: String, source: String) -> Found? {
        let servers = xml.components(separatedBy: "<incomingServer").dropFirst()
        for server in servers {
            let block = server.components(separatedBy: "</incomingServer>").first ?? server
            guard block.contains("type=\"imap\""),
                  let host = value("hostname", in: block),
                  let port = value("port", in: block).flatMap(UInt16.init),
                  value("socketType", in: block)?.uppercased() == "SSL" else { continue }
            return Found(kind: kind(of: host), host: host, port: port, source: source)
        }
        return nil
    }

    private static func value(_ tag: String, in block: String) -> String? {
        guard let start = block.range(of: "<\(tag)>"), let end = block.range(of: "</\(tag)>", range: start.upperBound..<block.endIndex) else { return nil }
        return block[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The domain's preferred mail server, asked of Cloudflare's DNS over HTTPS: the operating
    /// system has no plain call for an MX record.
    static func mailExchanger(of domain: String, session: URLSession) async -> String? {
        guard let url = URL(string: "https://cloudflare-dns.com/dns-query?name=\(domain)&type=MX") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.setValue("application/dns-json", forHTTPHeaderField: "accept")
        guard let (data, _) = try? await session.data(for: request) else { return nil }
        return preferredMX(inDNSJSON: data)
    }

    static func preferredMX(inDNSJSON data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["Answer"] as? [[String: Any]] else { return nil }
        // "10 aspmx.l.google.com.": the lowest number is preferred.
        let records = answers.compactMap { $0["data"] as? String }.compactMap { line -> (Int, String)? in
            let parts = line.split(separator: " ")
            guard parts.count == 2, let rank = Int(parts[0]) else { return nil }
            return (rank, parts[1].trimmingCharacters(in: CharacterSet(charactersIn: ".")))
        }
        return records.min { $0.0 < $1.0 }?.1
    }
}
