import EventKit
import MatterCore
import SwiftData
import SwiftUI

/// One matter on the iPhone: what to do next, the summary, the owner's notes, the tasks, the
/// dates, the people and the mail — read from the store the Mac fills. Ticking a task, writing
/// the notes and closing the matter sync back.
struct MatterScreen: View {
    /// "1 deadline open", "2 deadlines open".
    static func deadlinesOpen(_ count: Int) -> String { "\(count) \(count == 1 ? "deadline" : "deadlines") open" }
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var showsDone = false
    @State private var showsPast = false
    @State private var writingNote = false
    /// A task the owner is writing with "Add Task": in the matter while its sheet is open, taken
    /// out again if it is left without words.
    @State private var newTodo: Todo?
    @State private var asksToClose = false
    @State private var splitting = false
    @State private var find = PageFind()
    @State private var finding = false
    @FocusState private var findFocused: Bool
    @State private var newMatterName = ""
    @State private var marked: PersistentIdentifier?
    /// The page under what stands on top: what is to do, the record, or the people.
    enum Part: String { case todo, record, people, notes }
    /// The record, whole or one kind of it.
    enum RecordFilter: String { case all, mail, files, links }
    @State private var part: Part = .todo
    @State private var filter: RecordFilter = .all
    /// How much of the page is seen under the bar.
    @State private var pageHeight = CGFloat.zero
    @State private var choosingIcon = false
    /// The parts in the page have scrolled under the bar, which shows them then.
    @State private var partsUnder = false
    @State private var topInset = CGFloat.zero
    /// One person's part of the record: chosen in "People".
    @State private var person: PersistentIdentifier?
    /// Every conversation shown, not only the newest: a source pointed at an older mail.
    @State private var showsAllHistory = false
    @Query private var allMatters: [Matter]
    @Query private var profiles: [Profile]
    @Environment(PhoneStore.self) private var store
    @State private var askingStep = false
    @State private var stepError: String?
    @State private var writingSummary = false
    @State private var summaryError: String?
    /// The owner's reminders, read when the matter opens and again when Reminders changes.
    @State private var reminders: [Calendars.Reminder] = []
    @State private var calendarTick = 0

    var body: some View {
        let status = MatterStatus(matter)
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(status)
                    if matter.isClosed { closedBanner(status) } else { nextStep(status, scroller) }
                    summary
                    if find.isActive {
                        // Searching looks into every part, so everything is on the page.
                        todos(status)
                        dates(status)
                        FilesSection(matter: matter)
                        LinksSection(matter: matter)
                        PeopleSection(matter: matter)
                        notesPart
                        history(status)
                    } else {
                        parts(status)
                            .id("parts")
                            // Under the bar the pinned ones stand for them: these do not show through it.
                            .opacity(partsUnder ? 0 : 1)
                            // Gone up under the bar: then they stay at hand, pinned under it.
                            .onGeometryChange(for: Bool.self) { $0.frame(in: .global).minY < topInset } action: { under in
                                withAnimation(.easeOut(duration: 0.15)) { partsUnder = under }
                            }
                        // Where a part begins: a part chosen from the pinned tabs is shown from here.
                        Color.clear.frame(height: 0).id("part")
                        // At least as tall as the page shows: a short part does not pull the page
                        // down, and the parts stay where they were tapped.
                        VStack(alignment: .leading, spacing: 20) {
                            switch part {
                            case .todo:
                                todos(status)
                                dates(status)
                            case .record:
                                record(status)
                            case .people:
                                PeopleSection(matter: matter) { party in person = party.persistentModelID; filter = .all; part = .record }
                            case .notes:
                                notesPart
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: max(0, pageHeight - 120), alignment: .topLeading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                // Exactly the screen's width: nothing on the page — a long address, a word without
                // a break — can make it wider and let it slide sideways.
                .containerRelativeFrame(.horizontal)
                // A tap on the page puts the keyboard away. Behind the page, not over it: a tap
                // gesture over the scroll view takes the taps from the system's segmented control.
                .background {
                    Color.clear.contentShape(Rectangle()).onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { pageHeight = $1 }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.top } action: { topInset = $1 }
            // Another part chosen from the pinned tabs: it is shown from its start, not from where the last one was read.
            .onChange(of: part) {
                // Right under the pinned tabs, which stay: the part's start at their lower edge.
                if partsUnder { scroller.scrollTo("part", anchor: UnitPoint(x: 0.5, y: 44 / max(pageHeight, 200))) }
            }
            // Over the page, not in it: the page keeps its place when they come and go.
            .overlay(alignment: .top) {
                if partsUnder, !find.isActive {
                    parts(status)
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
                        .background(.bar, ignoresSafeAreaEdges: .top)
                        .overlay(alignment: .bottom) { Divider() }
                        .transition(.opacity)
                }
            }
            .onAppear { show(navigation.showing, with: scroller); loadCalendars() }
            // Asked to show a task while the page is open already — from a card in the assistant.
            .onChange(of: navigation.showing) { if navigation.showing != nil { show(navigation.showing, with: scroller) } }
            .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in loadCalendars() }
            .onPreferenceChange(PageFindMatches.self) { found in
                MainActor.assumeIsolated {
                    find.matches = found
                    if find.index >= found.count { find.index = 0 }
                }
            }
            .onChange(of: find.query) {
                find.index = 0
                // What is folded away is looked into too.
                if find.isActive { showsDone = true; showsPast = true }
            }
            .onChange(of: find.current) { if let at = find.current { withAnimation { scroller.scrollTo(at, anchor: .center) } } }
        }
        .environment(find)
        .safeAreaInset(edge: .top) { if finding { findBar } }
        .background(Theme.canvas)
        .overlay(alignment: .bottomTrailing) {
            // Not over the keyboard while finding.
            if !finding { AssistantButton { navigation.showsAssistant = true } }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { startFinding() } label: { Image(systemName: "magnifyingglass") }
                    .tint(.primary)
                    .accessibilityLabel("Find in this matter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Glasses, as on the Mac: on, black on the bee's yellow.
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
                } label: {
                    Image(systemName: "eyeglasses")
                        .foregroundStyle(navigation.reading ? Color.black : Color.primary)
                        .frame(width: 30, height: 30)
                        .background { if navigation.reading { Circle().fill(Theme.bee) } }
                }
                .accessibilityLabel(navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    MatterMenuItems(matter: matter, all: sidebarOrder(allMatters))
                    Divider()
                    if matter.isClosed {
                        Button("Open again", systemImage: "arrow.uturn.backward") { matter.reopen(); try? context.save() }
                    } else {
                        Button("Close", systemImage: "archivebox") { asksToClose = true }
                    }
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $newTodo, onDismiss: dropEmptyTodos) { todo in PhoneTodoEditor(todo: todo, isNew: true) }
        .confirmationDialog(closeQuestion, isPresented: $asksToClose, titleVisibility: .visible) {
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

    private var closeQuestion: String {
        let open = matter.openTodos.count
        return open == 0 ? "Close “\(matter.name)”?"
            : "Close “\(matter.name)”? \(open) \(open == 1 ? "task is" : "tasks are") still open."
    }

    private func close(markingOpenDone: Bool) {
        matter.close(markingOpenDone: markingOpenDone)
        try? context.save()
    }

    /// The task an overdue line pointed at: scrolled to and marked for a moment.
    private func show(_ id: PersistentIdentifier?, with scroller: ScrollViewProxy) {
        guard let id else { return }
        navigation.showing = nil
        if status(of: id)?.isDone == true { showsDone = true }
        // The part of the page it is in, with nothing filtered away.
        if (matter.todos ?? []).contains(where: { $0.persistentModelID == id })
            || (matter.appointments ?? []).contains(where: { $0.persistentModelID == id })
            || (matter.deadlines ?? []).contains(where: { $0.persistentModelID == id }) {
            part = .todo
        } else if matter.parties.contains(where: { $0.persistentModelID == id }) {
            part = .people
        } else {
            part = .record; filter = .all; person = nil
        }
        // A source of an answer can be anything on the page: what is folded away is unfolded for it.
        let today = MatterStatus(matter).today
        if (matter.appointments ?? []).contains(where: { $0.persistentModelID == id && $0.day < today })
            || (matter.deadlines ?? []).contains(where: { $0.persistentModelID == id && $0.day < today }) { showsPast = true }
        if (matter.entries ?? []).contains(where: { $0.persistentModelID == id }) { showsAllHistory = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { scroller.scrollTo(id, anchor: .center) }
            marked = id
            find.shown = id
            Haptics.landed()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { marked = nil; if find.shown == id { find.shown = nil } } }
        }
    }

    private func status(of id: PersistentIdentifier) -> Todo? { (matter.todos ?? []).first { $0.persistentModelID == id } }

    // MARK: Header

    private func header(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // The matter's icon in front of its name, level with the first line: a tap chooses another.
                Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 36) }
                    .buttonStyle(.plain)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 7 }
                    .accessibilityLabel("Icon").accessibilityHint("Chooses another icon")
                // The count under the name, on the name's left edge — not under the icon.
                VStack(alignment: .leading, spacing: 4) {
                    Text(matter.name).font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
                    Text(meta(status)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
        .sheet(isPresented: $choosingIcon) {
            MatterIconPicker(matter: matter).presentationDetents([.height(470)]).presentationDragIndicator(.visible)
        }
    }

    private func meta(_ status: MatterStatus) -> String {
        let mails = (matter.entries ?? []).count
        var parts = ["\(mails) \(mails == 1 ? "mail" : "mails")"]
        if let first = status.firstDate { parts.append("since \(Dates.short(first))") }
        return parts.joined(separator: " · ")
    }

    // MARK: Find

    /// Under the bar while finding: the words, how many rows have them, and the way between them.
    private var findBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find in this matter", text: $find.query)
                    .focused($findFocused)
                    .submitLabel(.next)
                    .onSubmit { find.next(); findFocused = true }
                    .autocorrectionDisabled()
                if find.isActive {
                    Text(find.matches.isEmpty ? "none" : "\(find.index + 1) of \(find.matches.count)")
                        .font(.footnote.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.box, in: Capsule())
            Button(action: find.previous) { Image(systemName: "chevron.up") }
                .disabled(find.matches.isEmpty).accessibilityLabel("Previous")
            Button(action: find.next) { Image(systemName: "chevron.down") }
                .disabled(find.matches.isEmpty).accessibilityLabel("Next")
            Button("Done") { stopFinding() }.fontWeight(.semibold)
        }
        .tint(.primary)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.canvas)
    }

    private func startFinding() {
        withAnimation(.easeOut(duration: 0.2)) { finding = true }
        findFocused = true
    }

    private func stopFinding() {
        find.query = ""
        findFocused = false
        withAnimation(.easeOut(duration: 0.2)) { finding = false }
    }

    private func closedBanner(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Closed on \(matter.closedAt.map(Dates.short) ?? "")", systemImage: "archivebox").font(.headline)
            let new = status.mailsSinceClosed.count
            Text(new == 0 ? "Nothing new since." : "\(new) new \(new == 1 ? "mail" : "mails") came after it was closed.")
                .foregroundStyle(new == 0 ? Color.secondary : Theme.warning)
            HStack(spacing: 10) {
                if new > 0 {
                    // The new mails, with what they brought, become a matter of their own; this one stays closed.
                    Button("Start a new matter") {
                        newMatterName = Matter.suggestedName(for: status.mailsSinceClosed)
                        splitting = true
                    }
                    .buttonStyle(.phoneFilled)
                }
                Button("Open again") { matter.reopen(); try? context.save() }.buttonStyle(.phone)
            }
            .padding(.top, 4)
        }
        .phoneBox()
        .alert("A new matter with the \(status.mailsSinceClosed.count) new \(status.mailsSinceClosed.count == 1 ? "mail" : "mails")", isPresented: $splitting) {
            TextField("Name", text: $newMatterName)
            Button("Cancel", role: .cancel) {}
            Button("Start", action: startNewMatter)
                .disabled(newMatterName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Their tasks, dates, files and links go with them. “\(matter.name)” stays closed.")
        }
    }

    private func startNewMatter() {
        let mails = MatterStatus(matter).mailsSinceClosed
        let name = newMatterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mails.isEmpty, !name.isEmpty,
              let new = try? matter.split(mails, intoNewMatterNamed: name, turnsSince: matter.closedAt, in: context) else { return }
        try? context.save()
        // The new matter in place of the closed one: back goes to the overview.
        if navigation.path.last == matter.persistentModelID { navigation.path.removeLast() }
        navigation.open(new)
    }

    // MARK: Next step

    /// The one thing to do now, and why: Causabee's suggestion while nothing has changed since,
    /// else the one worked out on the device.
    @ViewBuilder
    private func nextStep(_ status: MatterStatus, _ scroller: ScrollViewProxy) -> some View {
        let rule = status.nextStep
        let fresh = matter.nextStep != nil && matter.nextStepAt.map { at in (matter.lastChange ?? .distantPast) <= at } == true
        VStack(alignment: .leading, spacing: 10) {
            if fresh, let step = matter.nextStep {
                BeeChip(text: "NEXT · FROM CAUSABEE")
                Text(step).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), step, matter.nextStepWhy)
                if let why = matter.nextStepWhy { Text(why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() }
                let todo = matter.nextStepTodo.flatMap { origin in matter.openTodos.first { $0.origin == origin } }
                stepButtons(text: step, todo: todo, waiting: todo?.owner == .other, scroller).tool()
            } else if let rule {
                BeeChip(text: rule.label.uppercased(), tone: rule.kind == .overdue || rule.kind == .followUp ? .warning : .bee)
                Text(rule.text).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), rule.text, rule.why)
                Text(rule.why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation()
                // As on the Mac: a step worked out on the device has buttons when it is a task.
                if let todo = rule.todo.flatMap({ id in matter.openTodos.first { $0.persistentModelID == id } }) {
                    stepButtons(text: todo.text, todo: todo, waiting: rule.kind == .followUp || rule.kind == .wait, scroller).tool()
                }
            } else {
                Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Nothing open.").foregroundStyle(.secondary)
            }
            // Asking Claude, below the buttons: apart from what the step itself offers — as on the Mac.
            let cost = String(format: "≈ %.1f cents", AssistantAsk.nextStepEstimate(summaryFacts, model: ModelChoice.assistant) * 100)
            HStack(spacing: 4) {
                if askingStep {
                    BeeLoader(size: 12)
                    Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary)
                } else {
                    // An older suggestion says only its day; the link beside it says what to do.
                    if let at = matter.nextStepAt, matter.nextStep != nil, !fresh {
                        Text("From \(Dates.short(at)) ·").font(.caption).foregroundStyle(.secondary)
                    }
                    Button((fresh ? "ask again · " : "Suggest better · ") + cost, action: askStep)
                        .font(.caption).underline().foregroundStyle(.secondary)
                }
            }
            .tool()
            if let stepError { Text(stepError).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
        }
        .phoneBox()
    }

    /// The facts the step and the summary are asked from: this matter's, the last 40 mails.
    private var summaryFacts: Facts { FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), mails: 40) }

    /// The names the iPhone asks with: its own list, or a Mac's until it keeps one — or, in the
    /// demo, none: its people are made up.
    private func names() throws -> (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry]) {
        store.isDemo ? (Pseudonymizer.Mapping(), []) : try PhoneNames.current(in: context)
    }

    private func askStep() {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { stepError = ModelChoice.missingKey(model); return }
        let list: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        do { list = try names() } catch { stepError = error.localizedDescription; return }
        askingStep = true
        stepError = nil
        let facts = summaryFacts
        let owner = profiles.first?.names.first
        Task {
            do {
                let (step, why, ref, _) = try await AssistantAsk.nextStep(facts: facts, owner: owner, today: MatterStatus.day(Date()),
                                                                          mapping: list.mapping, others: list.others, claude: claude, model: model)
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

    private func writeSummary() {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { summaryError = ModelChoice.missingKey(model); return }
        let list: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        do { list = try names() } catch { summaryError = error.localizedDescription; return }
        writingSummary = true
        summaryError = nil
        let facts = summaryFacts
        let owner = profiles.first?.names.first
        Task {
            do {
                let (lines, _) = try await AssistantAsk.summarize(facts: facts, owner: owner, today: MatterStatus.day(Date()),
                                                                  mapping: list.mapping, others: list.others, claude: claude, model: model)
                matter.summary = lines.joined(separator: "\n")
                matter.summaryAt = Date()
                try? context.save()
            } catch {
                summaryError = plainWords(error)
            }
            writingSummary = false
        }
    }

    /// What can be done with the step right here, as on the Mac: write the message it is, tick it
    /// off, see it — or talk it over.
    @ViewBuilder
    private func stepButtons(text: String, todo: Todo?, waiting: Bool, _ scroller: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            if waiting {
                Button("Write follow-up") {
                    navigation.talk(todo?.text ?? text, kind: todo == nil ? "Step" : "Task", in: matter,
                                    prefill: "Write a short, friendly follow-up about this.")
                }
                .buttonStyle(.phoneFilled)
            } else if Todo.isMessage(text) || todo?.isMessage == true {
                Button("Write message") {
                    navigation.talk(todo?.text ?? text, kind: todo == nil ? "Step" : "Task", in: matter,
                                    prefill: "Write a short message about this.")
                }
                .buttonStyle(.phoneFilled)
            }
            if let todo {
                if !waiting { Button("Done") { withAnimation { toggle(todo) } }.buttonStyle(.phone) }
                Button("Show") { show(todo.persistentModelID, with: scroller) }.buttonStyle(.phone)
            } else if !waiting, !Todo.isMessage(text) {
                Button("Talk it over") { navigation.talk(text, kind: "Step", in: matter) }.buttonStyle(.phone)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Summary and notes

    /// Three or four lines on top, written only when asked for, and dated — as on the Mac.
    @ViewBuilder
    private var summary: some View {
        let cost = String(format: "≈ %.1f cents", AssistantAsk.summaryEstimate(summaryFacts, model: ModelChoice.assistant) * 100)
        let text = matter.summary ?? ""
        VStack(alignment: .leading, spacing: 10) {
            if !text.isEmpty {
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
            HStack(spacing: 8) {
                if writingSummary {
                    BeeLoader(size: 12)
                    Text("Writing the summary …").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if matter.summaryAt != nil {
                    Button("Update · \(cost)", action: writeSummary).font(.caption).underline().foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Spacer()
                    Button("Write summary · \(cost)", action: writeSummary).buttonStyle(.phone)
                }
            }
            .tool()
            if let summaryError { Text(summaryError).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(text.isEmpty ? 0 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(text.isEmpty ? Color.clear : Theme.box, in: RoundedRectangle(cornerRadius: 12))
    }

    /// The owner's own words on the matter: small dated blocks, read by the assistant too.
    private var notesPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            NotesPart(matter: matter, writing: $writingNote)
        }
    }

    // MARK: Tasks

    /// Any task at all, open or done — one being written with "Add Task" not yet among them.
    private var hasTodos: Bool { (matter.todos ?? []).contains { $0 !== newTodo } }

    /// "Add Task": an empty task of the owner's, opened in the editor.
    private func addTodo() {
        let todo = Todo(text: "", owner: .me, due: nil, source: Source(kind: .conversation, pointer: "you", date: Date()),
                        origin: "you#" + UUID().uuidString)
        context.insert(todo)
        todo.matter = matter
        newTodo = todo
    }

    /// A task closed without words was never there.
    private func dropEmptyTodos() {
        for todo in matter.todos ?? [] where todo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(todo)
        }
        try? context.save()
    }

    private func todos(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Tasks", detail: hasTodos ? "\(matter.openTodos.count) open · \(status.done.count) done" : nil)
                if hasTodos {
                    Button("Task", systemImage: "plus", action: addTodo)
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold)
                        .tool()
                }
            }
            if !hasTodos {
                PhoneEmptyBox(text: "What is to do, and whose. Tasks in mail are found when it is sorted in.",
                              action: "Add Task", symbol: "checklist", run: addTodo)
            }
            let overdue = status.overdue.sorted { ($0.due ?? "") < ($1.due ?? "") }
            let late = Set(overdue.map(\.persistentModelID))
            if !overdue.isEmpty {
                group("Overdue · \(overdue.count)", color: Theme.warning, overdue, status, showsOwner: true)
            }
            ForEach([(Todo.Owner.me, "Mine"), (.we, "Ours"), (.other, "Waiting for"), (.unknown, "Unclear whose")], id: \.1) { owner, title in
                let todos = status.open(owner).filter { !late.contains($0.persistentModelID) && !$0.isBlocked }
                if !todos.isEmpty { group("\(title) · \(todos.count)", todos, status) }
            }
            let blocked = matter.openTodos.filter(\.isBlocked).sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
            if !blocked.isEmpty {
                group("Only after · \(blocked.count)", color: .secondary, blocked, status, showsOwner: true)
            }
            let infos = matter.infos
            if !infos.isEmpty {
                DisclosureGroup("Info · \(infos.count)") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(infos.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { Divider().padding(.leading, 16) }
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle").foregroundStyle(.secondary).font(.title3)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(todo.text).fixedSize(horizontal: false, vertical: true)
                                        .findable(.model(todo.persistentModelID), todo.text)
                                    Text(Sources.origin(todo.sources.first)).font(.caption).foregroundStyle(.secondary)
                                    // A task after all: it goes back to the open tasks.
                                    Button("Back to tasks", systemImage: "arrow.uturn.backward") {
                                        withAnimation { todo.isInfo = false }
                                        try? context.save()
                                    }
                                    .font(.footnote).foregroundStyle(Theme.gold)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                        }
                    }
                    .phoneCard().padding(.top, 6)
                }
                .padding(.horizontal, 4)
            }
            if !status.done.isEmpty {
                DisclosureGroup("Done · \(status.done.count)", isExpanded: $showsDone) {
                    rows(status.done, status, showsOwner: false).padding(.top, 6)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func group(_ title: String, color: Color = .primary, _ todos: [Todo], _ status: MatterStatus, showsOwner: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 4).padding(.top, 4)
            rows(todos, status, showsOwner: showsOwner)
        }
    }

    private func rows(_ todos: [Todo], _ status: MatterStatus, showsOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(todos.enumerated()), id: \.element.persistentModelID) { index, todo in
                if index > 0 { Divider().padding(.leading, 50) }
                PhoneTodoRow(todo: todo, today: status.today, showsOwner: showsOwner, reminders: reminders, calendarTick: calendarTick) { withAnimation { toggle(todo) } }
                    .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                    // Also its place to scroll to, from an overdue line or the page search.
                    .findable(.model(todo.persistentModelID), todo.text, todo.note)
            }
        }
        .phoneCard()
    }

    private func toggle(_ todo: Todo) {
        todo.isDone.toggle()
        if todo.isDone { Haptics.success() } else { Haptics.tap() }
        todo.doneAt = todo.isDone ? Date() : nil
        // Done by the owner's tap, not by a mail: there is no mail to point at.
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
                PhoneEmptyBox(text: "Appointments and deadlines are found in mail when it is sorted in. A task can have a day too.")
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appointments and deadlines", detail: "\(upcoming.count) coming · \(Self.deadlinesOpen(deadlines.filter { $0.day >= status.today }.count))")
                CalendarAccessBanner { loadCalendars() }
                let rows: [PhoneDateRow.Item] = upcoming.map(PhoneDateRow.Item.init) + deadlines.filter { $0.day >= status.today }.map(PhoneDateRow.Item.init)
                dateRows(rows.sorted { $0.day != $1.day ? $0.day < $1.day : PhoneDateRow.Item.sameDay($0, $1) }, past: false)
                let earlier: [PhoneDateRow.Item] = past.map(PhoneDateRow.Item.init) + deadlines.filter { $0.day < status.today }.map(PhoneDateRow.Item.init)
                if !earlier.isEmpty {
                    DisclosureGroup("Past · \(earlier.count)", isExpanded: $showsPast) {
                        dateRows(earlier.sorted { $0.day != $1.day ? $0.day > $1.day : PhoneDateRow.Item.sameDay($0, $1) }, past: true).padding(.top, 6)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func dateRows(_ items: [PhoneDateRow.Item], past: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider().padding(.leading, 14) }
                PhoneDateRow(item: item, isPast: past, matter: matter, tick: calendarTick)
                    .findable(item.findID, item.what, item.place)
            }
            if items.isEmpty {
                Text("Nothing coming.").foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .phoneCard()
    }

    /// The owner's reminders, read when the matter opens and again when Reminders changes.
    private func loadCalendars() {
        Task {
            reminders = await Calendars.shared.allReminders()
            calendarTick += 1
        }
    }

    // MARK: People

    // MARK: Parts

    private var shownDocuments: [MatterCore.Document] { (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage } }
    private var keptLinks: [WebLink] { (matter.links ?? []).filter(\.isKept) }
    private var personParty: Party? { person.flatMap { id in matter.parties.first { $0.persistentModelID == id } } }

    /// What is to do, the record, the people: the system's own segmented control.
    private func parts(_ status: MatterStatus) -> some View {
        Picker("Part of the matter", selection: $part) {
            Text("To do · \(matter.openTodos.count)").tag(Part.todo)
            Text("Record · \(status.entries.count + shownDocuments.count + keptLinks.count)").tag(Part.record)
            Text("People · \(status.memberships.count)").tag(Part.people)
            Text("Notes · \(matter.noteCount)").tag(Part.notes)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// Whether this person wrote it: by any way their name is written.
    private func wrote(_ party: Party, _ from: String?) -> Bool {
        guard let from else { return false }
        let keys = Set(([party.name] + party.spellings).map(PartyNames.key))
        return keys.contains(PartyNames.key(Email.displayName(in: from) ?? Email.address(in: from)))
    }

    /// Everything that came in or was added — mail, files, links — as one list, or one kind of it.
    @ViewBuilder
    private func record(_ status: MatterStatus) -> some View {
        HStack(spacing: 10) {
            // Which kind of it: a slim menu, not a second row of tabs under the parts.
            Menu {
                Picker("Show", selection: $filter) {
                    Text("Everything").tag(RecordFilter.all)
                    Text("Mail").tag(RecordFilter.mail)
                    Text("Files").tag(RecordFilter.files)
                    Text("Links").tag(RecordFilter.links)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(filter == .all ? "Everything" : filter.rawValue.capitalized)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline)
                .padding(.vertical, 4).contentShape(Rectangle())
            }
            // Grey, not the gold a menu takes from the app.
            .tint(Color.secondary)
            .accessibilityLabel("Show")
            if let party = personParty, filter == .all {
                Button { person = nil } label: { Label(party.name, systemImage: "xmark.circle.fill") }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small).tint(.primary)
                    .accessibilityHint("Shows everyone's again")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        switch filter {
        case .all: recordList(status)
        case .mail: history(status)
        case .files: FilesSection(matter: matter)
        case .links: LinksSection(matter: matter)
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
        let threads = MailThreads.build(status.entries).filter { thread in
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
            PhoneEmptyBox(text: party == nil ? "Mail sorted into this matter, its files and links show here, newest first."
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
                            PhoneThreadCard(thread: thread, matter: matter)
                            ForEach((attached[thread.id] ?? []).filter { !$0.isOwnFile }) { document in FilesSection(matter: matter, only: document) }
                        }
                    case .document(let document):
                        FilesSection(matter: matter, only: document)
                    case .link(let link):
                        PhoneLinkRow(link: link, todos: matter.openTodos) {
                            withAnimation { context.delete(link) }
                            try? context.save()
                        }
                        .findable(.model(link.persistentModelID), link.shownName, link.address)
                        .phoneCard()
                    }
                }
            }
        }
        if all.count > visible.count {
            Button("… and \(all.count - visible.count) older — show them") { showsAllHistory = true }
                .font(.caption).foregroundStyle(Theme.gold).padding(.horizontal, 4)
        }
    }

    // MARK: History

    /// The mail, as the Mac shows it: conversation by conversation, the newest first, each reply
    /// under the mail it answers — until about 60 mails are shown.
    private func history(_ status: MatterStatus) -> some View {
        let threads = MailThreads.build(status.entries)
        var shown = 0
        let visible = threads.prefix { thread in defer { shown += thread.count }; return shown < 60 || showsAllHistory }
        let hidden = threads.count - visible.count
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History", detail: Self.count(status.entries)
                          + (threads.count == status.entries.count ? "" : " in \(threads.count) \(threads.count == 1 ? "conversation" : "conversations")"))
            if status.entries.isEmpty {
                PhoneEmptyBox(text: "Mail sorted into this matter shows here, newest first. It comes from your mailbox, not by hand.")
            }
            ForEach(visible) { thread in
                PhoneThreadCard(thread: thread, matter: matter)
            }
            if hidden > 0 {
                Text("… and \(hidden) older \(hidden == 1 ? "conversation" : "conversations")").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
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
}

/// A task with its box to tick: whose it is, by when, and where it came from.
struct PhoneTodoRow: View {
    let todo: Todo
    let today: String
    var showsOwner = false
    /// The owner's reminders, for the Reminders chip; nil where none is shown.
    var reminders: [Calendars.Reminder]? = nil
    var calendarTick = 0
    let toggle: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        // Taken back with Undo in the assistant, the task is gone while this row is drawn once more:
        // a deleted model must not be read — SwiftData stops the app.
        if todo.isDeleted || todo.modelContext == nil { EmptyView() } else { row }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(todo.isDone ? Theme.onInk : .secondary, todo.isDone ? Theme.ink : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Open again" : "Mark as done")
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.text)
                    .foregroundStyle(todo.isDone || todo.isBlocked ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let reminders, !todo.isDone, !todo.isInfo, todo.owner == .me || todo.owner == .we || todo.reminderID != nil {
                    CalendarChip(kind: .reminder, linkedID: todo.reminderID, title: todo.text, day: todo.due, time: todo.dueTime,
                                 note: todo.note, matterName: todo.matter?.name ?? "", reminders: reminders, tick: calendarTick) { id in
                        todo.reminderID = id
                        todo.reminderStamp = nil
                        try? context.save()
                    }
                }
                if !todo.isDone, let other = todo.waitsFor {
                    Label(other.isDone ? "its turn now — done: \(other.text)" : "only after: \(other.text)",
                          systemImage: other.isDone ? "arrow.right.circle.fill" : "hourglass")
                        .font(.footnote).foregroundStyle(other.isDone ? Theme.done : .secondary)
                }
                if let note = todo.note, !note.isEmpty {
                    // The owner's note under the task, as words alone: an icon would only add clutter.
                    Text(Linked.text(note)).fixedSize(horizontal: false, vertical: true)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let note = todo.note, !note.isEmpty {
                    let loose = WebLink.split(note: note).links.filter { found in !(todo.links ?? []).contains { $0.address == found.address } }
                    if !loose.isEmpty {
                        Button(loose.count == 1 ? "Save as link" : "Save \(loose.count) links") { keepLinks(from: note) }
                            .font(.caption).foregroundStyle(Theme.gold)
                    }
                }
                ForEach((todo.links ?? []).sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                    if let url = link.url {
                        Link(destination: url) { Label(link.shownName, systemImage: "link").font(.footnote).lineLimit(1) }
                    }
                }
                Text(line).font(.caption).foregroundStyle(lineColor)
            }
            Spacer(minLength: 0)
            // The Mac's ⋯: change it by hand, say it is only worth knowing, what it waits for.
            Menu { moreItems } label: {
                Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .tint(.secondary)
            .accessibilityLabel("More")
            // While reading, a long press still has everything.
            .tool()
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .sheet(isPresented: $editing) { PhoneTodoEditor(todo: todo) }
        .confirmationDialog("Delete “\(todo.text)”?", isPresented: $deleting, titleVisibility: .visible) {
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

    @ViewBuilder
    private var moreItems: some View {
        // Short, one line each, with an icon; one line only, above Delete.
        if let matter = todo.matter {
            AskCausabeeButton { navigation.talk(todo.text, kind: todo.isInfo ? "Info" : "Task", in: matter) }
        }
        Button("Edit", systemImage: "pencil") { editing = true }
        if !todo.isDone {
            Button("Move to Info", systemImage: "info.circle") {
                withAnimation { todo.isInfo = true }
                try? context.save()
            }
            let others = (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text < $1.text }
            Menu("Waits for", systemImage: "hourglass") {
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
                Button("Stop waiting", systemImage: "xmark.circle") {
                    withAnimation { todo.waitsFor = nil }
                    try? context.save()
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { deleting = true }
    }

    /// The addresses in the note become the task's links, and their lines leave the note.
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

    private var line: String {
        var parts: [String] = []
        if showsOwner { parts.append(["me": "Mine", "we": "Ours", "other": "Waiting for"][todo.owner.rawValue] ?? "Unclear whose") }
        if let due = todo.due {
            parts.append((!todo.isDone && due < today ? "Overdue since " : "by ") + Dates.short(due) + (todo.dueTime.map { " at \($0)" } ?? ""))
        }
        if todo.isDone {
            parts.append(todo.doneSource == nil ? "done by you" : "done, says the mail of \(todo.doneSource?.date.map(Dates.short) ?? "?")")
        } else {
            parts.append(Sources.origin(todo.sources.first))
        }
        return parts.joined(separator: " · ")
    }

    private var lineColor: Color {
        if todo.isDone { return Theme.done }
        if let due = todo.due, due < today { return Theme.warning }
        return .secondary
    }
}

/// A task put right by hand, as the Mac's editor: its words, a note, whose it is, what it waits
/// for, its links, and by when — a day, and a time if wanted.
struct PhoneTodoEditor: View {
    let todo: Todo
    /// A task just started with "Add Task": "New task", and nothing to add until it has words.
    var isNew = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
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

    private var others: [Todo] { (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text < $1.text } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What to do", text: $text, axis: .vertical).lineLimit(2...5)
                    TextField("Note — a list, a detail, what was agreed", text: $note, axis: .vertical).lineLimit(2...8)
                }
                Section {
                    Picker("Whose", selection: $owner) {
                        Text("Mine").tag(Todo.Owner.me)
                        Text("Ours").tag(Todo.Owner.we)
                        Text("Waiting for").tag(Todo.Owner.other)
                        Text("Unclear whose").tag(Todo.Owner.unknown)
                    }
                    // A menu, not the Mac's segments: four of them do not fit a phone's width in full.
                    .pickerStyle(.menu)
                    if !others.isEmpty {
                        Picker("Only after", selection: $after) {
                            Text("nothing — can go any time").tag(PersistentIdentifier?.none)
                            ForEach(others, id: \.persistentModelID) { other in Text(other.text).lineLimit(1).tag(Optional(other.persistentModelID)) }
                        }
                        if circle {
                            Text("The other one already waits for this one — neither could ever be done.").font(.footnote).foregroundStyle(Theme.warning)
                        }
                    }
                }
                Section {
                    ForEach((todo.links ?? []).sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                        HStack {
                            Label(link.shownName, systemImage: "link").lineLimit(1)
                            Spacer()
                            // Off the task; the link stays in the matter.
                            Button { link.todo = nil } label: { Image(systemName: "xmark.circle") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Paste a link — https://docs.google.com/…", text: $newLink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    if !newLink.isEmpty, WebLink.address(in: newLink) == nil {
                        Text("This is not a web address.").font(.footnote).foregroundStyle(Theme.warning)
                    }
                } header: { Text("Links") }
                Section {
                    Toggle("By a day", isOn: $hasDay)
                    if hasDay {
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                        Toggle("Time", isOn: $hasTime)
                        if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "en_US"))
            .navigationTitle(isNew ? "New task" : "Change task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", action: save)
                        .disabled(isNew && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
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

    /// As the Mac saves it: a wait in a circle stops the save before anything is changed.
    private func save() {
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
        try? context.save()
        dismiss()
    }
}

/// An appointment or a deadline, as the Mac's date row: the day on the left, what it is, its kind
/// and place, whether it is in Calendar — and its ⋯: talk about it, change it, delete it.
struct PhoneDateRow: View {
    struct Item {
        var day: String
        var time: String?
        var what: String
        var place: String?
        var kind: String
        var appointment: Appointment?
        var deadline: Deadline?

        var findID: PageFind.ID {
            if let id = appointment?.persistentModelID ?? deadline?.persistentModelID { return .model(id) }
            return .section("date \(day) \(what)")
        }

        /// On the same day: the whole-day ones first, then by the hour, then by name.
        static func sameDay(_ a: Item, _ b: Item) -> Bool {
            let (x, y) = (a.time ?? "", b.time ?? "")
            return x != y ? x < y : a.what.localizedStandardCompare(b.what) == .orderedAscending
        }

        init(_ appointment: Appointment) {
            (day, time, what, place, kind) = (appointment.day, appointment.time, appointment.what, appointment.place, "Appointment")
            self.appointment = appointment
        }

        init(_ deadline: Deadline) {
            (day, time, what, place, kind) = (deadline.day, nil, deadline.what, nil, "Deadline")
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
    let matter: Matter
    var tick = 0
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Dates.short(item.day)).font(.subheadline.weight(.semibold))
                if let time = item.time { Text(time).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.what).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(item.kind).font(.caption.weight(.medium))
                        .foregroundStyle(item.kind == "Deadline" ? Theme.warning : .secondary)
                    if let place = item.place { Text(place).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
                if !isPast || item.calendarID != nil {
                    CalendarChip(kind: .event, linkedID: item.calendarID, title: item.what, day: item.day, time: item.time,
                                 place: item.place, matterName: matter.name, tick: tick) { id in item.connect(id); try? context.save() }
                }
            }
            Spacer(minLength: 0)
            Menu { moreItems } label: {
                Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .tint(.secondary)
            .accessibilityLabel("More")
            // While reading, a long press still has everything.
            .tool()
        }
        .foregroundStyle(isPast ? .secondary : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { moreItems }
        .sheet(isPresented: $editing) { PhoneDateEditor(item: item) }
        .confirmationDialog("Delete “\(item.what)”?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let appointment = item.appointment { context.delete(appointment) }
                if let deadline = item.deadline { context.delete(deadline) }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.calendarID == nil ? "It goes from this matter. This cannot be undone."
                 : "It goes from this matter; the entry in Calendar stays. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var moreItems: some View {
        AskCausabeeButton { navigation.talk(item.what, kind: item.kind, in: matter) }
        Button("Edit", systemImage: "pencil") { editing = true }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { deleting = true }
    }
}

/// An appointment or a deadline put right by hand, as the Mac's editor: what, which day, and for
/// an appointment the time and the place. A connected Calendar entry follows on the next sync.
struct PhoneDateEditor: View {
    let item: PhoneDateRow.Item
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var what = ""
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var place = ""

    private var isAppointment: Bool { item.appointment != nil }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What", text: $what, axis: .vertical).lineLimit(1...4)
                DatePicker("Day", selection: $day, displayedComponents: .date)
                if isAppointment {
                    Toggle("Time", isOn: $hasTime)
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    TextField("Place", text: $place)
                }
            }
            .environment(\.locale, Locale(identifier: "en_US"))
            .navigationTitle(isAppointment ? "Change appointment" : "Change deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveChanges).disabled(what.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
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
        try? context.save()
        dismiss()
    }
}
