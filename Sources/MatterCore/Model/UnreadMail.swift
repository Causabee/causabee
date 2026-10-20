import Foundation
import SwiftData

/// Which mail of the matters is still unread in the mailbox: asked at each mail check, read-only —
/// `UID SEARCH UNSEEN` asks about the `\Seen` flag and changes none. Kept on each mail, so every
/// device shows the same. As fresh as the last check: mail read in Apple Mail loses its dot then.
@MainActor
public enum UnreadMail {
    /// The mails a check asks about: from the mailbox, not a scan or a file, from the last year —
    /// of every matter, or of one.
    static func asked(in context: ModelContext, of matter: Matter? = nil, now: Date = Date()) -> [Entry] {
        let since = now.addingTimeInterval(-365 * 86_400)
        let all = matter.map { $0.entries ?? [] } ?? ((try? context.fetch(FetchDescriptor<Entry>())) ?? [])
        return all.filter {
            $0.source.kind == .mail && $0.source.pointer.hasPrefix("imap://") && !$0.messageID.isEmpty && ($0.date ?? .distantPast) > since
        }
    }

    /// Asks, and puts down what changed. Says how many changed.
    @discardableResult
    public static func refresh(from mailbox: some ReadOnlyMailbox, in context: ModelContext, of matter: Matter? = nil) async -> Int {
        let entries = asked(in: context, of: matter)
        guard !entries.isEmpty,
              let unread = try? await MailFetch.unread(of: entries.map { (pointer: $0.source.pointer, messageID: $0.messageID) }, from: mailbox)
        else { return 0 }
        var changed = 0
        for entry in entries where entry.modelContext != nil {
            guard let now = unread[entry.messageID], entry.isUnread != now else { continue }
            entry.isUnread = now
            changed += 1
        }
        if changed > 0 { try? context.save() }
        return changed
    }

    /// The same, with its own connection: for a mail check that has the account and its password.
    @discardableResult
    public static func refresh(account: MailAccount, password: String, in context: ModelContext) async -> Int {
        guard !asked(in: context).isEmpty, let client = try? await IMAPClient.connect(to: account, password: password) else { return 0 }
        let changed = await refresh(from: client, in: context)
        await client.logout()
        return changed
    }
}

extension UnreadMail {
    /// When a matter opens, its mails only — one small read-only question, so the dots are as the
    /// mailbox has them the moment it is looked at. Not again within a minute for the same matter.
    public static func refresh(_ matter: Matter, in context: ModelContext) async {
        let key = matter.key
        guard Date().timeIntervalSince(lastAsked[key] ?? .distantPast) > 60, !asked(in: context, of: matter).isEmpty,
              let account = Keychain.accounts().first, let password = try? await MailSecret.secret(for: account) else { return }
        lastAsked[key] = Date()
        guard let client = try? await IMAPClient.connect(to: account, password: password) else { return }
        await refresh(from: client, in: context, of: matter)
        await client.logout()
    }

    private static var lastAsked: [String: Date] = [:]
}

extension Matter {
    /// Its mails still unread in the mailbox.
    public var unreadMails: [Entry] { (entries ?? []).filter { $0.isUnread == true } }
}
