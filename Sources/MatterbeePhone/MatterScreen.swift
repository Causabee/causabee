import MatterCore
import SwiftData
import SwiftUI

/// One matter on the iPhone: what to do next, the summary, the owner's notes, the tasks, the
/// dates, the people and the mail — read from the store the Mac fills. Ticking a task, writing
/// the notes and closing the matter sync back.
struct MatterScreen: View {
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var showsDone = false
    @State private var showsPast = false
    @State private var editingNotes = false
    @State private var asksToClose = false
    @State private var marked: PersistentIdentifier?
    @Query private var allMatters: [Matter]

    var body: some View {
        let status = MatterStatus(matter)
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(status)
                    if matter.isClosed { closedBanner(status) } else { nextStep(status, scroller) }
                    summary
                    notes
                    todos(status)
                    dates(status)
                    FilesSection(matter: matter)
                    parties(status)
                    history(status)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                // Exactly the screen's width: nothing on the page — a long address, a word without
                // a break — can make it wider and let it slide sideways.
                .containerRelativeFrame(.horizontal)
            }
            .onAppear { show(navigation.showing, with: scroller) }
        }
        .background(Theme.canvas)
        .overlay(alignment: .bottomTrailing) {
            AssistantButton { navigation.showsAssistant = true }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    MatterMenuItems(matter: matter, all: sidebarOrder(allMatters))
                    Divider()
                    if matter.isClosed {
                        Button("Open again", systemImage: "arrow.uturn.backward") { matter.reopen(); try? context.save() }
                    } else {
                        Button("Close the matter …", systemImage: "archivebox") { asksToClose = true }
                    }
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editingNotes) { NotesEditor(matter: matter) }
        .confirmationDialog("Close “\(matter.name)”?", isPresented: $asksToClose, titleVisibility: .visible) {
            if matter.openTodos.isEmpty {
                Button("Close") { close(markingOpenDone: false) }
            } else {
                Button("Mark all done and close") { close(markingOpenDone: true) }
                Button("Leave them open and close") { close(markingOpenDone: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The matter goes away from the overview. Nothing is deleted, and “Open again” brings it back.")
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { scroller.scrollTo(id, anchor: .center) }
            marked = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { marked = nil } }
        }
    }

    private func status(of id: PersistentIdentifier) -> Todo? { (matter.todos ?? []).first { $0.persistentModelID == id } }

    // MARK: Header

    private func header(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(matter.name).font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
            Text(meta(status)).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func meta(_ status: MatterStatus) -> String {
        let mails = (matter.entries ?? []).count
        var parts = ["\(mails) \(mails == 1 ? "mail" : "mails")"]
        if let first = status.firstDate { parts.append("since \(Dates.short(first))") }
        return parts.joined(separator: " · ")
    }

    private func closedBanner(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Closed on \(matter.closedAt.map(Dates.short) ?? "")", systemImage: "archivebox").font(.headline)
            let new = status.mailsSinceClosed.count
            Text(new == 0 ? "Nothing new since." : "\(new) new \(new == 1 ? "mail" : "mails") came after it was closed.")
                .foregroundStyle(new == 0 ? Color.secondary : Theme.warning)
            Button("Open again") { matter.reopen(); try? context.save() }.buttonStyle(.phone).padding(.top, 4)
        }
        .phoneBox()
    }

    // MARK: Next step

    /// The one thing to do now, and why: Matterbee's suggestion while nothing has changed since,
    /// else the one worked out on the device.
    @ViewBuilder
    private func nextStep(_ status: MatterStatus, _ scroller: ScrollViewProxy) -> some View {
        let rule = status.nextStep
        let fresh = matter.nextStep != nil && matter.nextStepAt.map { at in (matter.lastChange ?? .distantPast) <= at } == true
        VStack(alignment: .leading, spacing: 10) {
            if fresh, let step = matter.nextStep {
                BeeChip(text: "NEXT · FROM MATTERBEE")
                Text(step).font(.headline).fixedSize(horizontal: false, vertical: true)
                if let why = matter.nextStepWhy { Text(why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                let todo = matter.nextStepTodo.flatMap { origin in matter.openTodos.first { $0.origin == origin } }
                stepButtons(todo: todo, waiting: todo?.owner == .other, scroller)
            } else if let rule {
                BeeChip(text: rule.label.uppercased(), tone: rule.kind == .overdue || rule.kind == .followUp ? .warning : .bee)
                Text(rule.text).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(rule.why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                let todo = rule.todo.flatMap { id in matter.openTodos.first { $0.persistentModelID == id } }
                stepButtons(todo: todo, waiting: rule.kind == .followUp || rule.kind == .wait, scroller)
            } else {
                Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Nothing open.").foregroundStyle(.secondary)
            }
        }
        .phoneBox()
    }

    @ViewBuilder
    private func stepButtons(todo: Todo?, waiting: Bool, _ scroller: ScrollViewProxy) -> some View {
        if let todo {
            HStack(spacing: 8) {
                if !waiting { Button("Done") { withAnimation { toggle(todo) } }.buttonStyle(.phoneFilled) }
                Button("Show") { show(todo.persistentModelID, with: scroller) }.buttonStyle(.phone)
            }
            .padding(.top, 2)
        }
    }

    // MARK: Summary and notes

    @ViewBuilder
    private var summary: some View {
        if let text = matter.summary, !text.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    BeeChip(text: "SUMMARY")
                    if let at = matter.summaryAt { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(Array(text.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                    Text(String(line)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .phoneBox()
        }
    }

    private var notes: some View {
        let text = matter.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            HStack(alignment: .top, spacing: 12) {
                Text(text.isEmpty ? "Your own words on the matter — the assistant reads them too." : text)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(text.isEmpty ? "Write" : "Edit") { editingNotes = true }.buttonStyle(.phone)
            }
            .padding(16)
            .phoneCard()
        }
    }

    // MARK: Tasks

    private func todos(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Tasks", detail: "\(matter.openTodos.count) open · \(status.done.count) done")
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
                            Label(todo.text, systemImage: "info.circle").padding(14).frame(maxWidth: .infinity, alignment: .leading)
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
                PhoneTodoRow(todo: todo, today: status.today, showsOwner: showsOwner) { withAnimation { toggle(todo) } }
                    .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                    .id(todo.persistentModelID)
            }
        }
        .phoneCard()
    }

    private func toggle(_ todo: Todo) {
        todo.isDone.toggle()
        todo.doneAt = todo.isDone ? Date() : nil
        // Done by the owner's tap, not by a mail: there is no mail to point at.
        if !todo.isDone { todo.doneSource = nil }
        try? context.save()
    }

    // MARK: Dates

    @ViewBuilder
    private func dates(_ status: MatterStatus) -> some View {
        let coming = status.upcomingAppointments.map(PhoneDate.init) + status.deadlines.filter { $0.day >= status.today }.map(PhoneDate.init)
        let earlier = status.pastAppointments.map(PhoneDate.init) + status.deadlines.filter { $0.day < status.today }.map(PhoneDate.init)
        if !coming.isEmpty || !earlier.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appointments and deadlines", detail: "\(coming.count) coming")
                dateRows(coming.sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }, past: false)
                if !earlier.isEmpty {
                    DisclosureGroup("Past · \(earlier.count)", isExpanded: $showsPast) {
                        dateRows(earlier.sorted { ($0.day, $0.time ?? "") > ($1.day, $1.time ?? "") }, past: true).padding(.top, 6)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func dateRows(_ items: [PhoneDate], past: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider().padding(.leading, 16) }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.isDeadline ? "flag" : "calendar")
                        .foregroundStyle(item.isDeadline && !past ? Theme.warning : .secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.what).foregroundStyle(past ? .secondary : .primary).fixedSize(horizontal: false, vertical: true)
                        Text(([item.isDeadline ? "Deadline" : nil, Dates.short(item.day), item.time.map { "at \($0)" }, item.place].compactMap { $0 })
                            .joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
            if items.isEmpty {
                Text("Nothing coming.").foregroundStyle(.secondary).padding(14)
            }
        }
        .phoneCard()
    }

    // MARK: People

    @ViewBuilder
    private func parties(_ status: MatterStatus) -> some View {
        let memberships = status.memberships
        if !memberships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "People", detail: "\(memberships.count)")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(memberships.enumerated()), id: \.element.persistentModelID) { index, membership in
                        if index > 0 { Divider().padding(.leading, 16) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(membership.party?.name ?? "")
                            if let role = membership.role { Text(role).font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .phoneCard()
            }
        }
    }

    // MARK: History

    private func history(_ status: MatterStatus) -> some View {
        let entries = status.entries
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History", detail: entries.isEmpty ? "No mails yet" : "\(entries.count) \(entries.count == 1 ? "mail" : "mails")")
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.prefix(60).enumerated()), id: \.element.persistentModelID) { index, entry in
                        if index > 0 { Divider().padding(.leading, 16) }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.from).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Spacer()
                                if let date = entry.date { Text(Dates.short(date)).font(.caption).foregroundStyle(.secondary) }
                            }
                            Text(entry.title).font(.subheadline).lineLimit(2)
                            if let digest = entry.digest, !digest.isEmpty {
                                Text(digest).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }
                        .padding(14)
                    }
                }
                .phoneCard()
                if entries.count > 60 {
                    Text("… and \(entries.count - 60) older mails").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
                Text("The mails themselves stay on your Mac; here is what Matterbee kept of each.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
    }
}

/// A task with its box to tick: whose it is, by when, and where it came from.
struct PhoneTodoRow: View {
    let todo: Todo
    let today: String
    var showsOwner = false
    let toggle: () -> Void

    var body: some View {
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
                if !todo.isDone, let other = todo.waitsFor {
                    Label(other.isDone ? "its turn now — done: \(other.text)" : "only after: \(other.text)",
                          systemImage: other.isDone ? "arrow.right.circle.fill" : "hourglass")
                        .font(.footnote).foregroundStyle(other.isDone ? Theme.done : .secondary)
                }
                if let note = todo.note, !note.isEmpty {
                    Label { Text(Linked.text(note)).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "note.text") }
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach((todo.links ?? []).sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                    if let url = link.url {
                        Link(destination: url) { Label(link.shownName, systemImage: "link").font(.footnote).lineLimit(1) }
                    }
                }
                Text(line).font(.caption).foregroundStyle(lineColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .contentShape(Rectangle())
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

/// An appointment or a deadline, for one list of both.
struct PhoneDate {
    var what: String
    var day: String
    var time: String?
    var place: String?
    var isDeadline: Bool

    init(_ appointment: Appointment) {
        what = appointment.what; day = appointment.day; time = appointment.time; place = appointment.place; isDeadline = false
    }

    init(_ deadline: Deadline) {
        what = deadline.what; day = deadline.day; time = nil; place = nil; isDeadline = true
    }
}

/// The owner's notes, written on the iPhone: they sync to the Mac.
struct NotesEditor: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
                Text("The assistant reads the notes too — names in them are pseudonymised on the Mac first.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Theme.canvas)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let written = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        matter.notes = written.isEmpty ? nil : written
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { draft = matter.notes ?? ""; focused = true }
    }
}
