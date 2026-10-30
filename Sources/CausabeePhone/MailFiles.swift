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
            case .noPassword(let user): "No password saved for \(user) on this \(ThisDevice.name)."
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
    /// Only this file, as a card of its own: an entry in the record's one list.
    var only: MatterCore.Document? = nil
    /// What came from that file, shown under it.
    var made = RecordLinks.Made()
    /// A mail's files, as cards under it — "Read all" over them when more than one is kept only.
    var attachments: [MatterCore.Document] = []
    /// Only the files kept, not read: "Kept only" in the record.
    var keptOnly = false
    /// Choosing kept files to read several at once: nil when not choosing.
    @State private var chosen: Set<PersistentIdentifier>?
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
    @State private var deleting: MatterCore.Document?
    @State private var newName = ""

    var body: some View {
        // As on the Mac: newest first; a logo in a signature is not a file anyone attached. Only for
        // the list of all files: a single file's card, or a mail's, does not sort them all.
        let listsAll = only == nil && attachments.isEmpty && !keptOnly
        let all = !listsAll ? [] : (matter.documents ?? []).sorted {
            let (a, b) = ($0.source.date ?? .distantPast, $1.source.date ?? .distantPast)
            return a != b ? a > b : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let small = all.filter { $0.isSmallImage && !$0.isHidden }
        let hidden = all.filter(\.isHidden)
        let shown = all.filter { document in
            (!document.isHidden || showsHidden) && (!document.isSmallImage || showsSmallImages || document.isHidden)
        }
        VStack(alignment: .leading, spacing: 10) {
            if let only {
                VStack(alignment: .leading, spacing: 0) {
                    row(only)
                    if !made.isEmpty { MadeChips(made: made).padding(.leading, 52).padding(.trailing, 14).padding(.bottom, 12).padding(.top, -6) }
                }
                .findable(.model(only.persistentModelID), only.shownName, only.name).fileCardFrame(kept: only.reading != .read)
            } else if !attachments.isEmpty {
                ReadAllLine(count: attachments.filter { $0.reading == .kept }.count) { readAll(attachments) }
                ForEach(attachments, id: \.persistentModelID) { document in
                    row(document).findable(.model(document.persistentModelID), document.shownName, document.name)
                        .fileCardFrame(kept: document.reading != .read)
                }
            } else if keptOnly {
                let kept = matter.keptFiles
                let readable = kept.filter { $0.reading == .kept }
                HStack {
                    SectionHeader(title: "Kept only", detail: kept.isEmpty ? nil : "\(kept.count) · not read, never sent")
                    if chosen == nil, readable.count > 1 {
                        Button("Choose …") { chosen = [] }.font(.caption).foregroundStyle(Theme.gold)
                    }
                }
                if let picked = chosen {
                    ChooseBar(chosen: picked.count, readable: readable.count,
                              all: { chosen = Set(readable.map(\.persistentModelID)) },
                              read: { readAll(readable.filter { picked.contains($0.persistentModelID) }); chosen = nil },
                              cancel: { chosen = nil })
                }
                if kept.isEmpty {
                    PhoneEmptyBox(text: "Every file of this matter has been read. Files from a folder and files in mail are kept only until you have them read.")
                }
                ForEach(kept, id: \.persistentModelID) { document in
                    row(document).findable(.model(document.persistentModelID), document.shownName, document.name)
                        .fileCardFrame(kept: true)
                }
            } else {
            HStack {
                SectionHeader(title: "Files", detail: all.isEmpty ? nil : "\(all.count - small.count - hidden.count)"
                              + (hidden.isEmpty ? "" : " · \(hidden.count) hidden")
                              + (small.isEmpty ? "" : " · \(small.count) small \(small.count == 1 ? "image" : "images")"))
            }
            if all.isEmpty {
                PhoneEmptyBox(text: "A letter, a scan, a PDF. Files in mail come by themselves.",
                              action: "Add Document", symbol: "doc.badge.plus") { addsScan = true }
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
            if !hidden.isEmpty || !small.isEmpty {
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
            }
        }
        .quickLookPreview($preview)
        .sheetWhenAsked(isPresented: $addsAccount) { MailAccountSheet() }
        .sheetWhenAsked(isPresented: $addsScan) { ScanSheet(matter: matter) }
        .confirmationDialogWhenAsked(deleting.map { "Delete “\($0.shownName)”?" } ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let document = deleting { withAnimation { _ = matter.forget(document, besides: PhoneCloud.storeLocation(), in: context); try? context.save() } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text(deleting.map(Self.deleteWords) ?? "") }
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
            Text("Only here in Causabee: the file keeps its own name in the mail and in its folder.")
        }
    }

    private func isPDF(_ document: MatterCore.Document) -> Bool {
        document.contentType == "application/pdf" || document.name.lowercased().hasSuffix(".pdf")
    }

    private func sender(of document: MatterCore.Document) -> String? {
        matter.entry(messageID: document.messageID).map { Email.displayName(in: $0.from) ?? Email.address(in: $0.from) }
    }

    private func row(_ document: MatterCore.Document) -> some View {
        let id = document.persistentModelID
        return FileFace(document: document, sender: sender(of: document), state: state[id],
                        tap: {
                            if chosen != nil {
                                guard document.reading == .kept else { return }
                                if chosen?.remove(id) == nil { chosen?.insert(id) }
                            } else if !(document.isOwnFile && document.source.fileURL == nil && MatterFolders.kept(document) == nil) {
                                open(document)
                            }
                        },
                        read: { read(document) }, nameIt: { nameFromContent(document) },
                        chosen: chosen.map { $0.contains(id) }) { items(document) }
            .padding(14)
    }

    /// Into the assistant, one after the other: each read here, nothing sent until "Sort in".
    private func readAll(_ documents: [MatterCore.Document]) {
        for document in documents where document.reading == .kept { read(document) }
    }

    /// What goes with it, said before it goes.
    static func deleteWords(_ document: MatterCore.Document) -> String {
        guard let matter = document.matter else { return "" }
        let found = matter.brought(by: document)
        let tasks = found.todos.count, dates = found.appointments.count + found.deadlines.count
        let parts = [tasks == 0 ? nil : tasks == 1 ? "1 task" : "\(tasks) tasks", dates == 0 ? nil : dates == 1 ? "1 date" : "\(dates) dates"].compactMap { $0 }
        return "Causabee forgets what it read in it" + (parts.isEmpty ? "" : ", and " + parts.joined(separator: " and ") + " only it brought") + ". The file itself stays where it is."
    }

    @ViewBuilder
    private func items(_ document: MatterCore.Document) -> some View {
        if !document.isOwnFile || document.source.fileURL != nil || MatterFolders.kept(document) != nil { Button("Open", systemImage: "eye") { open(document) } }
        if document.reading == .kept { Button("Read", systemImage: "text.viewfinder") { read(document) } }
        AskCausabeeButton { navigation.talk(document.shownName, kind: "File", in: matter) }
        Button(Say.rename, systemImage: "pencil") { newName = document.shownName; renaming = document }
        if isPDF(document) { Button(Say.nameFromContent, systemImage: "text.magnifyingglass") { nameFromContent(document) } }
        if document.title != nil {
            Button(Say.useFileName, systemImage: "arrow.uturn.backward") { document.title = nil; try? context.save() }
        }
        Button(document.isHidden ? Say.showAgain : Say.hide, systemImage: document.isHidden ? "eye" : "eye.slash") {
            withAnimation { document.isHidden.toggle() }
            try? context.save()
        }
        // One the owner brought in can go for good — an outdated letter; a mail's file would come back with its mail.
        if document.isOwnFile {
            Divider()
            Button(Say.delete, systemImage: "trash", role: .destructive) { deleting = document }
        }
    }

    /// Takes the file out of its mail — read-only, only this one mail — and hands it on.
    private func fetch(_ document: MatterCore.Document, then use: @escaping (URL) -> Void) {
        let id = document.persistentModelID
        // One added on this iPhone is the file itself, here.
        if document.isOwnFile, let file = document.source.fileURL { use(file); return }
        // In its matter's folder in iCloud Drive: from there, whichever device put it in — no mail needed.
        if let kept = MatterFolders.kept(document) {
            state[id] = "Getting the file from iCloud Drive …"
            Task {
                do { let url = try await MatterFolders.fetched(kept); state[id] = nil; use(url) } catch { state[id] = plainWords(error) }
            }
            return
        }
        if MailFiles.account(for: document) == nil, !document.isOwnFile { addsAccount = true; return }
        state[id] = "Getting the file from the mail …"
        Task {
            do {
                let url = try await MailFiles.open(document)
                state[id] = nil
                use(url)
            } catch {
                state[id] = plainWords(error)
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
}

/// The mail accounts, and connecting another — the same setup as on the Mac: the address first,
/// then its way in, a login tried before anything is kept, and the label or folder Causabee reads.
/// The password is kept in iCloud Keychain, so the Macs and the iPad have it too.
struct MailAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var saved = Keychain.accounts().filter { !$0.usesGoogle }
    /// The saved account asked about before its password goes — from every device, and not back.
    @State private var removing: String?
    @State private var adding = false

    var body: some View {
        if saved.isEmpty || adding {
            // One thing per screen, in the system's navigation — its own back button and close.
            MailSetupFlow(finished: { connected in
                saved = Keychain.accounts().filter { !$0.usesGoogle }
                if connected == nil, !saved.isEmpty { adding = false } else { dismiss() }
            })
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsPart("Saved — shared with your Macs through iCloud Keychain")
                        ForEach(saved, id: \.user) { account in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.user)
                                    Text(account.host).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Remove", role: .destructive) { removing = account.user }
                                    .buttonStyle(.borderless)
                            }
                        }
                        Button("Add another account") { adding = true }.buttonStyle(.borderless)
                    }
                    .padding(20)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("Mail account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                // Asked first: the password goes from the Macs too, and cannot be brought back.
                .confirmationDialogWhenAsked("Remove the password for \(removing ?? "")?",
                                    isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                    titleVisibility: .visible) {
                    Button("Remove from all devices", role: .destructive) {
                        if let removing { try? Keychain.delete(account: removing) }
                        saved = Keychain.accounts().filter { !$0.usesGoogle }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("It goes from iCloud Keychain, so from your Macs as well. To get mail again you connect it anew.")
                }
            }
        }
    }
}
