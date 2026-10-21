import Foundation
import SwiftData

/// Which mail answers which, for mail sorted in before that was kept: read once from the mailbox,
/// headers only, read-only — by whichever device opens the matter's record first. Free: nothing
/// goes to any model.
@MainActor
public enum ReplyLinks {
    public static func fill(in matter: Matter, context: ModelContext) async {
        // The cheap questions first: a mail's source is slow to read, and with no account to ask
        // every mail of the matter was read for nothing, each time it was opened.
        let open = (matter.entries ?? []).filter { $0.replyTo == nil && !$0.messageID.isEmpty }
        guard !open.isEmpty, let account = Keychain.accounts().first else { return }
        let unknown = open.filter { $0.source.pointer.hasPrefix("imap://") }
        guard !unknown.isEmpty, let password = try? await MailSecret.secret(for: account) else { return }
        let mails = unknown.map { (pointer: $0.source.pointer, messageID: $0.messageID) }
        guard let client = try? await IMAPClient.connect(to: account, password: password) else { return }
        let links = try? await MailFetch.replyLinks(of: mails, from: client)
        await client.logout()
        guard let links else { return }
        // A mail the mailbox no longer has answers nothing we can know of; it is not asked again.
        for entry in unknown { entry.replyTo = links[entry.messageID] ?? "" }
        try? context.save()
    }
}
