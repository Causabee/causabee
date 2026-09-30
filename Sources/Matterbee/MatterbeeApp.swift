import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// The Mac app: the assistant and each matter's status, with a door in each direction.
///
/// It reads the same store `matter-spike import` writes. Where that store is: `--store <path>`,
/// then `MATTERBEE_STORE`, then `~/Library/Application Support/Matterbee/matters.store`.
/// `--demo` fills an empty store with made-up matters, in `Matterbee-Demo` unless a store is named.
@main
struct MatterbeeApp: App {
    let storeURL: URL
    let opened: Result<ModelContainer, Error>

    init() {
        // Once, before the schema goes to Production: every record type into Development, then quit.
        if let flag = CommandLine.arguments.firstIndex(of: "--init-cloudkit-schema") {
            let next = CommandLine.arguments.index(after: flag)
            let id = next < CommandLine.arguments.endIndex ? CommandLine.arguments[next] : CloudSync.Mode.on.container!
            do {
                try CloudSync.initializeSchema(container: id)
                print("✓ The CloudKit schema of \(id) is complete in Development.")
                exit(0)
            } catch {
                print("✗ \(error)")
                exit(1)
            }
        }
        // Once, moving the owner's matters from Development to Production: a copy iCloud has not seen.
        if let flag = CommandLine.arguments.firstIndex(of: "--fresh-cloud-copy"), flag + 2 < CommandLine.arguments.count {
            let from = URL(fileURLWithPath: CommandLine.arguments[flag + 1]), to = URL(fileURLWithPath: CommandLine.arguments[flag + 2])
            do {
                try CloudSync.freshCopy(from: from, to: to)
                print("✓ \(to.path): the matters of \(from.lastPathComponent), not yet in iCloud.")
                exit(0)
            } catch {
                print("✗ \(error)")
                exit(1)
            }
        }
        Theme.registerFonts()
        // Started from the terminal with `swift run`, the process is not an app yet until it says so.
        NSApplication.shared.setActivationPolicy(.regular)
        let url = MatterbeeApp.storeLocation()
        storeURL = url
        let cloud = CloudSync.mode
        opened = Result {
            let container = try MatterSchema.container(at: url, cloudKit: cloud.container)
            if cloud == .test { MainActor.assumeIsolated { CloudSync.seedTest(container.mainContext) } }
            if DemoData.isRequested { MainActor.assumeIsolated { Calendars.shared.isSealed = true; DemoData.seed(container.mainContext) } }
            // Files taken in before they were kept as files of their matter.
            MainActor.assumeIsolated { _ = try? MatterImport.addDroppedFiles(to: container.mainContext) }
            // This Mac's list of names, for the iPhone to ask with: now, and whenever Matterbee
            // goes to the background or quits — by then new mail may have taught it new names.
            MainActor.assumeIsolated { NameListPublisher.start(container.mainContext) }
            return container
        }
        CloudSync.shared.watch()
        DispatchQueue.main.async { NSApp.activate() }
    }

    var body: some Scene {
        WindowGroup("Matterbee") {
            switch opened {
            case .success(let container):
                RootView().modelContainer(container).frame(minWidth: 960, minHeight: 640)
            case .failure(let error):
                ContentUnavailableView("The store cannot be opened",
                                       systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("\(storeURL.path)\n\(error.localizedDescription)"))
                    .frame(minWidth: 600, minHeight: 400)
            }
        }
        // No bar of the Mac's: the window is drawn by Matterbee, and moved by its empty places.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Set Up Matterbee …") { NotificationCenter.default.post(name: .showSetup, object: nil) }
                Button(DemoData.isRequested ? "Leave the Demo" : "Try the Demo") { DemoData.restart(demo: !DemoData.isRequested) }
            }
            CommandGroup(replacing: .help) {
                Button("Introduction to Matterbee") { NotificationCenter.default.post(name: .showIntro, object: nil) }
            }
        }
        // With the store: the folder settings save the matters' files, and need to see them.
        Settings {
            if case .success(let container) = opened {
                ModelSettingsView().modelContainer(container)
            } else {
                ModelSettingsView()
            }
        }
    }

    /// `--mapping <path>`, then `MATTERBEE_MAPPING`, then `mapping.json` next to the store.
    nonisolated static func mappingLocation() -> URL {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--mapping"), flag + 1 < arguments.count {
            return URL(fileURLWithPath: arguments[flag + 1])
        }
        if let path = ProcessInfo.processInfo.environment["MATTERBEE_MAPPING"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return storeLocation().deletingLastPathComponent().appendingPathComponent("mapping.json")
    }

    nonisolated static func storeLocation() -> URL {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--store"), flag + 1 < arguments.count {
            return URL(fileURLWithPath: arguments[flag + 1])
        }
        if let path = ProcessInfo.processInfo.environment["MATTERBEE_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        // The iCloud test and the demo keep their own store, name list and record, apart from the owner's.
        // So does a development build syncing with CloudKit's Development environment: the owner's
        // matters sync in Production, and one store must never meet both.
        let name = DemoData.isRequested ? "Matterbee-Demo" : CloudSync.mode == .test ? "Matterbee-Test"
            : CloudSync.mode == .on && !CloudSync.isProduction ? "Matterbee-Development" : "Matterbee"
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("matters.store")
    }
}

/// Where the window is, and what the assistant has in hand.
@Observable
final class Navigation {
    enum Place: Hashable {
        case assistant
        case matter(PersistentIdentifier)
    }

    /// The item a "reden" put into the assistant: shown above the field, and taken off with ×.
    struct Pinned: Equatable, Codable {
        var matter: PersistentIdentifier
        var matterName: String
        var kind: String
        var text: String

        /// The whole matter in hand, not one thing in it. Old saved threads still say "Sache".
        static func isMatter(_ kind: String) -> Bool { kind == "Matter" || kind == "Sache" }
    }

    /// What is open on the right. A matter open there is what the next question is about — and what
    /// was in hand from another matter is put down.
    var place: Place? = .assistant {
        didSet {
            guard let pinned else { return }
            if case .matter(let id) = place, id == pinned.matter { return }
            self.pinned = nil
        }
    }
    var pinned: Pinned?
    /// The sidebar folded away: the assistant's bar then starts right of the window's buttons.
    var sidebarHidden = false
    /// Reading: small actions and the AI's explanations put away. Kept for the next start.
    /// The introduction's pictures show everything, whatever the owner chose.
    var reading = IntroShot.current == nil && UserDefaults.standard.bool(forKey: "ui.reading") {
        didSet { UserDefaults.standard.set(reading, forKey: "ui.reading") }
    }
    /// Counts up to put the cursor in the assistant's field.
    var focusRequest = 0
    /// Words to put in the assistant's field with the cursor, for the owner to send or change.
    var prefill: String?
    /// The assistant's one thread, kept beside the store: scrolling up shows everything ever asked,
    /// after a restart too. It holds real names — it is the owner's own record, like the store.
    var turns: [Turn] = [] { didSet { saveThread() } }
    /// `mapping.json`: the disguise, read and added to when the assistant asks.
    let mapping = MatterbeeApp.mappingLocation()
    /// The store, and beside it the record of what the label has answered.
    let store = MatterbeeApp.storeLocation()

    struct Turn: Identifiable {
        enum State {
            case asking
            case answered(AssistantAsk.Answer)
            case failed(String)
        }
        var id = UUID()
        var date = Date()
        var question: String
        var scope: String
        var inHand: Pinned?
        var seen: String
        var refs: [String: FactRef]
        var matter: PersistentIdentifier?
        var state: State = .asking
        /// Cards the owner ticked, by position.
        var applied: Set<Int> = []
        /// Set when this turn is a screenshot brought in, not a question.
        var shot: Shot?
        /// A line Matterbee wrote itself — what came in with "Get new mail" — not a question.
        var note: String?
        /// Typed names read as the known names they almost were: "„Geor“ als „Georg“".
        var readAs: [String] = []
        /// The matter a "new matter" card in this turn made: the to-do cards beside it go there.
        var madeMatter: PersistentIdentifier?
        /// How to take each ticked card back.
        var undos: [Int: Undo] = [:]
        /// Cards the owner dismissed, by position: kept, so they stay dismissed after a restart.
        var dismissedCards: Set<Int> = []
        /// Drafts put into the mailbox, by card: the folder they are in.
        var drafted: [Int: String] = [:]
        /// A draft on its way into the mailbox, or why it did not get there.
        var drafting: [Int: String] = [:]
    }

    /// A screenshot in the thread, from reading it to taking what it says into a matter.
    struct Shot {
        enum Stage {
            case reading
            case read(ScreenshotDoor.Look)
            case sending(ScreenshotDoor.Look)
            case answered(ScreenshotDoor.Look, Judgement)
            case taken(String, PersistentIdentifier?)
            case failed(String)
            case dismissed
        }
        var file: URL
        /// Copied in, because it had no home of its own; otherwise kept where it is.
        var copied: Bool
        var stage: Stage = .reading
        /// Set when it is a file taken out of a mail of a matter: marked read once taken in.
        var document: PersistentIdentifier? = nil
    }

    /// What a ticked card changed, kept so it can be put back as it was — the same on the iPhone.
    typealias Undo = CardActions.Undo

    /// A to-do to scroll to and mark when a matter opens: the one "überfällig" pointed at.
    var showing: PersistentIdentifier?

    private var threadURL: URL { store.deletingLastPathComponent().appendingPathComponent("assistant-thread.json") }
    @ObservationIgnored private var loading = false
    /// The store the thread is kept in, one record a turn — the way it can sync later.
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var records: [UUID: ThreadTurn] = [:]
    @ObservationIgnored private var written: [UUID: Data] = [:]

    /// Reads the thread from the store. The first time, the file it was kept in before is moved
    /// in, and left beside the store renamed, as it was.
    @MainActor
    func attach(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        loading = true
        defer { loading = false }
        let stored = (try? context.fetch(FetchDescriptor<ThreadTurn>(sortBy: [SortDescriptor(\.date)]))) ?? []
        if stored.isEmpty, let data = try? Data(contentsOf: threadURL), let saved = try? JSONDecoder().decode([Turn].self, from: data) {
            turns = saved
            loading = false
            saveThread()
            loading = true
            let kept = threadURL.deletingPathExtension().appendingPathExtension("moved-into-store.json")
            try? FileManager.default.moveItem(at: threadURL, to: kept)
            return
        }
        var loaded: [Turn] = []
        for record in stored {
            records[record.id] = record
            written[record.id] = record.payload
            if let turn = Self.turn(of: record) { loaded.append(turn) }
        }
        turns = loaded
    }

    /// A record's turn, with the matter it belongs to taken from the record: the id in the payload
    /// is the store's that asked, and another device's store has ids of its own.
    @MainActor
    private static func turn(of record: ThreadTurn) -> Turn? {
        guard var turn = try? JSONDecoder().decode(Turn.self, from: record.payload) else { return nil }
        if let matter = record.matter { turn.matter = matter.persistentModelID }
        return turn
    }

    /// Takes in the turns another device added or changed since — a question asked on the iPhone,
    /// a card ticked there — and leaves the ones written here as they are.
    @MainActor
    func refresh() {
        guard let context, !loading else { return }
        let stored = (try? context.fetch(FetchDescriptor<ThreadTurn>(sortBy: [SortDescriptor(\.date)]))) ?? []
        var updated = turns
        var changed = false
        for record in stored where written[record.id] != record.payload {
            guard var turn = Self.turn(of: record) else { continue }
            records[record.id] = record
            written[record.id] = record.payload
            if let index = updated.firstIndex(where: { $0.id == turn.id }) {
                // One still being asked here, or a screenshot being read, is this Mac's to finish.
                if case .asking = updated[index].state { continue }
                turn.undos = updated[index].undos
                turn.shot = updated[index].shot ?? turn.shot
                turn.drafting = updated[index].drafting
                updated[index] = turn
            } else {
                updated.append(turn)
            }
            changed = true
        }
        guard changed else { return }
        loading = true
        turns = updated.sorted { $0.date < $1.date }
        loading = false
    }

    /// Writes the turns that changed since the last time, each into its own record.
    private func saveThread() {
        guard !loading, let context else { return }
        // Keys in a fixed order: otherwise a dictionary encodes differently on each launch, every
        // turn looks changed, and the whole thread is written — and sent to iCloud — again.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var changed = false
        for turn in turns {
            guard let data = try? encoder.encode(turn), written[turn.id] != data else { continue }
            let record = records[turn.id] ?? {
                let made = ThreadTurn(id: turn.id, date: turn.date, payload: data)
                context.insert(made)
                records[turn.id] = made
                return made
            }()
            record.payload = data
            // Fetched, not taken by id: a matter merged away since is gone, and must not be touched.
            record.matter = turn.matter.flatMap { id in
                try? context.fetch(FetchDescriptor<Matter>(predicate: #Predicate { $0.persistentModelID == id })).first
            }
            written[turn.id] = data
            changed = true
        }
        if changed { try? context.save() }
    }

    func open(_ matter: Matter, showing todo: PersistentIdentifier? = nil) {
        showing = todo
        place = .matter(matter.persistentModelID)
    }

    /// What "Get new mail" took into each matter, as a line in that matter's part of the thread.
    /// Written here, from the answers already in hand: nothing is sent for it.
    @MainActor
    func logIntake(_ judgements: [Judgement], matters: [Matter], model: String) {
        var byMatter: [PersistentIdentifier: [Judgement]] = [:]
        for judgement in judgements where !judgement.isBulk {
            guard let key = judgement.matter, let matter = matters.first(where: { $0.answers(to: key) }) else { continue }
            byMatter[matter.persistentModelID, default: []].append(judgement)
        }
        for (id, mails) in byMatter.sorted(by: { ($0.value.first?.date ?? .distantPast) < ($1.value.first?.date ?? .distantPast) }) {
            let tasks = mails.reduce(0) { $0 + $1.todos.filter { $0.sameAs == nil }.count }
            let dates = mails.reduce(0) { $0 + $1.appointments.count + $1.deadlines.count }
            let done = mails.reduce(0) { $0 + $1.done.count }
            var head = "\(mails.count) \(mails.count == 1 ? "mail" : "mails") taken in"
            if tasks > 0 { head += " · \(tasks) new \(tasks == 1 ? "task" : "tasks")" }
            if dates > 0 { head += " · \(dates) \(dates == 1 ? "date" : "dates")" }
            if done > 0 { head += " · \(done) shown done" }
            head += " · sorted by \(model)"
            let lines = mails.prefix(5).map { "• " + ($0.subject.isEmpty ? "(no subject)" : $0.subject) }
                + (mails.count > 5 ? ["• … and \(mails.count - 5) more"] : [])
            var turn = Turn(question: "", scope: "Mail", inHand: nil, seen: "", refs: [:], matter: id)
            turn.note = ([head] + lines).joined(separator: "\n")
            turn.state = .failed("")
            turns.append(turn)
        }
    }

    /// Puts an item in hand without leaving where the owner is: typing in a matter stays there.
    func pin(_ text: String, kind: String, in matter: Matter) {
        pinned = Pinned(matter: matter.persistentModelID, matterName: matter.name, kind: kind, text: text)
    }
}

struct RootView: View {
    @Query private var matters: [Matter]
    @State private var navigation = Navigation()
    @Environment(\.modelContext) private var context
    @State private var renaming: Matter?
    @State private var mailCheck = MailCheck()
    /// The closed matters in the sidebar, folded away until opened; remembered on this Mac.
    @AppStorage("sidebar.showsClosed") private var showsClosed = false
    /// The five pages on what Matterbee is: once at the first start, then from Help.
    @AppStorage(IntroView.seenKey) private var introSeen = false
    @State private var showsIntro = false
    @State private var showsSetup = false
    @AppStorage(SetupAssistant.laterKey) private var setupLater = false
    @State private var newName = ""
    /// The matter to fold in, and the one it goes into.
    @State private var merging: (Matter, Matter)?
    /// The sidebar's search: a matter found by its name, a task or a mail — on the Mac.
    @State private var search = ""
    @Query private var profiles: [Profile]

    /// The sidebar in the overview's order: overdue first, then by the next date; the quiet
    /// ones — nothing open, no date — after them by their newest mail; closed ones last, the
    /// most recently closed first. Sorted once per drawing and handed on.
    private func sidebarOrder() -> [Matter] {
        let active = activeMatters(matters)
        let shown = Set(active.map(\.persistentModelID))
        let byNewestMail = { (list: [Matter]) in
            list.map { ($0, MatterStatus($0).lastDate ?? .distantPast) }.sorted { $0.1 > $1.1 }.map(\.0)
        }
        let quiet = byNewestMail(matters.filter { !$0.isClosed && !shown.contains($0.persistentModelID) })
        let closed = matters.filter(\.isClosed).sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        return active + quiet + closed
    }

    /// Always with a matter open; on the overview only while a dropped file waits to be taken in.
    private var showsAssistant: Bool {
        if case .matter = navigation.place { return true }
        return navigation.turns.contains { turn in
            guard turn.matter == nil, let shot = turn.shot else { return false }
            switch shot.stage {
            case .taken, .dismissed, .failed: return false
            default: return true
            }
        }
    }

    private func start(_ name: String) {
        guard let matter = try? Matter.make(named: name, in: context) else { return }
        try? context.save()
        search = ""
        navigation.open(matter)
    }

    private var mergeQuestion: String {
        guard let (from, into) = merging else { return "" }
        return "Merge “\(from.name)” into “\(into.name)”?"
    }

    /// Matterbee's own sidebar, not the Mac's: 270 wide, the window's buttons and the sidebar's on
    /// its top 52 points, the matters below, getting new mail at the bottom.
    /// One matter in the sidebar, open or closed alike, with its menu.
    private func sidebarRow(_ matter: Matter, _ sorted: [Matter]) -> some View {
        MatterRow(matter: matter)
            .sidebarRow(selected: navigation.place == .matter(matter.persistentModelID)) { navigation.open(matter) }
            .contextMenu {
                Button("Rename …") { newName = matter.name; renaming = matter }
                Menu("Merge with …") {
                    ForEach(sorted.filter { $0 !== matter }) { other in
                        Button(other.name + (other.isClosed ? " (closed)" : "")) { merging = (matter, other) }
                    }
                }
            }
    }

    private func sidebar(_ sorted: [Matter]) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: WindowMetrics.topLine)
            // The selection drawn by Matterbee, not by the Mac: a light grey, as in the design.
            List {
                let overview = navigation.place == .assistant || navigation.place == nil
                Text("Overview").fontWeight(.semibold)
                    .sidebarRow(selected: overview) { navigation.place = .assistant }
                Section("Matters") {
                    ForEach(sorted.filter { !$0.isClosed }) { matter in sidebarRow(matter, sorted) }
                }
                let closed = sorted.filter(\.isClosed)
                if !closed.isEmpty {
                    Section(isExpanded: $showsClosed) {
                        ForEach(closed) { matter in sidebarRow(matter, sorted) }
                    } header: {
                        Text("Closed · \(closed.count)")
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            MailCheckView(check: mailCheck)
        }
        .frame(width: WindowMetrics.sidebarWidth)
        .background(SidebarMaterial())
    }

    var body: some View {
        let sorted = sidebarOrder()
        // The whole window is Matterbee's: nothing of the Mac's bar is seen. Its three buttons sit in
        // the middle of a 52-point top line (WindowChrome), the sidebar's button right of them.
        HStack(spacing: 0) {
            if !navigation.sidebarHidden {
                sidebar(sorted)
                    .transition(.move(edge: .leading))
                Divider()
            }
            // A matter: the assistant on the left, the matter on the right, in the golden ratio —
            // 38.2 to 61.8. The overview: only what is going on — nothing is asked there — unless a
            // file dropped on it waits to be sorted into a matter.
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if showsAssistant {
                        AssistantColumn(matters: sorted)
                            .frame(width: max(320, geometry.size.width * 0.382))
                            .frame(maxHeight: .infinity)
                        Divider()
                    }
                    Group {
                        switch navigation.place {
                        case .matter(let id):
                            if let matter = matters.first(where: { $0.persistentModelID == id }) {
                                MatterStatusView(matter: matter).id(id)
                            }
                        case .assistant, nil:
                            OverviewView(matters: sorted, search: $search, start: start)
                        }
                    }
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // Up into the empty window bar: the pages start at the very top.
            .ignoresSafeArea(.container, edges: .top)
            .background(Theme.canvas)
            .dropDestination(for: URL.self) { urls, _ in
                let files = urls.filter { ScreenshotDoor.readable.contains($0.pathExtension.lowercased()) }
                let conversation = Conversation(context: context, navigation: navigation, owner: profiles.first?.names.first)
                for url in files { conversation.bring(url) }
                return !files.isEmpty
            }
        }
        .ignoresSafeArea()
        .environment(\.reading, navigation.reading)
        // Right of the green button, as far from it as the buttons are apart; open or folded alike.
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) { SidebarButton(); ReadingButton() }
                .padding(.leading, WindowMetrics.sidebarButtonX).padding(.top, WindowMetrics.sidebarButtonTop).ignoresSafeArea()
        }
        .background(WindowChrome())
        .environment(navigation)
        // Plain buttons, switches and checkboxes in black; links are gold by their own style.
        .tint(.primary)
        // Lines of running text 18 apart, as in the design: the system's 16 and 2 more.
        .lineSpacing(2)
        // A turn asked on the iPhone, or on the other Mac, arrives while Matterbee is open.
        .onReceive(NotificationCenter.default.publisher(for: .threadMayHaveChanged)) { _ in navigation.refresh() }
        .onAppear {
            navigation.attach(context)
            // `--demo --shot`: set up as one of the introduction's pictures.
            IntroShot.current?.arrange(navigation, matters: matters)
            MirrorRunner.shared.start(context)
            // Not over the demo: it is started to be looked at, and photographed, as it is.
            // The setup's test starts as a first start does: the introduction, then the setup.
            if SetupState.isFresh { showsIntro = true }
            else if !introSeen, !DemoData.isRequested { showsIntro = true }
            else if !setupLater, !DemoData.isRequested, SetupAssistant.isMissingSomething { showsSetup = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showIntro)) { _ in showsIntro = true }
        .onReceive(NotificationCenter.default.publisher(for: .showSetup)) { _ in showsSetup = true }
        // After the introduction, the setup — when something Matterbee needs is still missing.
        .sheet(isPresented: $showsIntro, onDismiss: {
            if SetupState.isFresh || (!setupLater && !DemoData.isRequested && SetupAssistant.isMissingSomething) { showsSetup = true }
        }) { IntroView() }
        .sheet(isPresented: $showsSetup) {
            SetupAssistant { mailCheck.look(store: navigation.store, context: context) }
        }
        .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
            Button("Merge") {
                if let (from, into) = merging {
                    into.absorb(from, in: context)
                    try? context.save()
                    navigation.open(into)
                }
                merging = nil
            }
            Button("Cancel", role: .cancel) { merging = nil }
        } message: {
            Text("All mails, tasks, appointments and people come along. The old name stays as an alias, so new mail still arrives. You cannot split it again later.")
        }
        .alert("Rename matter", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let matter = renaming, !name.isEmpty, name != matter.name { matter.rename(to: name); try? context.save() }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("The old name stays as an alias, so new mail still finds the matter.")
        }
        .onAppear {
            // `--open <matter>` starts in that matter's status.
            let arguments = CommandLine.arguments
            if let flag = arguments.firstIndex(of: "--open"), flag + 1 < arguments.count,
               let matter = matters.first(where: { $0.answers(to: arguments[flag + 1]) }) {
                navigation.open(matter)
            }
        }
        .overlay {
            if matters.isEmpty {
                ContentUnavailableView("No matters yet", systemImage: "tray",
                                       description: Text("First: matter-spike fetch --classify, then matter-spike import"))
            }
        }
    }
}

struct MatterRow: View {
    let matter: Matter

    var body: some View {
        let status = MatterStatus(matter)
        VStack(alignment: .leading, spacing: 2) {
            Text(matter.name).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary)
            if matter.isClosed {
                HStack(spacing: 4) {
                    Text("closed \(matter.closedAt.map(Dates.short) ?? "")")
                    let new = status.mailsSinceClosed.count
                    if new > 0 { Text("· \(new) new \(new == 1 ? "mail" : "mails")").foregroundStyle(Theme.warning) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
            HStack(spacing: 4) {
                Text("\(matter.openTodos.count) open")
                if let next = status.next { Text("· \(Dates.short(next.day))") }
                if !status.overdue.isEmpty {
                    Text("· \(status.overdue.count) overdue").foregroundStyle(Theme.warning)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: Keeping the thread

/// What is kept of a turn: the question, what came back, what was ticked. Not how to undo a tick —
/// that lasts as long as the app is open. A question still on its way when the app closed, and a
/// screenshot not taken in yet, come back saying so.
extension Navigation.Turn: Codable {
    enum CodingKeys: String, CodingKey {
        case id, date, question, scope, inHand, seen, refs, matter, answer, failed, applied, readAs, drafted, dismissedCards, note
        case shotFile, shotCopied, shotTaken, shotTakenInto, shotDismissed, shotDocument
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(question: try c.decode(String.self, forKey: .question), scope: try c.decode(String.self, forKey: .scope),
                  inHand: try c.decodeIfPresent(Navigation.Pinned.self, forKey: .inHand), seen: try c.decode(String.self, forKey: .seen),
                  refs: try c.decodeIfPresent([String: FactRef].self, forKey: .refs) ?? [:],
                  matter: try c.decodeIfPresent(PersistentIdentifier.self, forKey: .matter))
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        applied = try c.decodeIfPresent(Set<Int>.self, forKey: .applied) ?? []
        readAs = try c.decodeIfPresent([String].self, forKey: .readAs) ?? []
        drafted = try c.decodeIfPresent([Int: String].self, forKey: .drafted) ?? [:]
        dismissedCards = try c.decodeIfPresent(Set<Int>.self, forKey: .dismissedCards) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note)
        if let answer = try c.decodeIfPresent(AssistantAsk.Answer.self, forKey: .answer) {
            state = .answered(answer)
        } else {
            state = .failed(try c.decodeIfPresent(String.self, forKey: .failed) ?? "Stopped: the app was closed before the answer came.")
        }
        if let file = try c.decodeIfPresent(URL.self, forKey: .shotFile) {
            var shot = Navigation.Shot(file: file, copied: try c.decodeIfPresent(Bool.self, forKey: .shotCopied) ?? false)
            shot.document = try c.decodeIfPresent(PersistentIdentifier.self, forKey: .shotDocument)
            if let name = try c.decodeIfPresent(String.self, forKey: .shotTaken) {
                shot.stage = .taken(name, try c.decodeIfPresent(PersistentIdentifier.self, forKey: .shotTakenInto))
            } else if try c.decodeIfPresent(Bool.self, forKey: .shotDismissed) == true {
                shot.stage = .dismissed
            } else {
                shot.stage = .failed("Not finished before the app was closed. Please attach it again.")
            }
            self.shot = shot
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(question, forKey: .question)
        try c.encode(scope, forKey: .scope)
        try c.encodeIfPresent(inHand, forKey: .inHand)
        try c.encode(seen, forKey: .seen)
        try c.encode(refs, forKey: .refs)
        if !drafted.isEmpty { try c.encode(drafted, forKey: .drafted) }
        if !dismissedCards.isEmpty { try c.encode(dismissedCards, forKey: .dismissedCards) }
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(matter, forKey: .matter)
        try c.encode(applied, forKey: .applied)
        try c.encode(readAs, forKey: .readAs)
        switch state {
        case .answered(let answer): try c.encode(answer, forKey: .answer)
        case .failed(let message): try c.encode(message, forKey: .failed)
        case .asking: break
        }
        if let shot {
            try c.encode(shot.file, forKey: .shotFile)
            try c.encode(shot.copied, forKey: .shotCopied)
            try c.encodeIfPresent(shot.document, forKey: .shotDocument)
            switch shot.stage {
            case .taken(let name, let into):
                try c.encode(name, forKey: .shotTaken)
                try c.encodeIfPresent(into, forKey: .shotTakenInto)
            case .dismissed: try c.encode(true, forKey: .shotDismissed)
            default: break
            }
        }
    }
}

extension Notification.Name {
    /// iCloud brought changes in: the assistant's thread may have new or changed turns.
    static let threadMayHaveChanged = Notification.Name("matterbee.threadMayHaveChanged")
    /// Help → Introduction to Matterbee.
    static let showIntro = Notification.Name("matterbee.showIntro")
    /// Matterbee → Set Up Matterbee …
    static let showSetup = Notification.Name("matterbee.showSetup")
}
