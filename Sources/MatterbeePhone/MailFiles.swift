import MatterCore
import QuickLook
import SwiftData
import SwiftUI

/// A file of a matter, opened on the iPhone: taken out of its mail — read-only, only this one
/// mail — when it is opened, and kept in the cache so a second look is instant. Nothing of it is
/// in iCloud: the file lives in the mail.
@MainActor
enum MailFiles {
    static var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Mail files", isDirectory: true)
    }

    enum Failure: Error, CustomStringConvertible {
        case noAccount, notInMail, noPassword(String)
        var description: String {
            switch self {
            case .noAccount: "Add your mail account first, to open files from your mail."
            case .notInMail: "This file was added on your Mac, not attached to a mail — it is only there."
            case .noPassword(let user): "No password saved for \(user) on this iPhone."
            }
        }
    }

    /// The account the mail is in: the one on the mail's server, so a password only ever goes to
    /// the server it belongs to.
    static func account(for document: MatterCore.Document) -> MailAccount? {
        let host = document.source.pointer.firstMatch(of: /^imap:\/\/([^\/]+)\//).map { String($0.output.1) }
        let saved = Keychain.accounts().filter { !$0.usesGoogle }
        return saved.first { $0.host == host } ?? (host == nil ? saved.first : nil)
    }

    static func open(_ document: MatterCore.Document) async throws -> URL {
        guard !document.isOwnFile, document.source.pointer.hasPrefix("imap://") else { throw Failure.notInMail }
        guard let account = account(for: document) else { throw Failure.noAccount }
        guard let password = try Keychain.password(for: account.user) else { throw Failure.noPassword(account.user) }
        return try await MailFetch.file(document.name, pointer: document.source.pointer, messageID: document.messageID,
                                        account: account, password: password, cache: cache)
    }
}

/// The matter's files: what was attached to its mail, each opened from the mail with a tap.
/// A logo in a signature is not a file anyone attached, and is left out, as on the Mac.
struct FilesSection: View {
    let matter: Matter
    @State private var state: [PersistentIdentifier: String] = [:]
    @State private var preview: URL?
    @State private var addsAccount = false

    var body: some View {
        let shown = (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage }.sorted {
            ($0.source.date ?? .distantPast) > ($1.source.date ?? .distantPast)
        }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Files", detail: "\(shown.count)")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, document in
                        if index > 0 { Divider().padding(.leading, 50) }
                        row(document)
                    }
                }
                .phoneCard()
            }
            .quickLookPreview($preview)
            .sheet(isPresented: $addsAccount) { MailAccountSheet() }
        }
    }

    private func row(_ document: MatterCore.Document) -> some View {
        Button { open(document) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.shownName).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2)
                    Text(document.isOwnFile ? "added on your Mac · only there" : Sources.origin(document.source))
                        .font(.caption).foregroundStyle(.secondary)
                    if let message = state[document.persistentModelID] {
                        Text(message).font(.caption)
                            .foregroundStyle(message.hasPrefix("Getting") ? Color.secondary : Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if state[document.persistentModelID]?.hasPrefix("Getting") == true { ProgressView() }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(document.isOwnFile)
    }

    private func open(_ document: MatterCore.Document) {
        let id = document.persistentModelID
        if MailFiles.account(for: document) == nil, !document.isOwnFile { addsAccount = true; return }
        state[id] = "Getting the file from the mail …"
        Task {
            do {
                preview = try await MailFiles.open(document)
                state[id] = nil
            } catch {
                state[id] = "\(error)"
            }
        }
    }

    static func icon(_ document: MatterCore.Document) -> String {
        let type = document.contentType.lowercased(), name = document.name.lowercased()
        if type.hasPrefix("image/") { return "photo" }
        if type == "application/pdf" || name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".xlsx") || name.hasSuffix(".csv") { return "tablecells" }
        return "doc"
    }
}

/// The mail account the files come out of: the address and an app password, kept in this
/// iPhone's Keychain and handed only to that account's server. Read-only: nothing is changed or sent.
struct MailAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var host = ""
    @State private var password = ""
    @State private var saved = Keychain.accounts().filter { !$0.usesGoogle }
    @State private var failure: String?

    private var knownHost: String? { MailAccount(user: address.trimmingCharacters(in: .whitespaces))?.host }

    var body: some View {
        NavigationStack {
            Form {
                if !saved.isEmpty {
                    Section("On this iPhone") {
                        ForEach(saved, id: \.user) { account in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.user)
                                    Text(account.host).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    try? Keychain.delete(account: account.user)
                                    saved = Keychain.accounts().filter { !$0.usesGoogle }
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                Section {
                    TextField("Mail address", text: $address)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !address.isEmpty && knownHost == nil {
                        TextField("Mail server (IMAP), e.g. imap.example.com", text: $host)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    SecureField("App password", text: $password).textContentType(.password)
                } header: {
                    Text(saved.isEmpty ? "Mail account" : "Add another")
                } footer: {
                    Text("Files are taken out of your mail when you open them — read-only, one mail at a time — and are not kept in iCloud. The password stays in this iPhone's Keychain and goes only to your mail server. For Gmail, use an app password (Google Account › Security › App passwords).")
                }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
            }
            .navigationTitle("Mail account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(address.isEmpty || password.isEmpty || (knownHost == nil && host.isEmpty))
                }
            }
        }
    }

    private func save() {
        let user = address.trimmingCharacters(in: .whitespaces)
        let server = knownHost ?? host.trimmingCharacters(in: .whitespaces)
        do {
            try Keychain.save(password.trimmingCharacters(in: .whitespaces), for: MailAccount(user: user, host: server))
            password = ""
            dismiss()
        } catch {
            failure = "\(error)"
        }
    }
}
