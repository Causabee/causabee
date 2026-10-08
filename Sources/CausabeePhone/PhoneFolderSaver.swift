import Foundation
import MatterCore
import SwiftData

/// Puts matters' files into their folders from the iPhone, as the Mac's FolderSaver does: what
/// came attached to mail taken in here is fetched from its mail and saved, so the owner finds the
/// same files whichever device read the mail. One save at a time; what is asked for meanwhile
/// is done after it.
@MainActor
enum PhoneFolderSaver {
    private static var busy = false
    private static var waiting: [Matter] = []

    static func save(_ matters: [Matter]) {
        guard MatterFolders.root != nil, !matters.isEmpty else { return }
        guard !busy else { waiting += matters.filter { new in !waiting.contains { $0 === new } }; return }
        busy = true
        let account = Keychain.accounts().first
        Task {
            var password: String?
            if let account { password = try? await MailSecret.secret(for: account) }
            _ = await MatterFolders.save(matters, account: account, password: password)
            busy = false
            let next = waiting
            waiting = []
            save(next)
        }
    }

    /// The matters these mails went into that have something attached.
    static func save(for judgements: [Judgement], in matters: [Matter]) {
        let keys = Set(judgements.filter { !$0.attachments.isEmpty }.compactMap(\.matter))
        save(matters.filter { matter in keys.contains { matter.answers(to: $0) } })
    }
}
