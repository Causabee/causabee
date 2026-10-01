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
            case .notInMail: "This file was added on another device, not attached to a mail — it is only there."
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
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]
    @State private var state: [PersistentIdentifier: String] = [:]
    @State private var preview: URL?
    @State private var addsAccount = false
    @State private var addsScan = false
    @State private var showsHidden = false
    @State private var showsSmallImages = false
    @State private var renaming: MatterCore.Document?
    @State private var newName = ""

    var body: some View {
        // As on the Mac: newest first; a logo in a signature is not a file anyone attached.
        let all = (matter.documents ?? []).sorted {
            let (a, b) = ($0.source.date ?? .distantPast, $1.source.date ?? .distantPast)
            return a != b ? a > b : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let small = all.filter { $0.isSmallImage && !$0.isHidden }
        let hidden = all.filter(\.isHidden)
        let shown = all.filter { document in
            (!document.isHidden || showsHidden) && (!document.isSmallImage || showsSmallImages || document.isHidden)
        }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Files", detail: all.isEmpty ? nil : "\(all.count - small.count - hidden.count)"
                              + (hidden.isEmpty ? "" : " · \(hidden.count) hidden")
                              + (small.isEmpty ? "" : " · \(small.count) small \(small.count == 1 ? "image" : "images")"))
                Button("Add a document", systemImage: "plus") { addsScan = true }
                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold)
                    .tool()
            }
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, document in
                        if index > 0 { Divider().padding(.leading, 50) }
                        row(document).findable(.model(document.persistentModelID), document.shownName, document.name)
                    }
                }
                .phoneCard()
            }
            HStack(spacing: 14) {
                if !hidden.isEmpty {
                    Button(showsHidden ? "Hide the hidden ones" : "\(hidden.count) hidden · show") { showsHidden.toggle() }
                }
                if !small.isEmpty {
                    Button(showsSmallImages ? "Hide small images" : "Show small images") { showsSmallImages.toggle() }
                }
            }
            .font(.caption).foregroundStyle(Theme.gold).padding(.horizontal, 4)
        }
        .quickLookPreview($preview)
        .sheet(isPresented: $addsAccount) { MailAccountSheet() }
        .sheet(isPresented: $addsScan) { ScanSheet(matter: matter) }
        .alert("Rename file", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let document = renaming {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    document.title = name.isEmpty || name == document.name ? nil : name
                    try? context.save()
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("Only here in Matterbee: the file keeps its own name in the mail and in its folder.")
        }
    }

    private func isPDF(_ document: MatterCore.Document) -> Bool {
        document.contentType == "application/pdf" || document.name.lowercased().hasSuffix(".pdf")
    }

    private func sender(of document: MatterCore.Document) -> String? {
        (matter.entries ?? []).first { $0.messageID == document.messageID }.map { Email.displayName(in: $0.from) ?? Email.address(in: $0.from) }
    }

    private func row(_ document: MatterCore.Document) -> some View {
        let id = document.persistentModelID
        let offersName = document.title == nil && isPDF(document) && DocumentTitle.looksMachineMade(document.name) && !document.isOwnFile
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Button { open(document) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(document.shownName).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2)
                            // With a name of its own, the file's name is still there to see, small.
                            Text(document.isOwnFile
                                 ? (document.source.fileURL != nil ? "on this iPhone, in Files › Matterbee" : "added on \(document.source.addedOn) · only there")
                                 : [document.title == nil ? nil : document.name, Sources.origin(document.source), sender(of: document),
                                    ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file)]
                                    .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(document.isOwnFile && document.source.fileURL == nil)
                if state[id]?.hasPrefix("Getting") == true { ProgressView() }
                if let read = document.readAt {
                    Label("read \(Dates.short(read))", systemImage: "checkmark").font(.caption).foregroundStyle(Theme.done)
                        .labelStyle(.titleOnly)
                } else if document.isReadable, !document.isOwnFile, state[id] == nil {
                    Button("Read") { read(document) }.font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).tool()
                }
                Menu { items(document) } label: {
                    Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
                }
                .tint(.secondary)
                .accessibilityLabel("More")
                // While reading, a long press still has everything.
                .tool()
            }
            Group {
                if offersName, state[id] == nil {
                    Button("Name it from its content") { nameFromContent(document) }
                        .font(.caption).foregroundStyle(Theme.gold)
                        .tool()
                }
                if let message = state[id] {
                    Text(message).font(.caption)
                        .foregroundStyle(message.hasPrefix("Getting") ? Color.secondary : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 38)
        }
        .padding(14)
        .opacity(document.isHidden ? 0.55 : 1)
        .contextMenu { items(document) }
    }

    @ViewBuilder
    private func items(_ document: MatterCore.Document) -> some View {
        if !document.isOwnFile || document.source.fileURL != nil { Button("Open") { open(document) } }
        if document.isReadable, !document.isOwnFile, document.readAt == nil { Button("Read") { read(document) } }
        Divider()
        Button("Rename …") { newName = document.shownName; renaming = document }
        if isPDF(document), !document.isOwnFile { Button("Name it from its content") { nameFromContent(document) } }
        if document.title != nil {
            Button("Use the file's own name") { document.title = nil; try? context.save() }
        }
        Divider()
        Button(document.isHidden ? "Show again" : "Hide") {
            withAnimation { document.isHidden.toggle() }
            try? context.save()
        }
    }

    /// Takes the file out of its mail — read-only, only this one mail — and hands it on.
    private func fetch(_ document: MatterCore.Document, then use: @escaping (URL) -> Void) {
        let id = document.persistentModelID
        // One added on this iPhone is the file itself, here.
        if document.isOwnFile, let file = document.source.fileURL { use(file); return }
        if MailFiles.account(for: document) == nil, !document.isOwnFile { addsAccount = true; return }
        state[id] = "Getting the file from the mail …"
        Task {
            do {
                let url = try await MailFiles.open(document)
                state[id] = nil
                use(url)
            } catch {
                state[id] = "\(error)"
            }
        }
    }

    private func open(_ document: MatterCore.Document) { fetch(document) { preview = $0 } }

    /// Into the assistant, as on the Mac: read on the iPhone, sorted in only on "Sort in".
    private func read(_ document: MatterCore.Document) {
        fetch(document) { url in
            PhoneShots.shared.bring(url, matter: matter.persistentModelID, document: document.persistentModelID,
                                    context: context, owner: profiles.first?.names.first)
            navigation.showsAssistant = true
        }
    }

    /// A readable name from the file's first page — read on the iPhone, from the cache or the mail.
    private func nameFromContent(_ document: MatterCore.Document) {
        let id = document.persistentModelID
        fetch(document) { url in
            if let title = DocumentTitle.from(pdf: url) {
                withAnimation { document.title = title }
                try? context.save()
            } else {
                state[id] = "No heading found in it — give it a name with ⋯ → Rename."
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
                    Section("Saved — shared with your Macs through iCloud Keychain") {
                        ForEach(saved, id: \.user) { account in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.user)
                                    Text(account.host).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Remove from all devices", role: .destructive) {
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
                    Text("Files are taken out of your mail when you open them — read-only, one mail at a time — and are not kept in iCloud. The password is kept in your iCloud Keychain, end-to-end encrypted, so Matterbee on your Macs and this iPhone shares it — typed once — and it goes only to your mail server. For Gmail, use an app password (Google Account › Security › App passwords).")
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
