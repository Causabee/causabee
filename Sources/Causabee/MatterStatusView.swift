import AppKit
import CryptoKit
import EventKit
import MatterCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// C2 · a matter's status: the place to drill down. What is open and whose, the dates, the
/// people, and the history — every row with a door back into the assistant.
struct MatterStatusView: View {
    /// "1 deadline open", "2 deadlines open".
    static func deadlinesOpen(_ count: Int) -> String { "\(count) \(count == 1 ? "deadline" : "deadlines") open" }
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var showsDone = false
    @State private var showsInfos = false
    @State private var writingSummary = false
    @State private var showsSmallImages = false
    @State private var showsHidden = false
    /// Writing the notes, and what is written so far — its own text, so the cursor stays put.
    @State private var writingNote = false
    /// The new mails of a closed matter, being made a matter of their own: the name the owner gives it.
    @State private var splitting = false
    @State private var newMatterName = ""
    @State private var askingStep = false
    @AppStorage(AutoMode.key) private var auto = false
    @State private var addingLink = false
    /// A task the owner is writing with "+ Task": in the matter while its popover is open, taken
    /// out again if it is left without words.
    @State private var newTodo: Todo?
    @State private var addingFile = false
    /// The owner's reminders, read when the matter opens and again when Reminders changes.
    @State private var reminders: [Calendars.Reminder] = []
    @State private var calendarTick = 0
    @State private var searchingLinks: String?
    @State private var showsSuggestions = true
    @State private var stepError: String?
    /// Per file: fetching it, or why it could not be.
    @State private var fetching: [PersistentIdentifier: String] = [:]
    @State private var summaryError: String?
    @State private var showsPast = false
    @State private var merging: (Party, Party)?
    /// This matter and the one it is to go into, from the bar's ⋯.
    @State private var mergingMatter: (Matter, Matter)?
    @Query(sort: \Matter.name) private var allMatters: [Matter]
    /// Why the matter could not be written out, said once.
    @State private var exportFailure: String?
    @State private var asksToClose = false
    /// Renaming, and the name so far — its own text, so the cursor stays put.
    @State private var renaming = false
    @State private var newName = ""
    /// Where the cursor is while renaming: at the end, nothing selected.
    @State private var nameSelection: TextSelection?
    @FocusState private var naming: Bool
    @Query private var profiles: [Profile]
    /// The to-do "überfällig" pointed at, marked for a moment when the matter opens.
    @State private var marked: PersistentIdentifier?
    /// Every conversation shown, not only the newest: a source pointed at an older mail.
    @State private var showsAllHistory = false
    /// The page under what stands on top: what is to do, the record, or the people.
    enum Part: String { case todo, record, people, notes }
    /// The record, whole or one kind of it.
    enum RecordFilter: String { case all, mail, files, details, links }
    // `--demo --shot lisbon-files`: the picture of the files is of the record's files.
    @State private var part: Part = [.lisbonFiles, .careDetails, .lisbonRecord].contains(IntroShot.current) ? .record : [.carePeople, .careContact].contains(IntroShot.current) ? .people : .todo
    @State private var filter: RecordFilter = IntroShot.current == .lisbonFiles ? .files : IntroShot.current == .careDetails ? .details : .all
    /// One person's part of the record: chosen in "People".
    @State private var person: PersistentIdentifier?
    /// ⌘F on this page.
    @State private var find = PageFind()
    /// The page has gone up under the title bar: the bar turns to glass, with a line under it.
    @State private var scrolledUnder = false
    @State private var choosingIcon = false
    @State private var addingContact = IntroShot.current == .careContact
    @State private var addingDetail = false
    /// The parts in the page have scrolled under the title bar, which shows them then.
    @State private var partsUnder = false
    @State private var partsEdge = CGFloat.infinity
    /// How much of the page is seen under the title bar.
    @State private var pageHeight = CGFloat.zero
    @State private var barEdge = CGFloat.zero
    @Environment(\.reading) private var reading

    var body: some View {
        // What came from another device shows at once: an arriving change redraws the page.
        let _ = StoredChanges.shared.count
        let status = MatterStatus(matter)
        // Read once per drawing, for both cost estimates: the last 40 mails of the matter.
        let facts = summaryFacts
        VStack(spacing: 0) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        closedBanner(status)
                        if !matter.isClosed { nextStep(status, facts) }
                        summary(facts)
                        if find.isActive {
                            // Searching looks into every part, so everything is on the page.
                            todos(status).id("tasks")
                            dates(status)
                            files.id("files")
                            links.id("links")
                            parties(status)
                            notesPart.id("notes")
                            history(status)
                        } else {
                            parts(status).id("parts")
                                // Under the title bar the bar has them: these do not show through its glass.
                                .opacity(partsUnder ? 0 : 1)
                                // Its lower edge, to know when it has gone under the title bar.
                                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { partsEdge = $0 }
                            // At least as tall as the page shows: a short part does not pull the
                            // page down, and the parts stay where they were clicked.
                            VStack(alignment: .leading, spacing: 22) {
                                switch part {
                                case .todo:
                                    todos(status).id("tasks")
                                    dates(status)
                                case .record:
                                    record(status)
                                case .people:
                                    parties(status)
                                case .notes:
                                    notesPart.id("notes")
                                }
                            }
                            // As tall as the page shows, so its top can stand right under the title bar
                            // with the parts above it out of sight — and the ones in the bar stay.
                            .frame(maxWidth: .infinity, minHeight: max(0, pageHeight - 24), alignment: .topLeading)
                            .id("part")
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                // The name and the search stay on top while the page scrolls under them.
                .safeAreaInset(edge: .top, spacing: 0) { titleBar(status) }
                // What the page shows under the title bar: the container's size is already without the bar.
                .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { pageHeight = $1 }
                // Another part chosen in the title bar: it is shown from its start, not from where the last one was read.
                .onChange(of: part) { if partsUnder { scroller.scrollTo("part", anchor: .top) } }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 1 } action: { _, under in
                    withAnimation(.easeOut(duration: 0.15)) { scrolledUnder = under }
                }
                .onPreferenceChange(PageFindMatches.self) { found in
                    MainActor.assumeIsolated {
                        find.matches = found
                        if find.index >= found.count { find.index = 0 }
                    }
                }
                .onChange(of: find.query) { find.index = 0 }
                .onChange(of: find.current) { if let at = find.current { withAnimation { scroller.scrollTo(at, anchor: .center) } } }
                .onChange(of: matter.persistentModelID) { find.query = ""; showsAllHistory = false; person = nil; filter = .all }
                // `--demo --shot`: the part of the page the introduction's picture shows.
                .onAppear {
                    if let section = IntroShot.current?.section {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { scroller.scrollTo(section, anchor: .top) }
                    }
                }
                // A link dragged from the browser onto the matter is kept in it.
                // A file from the Finder becomes one of its files.
                .dropDestination(for: URL.self) { urls, _ in
                    let files = urls.filter(\.isFileURL)
                    if !files.isEmpty { addFiles(files) }
                    let web = urls.filter { !$0.isFileURL }.compactMap { WebLink.address(in: $0.absoluteString) }
                    for address in web { addLink(address, title: "", todo: nil) }
                    return !web.isEmpty || !files.isEmpty
                }
                .onAppear { show(navigation.showing, with: scroller); loadCalendars() }
                // The Matter menu: the section scrolled to, then what adds to it opened.
                .onReceive(NotificationCenter.default.publisher(for: .matterAction)) { note in
                    guard let action = (note.object as? String).flatMap(MatterAction.init) else { return }
                    let section = switch action {
                    case .newTask: "tasks"; case .writeNote: "notes"; case .addFile: "files"; case .addLink: "links"
                    case .addContact: "people"; case .addDetail: "details"
                    }
                    switch action {
                    case .newTask: part = .todo
                    case .addFile: part = .record; filter = .files
                    case .addLink: part = .record; filter = .links
                    case .addDetail: part = .record; filter = .details
                    case .addContact: part = .people
                    case .writeNote: part = .notes
                    }
                    withAnimation { scroller.scrollTo(section, anchor: .top) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        switch action {
                        case .newTask: addTodo()
                        case .writeNote: writingNote = true
                        case .addFile: addingFile = true
                        case .addLink: addingLink = true
                        case .addContact: addingContact = true
                        case .addDetail: addingDetail = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in loadCalendars() }
                .onChange(of: navigation.showing) { show(navigation.showing, with: scroller) }
                .sheet(isPresented: $addingContact) { ContactEditor(matter: matter) }
                .sheet(isPresented: $addingDetail) { DetailEditor(matter: matter) }
            }
        }
        .environment(find)
        .focusedSceneValue(\.openMatter, matter.persistentModelID)
        .navigationTitle(matter.name)
        .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
            Button("Merge") {
                if let (party, other) = merging { confirmSame(party, as: other) }
            }
            Button("Cancel", role: .cancel) { merging = nil }
        } message: {
            Text("This also counts for the next mail. You can undo it in the rules.")
        }
        .confirmationDialog(mergingMatter.map { "Merge “\($0.0.name)” into “\($0.1.name)”?" } ?? "",
                            isPresented: Binding(get: { mergingMatter != nil }, set: { if !$0 { mergingMatter = nil } })) {
            Button("Merge") {
                if let (from, into) = mergingMatter {
                    into.absorb(from, in: context)
                    try? context.save()
                    navigation.open(into)
                }
                mergingMatter = nil
            }
            Button("Cancel", role: .cancel) { mergingMatter = nil }
        } message: {
            Text("All mails, tasks, appointments and people come along. The old name stays as an alias, so new mail still arrives. You cannot split it again later.")
        }
        .alert("The matter could not be exported", isPresented: Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })) {
            Button("OK") { exportFailure = nil }
        } message: { Text(exportFailure ?? "") }
        .confirmationDialog(closeQuestion, isPresented: $asksToClose) {
            if matter.openTodos.isEmpty {
                Button("Close") { close(markingOpenDone: false) }
            } else {
                Button("Mark all done and close") { close(markingOpenDone: true) }
                Button("Leave them open and close") { close(markingOpenDone: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The matter goes away from the list and from the assistant. Nothing is deleted, and “Open again” brings it back.")
        }
    }

    // MARK: Summary

    private var summaryFacts: Facts { FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), mails: 40) }

    /// Three or four lines on top, written only when asked for, and dated.
    @ViewBuilder
    private func summary(_ facts: Facts) -> some View {
        let _ = AutoUpdate.shared.done
        let cost = String(format: "≈ %.1f cents", AssistantAsk.summaryEstimate(facts, model: ModelChoice.assistant) * 100)
        VStack(alignment: .leading, spacing: 10) {
            if let text = matter.summary, !text.isEmpty {
                HStack(spacing: 8) {
                    BeeChip(text: "SUMMARY")
                    // With Auto on it is kept up to date, and has no day to go by: "Auto mode" stands under it.
                    if let at = matter.summaryAt, !auto { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(Array(text.split(separator: "\n").enumerated()), id: \.offset) { index, line in
                    Text(String(line)).fixedSize(horizontal: false, vertical: true)
                        .findable(.section("summary-\(index)"), String(line))
                }
            }
            // Update below on the left, like "Suggest better"; with no summary yet, the button on the right.
            HStack(spacing: 10) {
                if writingSummary || AutoUpdate.shared.working.contains(matter.key) {
                    BeeLoader(size: 10)
                    Text("Writing the summary …").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if matter.summaryAt != nil, auto {
                    AutoLine(matter: matter)
                    Spacer()
                } else if matter.summaryAt != nil {
                    Button("Update · \(cost)", action: writeSummary)
                        .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Spacer()
                    Button("Write summary · \(cost)", action: writeSummary)
                        .help("Causabee writes three or four lines from the facts of this matter, pseudonymised.")
                }
            }
            .tool()
            if let summaryError { Text(summaryError).font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled) }
        }
        .padding(matter.summary == nil ? 0 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(matter.summary == nil ? Color.clear : Theme.box, in: RoundedRectangle(cornerRadius: 10))
    }

    private func writeSummary() {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { summaryError = ModelChoice.missingKey(model); return }
        writingSummary = true
        summaryError = nil
        let facts = summaryFacts
        let owner = profiles.first?.names.first
        let mapping = navigation.mapping
        Task {
            do {
                let (lines, _) = try await AssistantAsk.summarize(facts: facts, owner: owner, today: MatterStatus.day(Date()),
                                                                  mapping: mapping, claude: claude, model: model)
                matter.summary = lines.joined(separator: "\n")
                matter.summaryAt = Date()
                try? context.save()
            } catch {
                summaryError = plainWords(error)
            }
            writingSummary = false
        }
    }

    // MARK: Next step

    /// C2 · the one thing to do now, and why. Worked out on the Mac for nothing; Claude's
    /// suggestion, asked for with a click, is shown instead while nothing has changed since.
    @ViewBuilder
    private func nextStep(_ status: MatterStatus, _ facts: Facts) -> some View {
        // Drawn again when Auto has written it.
        let _ = AutoUpdate.shared.done
        let rule = status.nextStep
        let fresh = matter.nextStep != nil && matter.nextStepAt.map { at in (matter.lastChange ?? .distantPast) <= at } == true
        let cost = String(format: "≈ %.1f cents", AssistantAsk.nextStepEstimate(facts, model: ModelChoice.assistant) * 100)
        VStack(alignment: .leading, spacing: 10) {
            if fresh, let step = matter.nextStep {
                BeeChip(text: "NEXT · FROM CAUSABEE")
                Text(step).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), step, matter.nextStepWhy)
                if let why = matter.nextStepWhy { Text(why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() }
            } else if let rule {
                BeeChip(text: rule.label.uppercased(), tone: rule.kind == .overdue || rule.kind == .followUp ? .warning : .bee)
                Text(rule.text).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), rule.text, rule.why)
                Text(rule.why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation()
            } else {
                Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Nothing open.").foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if fresh, let step = matter.nextStep {
                    let todo = matter.nextStepTodo.flatMap { origin in matter.openTodos.first { $0.origin == origin } }
                    stepButtons(text: step, todo: todo, waiting: todo?.owner == .other)
                } else if !fresh, let rule, let id = rule.todo, let todo = matter.openTodos.first(where: { $0.persistentModelID == id }) {
                    stepButtons(text: todo.text, todo: todo, waiting: rule.kind == .followUp || rule.kind == .wait)
                }
                Spacer()
            }
            .tool()
            // Asking Claude, below the buttons on the left: apart from what the step itself offers.
            HStack(spacing: 10) {
                if askingStep || AutoUpdate.shared.working.contains(matter.key) {
                    BeeLoader(size: 10)
                    Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary)
                } else if auto {
                    // Auto asks: no link to ask with, and no price to weigh.
                    AutoLine(matter: matter)
                } else {
                    // An older suggestion says only its day; the link beside it says what to do.
                    if let at = matter.nextStepAt, matter.nextStep != nil, !fresh {
                        Text("From \(Dates.short(at)) ·").font(.caption).foregroundStyle(.secondary)
                            .help("Causabee suggested this on \(Dates.short(at)); the matter has changed since.")
                    }
                    Button((fresh ? "ask again · " : "Suggest better · ") + cost, action: askStep)
                        .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                        .help("Causabee reads the facts of this matter with your notes, pseudonymised, and suggests a step with a reason.")
                }
                Spacer()
            }
            .tool()
            if let stepError { Text(stepError).font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 10))
    }

    /// What can be done with the step right here: write the message it is, tick it off, see it.
    @ViewBuilder
    private func stepButtons(text: String, todo: Todo?, waiting: Bool) -> some View {
        if waiting {
            Button("Write follow-up") {
                navigation.prefill = "Write a short, friendly follow-up about this."
                talk(todo?.text ?? text, todo == nil ? "Step" : "Task")
            }
            .inkButton().fixedSize()
            .help("Puts the task into the assistant and writes the request for you. Nothing is sent until you press Return.")
        } else if Todo.isMessage(text) || todo?.isMessage == true {
            Button("Write message") {
                navigation.prefill = "Write a short message about this."
                talk(todo?.text ?? text, todo == nil ? "Step" : "Task")
            }
            .inkButton().fixedSize()
            .help("Puts the task into the assistant and writes the request for you. Nothing is sent until you press Return; the draft opens in Mail.")
        }
        if let todo {
            if !waiting { Button("Done") { withAnimation { toggle(todo) } }.fixedSize() }
            Button("Show") { navigation.showing = todo.persistentModelID }.fixedSize()
        } else if !waiting, !Todo.isMessage(text) {
            Button("Talk it over") { talk(text, "Step") }
                .help("Puts the step into the assistant, to talk it over or to make a task from it.")
        }
    }

    private func askStep() {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { stepError = ModelChoice.missingKey(model); return }
        askingStep = true
        stepError = nil
        let facts = summaryFacts
        let owner = profiles.first?.names.first
        let mapping = navigation.mapping
        Task {
            do {
                let (step, why, ref, _) = try await AssistantAsk.nextStep(facts: facts, owner: owner, today: MatterStatus.day(Date()),
                                                                          mapping: mapping, claude: claude, model: model)
                matter.nextStep = step
                matter.nextStepWhy = why
                if case .todo(let id) = ref { matter.nextStepTodo = (matter.todos ?? []).first { $0.persistentModelID == id }?.origin }
                else { matter.nextStepTodo = nil }
                matter.nextStepAt = Date()
                try? context.save()
            } catch {
                stepError = plainWords(error)
            }
            askingStep = false
        }
    }

    // MARK: Notes

    /// The owner's own words on the matter: small dated blocks, read by the assistant too.
    private var notesPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            NotesPart(matter: matter, writing: $writingNote)
        }
    }

    // MARK: Files

    private var conversation: Conversation {
        Conversation(context: context, navigation: navigation, owner: profiles.first?.names.first)
    }

    private static var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Causabee/Anhänge", isDirectory: true)
    }

    /// C2 · the files: what was attached to the matter's mail, each to open, and a PDF or a picture
    /// to read. A logo in a signature is not a file anyone attached, and is hidden.
    @ViewBuilder
    private var files: some View {
        let all = (matter.documents ?? []).sorted {
            let (a, b) = ($0.source.date ?? .distantPast, $1.source.date ?? .distantPast)
            return a != b ? a > b : alphabetically($0.name, $1.name)
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
                    if !all.isEmpty {
                        Button { addingFile = true } label: { Label("File", systemImage: "plus") }
                            .buttonStyle(.borderless).font(.caption)
                            .help("Add a PDF, a scan or any file from this Mac — or drag it onto the matter")
                    }
                    if MatterFolders.root != nil {
                        Button { if let folder = MatterFolders.folder(for: matter) { try? context.save(); FolderSaver.reveal(folder) } } label: {
                            Label("Folder", systemImage: "folder")
                        }
                        .buttonStyle(.borderless).font(.caption)
                        .tool()
                        .help("This matter's folder in iCloud Drive → Causabee")
                    }
                }
                .fileImporter(isPresented: $addingFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                    if case .success(let files) = result { addFiles(files) }
                }
                if all.isEmpty {
                    EmptyBox(text: "A letter, a scan, a PDF — or drag it here from the Finder. Files in mail come by themselves.",
                             action: "Add File", symbol: "doc.badge.plus") { addingFile = true }
                }
                if !shown.isEmpty {
                    Card {
                        ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, document in
                            if index > 0 { RowDivider() }
                            DocumentRow(document: document, sender: sender(of: document), state: fetching[document.persistentModelID],
                                        open: { fetch(document, then: { NSWorkspace.shared.open($0) }) },
                                        read: { fetch(document, then: { conversation.bring($0, document: document) }) },
                                        hide: { setHidden(document, !document.isHidden) },
                                        nameIt: { nameFromContent(document) },
                                        talk: { talk(document.shownName, "File") })
                                .findable(.model(document.persistentModelID), document.shownName, document.name, sender(of: document))
                        }
                    }
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
                .buttonStyle(.gold).font(.caption).padding(.horizontal, 4)
                }
        }
    }

    /// Files from this Mac, copied in beside the store so they stay when the originals move, each
    /// a file of the matter — and into its iCloud Drive folder, when there is one.
    private func addFiles(_ files: [URL]) {
        let folder = ScreenshotDoor.attachments(besides: navigation.store)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in files {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            let target = folder.appendingPathComponent(UUID().uuidString.prefix(8) + "-" + file.lastPathComponent)
            guard (try? FileManager.default.copyItem(at: file, to: target)) != nil else { continue }
            let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let type = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let source = Source(kind: .document, pointer: target.path, messageID: "file-" + UUID().uuidString, date: Date())
            let document = MatterCore.Document(name: file.lastPathComponent, contentType: type, byteCount: size, source: source)
            context.insert(document)
            document.matter = matter
        }
        try? context.save()
        FolderSaver.shared.save([matter])
    }

    // MARK: Calendar and Reminders

    private func loadCalendars() {
        Task {
            reminders = await Calendars.shared.allReminders()
            calendarTick += 1
        }
    }

    // MARK: Links

    /// The owner's links — a Google Doc, a sheet — each opened in the browser on a click. The
    /// app never opens them itself, and the assistant only hears their names.
    @ViewBuilder
    private var links: some View {
        let all = (matter.links ?? []).filter(\.isKept).sorted(by: newestFirst)
        let offered = (matter.links ?? []).filter { $0.isSuggestion && !$0.isDismissed }.sorted(by: newestFirst)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Links", detail: all.isEmpty ? nil : "\(all.count)")
                if !all.isEmpty {
                    Button { addingLink = true } label: { Label("Link", systemImage: "plus") }
                        .buttonStyle(.borderless).font(.caption)
                        .help("Paste a link — or drag it from the browser onto the matter")
                }
            }
            .popover(isPresented: $addingLink, arrowEdge: .bottom) {
                LinkEditor(link: nil, todos: matter.openTodos) { address, title, todo in
                    addLink(address, title: title, todo: todo)
                    addingLink = false
                } cancel: { addingLink = false }
            }
            if !all.isEmpty {
                Card {
                    ForEach(Array(all.enumerated()), id: \.element.persistentModelID) { index, link in
                        if index > 0 { RowDivider() }
                        LinkRow(link: link, todos: matter.openTodos) { remove(link) }
                            .findable(.model(link.persistentModelID), link.shownName, link.address)
                    }
                }
            } else if offered.isEmpty {
                EmptyBox(text: "A Google Doc, a sheet — or drag it here from the browser.",
                         action: "Add Link", symbol: "link.badge.plus") { addingLink = true }
            }
            if !offered.isEmpty, !reading {
                DisclosureGroup(isExpanded: open($showsSuggestions)) {
                    Card {
                        ForEach(Array(offered.enumerated()), id: \.element.persistentModelID) { index, link in
                            if index > 0 { RowDivider() }
                            SuggestedLinkRow(link: link, mail: (matter.entries ?? []).first { $0.messageID == link.messageID }) {
                                withAnimation { link.isSuggestion = false }
                                try? context.save()
                            } dismiss: {
                                withAnimation { link.isSuggestion = false; link.isDismissed = true }
                                try? context.save()
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("From the mails · \(offered.count) \(offered.count == 1 ? "suggestion" : "suggestions")").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 8) {
                if let searchingLinks {
                    if searchingLinks.hasSuffix("…") { ProgressView().controlSize(.small) }
                    Text(searchingLinks).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if searchingLinks?.hasSuffix("…") != true, !(matter.entries ?? []).isEmpty {
                    Button(matter.linksSearchedAt == nil ? "Look for links in the mails" : "Look in the mails again", action: searchLinks)
                        .buttonStyle(.gold).font(.caption)
                        .tool()
                        .help("Reads the \((matter.entries ?? []).count) mails of this matter again from Gmail, only reading, and suggests the important links. Costs nothing, sends nothing.")
                    if let at = matter.linksSearchedAt, searchingLinks == nil {
                        Text("last on \(Dates.short(at))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Reads the matter's mails again — read-only, over one connection — and offers what links
    /// in them matter. Free: nothing leaves the Mac but the reading itself.
    private func searchLinks() {
        guard let account = Keychain.accounts().first else {
            searchingLinks = "No mail account saved. Choose Causabee → Set Up Causabee … to add one."
            return
        }
        let mails = (matter.entries ?? []).filter { $0.source.pointer.hasPrefix("imap://") && !$0.messageID.isEmpty }
            .map { (pointer: $0.source.pointer, id: $0.messageID) }
        searchingLinks = "Reading 0 of \(mails.count) mails …"
        Task {
            var found = 0, missing = 0
            do {
                guard let password = try await MailSecret.secret(for: account) else { throw MailFetch.Failure.gone(account.user) }
                let client = try await IMAPClient.connect(to: account, password: password)
                for (index, mail) in mails.enumerated() {
                    searchingLinks = "Reading \(index + 1) of \(mails.count) mails …"
                    guard let data = try? await MailFetch.message(pointer: mail.pointer, messageID: mail.id, from: client) else { missing += 1; continue }
                    let email = EMLParser.parse(data: data, url: URL(string: mail.pointer) ?? URL(fileURLWithPath: "/"))
                    found += MailLinks.suggest(email.links, messageID: mail.id, to: matter, in: context)
                }
                await client.logout()
                matter.linksSearchedAt = Date()
                try? context.save()
                searchingLinks = (found == 0 ? "No new important links found." : "\(found) \(found == 1 ? "link" : "links") suggested.")
                    + (missing > 0 ? " \(missing) \(missing == 1 ? "mail is" : "mails are") no longer in the mailbox." : "")
            } catch {
                searchingLinks = plainWords(error)
            }
        }
    }

    /// "+ Task": an empty task of the owner's, opened in the editor.
    /// The matter as one RTF document in its folder — iCloud Drive › Causabee › the matter — shown in
    /// Finder. The demo's goes to a temporary folder, never among the owner's files.
    private func export() {
        do {
            try? context.save()
            let file = try MatterExport.write(matter, into: DemoData.isRequested ? nil : MatterFolders.folder(for: matter))
            FolderSaver.reveal(file)
        } catch {
            exportFailure = error.localizedDescription
        }
    }

    private func addTodo() {
        let todo = Todo(text: "", owner: .me, due: nil, source: Source(kind: .conversation, pointer: "you", date: Date()),
                        origin: "you#" + UUID().uuidString)
        context.insert(todo)
        todo.matter = matter
        newTodo = todo
    }

    /// The new task closed without words: it was never there.
    private func dropNewTodo() {
        guard let todo = newTodo else { return }
        newTodo = nil
        if todo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { context.delete(todo); try? context.save() }
    }

    private func addLink(_ address: String, title: String, todo: Todo?) {
        guard !(matter.links ?? []).contains(where: { $0.address == address && $0.todo === todo }) else { return }
        let link = WebLink(address: address, title: title)
        context.insert(link)
        link.matter = matter
        link.todo = todo
        try? context.save()
    }

    private func remove(_ link: WebLink) {
        withAnimation { context.delete(link) }
        try? context.save()
    }

    /// Off the list or back on it. Nothing is deleted: the file lives in its mail.
    /// A readable name from the file's first page — read on the Mac, from the cache or the mail.
    private func nameFromContent(_ document: MatterCore.Document) {
        let id = document.persistentModelID
        fetch(document) { url in
            if let title = DocumentTitle.from(pdf: url) {
                withAnimation { document.title = title }
                try? context.save()
                fetching[id] = nil
            } else {
                fetching[id] = "No heading found in it — give it a name with ⋯ → Rename."
            }
        }
    }

    private func setHidden(_ document: MatterCore.Document, _ hidden: Bool) {
        withAnimation { document.isHidden = hidden }
        try? context.save()
    }

    private func sender(of document: MatterCore.Document) -> String? {
        (matter.entries ?? []).first { $0.messageID == document.messageID }.map { Email.displayName(in: $0.from) ?? Email.address(in: $0.from) }
    }

    /// Takes the file out of its mail — read-only, only this one mail — and hands it on.
    private func fetch(_ document: MatterCore.Document, then use: @escaping @MainActor (URL) -> Void) {
        // A file the owner dropped in — a scanned letter — is the file itself, on this Mac.
        if document.isOwnFile {
            if let file = document.source.fileURL { use(file) } else if let kept = MatterFolders.kept(document) {
                // Brought in on the iPhone, and put into the matter's folder in iCloud Drive there.
                let id = document.persistentModelID
                fetching[id] = "Getting the file from the matter's folder …"
                Task {
                    do { let url = try await MatterFolders.fetched(kept); fetching[id] = nil; use(url) } catch { fetching[id] = plainWords(error) }
                }
            } else {
                fetching[document.persistentModelID] = document.source.addedOn == "your Mac"
                    ? "The file is not on this Mac: \(document.source.pointer)"
                    : "Added on your iPhone: the file is only there. What it said is here."
            }
            return
        }
        // From a mail dropped in as a file: straight out of that file, no mail server.
        if let file = document.source.fileURL, let data = try? Data(contentsOf: file),
           let bytes = EMLParser.attachment(named: document.name, in: data) {
            // Named by a digest of the mail's id, the same on every launch — `hashValue` changes with
            // each start, so the cache was never found again and grew without end.
            let digest = SHA256.hash(data: Data(document.messageID.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
            let folder = Self.cache.appendingPathComponent(digest, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent(document.name.replacingOccurrences(of: "/", with: "-"))
            if (try? bytes.write(to: target, options: .atomic)) != nil { use(target); return }
        }
        guard let account = Keychain.accounts().first else {
            fetching[document.persistentModelID] = "No mail account saved. Choose Causabee → Set Up Causabee … to add one."
            return
        }
        let id = document.persistentModelID
        let (name, pointer, messageID) = (document.name, document.source.pointer, document.messageID)
        fetching[id] = "Getting the file from the mail …"
        Task {
            do {
                guard let password = try await MailSecret.secret(for: account) else { throw MailFetch.Failure.gone(messageID) }
                let url = try await MailFetch.file(name, pointer: pointer, messageID: messageID, account: account,
                                                   password: password, cache: Self.cache)
                fetching[id] = nil
                use(url)
            } catch {
                fetching[id] = plainWords(error)
            }
        }
    }

    // MARK: Asking

    /// "reden" puts the row in hand and the cursor in the assistant's field on the left. The
    /// matter stays where it is.
    private func talk(_ text: String, _ kind: String) {
        navigation.pin(text, kind: kind, in: matter)
        navigation.focusRequest += 1
    }

    /// Scrolls to the to-do "überfällig" pointed at, and marks it for a moment.
    private func show(_ todo: PersistentIdentifier?, with scroller: ScrollViewProxy) {
        guard let todo else { return }
        navigation.showing = nil
        marked = todo
        find.shown = todo
        // The part of the page it is in, with nothing filtered away.
        if (matter.todos ?? []).contains(where: { $0.persistentModelID == todo })
            || (matter.appointments ?? []).contains(where: { $0.persistentModelID == todo })
            || (matter.deadlines ?? []).contains(where: { $0.persistentModelID == todo }) {
            part = .todo
        } else if matter.parties.contains(where: { $0.persistentModelID == todo }) {
            part = .people
        } else {
            part = .record; filter = .all; person = nil
        }
        // What is folded away — done, past, an old conversation — is unfolded for it.
        if (matter.todos ?? []).contains(where: { $0.persistentModelID == todo && $0.isDone }) { showsDone = true }
        if matter.infos.contains(where: { $0.persistentModelID == todo }) { showsInfos = true }
        let today = MatterStatus(matter).today
        if (matter.appointments ?? []).contains(where: { $0.persistentModelID == todo && $0.day < today })
            || (matter.deadlines ?? []).contains(where: { $0.persistentModelID == todo && $0.day < today }) { showsPast = true }
        if (matter.entries ?? []).contains(where: { $0.persistentModelID == todo }) { showsAllHistory = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { scroller.scrollTo(todo, anchor: .center) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { if marked == todo { marked = nil }; if find.shown == todo { find.shown = nil } } }
    }

    private var closeQuestion: String {
        let open = matter.openTodos.count
        return open == 0 ? "Close “\(matter.name)”?"
            : "Close “\(matter.name)”? \(open) \(open == 1 ? "task is" : "tasks are") still open."
    }

    private func startRenaming() {
        newName = matter.name
        nameSelection = TextSelection(insertionPoint: newName.endIndex)
        renaming = true
        naming = true
    }

    private func rename() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = false
        guard !name.isEmpty, name != matter.name else { return }
        matter.rename(to: name)
        try? context.save()
    }

    private func close(markingOpenDone: Bool) {
        matter.close(markingOpenDone: markingOpenDone)
        try? context.save()
    }

    // MARK: Header

    @ViewBuilder
    private func closedBanner(_ status: MatterStatus) -> some View {
            if let closed = matter.closedAt {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Closed on \(Dates.short(closed))").font(.callout.weight(.semibold))
                        let new = status.mailsSinceClosed.count
                        if new > 0 {
                            Text("\(new) new \(new == 1 ? "mail" : "mails") since closing").font(.callout).foregroundStyle(Theme.warning)
                        }
                    }
                    Spacer()
                    if !status.mailsSinceClosed.isEmpty {
                        Button("Start a new matter") {
                            newMatterName = Matter.suggestedName(for: status.mailsSinceClosed)
                            splitting = true
                        }
                        .help("The new mails, with what they brought, become a matter of their own; this one stays closed")
                        .popover(isPresented: $splitting, arrowEdge: .bottom) { splitForm(status) }
                    }
                    Button("Open again") { matter.reopen(); try? context.save() }
                }
                .padding(20)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
    }

    /// Mail the model filed under this closed matter, when the owner meant a new one: a name, and it goes.
    private func splitForm(_ status: MatterStatus) -> some View {
        let count = status.mailsSinceClosed.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("A new matter with the \(count) new \(count == 1 ? "mail" : "mails")").font(.headline)
            Text("Their tasks, dates, files and links go with them. “\(matter.name)” stays closed.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Name", text: $newMatterName).textFieldStyle(.roundedBorder).onSubmit(startNewMatter)
            HStack {
                Spacer()
                Button("Cancel") { splitting = false }.keyboardShortcut(.cancelAction)
                Button("Start", action: startNewMatter)
                    .keyboardShortcut(.defaultAction)
                    .disabled(newMatterName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private func startNewMatter() {
        let mails = MatterStatus(matter).mailsSinceClosed
        let name = newMatterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mails.isEmpty, !name.isEmpty,
              let new = try? matter.split(mails, intoNewMatterNamed: name, turnsSince: matter.closedAt, in: context) else { return }
        splitting = false
        navigation.open(new)
    }

    /// The name, how much mail and since when, the page search and Close: on glass, always on top.
    /// Where the bar's column begins in the window: at its left edge with the sidebar and the
    /// assistant put away, and then under the window's controls.
    @State private var barLeft: CGFloat = 400

    private func titleBar(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                // The matter's icon: a click chooses another.
                Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 30) }
                    .buttonStyle(.plain)
                    // Its middle on the middle of the name's capitals — 8 over the baseline at the
                    // system's size, more with the larger text.
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - (15 - 8 * Theme.textScale) }
                    .help("Choose another icon")
                    .popover(isPresented: $choosingIcon, arrowEdge: .bottom) { MatterIconPicker(matter: matter) }
                if renaming {
                    TextField("Name", text: $newName, selection: $nameSelection)
                        .font(Theme.titleFont)
                        .textFieldStyle(.plain)
                        .focused($naming)
                        .onSubmit(rename)
                        .onExitCommand { renaming = false }
                        // Clicking elsewhere keeps what was typed, as in Finder.
                        .onChange(of: naming) {
                            if !naming, renaming { rename(); return }
                            // macOS selects the whole name when the field takes the cursor; right
                            // after, the cursor goes to the end, so a first key adds, not replaces.
                            if naming {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    nameSelection = TextSelection(insertionPoint: newName.endIndex)
                                }
                            }
                        }
                    Button("Save", action: rename).keyboardShortcut(.defaultAction)
                    Button("Cancel") { renaming = false }
                } else {
                    Text(matter.name).font(Theme.titleFont)
                        .accessibilityIdentifier("matter.title")
                        .onTapGesture(perform: startRenaming)
                        .pointerStyle(.horizontalText)
                        .help("Click to rename. The old name stays as an alias, so new mail still finds the matter.")
                    Spacer()
                }
                if !renaming {
                    // What the bar can do, on glass as a toolbar's: the search, the rest. The bee that
                    // brings the assistant back is by the window's buttons, on the left.
                    HStack(spacing: 8) {
                        // What is added goes in by the assistant's plus, beside its field: there is none here.
                        PageFindField(find: find)
                        // What is seldom needed sits behind the dots, not in the bar: what the sidebar's
                        // menu has for the matter, as the iPhone's ⋯ has it, and closing it.
                        Menu {
                            PinMenuItem(matter: matter, all: allMatters)
                            Button("Rename …", action: startRenaming)
                            Menu("Merge with …") {
                                // Only into a matter that is going on: a closed one is opened again first.
                                ForEach(allMatters.filter { $0 !== matter && !$0.isClosed }) { other in
                                    Button(other.name) { mergingMatter = (matter, other) }
                                }
                            }
                            // Everything the matter holds, as one document: what is gathered here can leave at any time.
                            Button("Export as RTF", systemImage: "square.and.arrow.up", action: export)
                            Divider()
                            if matter.isClosed {
                                Button("Open Again", systemImage: "arrow.uturn.backward") { matter.reopen(); try? context.save() }
                            } else {
                                Button("Close Matter…", systemImage: "archivebox") { asksToClose = true }
                            }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 30, height: 30).contentShape(Circle())
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                        .onGlass(Circle())
                        .help("More: pin, rename, merge with another matter, export, close")
                        .accessibilityLabel("More")
                        .accessibilityIdentifier("matter.more")
                        .tool()
                    }
                    // On the line of the window's controls, as the icon is: their middle eight over
                    // the name's baseline, which is the middle of its capitals.
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 8 * Theme.textScale }
                }
            }
            // Once the parts in the page have gone under this bar, they stay at hand here — in the place
            // of the count, so the bar keeps its height and the page under it does not jump.
            let showsParts = partsUnder && !find.isActive && !renaming
            ZStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(Self.count(matter.entries ?? []))
                    if let first = status.firstDate { Text("· since \(Dates.short(first))") }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .opacity(showsParts ? 0 : 1)
                parts(status).opacity(showsParts ? 1 : 0).allowsHitTesting(showsParts).accessibilityHidden(!showsParts)
            }
        }
        // One row with the window's buttons and Causabee's controls by them: where this page is the
        // window's first column, its name begins after the bee, not under it. The cards keep the margin.
        .padding(.leading, max(0, navigation.controlsEdge + 16 - (barLeft + 24)))
        .padding(.horizontal, 24)
        // The icon's middle and the name's capitals on the middle of the window's top line, as the
        // controls': 26 down. The larger text has its capitals' middle lower in its line, by what
        // the padding gives back — at a fifth larger the name sat three points under the controls.
        .padding(.top, 7 - 16.5 * (Theme.textScale - 1))
        .padding(.bottom, 12)
        .frame(maxWidth: 820, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { barLeft = $0 }
        .frame(maxWidth: .infinity)
        // At the top it is the page itself; once the page scrolls under it, glass and a line.
        .background(scrolledUnder ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
        .overlay(alignment: .bottom) { if scrolledUnder { Divider() } }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { barEdge = $0 }
        .onChange(of: partsEdge < barEdge) { _, under in
            withAnimation(.easeOut(duration: 0.15)) { partsUnder = under && scrolledUnder }
        }
        .onChange(of: scrolledUnder) { _, under in if !under { partsUnder = false } }
    }

    // MARK: To-dos

    /// Any task at all, open or done — a task being written with "+ Task" not yet among them.
    private var hasTodos: Bool { (matter.todos ?? []).contains { $0 !== newTodo } }

    @ViewBuilder
    private func todos(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Tasks", detail: hasTodos ? "\(matter.openTodos.count) open · \(status.done.count) done" : nil)
                // No "+ Task" here: a task of one's own is said to the assistant, from its plus, or
                // written from the menu — whose editor still opens at this line.
            }
            .popover(isPresented: Binding(get: { newTodo != nil }, set: { if !$0 { dropNewTodo() } }), arrowEdge: .bottom) {
                if let newTodo {
                    TodoEditor(todo: newTodo, done: { self.newTodo = nil; try? context.save() }, cancel: dropNewTodo, isNew: true)
                }
            }
            if !hasTodos {
                EmptyBox(text: "What is to do, and whose. Tasks in mail are found when it is sorted in.",
                         action: "Add Task", symbol: "checklist", run: addTodo)
            }
            // What is past its day first, whoever's it is; the groups below hold the rest.
            let overdue = status.overdue.sorted { ($0.due ?? "") < ($1.due ?? "") }
            let late = Set(overdue.map(\.persistentModelID))
            if !overdue.isEmpty {
                Text("Overdue · \(overdue.count)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.warning)
                    .padding(.horizontal, 4).padding(.top, 4)
                Card {
                    ForEach(Array(overdue.enumerated()), id: \.element.persistentModelID) { index, todo in
                        if index > 0 { RowDivider() }
                        TodoRow(todo: todo, today: status.today, showsOwner: true, info: { setInfo(todo, true) },
                                reminders: reminders, calendarTick: calendarTick) { toggle(todo) } talk: { talk(todo.text, "Task") }
                            .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                            .findable(.model(todo.persistentModelID), todo.text, todo.note)
                    }
                }
            }
            ForEach([(Todo.Owner.me, "Mine"), (.we, "Ours"), (.other, "Waiting for"), (.unknown, "Unclear whose")], id: \.1) { owner, title in
                let todos = status.open(owner).filter { !late.contains($0.persistentModelID) && !$0.isBlocked }
                if !todos.isEmpty {
                    Text("\(title) · \(todos.count)").font(.subheadline.weight(.semibold)).padding(.horizontal, 4).padding(.top, 4)
                    Card {
                        ForEach(Array(todos.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { RowDivider() }
                            TodoRow(todo: todo, today: status.today, info: todo.isDone ? nil : { setInfo(todo, true) },
                                    reminders: reminders, calendarTick: calendarTick) { toggle(todo) } talk: { talk(todo.text, "Task") }
                                .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                                .findable(.model(todo.persistentModelID), todo.text, todo.note)
                        }
                    }
                }
            }
            // What cannot be done yet, whoever's it is: under everything that can.
            let blocked = matter.openTodos.filter(\.isBlocked).sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
            if !blocked.isEmpty {
                Text("Only after · \(blocked.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.top, 4)
                    .help("Tasks that wait for another one. When that one is done, they move up.")
                Card {
                    ForEach(Array(blocked.enumerated()), id: \.element.persistentModelID) { index, todo in
                        if index > 0 { RowDivider() }
                        TodoRow(todo: todo, today: status.today, showsOwner: true, info: { setInfo(todo, true) }) { toggle(todo) } talk: { talk(todo.text, "Task") }
                            .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                            .findable(.model(todo.persistentModelID), todo.text, todo.note)
                    }
                }
            }
            let infos = matter.infos
            if !infos.isEmpty {
                DisclosureGroup("Info · \(infos.count)", isExpanded: open($showsInfos)) {
                    Card {
                        ForEach(Array(infos.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { RowDivider() }
                            InfoRow(todo: todo) { setInfo(todo, false) } talk: { talk(todo.text, "Info") }
                                .findable(.model(todo.persistentModelID), todo.text)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 4)
            }
            if !status.done.isEmpty {
                DisclosureGroup("Done · \(status.done.count)", isExpanded: open($showsDone)) {
                    Card {
                        ForEach(Array(status.done.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { RowDivider() }
                            TodoRow(todo: todo, today: status.today, info: todo.isDone ? nil : { setInfo(todo, true) }) { toggle(todo) } talk: { talk(todo.text, "Task") }
                                .findable(.model(todo.persistentModelID), todo.text, todo.note)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// A folded group stays open while the page is searched, so what it holds can be found.
    private func open(_ shown: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { shown.wrappedValue || find.isActive }, set: { shown.wrappedValue = $0 })
    }

    /// Not a to-do, only worth knowing — or a to-do after all. Nothing is deleted either way.
    private func setInfo(_ todo: Todo, _ isInfo: Bool) {
        withAnimation { todo.isInfo = isInfo }
        try? context.save()
    }

    private func toggle(_ todo: Todo) {
        todo.isDone.toggle()
        todo.doneAt = todo.isDone ? Date() : nil
        // Done by the owner's click, not by a mail: there is no mail to point at.
        if !todo.isDone { todo.doneSource = nil }
        try? context.save()
    }

    // MARK: Dates

    @ViewBuilder
    private func dates(_ status: MatterStatus) -> some View {
        let upcoming = status.upcomingAppointments, past = status.pastAppointments
        let deadlines = status.deadlines
        if upcoming.isEmpty && past.isEmpty && deadlines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appointments and deadlines")
                EmptyBox(text: "Appointments and deadlines are found in mail when it is sorted in. A task can have a day too.")
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appointments and deadlines", detail: "\(upcoming.count) coming · \(Self.deadlinesOpen(deadlines.filter { $0.day >= status.today }.count))")
                CalendarAccessBanner { loadCalendars() }.tool()
                Card {
                    let rows: [DateRow.Item] = upcoming.map(DateRow.Item.init) + deadlines.filter { $0.day >= status.today }.map(DateRow.Item.init)
                    ForEach(Array(rows.sorted { $0.day != $1.day ? $0.day < $1.day : DateRow.Item.sameDay($0, $1) }.enumerated()), id: \.offset) { index, item in
                        if index > 0 { RowDivider() }
                        DateRow(item: item, isPast: false, matterName: matter.name, tick: calendarTick, save: { try? context.save() }) { talk(item.what, item.kind) }
                            .findable(item.findID, item.what, item.place)
                    }
                    if rows.isEmpty {
                        Text("Nothing coming.").foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                let earlier: [DateRow.Item] = past.map(DateRow.Item.init) + deadlines.filter { $0.day < status.today }.map(DateRow.Item.init)
                if !earlier.isEmpty {
                    DisclosureGroup("Past · \(earlier.count)", isExpanded: open($showsPast)) {
                        Card {
                            ForEach(Array(earlier.sorted { $0.day != $1.day ? $0.day > $1.day : DateRow.Item.sameDay($0, $1) }.enumerated()), id: \.offset) { index, item in
                                if index > 0 { RowDivider() }
                                DateRow(item: item, isPast: true, matterName: matter.name, tick: calendarTick, save: { try? context.save() }) { talk(item.what, item.kind) }
                                    .findable(item.findID, item.what, item.place)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: Parties

    private var mergeQuestion: String {
        guard let (party, other) = merging else { return "" }
        return "Is “\(party.name)” the same as “\(other.name)”?"
    }

    @ViewBuilder
    private func parties(_ status: MatterStatus) -> some View {
        let memberships = status.memberships
        if memberships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "People")
                EmptyBox(text: "Who writes and who is named come in with mail and screenshots — or add a contact yourself.",
                         action: "Add Contact", symbol: "person.badge.plus") { addingContact = true }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "People", detail: "\(memberships.count) · to merge, drag one name onto another")
                    Button { addingContact = true } label: { Label("Contact", systemImage: "plus") }
                        .buttonStyle(.gold).font(.caption)
                        .tool()
                }
                let rules = (try? context.fetch(FetchDescriptor<Rule>())) ?? []
                let suggestions = PartyBook.suggestions(in: matter, rules: rules)
                if !suggestions.isEmpty {
                    SuggestionCard(suggestions: suggestions) { suggestion in
                        confirmSame(suggestion.party, as: suggestion.into)
                    } refuse: { suggestion in
                        PartyBook.refuseSame(suggestion.party, as: suggestion.into, in: matter, context: context, origin: origin)
                        try? context.save()
                    }
                    .tool()
                }
                Card {
                    ForEach(Array(memberships.enumerated()), id: \.element.persistentModelID) { index, membership in
                        if index > 0 { RowDivider() }
                        if let party = membership.party {
                            PartyRow(party: party, membership: membership, matter: matter, save: { name, role in
                                edit(party, membership: membership, name: name, role: role)
                            }, remove: {
                                withAnimation { membership.remove(in: context, origin: origin) }
                                try? context.save()
                            }) {
                                talk(party.name, "Person")
                            }
                            .findable(.model(party.persistentModelID), party.name, membership.role)
                            .contentShape(Rectangle())
                            .onTapGesture { person = party.persistentModelID; filter = .all; part = .record }
                            .help("Shows what \(party.name) wrote, in the record")
                            .draggable(party.name)
                            .contextMenu {
                                MailAddressItems(addresses: CardActions.addresses(of: party))
                                Menu("Merge with …") {
                                    ForEach(matter.parties.filter { $0 !== party }.sorted { $0.name < $1.name }) { other in
                                        Button(other.name) { merging = (party, other) }
                                    }
                                }
                                Button("Ask Causabee") { talk(party.name, "Person") }
                                Divider()
                                Button("Remove from this matter") {
                                    withAnimation { membership.remove(in: context, origin: origin) }
                                    try? context.save()
                                }
                                .help("Takes them out of this matter only. A later mail naming them will not put them back.")
                            }
                            .dropDestination(for: String.self) { names, _ in
                                guard let name = names.first, let dropped = matter.parties.first(where: { $0.name == name }),
                                      dropped !== party else { return false }
                                merging = (dropped, party)
                                return true
                            }
                        }
                    }
                }
            }
        }
    }

    private var origin: String {
        "you, in \(matter.name), \(Dates.short(Date()))"
    }

    /// By hand, and free: nothing is sent. A new name is kept as a rule, like one from the assistant.
    private func edit(_ party: Party, membership: Membership, name: String, role: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != party.name {
            let old = party.name
            party.rename(to: name)
            context.insert(Rule(.partyName, subject: old, object: name, matterKey: matter.key, origin: origin))
        }
        if role.trimmingCharacters(in: .whitespaces) != (membership.role ?? "") { membership.setRole(role) }
        try? context.save()
    }

    private func confirmSame(_ party: Party, as other: Party) {
        PartyBook.confirmSame(party, as: other, in: matter, context: context, origin: origin)
        try? context.save()
        merging = nil
    }

    // MARK: Parts

    private var shownDocuments: [MatterCore.Document] { (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage } }
    private var keptLinks: [WebLink] { (matter.links ?? []).filter(\.isKept) }
    private var personParty: Party? { person.flatMap { id in matter.parties.first { $0.persistentModelID == id } } }

    /// What is to do, the record, the people: the system's own segmented control.
    private func parts(_ status: MatterStatus) -> some View {
        Picker("Part of the matter", selection: $part) {
            // By name only: a count on each was four numbers to read before anything was chosen.
            Text("To do").tag(Part.todo)
            Text("Record").tag(Part.record)
            Text("People").tag(Part.people)
            Text("Notes").tag(Part.notes)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        // The chosen part in white, as on the iPhone — not in the black the app's buttons have.
        .tint(Theme.card)
    }

    /// Whether this person wrote it: by any way their name is written.
    private func wrote(_ party: Party, _ from: String?) -> Bool {
        guard let from else { return false }
        return matter.writer(from) === party
    }

    /// Everything that came in or was added — mail, files, links — as one list, or one kind of it.
    @ViewBuilder
    private func record(_ status: MatterStatus) -> some View {
        HStack(spacing: 10) {
            // Which kind of it: a slim menu, not a second row of tabs under the parts.
            Menu {
                Picker("Show", selection: $filter) {
                    Text("All · \(status.mailEntries.count + shownDocuments.count + keptLinks.count)").tag(RecordFilter.all)
                    Text("Mail · \(status.mailEntries.count)").tag(RecordFilter.mail)
                    Text("Files · \(shownDocuments.count)").tag(RecordFilter.files)
                    Text("Details · \((matter.details ?? []).count)").tag(RecordFilter.details)
                    Text("Links · \(keptLinks.count)").tag(RecordFilter.links)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(filter == .all ? "Everything" : filter.rawValue.capitalized).font(.callout)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .tint(.secondary)
            .help("Show everything, or only the mail, the files or the links")
            if let party = personParty, filter == .all {
                Button { person = nil } label: { Label(party.name, systemImage: "xmark.circle.fill") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .help("Only what \(party.name) wrote is shown. Click to show everyone's again.")
            }
            Spacer()
        }
        switch filter {
        case .all:
            // What to have at hand, on top of what came in.
            if personParty == nil { DetailsSection(matter: matter).id("details") }
            recordList(status)
        case .mail: history(status)
        case .files: files.id("files")
        case .details: DetailsSection(matter: matter, showsEmpty: true).id("details")
        case .links: links.id("links")
        }
    }

    /// One file of the record, as a card.
    private func fileCard(_ document: MatterCore.Document) -> some View {
        Card {
            DocumentRow(document: document, sender: sender(of: document), state: fetching[document.persistentModelID],
                        open: { fetch(document, then: { NSWorkspace.shared.open($0) }) },
                        read: { fetch(document, then: { conversation.bring($0, document: document) }) },
                        hide: { setHidden(document, !document.isHidden) },
                        nameIt: { nameFromContent(document) },
                        talk: { talk(document.shownName, "File") })
                .findable(.model(document.persistentModelID), document.shownName, document.name, sender(of: document))
        }
    }

    /// One thing of the record, and the day it is sorted by.
    private enum RecordItem: Identifiable {
        case thread(MailThreads.Thread)
        case document(MatterCore.Document)
        case link(WebLink)

        var id: String {
            switch self {
            case .thread(let thread): "thread-\(thread.id)"
            case .document(let document): "file-\(document.persistentModelID.hashValue)"
            case .link(let link): "link-\(link.persistentModelID.hashValue)"
            }
        }
        var date: Date {
            switch self {
            case .thread(let thread): thread.last ?? thread.first ?? .distantPast
            case .document(let document): document.source.date ?? .distantPast
            case .link(let link): link.createdAt
            }
        }
    }

    private static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    /// Mail, files and links together, newest first, month by month.
    @ViewBuilder
    private func recordList(_ status: MatterStatus) -> some View {
        let party = personParty
        let threads = MailThreads.build(status.mailEntries).filter { thread in
            party.map { party in thread.rows.contains { wrote(party, $0.entry.from) } } ?? true
        }
        let documents = shownDocuments.filter { document in
            party.map { party in
                wrote(party, (matter.entries ?? []).first { $0.messageID == document.messageID }?.from)
            } ?? true
        }
        let links = party == nil ? keptLinks : []
        // A file that came with a mail — or the scan a file was read into — is one thing with it:
        // the file stands right under its mail, not as an entry of its own.
        let mailIDs = Dictionary(threads.flatMap { thread in thread.rows.map { ($0.entry.messageID, thread.id) } }.filter { !$0.0.isEmpty },
                                 uniquingKeysWith: { first, _ in first })
        let attached = Dictionary(grouping: documents.filter { mailIDs[$0.messageID] != nil }) { mailIDs[$0.messageID] ?? "" }
        let loose = documents.filter { mailIDs[$0.messageID] == nil }
        let all = (threads.map(RecordItem.thread) + loose.map(RecordItem.document) + links.map(RecordItem.link)).sorted { $0.date > $1.date }
        let visible = showsAllHistory ? all : Array(all.prefix(60))
        let months = Dictionary(grouping: visible) { Calendar.current.dateComponents([.year, .month], from: $0.date) }
            .sorted { ($0.key.year ?? 0, $0.key.month ?? 0) > ($1.key.year ?? 0, $1.key.month ?? 0) }
        if all.isEmpty {
            EmptyBox(text: party == nil ? "Mail sorted into this matter, its files and links show here, newest first."
                                        : "Nothing in this matter was written by \(party?.name ?? "them").")
        }
        ForEach(months, id: \.key) { _, items in
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: items.first.map { $0.date == .distantPast ? "Without a day" : Self.month.string(from: $0.date) } ?? "",
                              detail: items.count == 1 ? "1 entry" : "\(items.count) entries")
                ForEach(items) { item in
                    switch item {
                    case .thread(let thread):
                        // Its files right under it, close: one thing. A scan or a picture the owner
                        // brought in is its entry already — "Open" is on it — and is not listed again.
                        VStack(alignment: .leading, spacing: 4) {
                            ThreadCard(thread: thread) { entry in talk(entry.title, "Mail") }
                            ForEach((attached[thread.id] ?? []).filter { !$0.isOwnFile }) { document in fileCard(document) }
                        }
                    case .document(let document):
                        fileCard(document)
                    case .link(let link):
                        Card {
                            LinkRow(link: link, todos: matter.openTodos) { remove(link) }
                                .findable(.model(link.persistentModelID), link.shownName, link.address)
                        }
                    }
                }
            }
        }
        if all.count > visible.count {
            Button("… and \(all.count - visible.count) older — show them") { showsAllHistory = true }
                .buttonStyle(.gold).font(.caption).padding(.horizontal, 4)
        }
    }

    // MARK: History

    private func history(_ status: MatterStatus) -> some View {
        let threads = MailThreads.build(status.mailEntries)
        // The newest conversations, until about 60 mails are shown.
        var shown = 0
        let visible = threads.prefix { thread in defer { shown += thread.count }; return shown < 60 || find.isActive || showsAllHistory }
        let hidden = threads.count - visible.count
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History", detail: Self.count(status.mailEntries)
                          + (threads.count == status.mailEntries.count ? "" : " in \(threads.count) \(threads.count == 1 ? "conversation" : "conversations")"))
            if status.mailEntries.isEmpty {
                EmptyBox(text: "Mail sorted into this matter shows here, newest first. It comes from your mailbox, not by hand.")
            }
            ForEach(visible) { thread in
                ThreadCard(thread: thread) { entry in talk(entry.title, "Mail") }
            }
            if hidden > 0 {
                Text("… and \(hidden) older \(hidden == 1 ? "conversation" : "conversations")").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
        .task(id: matter.persistentModelID) { await linkReplies() }
    }

    /// "32 mails · 3 screenshots · 1 document": each kind counted as what it is.
    static func count(_ entries: [Entry]) -> String {
        let names: [(Source.Kind, String, String)] = [
            (.mail, "mail", "mails"), (.screenshot, "screenshot", "screenshots"), (.document, "document", "documents"),
            (.photo, "photo", "photos"), (.spokenNote, "spoken note", "spoken notes"), (.phoneCall, "call", "calls"),
            (.conversation, "from the assistant", "from the assistant"),
        ]
        let parts = names.compactMap { kind, one, many -> String? in
            let n = entries.filter { $0.source.kind == kind }.count
            return n == 0 ? nil : "\(n) \(n == 1 ? one : many)"
        }
        return parts.isEmpty ? "No mails yet" : parts.joined(separator: " · ")
    }

    /// Mail sorted in before it was kept which mail it answers: read once from the mailbox,
    /// headers only, read-only. Free: nothing goes to any model.
    private func linkReplies() async {
        let unknown = (matter.entries ?? []).filter { $0.replyTo == nil && $0.source.pointer.hasPrefix("imap://") && !$0.messageID.isEmpty }
        guard !unknown.isEmpty, let account = Keychain.accounts().first,
              let password = try? await MailSecret.secret(for: account) else { return }
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

// MARK: Rows

struct TodoRow: View {
    let todo: Todo
    let today: String
    var showsOwner = false
    /// "Nur Info": it is nothing to do, only worth knowing.
    var info: (() -> Void)? = nil
    /// Given where the owner's reminders are shown: then a task of theirs gets its sign.
    var reminders: [Calendars.Reminder]? = nil
    var calendarTick = 0
    let toggle: () -> Void
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(todo.isDone ? Theme.onInk : .secondary, todo.isDone ? Theme.ink : .secondary)
            }
            .buttonStyle(.plain)
            .help(todo.isDone ? "Open again" : "Mark as done")
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.text)
                    .foregroundStyle(todo.isDone || todo.isBlocked ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let links = todo.links, !links.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(links.sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                            Button { if let url = link.url { NSWorkspace.shared.open(url) } } label: {
                                Label(link.shownName, systemImage: LinkRow.icon(link)).font(.callout).lineLimit(1)
                            }
                            .buttonStyle(.gold)
                            .help("Open \(link.kind) in the browser")
                        }
                    }
                }
                if let reminders, !todo.isDone, !todo.isInfo, todo.owner == .me || todo.owner == .we || todo.reminderID != nil {
                    CalendarChip(kind: .reminder, linkedID: todo.reminderID, title: todo.text, day: todo.due, time: todo.dueTime,
                                 note: todo.note, matterName: todo.matter?.name ?? "", reminders: reminders, tick: calendarTick) { id in
                        todo.reminderID = id
                        todo.reminderStamp = nil
                        try? context.save()
                    }
                }
                if !todo.isDone, let other = todo.waitsFor {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: other.isDone ? "arrow.right.circle.fill" : "hourglass")
                            .font(.caption).foregroundStyle(other.isDone ? Theme.done : .secondary)
                        Text(other.isDone ? "its turn now — done: \(other.text)" : "only after: \(other.text)")
                            .font(.callout).foregroundStyle(other.isDone ? Theme.done : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let note = todo.note, !note.isEmpty {
                    // The owner's note under the task, as words alone: an icon would only add clutter.
                    Text(Linked.text(note)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    let loose = WebLink.split(note: note).links.filter { found in !(todo.links ?? []).contains { $0.address == found.address } }
                    if !loose.isEmpty {
                        Button(loose.count == 1 ? "Save as link" : "Save \(loose.count) links") { keepLinks(from: note) }
                            .buttonStyle(.gold).font(.caption)
                            .tool()
                            .help("Makes the address in the note a link on this task, and takes the line out of the note.")
                    }
                }
                HStack(spacing: 8) {
                    if showsOwner {
                        Text(["me": "Mine", "we": "Ours", "other": "Waiting for"][todo.owner.rawValue] ?? "Unclear whose")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if let due = todo.due {
                        Text("by \(Dates.short(due))\(todo.dueTime.map { " at \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(!todo.isDone && due < today ? Theme.warning : .secondary)
                    }
                    if todo.sources.count > 1 {
                        Text("asked \(todo.sources.count)×").font(.caption).foregroundStyle(.secondary)
                    }
                    if todo.isDone {
                        SourceLink(source: todo.doneSource,
                                   label: todo.doneSource == nil ? "done by you" : "done, says the mail of \(todo.doneSource?.date.map(Dates.short) ?? "?")")
                            .foregroundStyle(Theme.done)
                    } else {
                        SourceLink(source: todo.sources.first, label: Sources.origin(todo.sources.first))
                    }
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                MoreMenu { moreItems }
                    .popover(isPresented: $editing, arrowEdge: .bottom) {
                        TodoEditor(todo: todo, done: { editing = false; try? context.save() }, cancel: { editing = false })
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .task {
            // The picture of the popover: this one task's open, once the page has settled.
            guard IntroShot.current == .lisbonEdit, todo.text.hasPrefix("Ask for express") else { return }
            try? await Task.sleep(for: .seconds(2.5))
            editing = true
        }
        .confirmationDialog("Delete “\(todo.text)”?", isPresented: $deleting) {
            Button("Delete", role: .destructive) {
                // The reminder it is connected with goes too: a task that is gone reminds of nothing.
                Calendars.shared.removeReminder(todo.reminderID)
                withAnimation { context.delete(todo) }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(todo.reminderID == nil ? "It goes from this matter. This cannot be undone. Something only good to know can go to Info instead."
                 : "It goes from this matter, and its reminder from Reminders. This cannot be undone.")
        }
    }

    /// The addresses in the note become the to-do's links, and their lines leave the note.
    private func keepLinks(from note: String) {
        guard let matter = todo.matter else { return }
        let (found, rest) = WebLink.split(note: note)
        for item in found where !(todo.links ?? []).contains(where: { $0.address == item.address }) {
            let link = WebLink(address: item.address, title: item.title)
            context.insert(link)
            link.matter = matter
            link.todo = todo
        }
        withAnimation { todo.note = rest }
        try? context.save()
    }

    /// What the ⋯ and a right-click offer: change it by hand, say it is only worth knowing, and
    /// what it waits for.
    @ViewBuilder
    private var moreItems: some View {
        Button("Ask Causabee", action: talk)
        Button("Edit …") { editing = true }
        if let info {
            Button("Not a task — move to Info", action: info)
        }
        if !todo.isDone {
            Divider()
            waitMenu
        }
        Divider()
        Button("Delete …", role: .destructive) { deleting = true }
    }

    /// The other open to-dos of the matter, to pick the one this one needs first.
    @ViewBuilder
    private var waitMenu: some View {
        let others = (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text < $1.text }
        Menu("Waits for …") {
            ForEach(others, id: \.persistentModelID) { other in
                Button(other.text) {
                    withAnimation { _ = todo.wait(for: other) }
                    try? context.save()
                }
                .disabled(other === todo.waitsFor)
            }
        }
        .disabled(others.isEmpty)
        if todo.waitsFor != nil {
            Button("Waits for nothing any more") {
                withAnimation { todo.waitsFor = nil }
                try? context.save()
            }
        }
    }
}

/// A to-do put right by hand: its words, whose it is, and by when — a day, and a time if wanted.
struct TodoEditor: View {
    let todo: Todo
    /// After Save: the change is written.
    let done: () -> Void
    /// Cancel: closes, and nothing of it is written.
    var cancel: () -> Void = {}
    /// A task just started with "+ Task": "New task", and nothing to save until it has words.
    var isNew = false
    @State private var text = ""
    @State private var note = ""
    @State private var owner = Todo.Owner.me
    @State private var hasDay = false
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var after: PersistentIdentifier?
    @State private var circle = false
    @State private var newLink = ""
    @Environment(\.modelContext) private var context

    private var others: [Todo] { (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text < $1.text } }

    @FocusState private var focus: Field?
    private enum Field { case text, note, link }

    var body: some View {
        // As Figma's "Mac popovers" draw it: the words first, whose in pills, then one card with
        // the day, what it waits for and its links — each with its label on the left.
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "New task" : "Change task").font(.headline)
            VStack(spacing: 8) {
                box(TextField("What to do", text: $text, axis: .vertical).lineLimit(1...5).accessibilityIdentifier("task.text"), field: .text)
                box(TextField("Note — a list, a detail, what was agreed", text: $note, axis: .vertical).lineLimit(2...8), field: .note)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("WHOSE").font(.caption).foregroundStyle(.secondary).kerning(0.4)
                HStack(spacing: 6) {
                    pill("Mine", .me)
                    pill("Ours", .we)
                    pill("Waiting for", .other)
                    pill("Unclear", .unknown)
                }
            }
            VStack(spacing: 0) {
                row("Due") { dueControl }
                if !others.isEmpty {
                    Divider().padding(.leading, 12)
                    row("Only after") {
                        Menu {
                            Picker("Only after", selection: $after) {
                                Text("nothing — can go any time").tag(PersistentIdentifier?.none)
                                ForEach(others, id: \.persistentModelID) { other in Text(other.text).tag(Optional(other.persistentModelID)) }
                            }
                            .pickerStyle(.inline).labelsHidden()
                        } label: {
                            HStack {
                                Text(others.first { $0.persistentModelID == after }?.text ?? "nothing — can go any time").lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                        .help("When this task can only go ahead after another one is done")
                    }
                }
                Divider().padding(.leading, 12)
                row("Link") { linkControl }
            }
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 10))
            if circle {
                Text("The other one already waits for this one — neither could ever be done.").font(.caption).foregroundStyle(Theme.warning)
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save", action: save).keyboardShortcut(.defaultAction).inkButton()
                    .disabled(isNew && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(width: 396)
        .environment(\.locale, Locale(identifier: "en_US"))
        .onAppear { load(); focus = .text }
    }

    /// A field on white, a thin line round it, gold while typing in it.
    private func box(_ content: some View, field: Field) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($focus, equals: field)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focus == field ? Theme.gold : Theme.line, lineWidth: focus == field ? 1.5 : 1))
    }

    private func pill(_ label: String, _ value: Todo.Owner) -> some View {
        let on = owner == value
        return Button { owner = value } label: {
            Text(label).font(.subheadline)
                .padding(.horizontal, 11).padding(.vertical, 4)
                .foregroundStyle(on ? Theme.onInk : Color.primary)
                .background(on ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Color.primary.opacity(0.06)), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(.callout).foregroundStyle(.secondary).frame(width: 76, alignment: .leading)
            control().font(.callout).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    @ViewBuilder
    private var dueControl: some View {
        if hasDay {
            HStack(spacing: 6) {
                DatePicker("Day", selection: $day, displayedComponents: .date).labelsHidden().datePickerStyle(.field).fixedSize()
                if hasTime {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field).fixedSize()
                } else {
                    Button("+ time") { hasTime = true }.buttonStyle(.plain).foregroundStyle(Theme.gold)
                }
                Spacer(minLength: 4)
                Button { hasDay = false; hasTime = false } label: { Image(systemName: "xmark").font(.caption) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("No day")
            }
        } else {
            Button("Add a day") { hasDay = true }.buttonStyle(.plain).foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    private var linkControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach((todo.links ?? []).sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                HStack(spacing: 6) {
                    Label(link.shownName, systemImage: LinkRow.icon(link)).lineLimit(1)
                    Spacer(minLength: 4)
                    Button { link.todo = nil } label: { Image(systemName: "xmark").font(.caption) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Take it off the task. The link stays in the matter.")
                }
            }
            TextField("Paste a link", text: $newLink).textFieldStyle(.plain).focused($focus, equals: .link)
            if !newLink.isEmpty, WebLink.address(in: newLink) == nil {
                Text("This is not a web address.").font(.caption).foregroundStyle(Theme.warning)
            }
        }
    }

    private func load() {
        text = todo.text
        note = todo.note ?? ""
        owner = todo.owner
        after = todo.waitsFor?.persistentModelID
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm"
        if let due = todo.due, let date = parser.date(from: due + " " + (todo.dueTime ?? "09:00")) {
            hasDay = true
            day = date
            time = date
            hasTime = todo.dueTime != nil
        }
    }

    private func save() {
        // What cannot be saved is found first, before anything is changed: a wait in a circle
        // stops the save, and must not leave half of the edit behind.
        let other = after.flatMap { id in others.first { $0.persistentModelID == id } }
        if other !== todo.waitsFor, !todo.wait(for: other) {
            circle = true
            return
        }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { todo.text = words }
        let written = note.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.note = written.isEmpty ? nil : written
        if let address = WebLink.address(in: newLink), let matter = todo.matter,
           !(todo.links ?? []).contains(where: { $0.address == address }) {
            let link = WebLink(address: address)
            context.insert(link)
            link.matter = matter
            link.todo = todo
        }
        todo.owner = owner
        if hasDay {
            todo.due = MatterStatus.day(day)
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "HH:mm"
            todo.dueTime = hasTime ? format.string(from: time) : nil
        } else {
            todo.due = nil
            todo.dueTime = nil
        }
        done()
    }
}

/// Something the mail said that is worth knowing but is nothing to do.
struct InfoRow: View {
    let todo: Todo
    let back: () -> Void
    let talk: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle").foregroundStyle(.secondary).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.text).fixedSize(horizontal: false, vertical: true)
                SourceLink(source: todo.sources.first, label: Sources.origin(todo.sources.first))
            }
            Spacer(minLength: 8)
            Button(action: back) { Label("Back to tasks", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.gold).font(.callout)
                .tool()
                .help("A task after all: it goes back to the open tasks")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Ask Causabee", action: talk)
            Button("Back to tasks", action: back)
        }
    }
}

struct DateRow: View {
    struct Item {
        var day: String
        var time: String?
        var what: String
        /// On the same day: the whole-day ones first, then by the hour, then by name.
        static func sameDay(_ a: Item, _ b: Item) -> Bool {
            let (x, y) = (a.time ?? "", b.time ?? "")
            return x != y ? x < y : alphabetically(a.what, b.what)
        }
        var place: String?
        var kind: String
        var source: Source?
        var appointment: Appointment?
        var deadline: Deadline?

        var findID: PageFind.ID {
            if let id = appointment?.persistentModelID ?? deadline?.persistentModelID { return .model(id) }
            return .section("date \(day) \(what)")
        }

        init(_ appointment: Appointment) {
            (day, time, what, place, kind, source) = (appointment.day, appointment.time, appointment.what, appointment.place, "Appointment", appointment.sources.first)
            self.appointment = appointment
        }

        init(_ deadline: Deadline) {
            (day, time, what, place, kind, source) = (deadline.day, nil, deadline.what, nil, "Deadline", deadline.sources.first)
            self.deadline = deadline
        }

        var calendarID: String? { appointment?.calendarID ?? deadline?.calendarID }
        func connect(_ id: String?) {
            appointment?.calendarID = id
            deadline?.calendarID = id
            // Connected anew: in step from here on, as each side is now.
            appointment?.calendarStamp = nil
            deadline?.calendarStamp = nil
        }
    }

    let item: Item
    let isPast: Bool
    var matterName = ""
    var tick = 0
    var save: () -> Void = {}
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Dates.short(item.day)).font(.callout.weight(.semibold))
                if let time = item.time { Text(time).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(width: 74, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.what).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(item.kind).font(.caption.weight(.medium))
                        .foregroundStyle(item.kind == "Deadline" ? Theme.warning : .secondary)
                    if let place = item.place { Text(place).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    SourceLink(source: item.source, label: "Source")
                }
                if !isPast || item.calendarID != nil {
                    CalendarChip(kind: .event, linkedID: item.calendarID, title: item.what, day: item.day, time: item.time,
                                 place: item.place, matterName: matterName, tick: tick) { id in item.connect(id); save() }
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                MoreMenu { moreItems }
                    .popover(isPresented: $editing, arrowEdge: .bottom) {
                        DateEditor(item: item, done: { editing = false; save() }, cancel: { editing = false })
                    }
            }
        }
        .foregroundStyle(isPast ? .secondary : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .confirmationDialog("Delete “\(item.what)”?", isPresented: $deleting) {
            Button("Delete", role: .destructive) {
                // The entry in Calendar it is connected with goes too.
                Calendars.shared.removeEvent(item.calendarID)
                if let appointment = item.appointment { context.delete(appointment) }
                if let deadline = item.deadline { context.delete(deadline) }
                save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.calendarID == nil ? "It goes from this matter. This cannot be undone."
                 : "It goes from this matter, and its entry from Calendar. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var moreItems: some View {
        Button("Ask Causabee", action: talk)
        Button("Edit …") { editing = true }
        Divider()
        Button("Delete …", role: .destructive) { deleting = true }
    }
}

/// An appointment or a deadline put right by hand: what, which day, and for an appointment the
/// time and the place. A connected Calendar entry follows on the next sync.
struct DateEditor: View {
    let item: DateRow.Item
    let done: () -> Void
    let cancel: () -> Void
    @State private var what = ""
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var place = ""

    private var isAppointment: Bool { item.appointment != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isAppointment ? "Change appointment" : "Change deadline").font(.headline)
            TextField("What", text: $what, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .frame(width: 360)
            HStack {
                DatePicker("Day", selection: $day, displayedComponents: .date).labelsHidden()
                if isAppointment {
                    Toggle("Time", isOn: $hasTime)
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).labelsHidden() }
                }
            }
            if isAppointment {
                TextField("Place", text: $place).textFieldStyle(.roundedBorder).frame(width: 360)
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Save", action: saveChanges)
                    .keyboardShortcut(.defaultAction)
                    .disabled(what.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .environment(\.locale, Locale(identifier: "en_US"))
        .onAppear(perform: load)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private func load() {
        what = item.what
        place = item.place ?? ""
        day = MatterStatus.date(of: item.day) ?? Date()
        if let at = item.time, let parsed = Self.formatter("HH:mm").date(from: at) {
            hasTime = true
            time = parsed
        }
    }

    private func saveChanges() {
        let text = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayText = Self.formatter("yyyy-MM-dd").string(from: day)
        if let appointment = item.appointment {
            appointment.what = text
            appointment.day = dayText
            appointment.time = hasTime ? Self.formatter("HH:mm").string(from: time) : nil
            let spot = place.trimmingCharacters(in: .whitespacesAndNewlines)
            appointment.place = spot.isEmpty ? nil : spot
        }
        if let deadline = item.deadline {
            deadline.what = text
            deadline.day = dayText
        }
        done()
    }
}

struct PartyRow: View {
    let party: Party
    let membership: Membership
    let matter: Matter
    let save: (String, String) -> Void
    /// Out of this matter; nil where it is not offered.
    var remove: (() -> Void)? = nil
    let talk: () -> Void
    @State private var editing = false
    @State private var name = ""
    @State private var role = ""
    @State private var address = ""
    @State private var phone = ""

    var body: some View {
        let addresses = CardActions.addresses(of: party)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(party.name).font(.body.weight(.medium))
                    if let role = membership.role { Text("· \(role)").foregroundStyle(.secondary).lineLimit(1) }
                }
                // How much they are in the matter — the one named most in gold.
                if let share = membership.share {
                    Text(share.isMost ? share.text + " · the most" : share.text).font(.caption)
                        .foregroundStyle(share.isMost ? Theme.gold : .secondary)
                }
                MailAddressLine(addresses: addresses)
                ContactActions(party: party)
                let also = party.otherSpellings
                if !also.isEmpty {
                    Text("also written: " + also.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                let elsewhere = party.matters.filter { $0 !== matter }.map(\.name)
                if !elsewhere.isEmpty {
                    Text("also in: " + elsewhere.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
            MoreMenu {
                MailAddressItems(addresses: addresses)
                ContactItems(party: party)
                Button("Ask Causabee", action: talk)
                Button("Edit name and role …") {
                    name = party.name
                    role = membership.role ?? ""
                    address = party.address ?? ""
                    phone = party.phone ?? ""
                    editing = true
                }
                if let remove {
                    Button("Remove from this matter", role: .destructive, action: remove)
                }
            }
                .popover(isPresented: $editing, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Change person").font(.headline)
                        TextField("Name", text: $name).textFieldStyle(.roundedBorder).frame(width: 300)
                        TextField("Role in \(matter.name)", text: $role).textFieldStyle(.roundedBorder).frame(width: 300)
                        TextField("Mail", text: $address).textFieldStyle(.roundedBorder).frame(width: 300)
                        TextField("Phone", text: $phone).textFieldStyle(.roundedBorder).frame(width: 300)
                        Text("The old name stays as a spelling, so new mail still finds the person.")
                            .font(.caption).foregroundStyle(.secondary).frame(width: 300, alignment: .leading)
                        HStack {
                            if let remove {
                                Button("Remove from this matter", role: .destructive) { editing = false; remove() }
                                    .help("Only from this matter. A later mail naming them will not put them back.")
                            }
                            Spacer()
                            Button("Cancel") { editing = false }.keyboardShortcut(.cancelAction)
                            Button("Save") {
                                save(name, role)
                                let mail = address.trimmingCharacters(in: .whitespacesAndNewlines), number = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                                party.address = mail.isEmpty ? nil : mail
                                party.phone = number.isEmpty ? nil : number
                                try? party.modelContext?.save()
                                editing = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

/// "Same person?" — what is only likely is asked, with its reason, and a no is kept.
struct SuggestionCard: View {
    let suggestions: [PartyBook.Suggestion]
    let accept: (PartyBook.Suggestion) -> Void
    let refuse: (PartyBook.Suggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Same person? · \(suggestions.count)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                if index > 0 { RowDivider() }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(suggestion.party.name)  →  \(suggestion.into.name)").font(.body.weight(.medium))
                        Text(suggestion.reason).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Not the same") { refuse(suggestion) }
                    Button("Merge") { accept(suggestion) }.inkButton()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .padding(.bottom, 4)
        .box()
    }
}

/// One conversation of a matter: its subject once, the first mail on top, and each reply
/// under the mail it answers, joined by a line.
struct ThreadCard: View {
    let thread: MailThreads.Thread
    let talk: (Entry) -> Void
    @Query private var profiles: [Profile]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(thread.subject.isEmpty ? "(no subject)" : thread.subject).font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                if thread.count > 1 {
                    Text(span + " · \(thread.senders.count) \(thread.senders.count == 1 ? "person" : "people")")
                        .font(.caption).foregroundStyle(.secondary).fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                let me = Me(names: profiles.first?.names ?? [], withAccounts: true)
                let joined = MailThreads.joined(thread.rows, deepest: ThreadMailRow.deepest)
                ForEach(thread.rows) { row in
                    ThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1, sent: me.sent(row.entry.from), joinsNext: joined.contains(row.id)) { talk(row.entry) }
                        .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private var span: String {
        let first = thread.first.map(Dates.short) ?? "", last = thread.last.map(Dates.short) ?? ""
        return first == last ? first : "\(first) – \(last)"
    }
}

/// One mail in a conversation, set in by how deep it answers, with the lines to the mail it
/// answers drawn on its left.
/// Which way a mail went: in to the owner, or out from them.
struct MailWay: View {
    let sent: Bool

    var body: some View {
        Image(systemName: sent ? "arrow.up.right" : "arrow.down.left")
            .font(.caption.weight(.semibold))
            .foregroundStyle(sent ? Theme.gold : Color.secondary)
            .help(sent ? "You sent it" : "It came in")
            .accessibilityLabel(sent ? "sent" : "came in")
    }
}

struct ThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    /// The owner wrote it: it went out, the others came in.
    let sent: Bool
    /// At the deepest indent and answered: its line goes on down to its answer.
    var joinsNext = false
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @State private var naming = false
    @State private var newName = ""

    nonisolated static let step: CGFloat = 20
    /// How far in replies go; deeper ones stay at this depth.
    static let deepest = 4

    /// A letter scanned and taken in is no mail: the button says what it opens.
    static func openLabel(_ kind: Source.Kind) -> String {
        switch kind {
        case .screenshot: "Open screenshot"
        case .document: "Open document"
        case .photo: "Open photo"
        default: "Open mail"
        }
    }

    /// What the dots and the right click both bring.
    @ViewBuilder
    private var items: some View {
        // To see the mail itself: first in its menu, as "Open" is for a file.
        // A letter scanned or a mail dropped in is a file on this Mac; a mail from the label is in Mail.
        if let url = row.entry.source.fileURL ?? row.entry.mailURL {
            Button(Self.openLabel(row.entry.source.kind), systemImage: row.entry.source.kind == .mail ? "envelope" : "arrow.up.forward.app") {
                NSWorkspace.shared.open(url)
            }
        }
        Button("Ask Causabee", action: talk)
        MoveMailMenu(entry: row.entry) { newName = Matter.suggestedName(for: [row.entry]); naming = true }
    }

    var body: some View {
        let depth = min(row.depth, Self.deepest)
        let entry = row.entry
        // The lines to the mail it answers are drawn behind the row, as tall as the row is: set
        // beside it, the lines asked for all the height there was, and the row grew with them.
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(sent ? "You" : entry.matter?.writerName(entry.from) ?? Email.address(in: entry.from)).fontWeight(.medium).lineLimit(1)
                        if entry.source.kind == .mail { MailWay(sent: sent) }
                    }
                    .accessibilityElement(children: .combine)
                    if started { BeeChip(text: "started") }
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    // As every row has it: what the mail can do, behind its dots — opening it first.
                    MoreMenu { items }
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest).font(.callout).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, depth > 0 ? 6 : 0)
        }
        .padding(.leading, CGFloat(depth) * Self.step)
        .background(alignment: .topLeading) {
            if depth > 0 {
                ThreadRails(depth: depth, rails: Array(row.rails.prefix(depth - 1)), isLast: row.isLast && !joinsNext)
                    .stroke(Theme.strongLine, lineWidth: 1.5)
                    .frame(width: CGFloat(depth) * Self.step)
            }
        }
        .contentShape(Rectangle())
        // The same in the right click, as on every row: no button that comes and goes.
        .contextMenu { items }
        .alert("Move to a new matter", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Move") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let from = row.entry.matter else { return }
                _ = try? from.split([row.entry], intoNewMatterNamed: name, turnsSince: nil, in: context)
            }
        } message: {
            Text("The mail goes, with the tasks, dates and files only it brought.")
        }
    }
}

/// The lines left of a reply: one down from the mail it answers with a short turn into this
/// one, and the lines of the levels above that still lead on to later replies.
struct ThreadRails: Shape {
    let depth: Int
    let rails: [Bool]
    let isLast: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = ThreadMailRow.step
        // Level by level: the line sits under the first letter of the mail one level up.
        func x(_ level: Int) -> CGFloat { CGFloat(level - 1) * step + 6 }
        for (index, goesOn) in rails.enumerated() where goesOn {
            path.move(to: CGPoint(x: x(index + 1), y: rect.minY))
            path.addLine(to: CGPoint(x: x(index + 1), y: rect.maxY))
        }
        let turn: CGFloat = 16
        path.move(to: CGPoint(x: x(depth), y: rect.minY))
        path.addLine(to: CGPoint(x: x(depth), y: isLast ? turn : rect.maxY))
        path.move(to: CGPoint(x: x(depth), y: turn))
        path.addLine(to: CGPoint(x: x(depth) + step - 8, y: turn))
        return path
    }
}

struct DocumentRow: View {
    let document: MatterCore.Document
    let sender: String?
    let state: String?
    let open: () -> Void
    let read: () -> Void
    let hide: () -> Void
    /// A name from the file's first page.
    let nameIt: () -> Void
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @State private var renaming = false
    @State private var deleting = false
    @Environment(Navigation.self) private var navigation
    @State private var newName = ""

    private var isPDF: Bool { document.contentType == "application/pdf" || document.name.lowercased().hasSuffix(".pdf") }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (document.name as NSString).pathExtension) ?? .data))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.shownName).lineLimit(2)
                // With a name of its own, the file's name is still there to see, small.
                Text([document.title == nil ? nil : document.name, Sources.origin(document.source), sender,
                      ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                if let says = document.says {
                    Text(says).font(.callout).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                }
                if document.title == nil, isPDF, DocumentTitle.looksMachineMade(document.name), state == nil {
                    Button("Name it from its content", action: nameIt)
                        .buttonStyle(.gold).font(.caption)
                        .tool()
                        .help("Scans the first page on the Mac and takes its heading as the name. Costs nothing, sends nothing.")
                }
                if let state {
                    Text(state).font(.caption).foregroundStyle(state.hasPrefix("Getting") ? Color.secondary : Theme.warning).textSelection(.enabled)
                }
            }
            Spacer(minLength: 8)
            if let read = document.readAt {
                Label("scanned \(Dates.short(read))", systemImage: "checkmark").font(.caption).foregroundStyle(Theme.done)
            }
            MoreMenu { moreItems }
                .popover(isPresented: $renaming, arrowEdge: .bottom) { renameField }
                .confirmationDialog("Delete “\(document.shownName)”?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete", role: .destructive, action: forget)
                    Button("Cancel", role: .cancel) {}
                } message: { Text(Self.deleteWords(document)) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        // A click on the row opens the file; everything else is in ⋯ and the right click.
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .help(document.isOwnFile ? "Opens the file." : "Opens the file — only this one mail is read from the mailbox.")
        .opacity(document.isHidden ? 0.55 : 1)
        .disabled(state?.hasPrefix("Getting") == true)
        .contextMenu { moreItems }
    }

    @ViewBuilder
    private var moreItems: some View {
        Button("Open", action: open)
        if document.isReadable, document.readAt == nil {
            Button("Scan", action: read)
                .help("Scans it on the Mac and shows it in the assistant. Nothing is sent until “Sort in” (≈ 4 cents).")
        }
        Button("Ask Causabee", action: talk)
        Divider()
        Button("Rename …") { newName = document.shownName; renaming = true }
        if isPDF { Button("Name it from its content", action: nameIt) }
        if document.title != nil {
            Button("Use the file's own name") { document.title = nil; try? context.save() }
        }
        Divider()
        Button(document.isHidden ? "Show again" : "Hide", action: hide)
        // One the owner brought in can go for good — an outdated letter; a mail's file would come back with its mail.
        if document.isOwnFile { Button("Delete …", role: .destructive) { deleting = true } }
    }

    /// What goes with it, said before it goes.
    static func deleteWords(_ document: MatterCore.Document) -> String {
        guard let matter = document.matter else { return "" }
        let found = matter.brought(by: document)
        let tasks = found.todos.count, dates = found.appointments.count + found.deadlines.count
        let parts = [tasks == 0 ? nil : tasks == 1 ? "1 task" : "\(tasks) tasks", dates == 0 ? nil : dates == 1 ? "1 date" : "\(dates) dates"].compactMap { $0 }
        return "Causabee forgets what it read in it" + (parts.isEmpty ? "" : ", and " + parts.joined(separator: " and ") + " only it brought") + ". The file itself stays where it is."
    }

    private func forget() {
        guard let matter = document.matter else { return }
        withAnimation { _ = matter.forget(document, besides: navigation.store, in: context); try? context.save() }
    }

    private var renameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rename file").font(.headline)
            TextField("Name", text: $newName).textFieldStyle(.roundedBorder).frame(width: 320)
                .onSubmit(saveName)
            Text("Only here in Causabee: the file keeps its own name in the mail and in its folder.")
                .font(.caption).foregroundStyle(.secondary).frame(width: 320, alignment: .leading)
            HStack {
                Spacer()
                Button("Cancel") { renaming = false }.keyboardShortcut(.cancelAction)
                Button("Save", action: saveName).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private func saveName() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.title = name.isEmpty || name == document.name ? nil : name
        try? context.save()
        renaming = false
    }
}


/// One link in a matter: its name, what kind of page, the to-do it goes with, and a click to open.
struct LinkRow: View {
    let link: WebLink
    let todos: [Todo]
    let remove: () -> Void
    @Environment(\.modelContext) private var context
    @State private var editing = false

    static func icon(_ link: WebLink) -> String {
        switch link.kind {
        case "Google Doc": "doc.text"
        case "Google Sheet": "tablecells"
        case "Google Slides": "rectangle.on.rectangle"
        case "Google Form": "list.bullet.rectangle"
        case "Google Drive", "Google Docs": "folder"
        default: "link"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Self.icon(link)).font(.title3).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Button { if let url = link.url { NSWorkspace.shared.open(url) } } label: {
                    Text(link.shownName).multilineTextAlignment(.leading)
                }
                .buttonStyle(.gold)
                .help(link.address)
                HStack(spacing: 8) {
                    Text(link.kind)
                    if let todo = link.todo { Text("· for: \(todo.text)").lineLimit(1) }
                    Text("· \(Dates.short(link.createdAt))")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            MoreMenu {
                LinkItems(link: link)
                Button("Edit name, address, task …") { editing = true }
                Button("Remove link", role: .destructive, action: remove)
                    .help("Take the link out of the matter. The document itself stays where it is.")
            }
                .popover(isPresented: $editing, arrowEdge: .bottom) {
                    LinkEditor(link: link, todos: todos) { address, title, todo in
                        link.address = address
                        link.title = title
                        link.todo = todo
                        try? context.save()
                        editing = false
                    } cancel: { editing = false }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// A link put in or put right: the address, a name to read, and the to-do it goes with, if any.
struct LinkEditor: View {
    let link: WebLink?
    let todos: [Todo]
    let save: (String, String, Todo?) -> Void
    let cancel: () -> Void
    @State private var address = ""
    @State private var title = ""
    @State private var todo: PersistentIdentifier?

    var body: some View {
        let valid = WebLink.address(in: address)
        VStack(alignment: .leading, spacing: 12) {
            Text(link == nil ? "Add link" : "Change link").font(.headline)
            TextField("https://docs.google.com/…", text: $address).textFieldStyle(.roundedBorder).frame(width: 380)
            if !address.isEmpty {
                Text(valid.map { WebLink.kind(of: URL(string: $0)) } ?? "This is not a web address.")
                    .font(.caption).foregroundStyle(valid == nil ? Theme.warning : .secondary)
            }
            TextField("Name, e.g. Cost list", text: $title).textFieldStyle(.roundedBorder).frame(width: 380)
            Text("Causabee does not open the link by itself. The assistant learns only the name, never the address.")
                .font(.caption).foregroundStyle(.secondary).frame(width: 380, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            if !todos.isEmpty {
                Picker("For task", selection: $todo) {
                    Text("none — just for the matter").tag(PersistentIdentifier?.none)
                    ForEach(todos.sorted { $0.text < $1.text }, id: \.persistentModelID) { item in
                        Text(item.text).lineLimit(1).tag(Optional(item.persistentModelID))
                    }
                }
                .frame(width: 380)
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let valid else { return }
                    save(valid, title.trimmingCharacters(in: .whitespacesAndNewlines), todos.first { $0.persistentModelID == todo })
                }
                .keyboardShortcut(.defaultAction)
                .disabled(valid == nil)
            }
        }
        .padding(16)
        .onAppear {
            if let link {
                address = link.address
                title = link.title
                todo = link.todo?.persistentModelID
            } else if let pasted = NSPasteboard.general.string(forType: .string), let found = WebLink.address(in: pasted),
                      found.lowercased().hasPrefix("http") {
                // A link just copied in the browser is what the owner is about to add.
                address = found
            }
        }
    }
}

/// A link found in a mail, offered: kept with a click, or set aside for good.
struct SuggestedLinkRow: View {
    let link: WebLink
    let mail: Entry?
    let keep: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: LinkRow.icon(link)).font(.title3).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Button { if let url = link.url { NSWorkspace.shared.open(url) } } label: {
                    Text(link.shownName).multilineTextAlignment(.leading)
                }
                .buttonStyle(.gold)
                .help(link.address)
                HStack(spacing: 6) {
                    Text(link.kind)
                    if let mail {
                        Text("· from the mail of \(mail.date.map(Dates.short) ?? "?"): \(mail.title)").lineLimit(1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Not important", action: dismiss).buttonStyle(.borderless).font(.caption)
                .help("It will not come back. Nothing is deleted: the link is in the mail.")
            Button("Keep", action: keep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// The last word on a tie in a list — two files from the same mail, two links of one day, two dates
/// at the same time: by name, as a person reads it, so the same matter always lists in the same order.
func alphabetically(_ a: String, _ b: String) -> Bool { a.localizedStandardCompare(b) == .orderedAscending }

/// Newest first; links of the same moment by their title, or their address when they have none.
func newestFirst(_ a: WebLink, _ b: WebLink) -> Bool {
    a.createdAt != b.createdAt ? a.createdAt > b.createdAt
        : alphabetically(a.title.isEmpty ? a.address : a.title, b.title.isEmpty ? b.address : b.title)
}

/// "Move to Another Matter": the open matters, the newest mail first, the one it is in ticked; and a
/// new one. The mail goes with what only it brought — its tasks, dates, decisions, files and links.
struct MoveMailMenu: View {
    let entry: Entry
    let newMatter: () -> Void
    @Query private var matters: [Matter]
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Move to Another Matter") {
            ForEach(MoveMailMenu.order(matters, current: entry.matter)) { matter in
                if matter === entry.matter {
                    Button { } label: { Label(matter.name, systemImage: "checkmark") }.disabled(true)
                } else {
                    Button(matter.name) { MoveMailMenu.move(entry, to: matter, in: context) }
                }
            }
            Divider()
            Button("New Matter …", action: newMatter)
        }
    }

    /// The one it is in first, then the open ones by their newest mail.
    static func order(_ matters: [Matter], current: Matter?) -> [Matter] {
        let open = matters.filter { !$0.isClosed && $0 !== current }
            .map { ($0, MatterStatus($0).lastDate ?? .distantPast) }.sorted { $0.1 > $1.1 }.map(\.0)
        return (current.map { [$0] } ?? []) + open
    }

    static func move(_ entry: Entry, to matter: Matter, in context: ModelContext) {
        guard let from = entry.matter else { return }
        withAnimation { try? from.move([entry], into: matter, in: context) }
    }
}

/// A section with nothing in it yet: a grey box, what goes in it in the middle, and — where the
/// owner can add it by hand — the button that does.
struct EmptyBox: View {
    let text: String
    var action: String? = nil
    var symbol = "plus"
    var run: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: run) { Label(action, systemImage: symbol) }.inkButton()
            }
        }
        .padding(.horizontal, 24).padding(.vertical, action == nil ? 18 : 22)
        .frame(maxWidth: .infinity)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 10))
    }
}
