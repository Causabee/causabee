import Foundation
import SwiftData

/// Which mail of the matters is still unread in the mailbox: asked at each mail check, read-only —
/// `UID SEARCH UNSEEN` asks about the `\Seen` flag and changes none. Kept on each mail, so every
/// device shows the same. As fresh as the last check: mail read in Apple Mail loses its dot then.
/// The store is read and written by the worker, away from the screen.
@MainActor
public enum UnreadMail {
    /// Asks, and puts down what changed. Says how many changed.
    @discardableResult
    static func refresh(from mailbox: some ReadOnlyMailbox, asked: [(pointer: String, messageID: String)], worker: StoreWorker,
                        in context: ModelContext) async -> Int {
        guard !asked.isEmpty, let unread = try? await MailFetch.unread(of: asked, from: mailbox) else { return 0 }
        return apply(await worker.unreadChanges(unread), in: context)
    }

    /// The dots that changed, put down here: only those mails are fetched.
    static func apply(_ changes: [String: Bool], in context: ModelContext) -> Int {
        guard !changes.isEmpty else { return 0 }
        let ids = Array(changes.keys)
        let entries = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { ids.contains($0.messageID) }))) ?? []
        var changed = 0
        for entry in entries {
            guard let now = changes[entry.messageID], entry.isUnread != now else { continue }
            entry.isUnread = now
            changed += 1
        }
        if changed > 0 { try? context.save() }
        return changed
    }

    /// The same, with its own connection: for a mail check that has the account and its password.
    @discardableResult
    public static func refresh(account: MailAccount, password: String, in context: ModelContext) async -> Int {
        let worker = StoreWorker.for(context.container)
        let asked = await worker.unreadAsked()
        guard !asked.isEmpty, let client = try? await IMAPClient.connect(to: account, password: password) else { return 0 }
        let changed = await refresh(from: client, asked: asked, worker: worker, in: context)
        await client.logout()
        return changed
    }
}

extension UnreadMail {
    /// When a matter opens, its mails only — one small read-only question, so the dots are as the
    /// mailbox has them the moment it is looked at. Not again within a minute for the same matter.
    public static func refresh(_ matter: Matter, in context: ModelContext) async {
        let key = matter.key
        guard Date().timeIntervalSince(lastAsked[key] ?? .distantPast) > 60 else { return }
        let worker = StoreWorker.for(context.container)
        let asked = await worker.unreadAsked(matter: key)
        guard !asked.isEmpty, let account = Keychain.accounts().first, let password = try? await MailSecret.secret(for: account) else { return }
        lastAsked[key] = Date()
        guard let client = try? await IMAPClient.connect(to: account, password: password) else { return }
        await refresh(from: client, asked: asked, worker: worker, in: context)
        await client.logout()
    }

    private static var lastAsked: [String: Date] = [:]
}

extension Matter {
    /// Where a person of the matter is reached by mail: the address the owner put in by hand, else
    /// the one they last wrote from here.
    public func reachAddress(of party: Party) -> String? {
        if let typed = party.address?.trimmingCharacters(in: .whitespacesAndNewlines), typed.contains("@") { return typed }
        return lastAddresses()[party.persistentModelID]
    }

    /// Its mails still unread in the mailbox.
    public var unreadMails: [Entry] { (entries ?? []).filter { $0.isUnread == true } }
}
