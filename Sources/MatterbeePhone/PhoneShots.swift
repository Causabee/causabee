import MatterCore
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A file brought into the assistant on the iPhone — a chat screenshot, a photo of a letter, a PDF
/// from Files, or a matter's file taken out of its mail with "Scan" — the way the Mac brings one
/// in: read on the iPhone, shown before anything is sent, sent pseudonymised only on "Sort in",
/// and taken into a matter the owner chooses. A picture or a scan is kept on this iPhone, in Files
/// (On My iPhone › Matterbee), as the Mac's stay on the Mac; what it said — tasks, dates, people —
/// goes to every device.
@MainActor
@Observable
final class PhoneShots {
    static let shared = PhoneShots()

    enum Stage {
        case reading
        case read(ScreenshotDoor.Look)
        case sending(ScreenshotDoor.Look)
        case answered(ScreenshotDoor.Look, Judgement)
        case taken(String, PersistentIdentifier?)
        case failed(String)
    }

    struct Shot: Identifiable {
        let id = UUID()
        let file: URL
        /// The matter it was brought in from, and the file of a matter it is, when it is one.
        var matter: PersistentIdentifier?
        var document: PersistentIdentifier?
        var stage: Stage = .reading
        let date = Date()
    }

    var shots: [Shot] = []

    private var store: URL { PhoneCloud.storeLocation() }

    /// Where a picture, a scan or a file brought in here is kept: Matterbee's own folder on this
    /// iPhone, which Files shows as On My iPhone › Matterbee — the owner can find, share or delete
    /// it there. The demo's in a folder of their own.
    static var folder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return DemoData.isRequested ? documents.appendingPathComponent("Demo", isDirectory: true) : documents
    }
    /// The same, in the words Files uses.
    static let place = "Files › On My iPhone › Matterbee"

    static func isKept(_ file: URL) -> Bool {
        file.resolvingSymlinksInPath().path.hasPrefix(folder.resolvingSymlinksInPath().path)
    }

    /// Under its own name — "Tax assessment.pdf" — and "Tax assessment 2.pdf" when that is taken.
    func keep(_ data: Data, named name: String) -> URL? {
        let folder = Self.folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let base = (safe as NSString).deletingPathExtension, ending = (safe as NSString).pathExtension
        var file = folder.appendingPathComponent(safe)
        var number = 2
        while FileManager.default.fileExists(atPath: file.path) {
            file = folder.appendingPathComponent("\(base) \(number)" + (ending.isEmpty ? "" : ".\(ending)"))
            number += 1
        }
        return (try? data.write(to: file)) != nil ? file : nil
    }

    func bring(_ file: URL, matter: PersistentIdentifier?, document: PersistentIdentifier? = nil, context: ModelContext, owner: String?) {
        var shot = Shot(file: file, matter: matter, document: document)
        // This iPhone's own list of names, started from the Mac's, with the other devices' names in it.
        if !DemoData.isRequested {
            do { try NameLists.adopt(into: PhoneNames.mapping, device: PhoneNames.device, in: context) } catch {
                shot.stage = .failed("The list of names cannot be written: \(error.localizedDescription)")
            }
        }
        shots.append(shot)
        guard case .reading = shot.stage else { return }
        let door = ScreenshotDoor(besides: store, model: ModelChoice.mail)
        let owner = owner ?? "Ich"
        let id = shot.id
        Task {
            // Text recognition takes a moment: away from the screen.
            let stage = await Task.detached { () -> Stage in
                do { return .read(try door.look(at: file, owner: owner)) } catch { return .failed("\(error)") }
            }.value
            set(id, stage)
        }
    }

    /// Sends it, pseudonymised, after "Sort in". The same file twice is answered from the record.
    func classify(_ id: UUID, context: ModelContext, owner: [String]) {
        guard let shot = shots.first(where: { $0.id == id }), case .read(let look) = shot.stage else { return }
        var door = ScreenshotDoor(besides: store, model: ModelChoice.mail)
        door.strict = ModelChoice.strict
        guard let claude = ModelChoice.client(for: door.model) else {
            set(id, .failed(ModelChoice.missingKey(door.model)))
            return
        }
        set(id, .sending(look))
        let matters = Unplaced.matters(in: context)
        Task {
            do {
                let judgement = try await door.classify(look, claude: claude, owner: owner, matters: matters)
                set(id, .answered(look, judgement))
            } catch {
                set(id, .failed("\(error)"))
            }
        }
    }

    /// Takes what it said into a matter: the one chosen, or a new one with the name given.
    func take(_ id: UUID, into matter: Matter?, newName: String, owner: [String], context: ModelContext) {
        guard let shot = shots.first(where: { $0.id == id }), case .answered(let look, var judgement) = shot.stage else { return }
        if let matter {
            judgement.matter = matter.key
            judgement.matterTitle = nil
        } else {
            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = PartyNames.key(name).isEmpty ? (judgement.matter ?? "chat") : PartyNames.key(name)
            let taken = ((try? context.fetch(FetchDescriptor<Matter>())) ?? []).contains { $0.answers(to: key) }
            judgement.matter = taken ? key + "-" + String(id.uuidString.prefix(4)).lowercased() : key
            judgement.matterTitle = name.isEmpty ? nil : name
        }
        judgement.decidedBy = .claude
        do {
            _ = try MatterImport.apply([judgement], to: context, owner: owner)
            let taken = (try? context.fetch(FetchDescriptor<Matter>()))?.first { $0.answers(to: judgement.matter ?? "") }
            // The people in a chat are its parties, read from who spoke — the owner left out.
            if let taken, !look.transcript.people.isEmpty {
                var book = try PartyBook(context: context, owner: OwnerNames(owner))
                let others = Set(look.transcript.people.flatMap(PartyNames.tokens))
                for name in look.transcript.people {
                    guard let party = book.party(named: name, in: taken, others: others, context: context) else { continue }
                    let membership = taken.membership(of: party) ?? {
                        let new = Membership()
                        context.insert(new)
                        new.party = party
                        new.matter = taken
                        return new
                    }()
                    membership.mentions += look.transcript.messages.filter { $0.speaker == name }.count
                    if membership.roles.isEmpty { membership.roles = ["in the chat"] }
                }
            }
            if let document = shot.document.flatMap({ context.model(for: $0) as? MatterCore.Document }) { document.readAt = Date() }
            // A picture brought in here is a file of the matter now: named by what it is, read.
            for document in taken?.documents ?? [] where document.messageID == judgement.emailID {
                if document.title == nil, look.kind == .chat { document.title = look.heading }
                document.readAt = document.readAt ?? Date()
            }
            // Known on every device, so the Mac never sends it again.
            if !DemoData.isRequested { try? SortedMails.record([judgement], device: PhoneNames.device, in: context) }
            try context.save()
            if !DemoData.isRequested { PhoneNames.publish(in: context) }
            set(id, .taken(taken?.name ?? judgement.matter ?? "", taken?.persistentModelID))
        } catch {
            set(id, .failed("\(error)"))
        }
    }

    func remove(_ id: UUID) { shots.removeAll { $0.id == id } }

    private func set(_ id: UUID, _ stage: Stage) {
        guard let index = shots.firstIndex(where: { $0.id == id }) else { return }
        shots[index].stage = stage
    }
}

/// A file in the assistant's thread, from read to taken in.
struct PhoneShotCard: View {
    let shot: PhoneShots.Shot
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var matters: [Matter]
    @Query private var profiles: [Profile]
    /// The matter to take it into: nil for a new one, with `newName`.
    @State private var target: PersistentIdentifier?
    @State private var chosen = false
    @State private var newName = ""

    private var shots: PhoneShots { PhoneShots.shared }

    /// The file's own name, without the few letters an earlier version kept it under.
    private var name: String {
        let raw = shot.file.lastPathComponent
        return raw.count > 9 && raw.dropFirst(8).first == "-" ? String(raw.dropFirst(9)) : raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(name, systemImage: shot.file.pathExtension.lowercased() == "pdf" ? "doc.text" : "photo")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if PhoneShots.isKept(shot.file) {
                Text("Saved on this iPhone, in \(PhoneShots.place).").font(.caption).foregroundStyle(.secondary)
            }
            switch shot.stage {
            case .reading:
                HStack(spacing: 8) { BeeLoader(size: 15); Text("Reading it on this iPhone …").font(.subheadline).foregroundStyle(.secondary) }
            case .read(let look):
                preview(look)
                Text(look.earlier != nil ? "Read before: its answer is kept, nothing is sent again."
                     : String(format: "Sorting in costs about %.1f cents. Sent pseudonymised to %@.", look.estimate * 100, ModelChoice.mail.label))
                    .font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Not now") { shots.remove(shot.id) }.buttonStyle(.phone)
                    Button("Sort in") { shots.classify(shot.id, context: context, owner: profiles.first?.names ?? []) }.buttonStyle(.phoneFilled)
                }
            case .sending(let look):
                preview(look)
                HStack(spacing: 8) { BeeLoader(size: 15); Text("Sorting it in …").font(.subheadline).foregroundStyle(.secondary) }
            case .answered(let look, let judgement):
                Text(look.heading).font(.headline).fixedSize(horizontal: false, vertical: true)
                found(judgement)
                destination(judgement)
                HStack(spacing: 10) {
                    Button("Not needed") { shots.remove(shot.id) }.buttonStyle(.phone)
                    Button("Take in") { take(judgement) }.buttonStyle(.phoneFilled)
                        .disabled(target == nil && newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            case .taken(let name, let id):
                HStack {
                    Label("Taken into “\(name)”", systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Theme.done)
                    Spacer()
                    if let id, let matter = matters.first(where: { $0.persistentModelID == id }) {
                        Button("Open") { navigation.open(matter) }.buttonStyle(.phone)
                    }
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Remove") { shots.remove(shot.id) }.buttonStyle(.phone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneBox()
    }

    @ViewBuilder
    private func preview(_ look: ScreenshotDoor.Look) -> some View {
        Text(look.heading).font(.headline).fixedSize(horizontal: false, vertical: true)
        Text(look.byline).font(.caption).foregroundStyle(.secondary)
        Text(look.preview).font(.footnote).lineLimit(6).fixedSize(horizontal: false, vertical: true)
        ForEach(look.notes, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
    }

    /// What the answer found: what will go into the matter.
    @ViewBuilder
    private func found(_ judgement: Judgement) -> some View {
        let lines = judgement.todos.map { "☐ " + $0.text }
            + judgement.appointments.map { "📅 \(Dates.short($0.date)) \($0.what)" }
            + judgement.deadlines.map { "⏱ \(Dates.short($0.date)) \($0.what)" }
        if lines.isEmpty {
            Text("Nothing to do or to note in it.").font(.subheadline).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.prefix(8).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                if lines.count > 8 { Text("… and \(lines.count - 8) more").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    /// Into the matter it came from or the answer suggests, another, or a new one.
    @ViewBuilder
    private func destination(_ judgement: Judgement) -> some View {
        let open = matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }
        Picker("Into", selection: $target) {
            ForEach(open) { matter in Text(matter.name).tag(Optional(matter.persistentModelID)) }
            Text("A new matter …").tag(PersistentIdentifier?.none)
        }
        .pickerStyle(.menu)
        .tint(.primary)
        .onAppear {
            guard !chosen else { return }
            chosen = true
            let suggested = judgement.matter.flatMap { key in open.first { $0.answers(to: key) } }
            target = shot.matter.flatMap { id in open.first { $0.persistentModelID == id } }?.persistentModelID ?? suggested?.persistentModelID
            newName = judgement.matterTitle ?? ""
        }
        if target == nil {
            TextField("Name of the new matter", text: $newName)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func take(_ judgement: Judgement) {
        let matter = target.flatMap { id in matters.first { $0.persistentModelID == id } }
        shots.take(shot.id, into: matter, newName: newName, owner: profiles.first?.names ?? [], context: context)
    }
}

/// The paperclip beside the assistant's field: a photo or a screenshot, or a file from Files.
struct AttachButton: View {
    let matter: Matter?
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @State private var picksPhoto = false
    @State private var picksFile = false
    @State private var photo: PhotosPickerItem?

    var body: some View {
        Menu {
            Button("Screenshot or photo …") { picksPhoto = true }
            Button("File …") { picksFile = true }
        } label: {
            Image(systemName: "paperclip").font(.body.weight(.medium)).foregroundStyle(.primary)
                .frame(width: 34, height: 34)
        }
        .accessibilityLabel("Bring in a screenshot or a file")
        .photosPicker(isPresented: $picksPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) {
            guard let photo else { return }
            self.photo = nil
            Task {
                guard let data = try? await photo.loadTransferable(type: Data.self) else { return }
                let type = photo.supportedContentTypes.first { ["png", "jpeg", "heic"].contains($0.preferredFilenameExtension ?? "") }
                // As the iPhone names its own: "Screenshot 2026-09-30 at 23.37.01", in local time.
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
                let name = "Screenshot \(formatter.string(from: Date())).\(type?.preferredFilenameExtension ?? "png")"
                if let file = PhoneShots.shared.keep(data, named: name) { bring(file) }
            }
        }
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.pdf, .image, UTType(filenameExtension: "eml") ?? .data]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let file = PhoneShots.shared.keep(data, named: url.lastPathComponent) { bring(file) }
        }
    }

    private func bring(_ file: URL) {
        PhoneShots.shared.bring(file, matter: matter?.persistentModelID, context: context, owner: profiles.first?.names.first)
    }
}
