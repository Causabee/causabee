import MatterCore
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// A file brought into the assistant on the iPhone — a chat screenshot, a photo of a letter, a PDF
/// from Files, or a matter's file taken out of its mail with "Scan" — the way the Mac brings one
/// in: bringing it in is the yes, so it is read on the iPhone, sorted in — pseudonymised with
/// Pro, on the device without — and taken into its matter by itself; the owner is asked only when
/// Causabee is not sure which matter it is (docs/digest-and-chat.md). A picture or a scan is kept on this iPhone, in Files
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
        /// What it brought, once taken in, in a line each — and its file's id in the record, for
        /// Undo and Move.
        var made: [String] = []
        var fileID: String?
        /// Read by itself — a file that came attached to a mail: not said in the chat, what it
        /// brings just comes in, marked NEW like everything else.
        var quiet = false
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
    static let place = "Files › On My \(ThisDevice.name) › Causabee"

    static func isKept(_ file: URL) -> Bool {
        file.resolvingSymlinksInPath().path.hasPrefix(folder.resolvingSymlinksInPath().path)
    }

    /// Under its own name — "Tax assessment.pdf" — and "Tax assessment 2.pdf" when that is taken.
    func keep(_ data: Data, named name: String) -> URL? { Self.keep(data, named: name, in: Self.folder) }

    /// The same from any thread, for many files at once: the folder is asked for beforehand.
    /// A big photo is kept at a size to read and send — see `ImageSize`.
    nonisolated static func keep(_ data: Data, named name: String, in folder: URL) -> URL? {
        let (data, name) = ImageSize.kept(data, name: name)
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

    /// The shot's id, to follow it: the first step opens the matter it goes into.
    @discardableResult
    func bring(_ file: URL, matter: PersistentIdentifier?, document: PersistentIdentifier? = nil, context: ModelContext, owner: String?, quiet: Bool = false) -> UUID {
        var shot = Shot(file: file, matter: matter, document: document)
        shot.quiet = quiet
        // This iPhone's own list of names, started from the Mac's, with the other devices' names in it.
        if !DemoData.isRequested {
            do { try NameLists.adopt(into: PhoneNames.mapping, device: PhoneNames.device, in: context) } catch {
                shot.stage = .failed("The list of names cannot be written: \(error.localizedDescription)")
            }
        }
        shots.append(shot)
        let id = shot.id
        guard case .reading = shot.stage else { return id }
        let door = ScreenshotDoor(besides: store, model: ModelChoice.mail)
        let owner = owner ?? "Ich"
        Task {
            // Text recognition takes a moment: away from the screen.
            let stage = await Task.detached { () -> Stage in
                do { return .read(try door.look(at: file, owner: owner)) } catch { return .failed(plainWords(error)) }
            }.value
            set(id, stage)
            // Brought in is the yes: sorted in at once, no "Sort in".
            if case .read = stage { classify(id, context: context, owner: AutoMode.owner(in: context)) }
        }
        return id
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
            settle(id, owner: owner, context: context)
            return
        }
        let reader = ModelChoice.mailReader(for: door.model)
        if case .none(let why) = reader {
            set(id, .failed(why))
            return
        }
        let matters = Unplaced.matters(in: context)
        let claude = Welcome.readsOnDevice(look.file, matters: matters.count) ? nil : reader.client
        set(id, .sending(look))
        Task {
            do {
                let judgement = try await door.classify(look, claude: claude, owner: owner, matters: matters, onFile: Unplaced.onFile(in: context))
                set(id, .answered(look, judgement))
                settle(id, owner: owner, context: context)
            } catch {
                set(id, .failed(plainWords(error)))
            }
        }
    }

    /// Sorted in: into its matter by itself when Causabee is sure which — the one it was brought
    /// in from, or the one the answer names with confidence. Otherwise the card asks.
    func settle(_ id: UUID, owner: [String], context: ModelContext) {
        guard let shot = shots.first(where: { $0.id == id }), case .answered(let look, let judgement) = shot.stage else { return }
        // No matters at all (F008 AC-4, AC-5): nothing to choose — a new matter at once, the bee's name.
        if shot.matter == nil, Welcome.takesAtOnce(matters: (try? context.fetchCount(FetchDescriptor<Matter>())) ?? 1) {
            take(id, into: nil, newName: Welcome.matterName(proposed: judgement.matterTitle, typed: look.heading), owner: owner, opens: true, context: context)
            return
        }
        guard let matter = SortsIn.matter(for: judgement, from: shot.matter, in: context) else { return }
        take(id, into: matter, newName: "", owner: owner, skipping: SortsIn.doubles(judgement, in: matter), context: context)
    }

    /// Takes what it said into a matter: the one chosen, or a new one with the name given.
    /// `opens`: the first matter, made at once (F008) — the window opens it.
    func take(_ id: UUID, into matter: Matter?, newName: String, owner: [String], skipping skipped: Set<String> = [], opens: Bool = false, context: ModelContext) {
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
            if opens, !name.isEmpty { Welcome.nameDates(&judgement, name: name) }
        }
        judgement.decidedBy = .claude
        do {
            // On Normal, a file that would start a fourth open matter waits: the plans first.
            let imported = try MatterImport.apply([judgement], to: context, owner: owner, room: Store.shared.room(in: context))
            if !imported.held.isEmpty { Store.shared.asks = .matters }
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
            // Typed words (F008): kept on the matter as the owner's own note, too.
            if let taken { Welcome.keepTyped(look, in: taken, context: context) }
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
            let offered = look.offers(own: owner).keeping { !skipped.contains($0) }
            let made = SortsIn.lines(of: judgement, offers: offered)
            if let index = shots.firstIndex(where: { $0.id == id }) {
                shots[index].made = made
                shots[index].fileID = judgement.emailID
            }
            set(id, .taken(taken?.name ?? judgement.matter ?? "", taken?.persistentModelID))
            if opens, let made = taken?.persistentModelID { NotificationCenter.default.post(name: .firstMatter, object: made) }
            Haptics.success()
            // Kept in the thread, as the Mac keeps it: every device shows what became of it, also
            // after a restart. The card here gives way to it.
            if !DemoData.isRequested {
                var turn = Navigation.Turn(question: "", scope: "", inHand: nil, seen: "", refs: [:], matter: taken?.persistentModelID)
                turn.id = id
                turn.date = shot.date
                turn.state = .failed("")
                turn.shot = .init(file: shot.file, taken: taken?.name ?? judgement.matter ?? "", into: taken?.persistentModelID,
                                  made: made, fileID: judgement.emailID)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                if let payload = try? encoder.encode(turn) {
                    let record = ThreadTurn(id: id, date: shot.date, payload: payload)
                    context.insert(record)
                    // In the thread of the matter it went into: there it is found again.
                    record.matter = taken
                    try? context.save()
                    remove(id)
                }
            }
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
    /// What the owner untick: "t0", "a1", "d0" — left out when it is taken in.
    @State private var skipped: Set<String> = []
    /// "A new matter …" was picked: its name is asked.
    @State private var makesNew = false
    @State private var newName = ""

    private var shots: PhoneShots { PhoneShots.shared }

    /// The file's own name, without the few letters an earlier version kept it under.
    private var name: String {
        let raw = shot.file.lastPathComponent
        return raw.count > 9 && raw.dropFirst(8).first == "-" ? String(raw.dropFirst(9)) : raw
    }

    var body: some View {
        // Taken in: only the line that says so, as the thread keeps it.
        if case .taken(let name, let id) = shot.stage {
            TakenLine(name: name, made: shot.made, file: shot.file, fileID: shot.fileID,
                      matter: id.flatMap { id in matters.first { $0.persistentModelID == id } }, record: nil) {
                shots.remove(shot.id)
            }
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(name, systemImage: shot.file.pathExtension.lowercased() == "pdf" ? "doc.text" : "photo")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if PhoneShots.isKept(shot.file) {
                Text("Saved on this \(ThisDevice.name), in \(PhoneShots.place).").font(.caption).foregroundStyle(.secondary)
            }
            switch shot.stage {
            case .reading:
                HStack(spacing: 8) { BeeLoader(size: 15); Text("Scanning it on this \(ThisDevice.name) …").font(.subheadline).foregroundStyle(.secondary) }
            case .read(let look), .sending(let look):
                // Brought in is the yes: it is sorting itself in already.
                preview(look)
                HStack(spacing: 8) { BeeLoader(size: 15); Text("Sorting it in …").font(.subheadline).foregroundStyle(.secondary) }
            case .answered(let look, let judgement):
                // Only here when Causabee is not sure which matter: what it brought, and the question.
                Text(look.heading).font(.headline).fixedSize(horizontal: false, vertical: true)
                found(judgement, look.offers(own: profiles.first?.names ?? []))
                ask(judgement)
            case .taken:
                EmptyView()
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

    /// Which matter, when Causabee is not sure: the likelier one as the button, the others and a
    /// new one under "Other". Never the whole list first.
    @ViewBuilder
    private func ask(_ judgement: Judgement) -> some View {
        let open = matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }
        let likely = judgement.matter.flatMap { key in open.first { $0.answers(to: key) } }
        let proposed = (judgement.matterTitle ?? "").trimmingCharacters(in: .whitespaces)
        Text("Which matter?").font(.subheadline.weight(.semibold))
        if makesNew {
            TextField("Name of the new matter", text: $newName)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
                .onAppear { if newName.isEmpty { newName = proposed } }
        }
        HStack(spacing: 10) {
            Menu {
                ForEach(open.filter { $0 !== likely }) { matter in
                    Button(matter.name) { take(into: matter) }
                }
                Divider()
                Button("A new matter …", systemImage: "plus") { makesNew = true }
                Button("Not needed", role: .destructive) { shots.remove(shot.id) }
            } label: { Text("Other").frame(maxWidth: .infinity) }
            .buttonStyle(.phone)
            .accessibilityIdentifier("shot.other")
            if makesNew {
                Button("Make it") { take(into: nil) }.buttonStyle(.phoneFilled)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } else if let likely {
                Button(likely.name) { take(into: likely) }.buttonStyle(.phoneFilled).lineLimit(1)
                    .accessibilityIdentifier("shot.likely")
            } else if !proposed.isEmpty {
                Button("New: \(proposed)") { newName = proposed; take(into: nil) }.buttonStyle(.phoneFilled).lineLimit(1)
                    .accessibilityIdentifier("shot.likely")
            }
        }
    }

    private func take(into matter: Matter?) {
        shots.take(shot.id, into: matter, newName: newName, owner: profiles.first?.names ?? [], skipping: skipped, context: context)
    }
}

/// What the panel over the field brings in: a photo or a screenshot, a scan, files or a folder.
enum AttachKind: Hashable { case photo, camera, scan, files }

/// The plus beside the assistant's field: what is brought in — files or a folder, a scan, a photo
/// or a screenshot. Picked, it asks what becomes of it: read and sorted in, or only imported, kept
/// with the matter unread. A task, a note, a link, a detail and a contact are cards over the field.
/// With a panel over the field, the plus opens it and is its × while it is open; the panel asks for
/// what is brought in through `request`.
struct AttachButton: View {
    let matter: Matter?
    var panel: Binding<Bool>? = nil
    var request: Binding<AttachKind?> = .constant(nil)
    /// "Task" or "Note" was picked: the field takes the cursor.
    var picked: () -> Void = {}
    /// Off on the first step (F008): it shows the reading itself, and opens the matter.
    var opensAssistant = true
    /// Each file brought in, by its shot's id.
    var brought: (UUID) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]
    @AppStorage(AutoMode.key) private var auto = false
    @State private var picksFiles = false
    @State private var scans = false
    @State private var picksPhoto = false
    @State private var takesPhoto = false
    @State private var photo: PhotosPickerItem?
    /// What was picked, waiting for the answer: read, or only import.
    @State private var waiting: [Picked] = []
    @State private var asks = false
    @State private var said: String?

    /// A file picked from Files, kept on the device until it is read or imported.
    private struct Picked { let file: URL; let name: String }

    private var pro: Bool { Plan.proIsOn(switched: auto, plan: Store.shared.plan, credit: BeeServer.hasCredit) }

    /// How the panel comes out of the plus, and goes back into it.
    static let panelMotion = Animation.spring(response: 0.36, dampingFraction: 0.86)

    /// With a panel: a plain plus that opens it, turned into an × while it is open. Without: the menu.
    @ViewBuilder private var opener: some View {
        if let panel {
            Button {
                Haptics.tap()
                withAnimation(Self.panelMotion) { panel.wrappedValue.toggle() }
            } label: {
                // A plus, as on the Mac (Figma "Composer"): quiet, so the send button is the one loud thing.
                Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(.secondary)
                    .rotationEffect(.degrees(panel.wrappedValue ? 45 : 0))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(panel.wrappedValue ? "Close" : "Add or bring in")
        } else {
            Menu {
                Button("Files or a folder", systemImage: "folder") { picksFiles = true }
                    .accessibilityIdentifier("plus.files")
                if VNDocumentCameraViewController.isSupported {
                    Button("Scan a document", systemImage: "doc.viewfinder") { scans = true }
                        .accessibilityIdentifier("plus.scan")
                }
                if PhotoCamera.isAvailable {
                    Button("Take a photo", systemImage: "camera") { takesPhoto = true }
                        .accessibilityIdentifier("plus.camera")
                }
                Button("Photo or screenshot", systemImage: "photo") { picksPhoto = true }
                    .accessibilityIdentifier("plus.photo")
            } label: {
                Image(systemName: "plus").font(.system(size: 17)).foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            // A menu's label takes the app's gold; the plus stays grey.
            .tint(Color.secondary)
            .accessibilityLabel("Bring in files, a scan or a photo")
        }
    }

    var body: some View {
        opener
        .accessibilityIdentifier("assistant.plus")
        // Asked for by the panel: the picker it names.
        .onChange(of: request.wrappedValue) {
            guard let kind = request.wrappedValue else { return }
            request.wrappedValue = nil
            switch kind {
            case .photo: picksPhoto = true
            case .camera: takesPhoto = true
            case .scan: scans = true
            case .files: picksFiles = true
            }
        }
        .fileImporter(isPresented: $picksFiles, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            ask(about: kept(urls))
        }
        .fullScreenCover(isPresented: $scans) {
            DocumentCamera { pages in
                scans = false
                if let data = Scans.pdf(of: pages) { ask(about: keep(data, named: "Scan \(MatterStatus.day(Date())).pdf")) }
            } cancel: { scans = false }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $takesPhoto) {
            PhotoCamera { image in
                takesPhoto = false
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                ask(about: keep(data, named: "Photo \(Self.stamp()).jpg"))
            } cancel: { takesPhoto = false }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $picksPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) {
            guard let photo else { return }
            self.photo = nil
            Task {
                guard let data = try? await photo.loadTransferable(type: Data.self) else { return }
                let type = photo.supportedContentTypes.first { ["png", "jpeg", "heic"].contains($0.preferredFilenameExtension ?? "") }
                // As the iPhone names its own: "Screenshot 2026-09-30 at 23.37.01", in local time — a
                // picture from the camera roll is a photo, a PNG a screenshot.
                let ext = type?.preferredFilenameExtension ?? "png"
                ask(about: keep(data, named: "\(ext == "png" ? "Screenshot" : "Photo") \(Self.stamp()).\(ext)"))
            }
        }
        .confirmationDialog(question, isPresented: $asks, titleVisibility: .visible) {
            Button("Read and sort in") { read() }
            if matter != nil { Button("Only import") { importOnly() } }
            Button("Cancel", role: .cancel) { waiting = [] }
        } message: {
            Text(pro ? "Read: Pro sorts each in, with its tasks and dates. Only import: kept with the matter, unread."
                     : "Read: each is sorted in on this \(ThisDevice.name). Only import: kept with the matter, unread.")
        }
        .alert(said ?? "", isPresented: Binding(get: { said != nil }, set: { if !$0 { said = nil } })) {
            Button("OK", role: .cancel) { }
        }
    }

    /// "2026-09-30 at 23.37.01", in local time, as the iPhone names its own.
    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }

    /// With Pro the choice; without it, only importing is offered, and asked as that.
    private var question: String {
        let one = waiting.count == 1, name = waiting.first?.name ?? ""
        return one ? "Read “\(name)”, or only import it?" : "Read \(waiting.count) files, or only import them?"
    }

    /// Picked is the yes: a photo, a scan or a few files are read and sorted in at once. Only a
    /// pile — a folder — asks first whether to read it all or only keep it with the matter.
    private func ask(about picked: [Picked]) {
        guard !picked.isEmpty else { return }
        waiting = picked
        if picked.count <= Self.readsWithoutAsking || matter == nil { read() } else { asks = true }
    }

    /// How many files picked at once are read without asking.
    static let readsWithoutAsking = 5

    /// Picked from Files: every file of a folder with it, copied onto the device, where reading and
    /// importing both find it.
    private func kept(_ urls: [URL]) -> [Picked] {
        urls.flatMap { url -> [Picked] in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            return FolderImport.files(in: [url]).flatMap { file -> [Picked] in
                guard let data = FolderImport.data(of: file) else { return [] }
                return keep(data, named: file.lastPathComponent)
            }
        }
    }

    private func keep(_ data: Data, named name: String) -> [Picked] {
        guard let file = PhoneShots.shared.keep(data, named: name) else { return [] }
        return [Picked(file: file, name: name)]
    }

    /// Read on the device and by Pro, and shown in the assistant, where it waits for "Sort in".
    private func read() {
        for item in waiting {
            brought(PhoneShots.shared.bring(item.file, matter: matter?.persistentModelID, context: context, owner: profiles.first?.names.first))
        }
        waiting = []
        if opensAssistant { navigation.showsAssistant = true }
    }

    /// Kept with the matter as files, unread — as "Files or a folder" did.
    private func importOnly() {
        guard let matter else { waiting = []; return }
        let files = waiting.map(\.file)
        waiting = []
        let folder = PhoneShots.folder
        let result = FolderImport.add(files, to: matter, context: context) { file, name in
            FolderImport.data(of: file).flatMap { PhoneShots.keep($0, named: name, in: folder) }
        }
        try? context.save()
        PhoneFolderSaver.save([matter])
        Haptics.success()
        said = result.said ?? (files.count == 1 ? "Imported into “\(matter.name)”, unread." : nil)
    }
}

/// Picked from the plus with no matter open: the matter it is for — those opened last on top, then
/// every open one, found by its name.
struct MatterChooser: View {
    let plus: Navigation.Plus
    @Environment(Navigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @Query private var matters: [Matter]
    @State private var search = ""

    private var title: String {
        switch plus {
        case .scan: "Scan for which matter?"
        case .files: "Files for which matter?"
        case .contact: "Contact for which matter?"
        case .detail: "Detail for which matter?"
        case .link: "Link for which matter?"
        case .note: "Note for which matter?"
        case .task: "Task for which matter?"
        }
    }

    var body: some View {
        let open = sidebarOrder(matters).filter { !$0.isClosed }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let recent = query.isEmpty ? RecentMatters.list(in: open) : []
        let rest = query.isEmpty ? open.filter { matter in !recent.contains { $0 === matter } }
                                 : open.filter { $0.name.localizedCaseInsensitiveContains(query) }
        NavigationStack {
            List {
                if !recent.isEmpty { Section("Recent") { rows(recent) } }
                Section(recent.isEmpty ? "" : "All matters") { rows(rest) }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a matter")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetCancel { dismiss() } } }
        }
        .tint(Theme.gold)
    }

    private func rows(_ list: [Matter]) -> some View {
        ForEach(list) { matter in
            Button { navigation.chosen(matter, for: plus) } label: {
                HStack(spacing: 10) {
                    MatterIconTile(matter: matter, size: 28)
                    Text(matter.name).lineLimit(1)
                }
            }
            // The names as any words; gold is for Cancel.
            .tint(.primary)
            .accessibilityIdentifier("chooser.matter")
        }
    }
}

/// `--demo --shot letter`: a letter as the camera would bring it, for the regression test — brought
/// when the matter opens, into the assistant, where it is read and offers what it found.
struct LetterShotBringer: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]

    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .task {
                guard LetterShot.isRequested, !LetterShot.brought, let file = LetterShot.file() else { return }
                LetterShot.brought = true
                PhoneShots.shared.bring(file, matter: matter.persistentModelID, context: context, owner: profiles.first?.names.first)
                navigation.showsAssistant = true
            }
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

/// A screenshot, a picture or a PDF dragged onto the page or the assistant — from another app on
/// the iPad — or pasted with the keyboard: kept, read, and shown in the assistant, as the Mac takes
/// what is dropped or pasted on it.
private struct ReceivesFiles: ViewModifier {
    let matter: Matter?
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]

    func body(content: Content) -> some View {
        let received = content.dropDestination(for: BroughtFile.self) { items, _ in
            bring(items)
            return !items.isEmpty
        }
        if #available(iOS 27, *) {
            received.pasteDestination(for: BroughtFile.self) { items in bring(items) }
        } else {
            received
        }
    }

    private func bring(_ items: [BroughtFile]) {
        for item in items {
            guard let file = PhoneShots.shared.keep(item.data, named: item.name) else { continue }
            PhoneShots.shared.bring(file, matter: matter?.persistentModelID, context: context, owner: profiles.first?.names.first)
        }
        if !items.isEmpty { navigation.showsAssistant = true }
    }
}

extension View {
    func receivesFiles(matter: Matter?) -> some View { modifier(ReceivesFiles(matter: matter)) }
}

/// The one line that says where a file went and what it brought — "Kita · Pay €120 by 20 Nov" —
/// with Undo, which takes it all back out, and Change: open the matter, or move it with what it
/// brought into another. Said once, where it was brought in (docs/digest-and-chat.md).
struct TakenLine: View {
    let name: String
    let made: [String]?
    let file: URL
    let fileID: String?
    let matter: Matter?
    /// The thread's record of it, when it is kept: changed with a move, gone with Undo.
    let record: ThreadTurn?
    var gone: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var matters: [Matter]

    private var document: MatterCore.Document? {
        guard let fileID else { return nil }
        return matter?.documents?.first { $0.messageID == fileID }
    }

    /// The owner's tasks it brought that have no day yet.
    private var undated: [Todo] {
        guard let matter, let document else { return [] }
        return matter.brought(by: document).todos.filter { $0.due == nil && $0.owner != .other && !$0.isDone && !$0.isInfo }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done).font(.body)
            VStack(alignment: .leading, spacing: 3) {
                // Older turns, from before it sorted in by itself, say only where it went.
                let lines = made ?? []
                Text(SortsIn.headline(name, made))
                    .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                ForEach(Array(lines.dropFirst().prefix(3).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if lines.count > 4 { Text("and \(lines.count - 4) more").font(.footnote).foregroundStyle(.secondary) }
                Text(Document.ownName(of: file)).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                // Its tasks with no day: given one here, where it came in, they are a plan.
                if !undated.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(undated.count == 1 ? "When?" : "When, for its \(undated.count) tasks?").font(.footnote.weight(.medium))
                        WhenChips { when in
                            let day = Planning.day(when, today: MatterStatus.day(Date()))
                            for todo in undated { todo.due = day }
                            try? context.save()
                            Haptics.tap()
                        }
                    }
                    .padding(.top, 4)
                }
                HStack(spacing: 18) {
                    Menu {
                        if let matter { Button("Open \(matter.name)", systemImage: "arrow.right") { navigation.open(matter) } }
                        if document != nil {
                            Menu("Move to …") {
                                ForEach(matters.filter { !$0.isClosed && $0 !== matter }.sorted { $0.name < $1.name }) { other in
                                    Button(other.name) { move(to: other) }
                                }
                            }
                        }
                    } label: { Text("Change") }
                    .accessibilityIdentifier("taken.change")
                    if document != nil {
                        Button("Undo") { undo() }.accessibilityIdentifier("taken.undo")
                    }
                }
                .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("taken.line")
    }

    /// Back out: the file and what only it brought, and this line. A copy Causabee kept is deleted.
    private func undo() {
        guard let matter, let document else { return }
        matter.forget(document, besides: PhoneCloud.storeLocation(), in: context)
        if PhoneShots.isKept(file) { try? FileManager.default.removeItem(at: file) }
        if let record { context.delete(record) }
        try? context.save()
        Haptics.tap()
        gone()
    }

    /// Into another matter, with what it brought; the line says the new one.
    private func move(to other: Matter) {
        guard let matter, let document else { return }
        try? matter.carry(document, to: other, in: context)
        if let record, var turn = try? JSONDecoder().decode(Navigation.Turn.self, from: record.payload) {
            turn.shot?.taken = other.name
            turn.shot?.into = other.persistentModelID
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let payload = try? encoder.encode(turn) { record.payload = payload }
            record.matter = other
        }
        try? context.save()
        Haptics.success()
        if record == nil { gone() }
    }
}

/// Files that came attached to mail — a PDF, a scan, a photo — read by themselves after a round of
/// mail, as a screenshot shared is: what they say comes into their matter, marked NEW. A logo or a
/// signature is not read (`Document.isBranding`). Each is tried once: a failure is not paid for again.
@MainActor
enum AttachmentReading {
    private static let triedKey = "attachments.tried"
    private static var running = false

    static func readNew(context: ModelContext, owner: String?) {
        guard AutoMode.isOn, !DemoData.isRequested, !running else { return }
        var tried = Set(UserDefaults.standard.stringArray(forKey: triedKey) ?? [])
        let since = Date().addingTimeInterval(-14 * 86_400)
        let waiting = ((try? context.fetch(FetchDescriptor<MatterCore.Document>())) ?? []).filter { document in
            document.source.kind == .mail && document.reading == .kept && !document.isHidden && document.matter != nil
                && (document.source.date ?? .distantPast) > since && !tried.contains(document.messageID + "|" + document.name)
        }
        guard !waiting.isEmpty else { return }
        running = true
        Task {
            defer { running = false }
            for document in waiting.prefix(8) {
                tried.insert(document.messageID + "|" + document.name)
                UserDefaults.standard.set(Array(tried.suffix(2000)), forKey: triedKey)
                guard let url = try? await MailFiles.open(document) else { continue }
                PhoneShots.shared.bring(url, matter: document.matter?.persistentModelID, document: document.persistentModelID,
                                        context: context, owner: owner, quiet: true)
            }
        }
    }
}
