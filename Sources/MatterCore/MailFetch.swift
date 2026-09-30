import CryptoKit
import Foundation

/// One mail, read again when a file attached to it is wanted — by the pointer the matter kept,
/// and, if the mail has moved since or its folder was renumbered, by its Message-ID in all mail.
/// Read-only like everything here: EXAMINE, BODY.PEEK.
public enum MailFetch {
    public enum Failure: Error, CustomStringConvertible {
        case gone(String)
        public var description: String {
            switch self { case .gone(let id): "The mail \(id) is no longer in the mailbox." }
        }
    }

    /// `imap://host/folder;UIDVALIDITY=v/;UID=u`, taken apart.
    static func parse(_ pointer: String) -> (folder: String, validity: UInt32, uid: UInt32)? {
        guard let match = pointer.firstMatch(of: /^imap:\/\/[^\/]+\/(.+);UIDVALIDITY=(\d+)\/;UID=(\d+)$/),
              let validity = UInt32(match.output.2), let uid = UInt32(match.output.3) else { return nil }
        return (String(match.output.1).removingPercentEncoding ?? String(match.output.1), validity, uid)
    }

    public static func message(pointer: String, messageID: String, from mailbox: some ReadOnlyMailbox) async throws -> Data {
        if let (folder, validity, uid) = parse(pointer), let opened = try? await mailbox.examine(folder), opened.uidValidity == validity,
           let message = try await mailbox.fetch([uid], .whole).first,
           EMLParser.parse(data: message.data, url: URL(fileURLWithPath: "/")).id == messageID {
            return message.data
        }
        let folders = try await mailbox.folders()
        let everywhere = folders.first { $0.attributes.contains("\\all") }.map { [$0.name] } ?? folders.map(\.name)
        for name in everywhere where !(folders.first { $0.name == name }?.attributes.contains("\\noselect") ?? false) {
            _ = try await mailbox.examine(name)
            if let uid = try await mailbox.search([.messageID(messageID)]).first, let message = try await mailbox.fetch([uid], .whole).first {
                return message.data
            }
        }
        throw Failure.gone(messageID)
    }

    /// The file itself, from the mail it is attached to, kept in the cache so a second look is
    /// instant. The cache can be emptied at any time; the file lives in the mail.
    public static func file(_ name: String, pointer: String, messageID: String, account: MailAccount, password: String,
                            cache: URL) async throws -> URL {
        // Named by a checksum of the Message-ID, the same on every start.
        let key = SHA256.hash(data: Data(messageID.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let folder = cache.appendingPathComponent(key, isDirectory: true)
        let target = folder.appendingPathComponent(name.replacingOccurrences(of: "/", with: "-"))
        if FileManager.default.fileExists(atPath: target.path) { return target }
        let client = try await IMAPClient.connect(to: account, password: password)
        let data: Data
        do { data = try await message(pointer: pointer, messageID: messageID, from: client) } catch { await client.logout(); throw error }
        await client.logout()
        guard let bytes = EMLParser.attachment(named: name, in: data) else { throw Failure.gone(name) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bytes.write(to: target, options: .atomic)
        return target
    }
}
