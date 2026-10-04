import MatterCore
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A file brought into the assistant on the iPhone — a chat screenshot, a photo of a letter, a PDF
/// from Files, or a matter's file taken out of its mail with "Scan" — the way the Mac brings one
/// in: read on the iPhone, shown before anything is sent, sent pseudonymised only on "Sort in",
/// and taken into a matter the owner chooses. A picture or a scan is kept on this iPhone, in Files
/// (On My iPhone › Causabee), as the Mac's stay on the Mac; what it said — tasks, dates, people —
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
        /// How far it is, as a number: the thread follows its card down as it grows.
        var step: Int {
            switch stage {
            case .reading: 0
            case .read: 1
            case .sending: 2
            case .answered: 3
            case .taken: 4
            case .failed: 5
            }
        }
    }

    var shots: [Shot] = []

    private var store: URL { PhoneCloud.storeLocation() }

    /// Where a picture, a scan or a file brought in here is kept: Causabee's own folder on this
    /// iPhone, which Files shows as On My iPhone › Causabee — the owner can find, share or delete
    /// it there. The demo's in a folder of their own.
    static var folder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return DemoData.isRequested ? documents.appendingPathComponent("Demo", isDirectory: true) : documents
    }
    /// The same, in the words Files uses.
    static let place = "Files › On My iPhone › Causabee"

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
                do { return .read(try door.look(at: file, owner: owner)) } catch { return .failed(plainWords(error)) }
            }.value
            set(id, stage)
        }
    }

    /// Sends it, pseudonymised, after "Sort in". The same file twice is answered from the record.
    func classify(_ id: UUID, context: ModelContext, owner: [String]) {
        guard let shot = shots.first(where: { $0.id == id }), case .read(let look) = shot.stage else { return }
        var door = ScreenshotDoor(besides: store, model: ModelChoice.mail)
        door.strict = ModelChoice.strict
        // The demo sends nothing and has no key: its answer is made up, a task from the file's own words.
        if DemoData.isRequested, var judgement = look.report.outcomes.first?.judgement {
            judgement.todos = [.init(text: "Answer “\(look.heading)”", owner: .me, due: nil, sourceQuote: look.heading)]
            set(id, .answered(look, judgement))
            return
        }
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
                set(id, .failed(plainWords(error)))
            }
        }
    }

    /// Takes what it said into a matter: the one chosen, or a new one with the name given.
    func take(_ id: UUID, into matter: Matter?, newName: String, owner: [String], skipping skipped: Set<String> = [], context: ModelContext) {
        guard let shot = shots.first(where: { $0.id == id }), case .answered(let look, var judgement) = shot.stage else { return }
        // Only what the owner left ticked, as on the Mac; the file and its words come in either way.
        judgement.todos = judgement.todos.enumerated().filter { !skipped.contains("t\($0.offset)") }.map(\.element)
        judgement.appointments = judgement.appointments.enumerated().filter { !skipped.contains("a\($0.offset)") }.map(\.element)
        judgement.deadlines = judgement.deadlines.enumerated().filter { !skipped.contains("d\($0.offset)") }.map(\.element)
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
            // Who wrote and the numbers it is filed under, as far as the owner left them ticked.
            taken?.take(look.offers(own: owner).keeping { !skipped.contains($0) }, in: context)
            if let document = shot.document.flatMap({ context.model(for: $0) as? MatterCore.Document }) { document.readAt = Date() }
            // A picture brought in here is a file of the matter now: named by what it is, read.
            for document in taken?.documents ?? [] where document.messageID == judgement.emailID {
                if document.title == nil, look.kind == .chat { document.title = look.heading }
                document.readAt = document.readAt ?? Date()
                // Into the matter's folder in iCloud Drive, when one was picked: the Mac opens it from there.
                if document.isOwnFile { MatterFolders.keep(look.file, as: document) }
            }
            // Its words kept on this iPhone with it, as a mail's text is: for the assistant, later.
            if let email = look.report.outcomes.first?.email { MailText.save(email, besides: store) }
            // Known on every device, so the Mac never sends it again.
            if !DemoData.isRequested { _ = try? SortedMails.record([judgement], device: PhoneNames.device, in: context) }
            try context.save()
            if !DemoData.isRequested { PhoneNames.publish(in: context) }
            set(id, .taken(taken?.name ?? judgement.matter ?? "", taken?.persistentModelID))
        } catch {
            set(id, .failed(plainWords(error)))
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
    /// What the owner untick: "t0", "a1", "d0" — left out when it is taken in.
    @State private var skipped: Set<String> = []
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
                HStack(spacing: 8) { BeeLoader(size: 15); Text("Scanning it on this iPhone …").font(.subheadline).foregroundStyle(.secondary) }
            case .read(let look):
                preview(look)
                Text(look.earlier != nil ? "Scanned before: its answer is kept, nothing is sent again."
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
                found(judgement, look.offers(own: profiles.first?.names ?? []))
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
        // A chat's lines say what it is. A file's first words, as text recognition read them, are
        // mostly noise: what it brings shows once it is sorted in.
        if look.kind == .chat {
            Text(look.preview).font(.footnote).lineLimit(6).fixedSize(horizontal: false, vertical: true)
        }
        ForEach(look.warnings, id: \.self) {
            Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warning)
        }
    }

    /// What the answer found: what will go into the matter.
    @ViewBuilder
    private func found(_ judgement: Judgement, _ offers: VaultOffers) -> some View {
        // Each with a tick, as on the Mac: untick what is not wanted. The file and its words are
        // kept with the matter either way.
        let lines: [(id: String, text: String)] = judgement.todos.enumerated().map { ("t\($0.offset)", $0.element.text) }
            + judgement.appointments.enumerated().map { ("a\($0.offset)", "\(Dates.short($0.element.date))\($0.element.time.map { " \($0)" } ?? "") \($0.element.what)") }
            + judgement.deadlines.enumerated().map { ("d\($0.offset)", "by \(Dates.short($0.element.date)) \($0.element.what)") }
            + offers.lines
        if lines.isEmpty {
            Text("Nothing to do or to note in it — it is kept with the matter, with its words.").font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.id) { line in
                    let on = !skipped.contains(line.id)
                    Button {
                        if on { skipped.insert(line.id) } else { skipped.remove(line.id) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.gold : .secondary)
                            Text(line.text).font(.subheadline).foregroundStyle(on ? .primary : .secondary)
                                .strikethrough(!on).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
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
        shots.take(shot.id, into: matter, newName: newName, owner: profiles.first?.names ?? [], skipping: skipped, context: context)
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
            // A plus, as on the Mac (Figma "Composer"): quiet, so the send button is the one loud thing.
            Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
        }
        // A menu's label takes the app's gold; the plus stays grey.
        .tint(Color.secondary)
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

/// The black plus over the bee, on a matter: one place to add whatever the owner has in hand — a
/// photo or scan, a file, a contact, a detail, a link, a note, a task.
struct MatterPlusButton: View {
    let matter: Matter
    let contact: () -> Void
    let detail: () -> Void
    let link: () -> Void
    let note: () -> Void
    let task: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]
    @State private var picksPhoto = false
    @State private var picksFile = false
    @State private var photo: PhotosPickerItem?

    var body: some View {
        Menu {
            Button("Photo or screenshot", systemImage: "photo") { picksPhoto = true }
            Button("File", systemImage: "doc") { picksFile = true }
            Divider()
            Button("Contact", systemImage: "person.badge.plus", action: contact).accessibilityIdentifier("plus.contact")
            Button("Detail", systemImage: "info.circle", action: detail).accessibilityIdentifier("plus.detail")
            Button("Link", systemImage: "link", action: link).accessibilityIdentifier("plus.link")
            Button("Note", systemImage: "note.text", action: note).accessibilityIdentifier("plus.note")
            Button("Task", systemImage: "checklist", action: task).accessibilityIdentifier("plus.task")
        } label: {
            Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.onInk)
                .frame(width: 48, height: 48)
                .background(Theme.ink, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .accessibilityLabel("Add to this matter")
        .accessibilityIdentifier("matter.plus")
        .padding(.trailing, 22)
        // `--demo --shot letter`: a letter as the camera would bring it, for the regression test.
        .task {
            guard LetterShot.isRequested, !LetterShot.brought, let file = LetterShot.file() else { return }
            LetterShot.brought = true
            bring(file)
        }
        .photosPicker(isPresented: $picksPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) {
            guard let photo else { return }
            self.photo = nil
            Task {
                guard let data = try? await photo.loadTransferable(type: Data.self) else { return }
                let type = photo.supportedContentTypes.first { ["png", "jpeg", "heic"].contains($0.preferredFilenameExtension ?? "") }
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

    /// Into the assistant, where it is read and offers what it found: without it the photo was
    /// taken and nothing was seen to happen.
    private func bring(_ file: URL) {
        PhoneShots.shared.bring(file, matter: matter.persistentModelID, context: context, owner: profiles.first?.names.first)
        navigation.showsAssistant = true
    }
}

/// Started as `--demo --shot letter`, a matter is handed a made-up insurer's letter as a picture:
/// read by the same text recognition as a photographed one, so the test sees what the owner would.
@MainActor
enum LetterShot {
    static var brought = false
    static var isRequested: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot"), at + 1 < arguments.count else { return false }
        return arguments[at + 1] == "letter"
    }

    static let words = """
        hkk Krankenkasse
        Martinistraße 26, 28195 Bremen
        Telefon 0421 3655 0
        reha@hkk.de

        Versichertennummer: A123456789

        Sehr geehrte Frau Muster,
        bitte senden Sie uns den Befundbericht
        bis zum 20.10.2026.
        """

    static func file() -> URL? {
        let size = CGSize(width: 1240, height: 1754)
        let image = UIGraphicsImageRenderer(size: size).image { canvas in
            UIColor.white.setFill()
            canvas.fill(CGRect(origin: .zero, size: size))
            (words as NSString).draw(in: CGRect(x: 120, y: 140, width: 1000, height: 1400),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black])
        }
        guard let data = image.pngData() else { return nil }
        return PhoneShots.shared.keep(data, named: "Letter from the insurer.png")
    }
}
