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
    @State private var editingNotes = false
    /// The new mails of a closed matter, being made a matter of their own: the name the owner gives it.
    @State private var splitting = false
    @State private var newMatterName = ""
    @State private var notesDraft = ""
    @State private var askingStep = false
    @State private var addingLink = false
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
    /// ⌘F on this page.
    @State private var find = PageFind()
    /// The page has gone up under the title bar: the bar turns to glass, with a line under it.
    @State private var scrolledUnder = false
    @Environment(\.reading) private var reading

    var body: some View {
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
                        notes
                        todos(status)
                        dates(status)
                        files.id("files")
                        links
                        parties(status)
                        history(status)
                    }
                    .padding(24)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                // The name and the search stay on top while the page scrolls under them.
                .safeAreaInset(edge: .top, spacing: 0) { titleBar(status) }
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
                .onChange(of: matter.persistentModelID) { find.query = "" }
                // `--demo --shot`: the part of the page the introduction's picture shows.
                .onAppear {
                    if let section = IntroShot.current?.section {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { scroller.scrollTo(section, anchor: .top) }
                    }
                }
                // A link dragged from the browser onto the matter is kept in it.
                .dropDestination(for: URL.self) { urls, _ in
                    let web = urls.compactMap { WebLink.address(in: $0.absoluteString) }
                    for address in web { addLink(address, title: "", todo: nil) }
                    return !web.isEmpty
                }
                .onAppear { show(navigation.showing, with: scroller); loadCalendars() }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in loadCalendars() }
                .onChange(of: navigation.showing) { show(navigation.showing, with: scroller) }
            }
        }
        .environment(find)
        .navigationTitle(matter.name)
        .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
            Button("Merge") {
                if let (party, other) = merging { confirmSame(party, as: other) }
            }
            Button("Cancel", role: .cancel) { merging = nil }
        } message: {
            Text("This also counts for the next mail. You can undo it in the rules.")
        }
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
        let cost = String(format: "≈ %.1f cents", AssistantAsk.summaryEstimate(facts, model: ModelChoice.assistant) * 100)
        VStack(alignment: .leading, spacing: 10) {
            if let text = matter.summary, !text.isEmpty {
                HStack(spacing: 8) {
                    BeeChip(text: "SUMMARY")
                    if let at = matter.summaryAt { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(Array(text.split(separator: "\n").enumerated()), id: \.offset) { index, line in
                    Text(String(line)).fixedSize(horizontal: false, vertical: true)
                        .findable(.section("summary-\(index)"), String(line))
                }
            }
            // Update below on the left, like "Suggest better"; with no summary yet, the button on the right.
            HStack(spacing: 10) {
                if writingSummary {
                    BeeLoader(size: 10)
                    Text("Writing the summary …").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if matter.summaryAt != nil {
                    Button("Update · \(cost)", action: writeSummary)
                        .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Spacer()
                    Button("Write summary · \(cost)", action: writeSummary)
                        .help("Matterbee writes three or four lines from the facts of this matter, pseudonymised.")
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
                summaryError = "\(error)"
            }
            writingSummary = false
        }
    }

    // MARK: Next step

    /// C2 · the one thing to do now, and why. Worked out on the Mac for nothing; Claude's
    /// suggestion, asked for with a click, is shown instead while nothing has changed since.
    @ViewBuilder
    private func nextStep(_ status: MatterStatus, _ facts: Facts) -> some View {
        let rule = status.nextStep
        let fresh = matter.nextStep != nil && matter.nextStepAt.map { at in (matter.lastChange ?? .distantPast) <= at } == true
        let cost = String(format: "≈ %.1f cents", AssistantAsk.nextStepEstimate(facts, model: ModelChoice.assistant) * 100)
        VStack(alignment: .leading, spacing: 10) {
            if fresh, let step = matter.nextStep {
                BeeChip(text: "NEXT · FROM MATTERBEE")
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
                if askingStep {
                    BeeLoader(size: 10)
                    Text("Matterbee is on it …").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button((fresh ? "ask again · " : "Suggest better · ") + cost, action: askStep)
                        .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                        .help("Matterbee reads the facts of this matter with your notes, pseudonymised, and suggests a step with a reason.")
                    if let at = matter.nextStepAt, matter.nextStep != nil, !fresh {
                        Text("Matterbee's suggestion of \(Dates.short(at)) is older than the last change").font(.caption).foregroundStyle(.secondary)
                    }
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
                stepError = "\(error)"
            }
            askingStep = false
        }
    }

    // MARK: Notes

    /// The owner's own words on the matter, written and read here, and read by the assistant too.
    @ViewBuilder
    private var notes: some View {
        let text = matter.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            if editingNotes {
                TextEditor(text: $notesDraft)
                    .font(.body)
                    .frame(minHeight: 110, maxHeight: 320)
                    .padding(6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                HStack {
                    Text("The assistant reads the notes too — names in them are pseudonymised on the Mac first.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { editingNotes = false }
                    Button("Save") {
                        let written = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        matter.notes = written.isEmpty ? nil : written
                        try? context.save()
                        editingNotes = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else if text.isEmpty {
                Button { notesDraft = ""; editingNotes = true } label: { Label("Write note", systemImage: "square.and.pencil") }
                    .buttonStyle(.gold)
                    .tool()
                    .padding(.horizontal, 4)
            } else {
                HStack(alignment: .top) {
                    Text(Linked.text(text)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        .findable(.section("notes"), text)
                    Spacer(minLength: 8)
                    Button("Edit") { notesDraft = matter.notes ?? ""; editingNotes = true }.tool()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
            }
        }
    }

    // MARK: Files

    private var conversation: Conversation {
        Conversation(context: context, navigation: navigation, owner: profiles.first?.names.first)
    }

    private static var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Matterbee/Anhänge", isDirectory: true)
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
        if !all.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Files", detail: "\(all.count - small.count - hidden.count)"
                                  + (hidden.isEmpty ? "" : " · \(hidden.count) hidden")
                                  + (small.isEmpty ? "" : " · \(small.count) small \(small.count == 1 ? "image" : "images")"))
                    if MatterFolders.root != nil {
                        Button { if let folder = MatterFolders.folder(for: matter) { try? context.save(); FolderSaver.reveal(folder) } } label: {
                            Label("Folder", systemImage: "folder")
                        }
                        .buttonStyle(.borderless).font(.caption)
                        .tool()
                        .help("This matter's folder in iCloud Drive → Matterbee")
                    }
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
                Button { addingLink = true } label: { Label("Link", systemImage: "plus") }
                    .buttonStyle(.borderless).font(.caption)
                    .tool()
                    .help("Paste a link — or drag it from the browser onto the matter")
                    .popover(isPresented: $addingLink, arrowEdge: .bottom) {
                        LinkEditor(link: nil, todos: matter.openTodos) { address, title, todo in
                            addLink(address, title: title, todo: todo)
                            addingLink = false
                        } cancel: { addingLink = false }
                    }
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
                Text("None yet. A Google Doc, a sheet: add it with +, or drag it here from the browser.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
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
            searchingLinks = "No mail account saved. First: matter-spike login"
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
                searchingLinks = "\(error)"
            }
        }
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
            if let file = document.source.fileURL { use(file) } else {
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
            fetching[document.persistentModelID] = "No mail account saved. First: matter-spike login"
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
                fetching[id] = "\(error)"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation { scroller.scrollTo(todo, anchor: .center) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { if marked == todo { marked = nil } } }
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
                Button("Cancel") { splitting = false }
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
    private func titleBar(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
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
                        .onTapGesture(perform: startRenaming)
                        .pointerStyle(.horizontalText)
                        .help("Click to rename. The old name stays as an alias, so new mail still finds the matter.")
                    Spacer()
                }
                if !renaming {
                    PageFindField(find: find)
                    if !matter.isClosed {
                        Button("Close") { asksToClose = true }
                            .help("Take it out of the list and the assistant. Nothing is deleted.")
                            .tool()
                    }
                }
            }
            HStack(spacing: 6) {
                Text(Self.count(matter.entries ?? []))
                if let first = status.firstDate { Text("· since \(Dates.short(first))") }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 820, alignment: .leading)
        .frame(maxWidth: .infinity)
        // At the top it is the page itself; once the page scrolls under it, glass and a line.
        .background(scrolledUnder ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
        .overlay(alignment: .bottom) { if scrolledUnder { Divider() } }
    }

    // MARK: To-dos

    @ViewBuilder
    private func todos(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Tasks", detail: "\(matter.openTodos.count) open · \(status.done.count) done")
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
        if !upcoming.isEmpty || !past.isEmpty || !deadlines.isEmpty {
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
        if !memberships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "People", detail: "\(memberships.count) · to merge, drag one name onto another")
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
                            .draggable(party.name)
                            .contextMenu {
                                Menu("Merge with …") {
                                    ForEach(matter.parties.filter { $0 !== party }.sorted { $0.name < $1.name }) { other in
                                        Button(other.name) { merging = (party, other) }
                                    }
                                }
                                Button("Ask Matterbee") { talk(party.name, "Person") }
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

    // MARK: History

    private func history(_ status: MatterStatus) -> some View {
        let threads = MailThreads.build(status.entries)
        // The newest conversations, until about 60 mails are shown.
        var shown = 0
        let visible = threads.prefix { thread in defer { shown += thread.count }; return shown < 60 || find.isActive }
        let hidden = threads.count - visible.count
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History", detail: Self.count(status.entries)
                          + (threads.count == status.entries.count ? "" : " in \(threads.count) \(threads.count == 1 ? "conversation" : "conversations")"))
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
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text").font(.caption).foregroundStyle(.secondary)
                        Text(Linked.text(note)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
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
                PinButton(action: talk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .confirmationDialog("Delete “\(todo.text)”?", isPresented: $deleting) {
            Button("Delete", role: .destructive) {
                withAnimation { context.delete(todo) }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(todo.reminderID == nil ? "It goes from this matter. This cannot be undone. Something only good to know can go to Info instead."
                 : "It goes from this matter; the reminder stays in Reminders. This cannot be undone.")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Change task").font(.headline)
            TextField("What to do", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .frame(width: 360)
            TextField("Note — a list, a detail, what was agreed", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...8)
                .frame(width: 360)
            Picker("Whose", selection: $owner) {
                Text("Mine").tag(Todo.Owner.me)
                Text("Ours").tag(Todo.Owner.we)
                Text("Waiting for").tag(Todo.Owner.other)
                Text("Unclear whose").tag(Todo.Owner.unknown)
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            if !others.isEmpty {
                Picker("Only after", selection: $after) {
                    Text("nothing — can go any time").tag(PersistentIdentifier?.none)
                    ForEach(others, id: \.persistentModelID) { other in Text(other.text).lineLimit(1).tag(Optional(other.persistentModelID)) }
                }
                .frame(width: 360)
                .help("When this task can only go ahead after another one is done")
                if circle {
                    Text("The other one already waits for this one — neither could ever be done.").font(.caption).foregroundStyle(Theme.warning)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach((todo.links ?? []).sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                    HStack {
                        Label(link.shownName, systemImage: LinkRow.icon(link)).lineLimit(1)
                        Spacer()
                        Button { link.todo = nil } label: { Image(systemName: "xmark.circle") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                            .help("Take it off the task. The link stays in the matter.")
                    }
                }
                TextField("Paste a link — https://docs.google.com/…", text: $newLink)
                    .textFieldStyle(.roundedBorder)
                if !newLink.isEmpty, WebLink.address(in: newLink) == nil {
                    Text("This is not a web address.").font(.caption).foregroundStyle(Theme.warning)
                }
            }
            .frame(width: 360)
            Toggle("By a day", isOn: $hasDay)
            if hasDay {
                HStack {
                    DatePicker("Day", selection: $day, displayedComponents: .date).labelsHidden()
                    Toggle("Time", isOn: $hasTime)
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).labelsHidden() }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .environment(\.locale, Locale(identifier: "en_US"))
        .onAppear(perform: load)
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
            PinButton(action: talk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu { Button("Back to tasks", action: back) }
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
                PinButton(action: talk)
            }
        }
        .foregroundStyle(isPast ? .secondary : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .confirmationDialog("Delete “\(item.what)”?", isPresented: $deleting) {
            Button("Delete", role: .destructive) {
                if let appointment = item.appointment { context.delete(appointment) }
                if let deadline = item.deadline { context.delete(deadline) }
                save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.calendarID == nil ? "It goes from this matter. This cannot be undone."
                 : "It goes from this matter; the entry in Calendar stays. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var moreItems: some View {
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
                Button("Cancel", action: cancel)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(party.name).font(.body.weight(.medium))
                    if let role = membership.role { Text("· \(role)").foregroundStyle(.secondary).lineLimit(1) }
                }
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
            Text("\(membership.mentions)×").font(.caption).foregroundStyle(.secondary).padding(.trailing, 4)
            MoreMenu {
                Button("Edit name and role …") {
                    name = party.name
                    role = membership.role ?? ""
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
                        Text("The old name stays as a spelling, so new mail still finds the person.")
                            .font(.caption).foregroundStyle(.secondary).frame(width: 300, alignment: .leading)
                        HStack {
                            if let remove {
                                Button("Remove from this matter", role: .destructive) { editing = false; remove() }
                                    .help("Only from this matter. A later mail naming them will not put them back.")
                            }
                            Spacer()
                            Button("Cancel") { editing = false }
                            Button("Save") { save(name, role); editing = false }.keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(16)
                }
            PinButton(action: talk)
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
                ForEach(thread.rows) { row in
                    ThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1) { talk(row.entry) }
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
struct ThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    let talk: () -> Void
    @State private var hovering = false

    static let step: CGFloat = 20
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

    var body: some View {
        let depth = min(row.depth, Self.deepest)
        let entry = row.entry
        HStack(alignment: .top, spacing: 0) {
            if depth > 0 {
                ThreadRails(depth: depth, rails: Array(row.rails.suffix(depth - 1)), isLast: row.isLast)
                    .stroke(Theme.strongLine, lineWidth: 1.5)
                    .frame(width: CGFloat(depth) * Self.step)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Email.displayName(in: entry.from) ?? Email.address(in: entry.from)).fontWeight(.medium).lineLimit(1)
                    if started { BeeChip(text: "started") }
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    SourceLink(source: entry.source, label: Self.openLabel(entry.source.kind))
                    PinButton(action: talk).opacity(hovering ? 1 : 0)
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest).font(.callout).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
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
    @State private var hovering = false
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
            PinButton(action: talk).opacity(hovering ? 1 : 0)
            MoreMenu { moreItems }
                .popover(isPresented: $renaming, arrowEdge: .bottom) { renameField }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        // A click on the row opens the file; everything else is in ⋯ and the right click.
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .onHover { hovering = $0 }
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
        Button("Ask Matterbee", action: talk)
        Divider()
        Button("Rename …") { newName = document.shownName; renaming = true }
        if isPDF { Button("Name it from its content", action: nameIt) }
        if document.title != nil {
            Button("Use the file's own name") { document.title = nil; try? context.save() }
        }
        Divider()
        Button(document.isHidden ? "Show again" : "Hide", action: hide)
    }

    private var renameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rename file").font(.headline)
            TextField("Name", text: $newName).textFieldStyle(.roundedBorder).frame(width: 320)
                .onSubmit(saveName)
            Text("Only here in Matterbee: the file keeps its own name in the mail and in its folder.")
                .font(.caption).foregroundStyle(.secondary).frame(width: 320, alignment: .leading)
            HStack {
                Spacer()
                Button("Cancel") { renaming = false }
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
            Text("Matterbee does not open the link by itself. The assistant learns only the name, never the address.")
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
                Button("Cancel", action: cancel)
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
