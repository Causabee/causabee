import MatterCore
import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

// The record's conversations and the links between it and the tasks and dates: one code for the
// Mac, the iPhone and the iPad. Only sizes and the menus' own look differ by screen.

/// One conversation of a matter: its subject once, the first mail on top, and each reply under
/// the mail it answers, joined by a line. Under each mail, what came from it.
struct ThreadCard: View {
    let thread: MailThreads.Thread
    /// What came from each mail; nil where it is not shown.
    var links: RecordLinks? = nil
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
                    ThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1, sent: me.sent(row.entry.from),
                                  made: links?.made(from: row.entry) ?? RecordLinks.Made(), joinsNext: joined.contains(row.id)) { talk(row.entry) }
                        .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(macOS)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        #else
        .phoneCard()
        #endif
    }

    private var span: String {
        let first = thread.first.map(Dates.short) ?? "", last = thread.last.map(Dates.short) ?? ""
        return first == last ? first : "\(first) – \(last)"
    }
}

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

/// One mail in a conversation, set in by how deep it answers, with the lines to the mail it
/// answers drawn on its left, and under it what came from it.
struct ThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    /// The owner wrote it: it went out, the others came in.
    let sent: Bool
    var made = RecordLinks.Made()
    /// At the deepest indent and answered: its line goes on down to its answer.
    var joinsNext = false
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var naming = false
    @State private var newName = ""

    #if os(macOS)
    nonisolated static let step: CGFloat = 20
    /// How far in replies go; deeper ones stay at this depth.
    static let deepest = 4
    #else
    nonisolated static let step: CGFloat = 16
    static let deepest = 3
    #endif

    /// A letter scanned and taken in is no mail: the button says what it opens.
    static func openLabel(_ kind: Source.Kind) -> String {
        switch kind {
        case .screenshot: "Open screenshot"
        case .document: "Open document"
        case .photo: "Open photo"
        default: "Open mail"
        }
    }

    /// The mail itself: a letter scanned or a mail dropped in is a file on the Mac that took it in;
    /// a mail from the label is in Mail.
    private var outside: URL? {
        #if os(macOS)
        row.entry.source.fileURL ?? row.entry.mailURL
        #else
        row.entry.mailURL
        #endif
    }

    /// What the dots and the right click or a long press both bring.
    @ViewBuilder
    private var items: some View {
        // To see the mail itself: first in its menu, as "Open" is for a file.
        if let url = outside {
            Button(Self.openLabel(row.entry.source.kind), systemImage: row.entry.source.kind == .mail ? "envelope" : "arrow.up.forward.app") {
                openURL(url)
            }
        }
        #if os(macOS)
        Button("Ask Causabee", action: talk)
        MoveMailMenu(entry: row.entry) { newName = Matter.suggestedName(for: [row.entry]); naming = true }
        #else
        AskCausabeeButton(action: talk)
        PhoneMoveMail(entry: row.entry) { newName = Matter.suggestedName(for: [row.entry]); naming = true }
        #endif
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
                    #if os(macOS)
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    // As every row has it: what the mail can do, behind its dots — opening it first.
                    MoreMenu { items }
                    #else
                    Spacer(minLength: 4)
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Menu { items } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
                    }
                    .tint(.secondary)
                    .accessibilityLabel("More")
                    // While reading, a long press still has everything.
                    .tool()
                    #endif
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.subheadline)
                        #endif
                        .foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                MadeChips(made: made).padding(.top, made.isEmpty ? 0 : 4)
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
        #if os(macOS)
        .contextMenu { items }
        #else
        .contextMenu { Group { items }.menuSigns() }
        #endif
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

// MARK: Links both ways

/// Where a fact came from, as a link into the record: a tap shows that mail or file there, marked
/// for a moment. Asked for by several mails, it says "· +2", and a tap asks which of them. A source
/// that is not in the record — the owner in the assistant — stays words. Set in the line's own
/// text, after what comes before it, so the line wraps as one.
struct SourceJump: View {
    let sources: [Source]
    let label: String
    let matter: Matter?
    var color: Color = .secondary
    /// The words before it on the same line — whose, by when — in their own colour.
    var before = ""
    var beforeColor: Color = .secondary
    @Environment(Navigation.self) private var navigation
    @Environment(\.openURL) private var openURL
    @State private var choosing = false

    private static let jump = URL(string: "causabee-source:jump")!

    /// Where each source is in the record, or nil.
    private var places: [(source: Source, item: PersistentIdentifier?)] {
        sources.map { source in (source, matter.flatMap { RecordLinks.item(for: source, in: $0) }) }
    }

    /// Not in this matter's record — moved away, or never in it — but still openable outside.
    private func outside(_ source: Source) -> URL? {
        #if os(macOS)
        source.fileURL ?? source.mailURL
        #else
        source.mailURL
        #endif
    }

    private var line: AttributedString {
        let places = places
        let reachable = places.contains { $0.item != nil || outside($0.source) != nil }
        var start = AttributedString(before.isEmpty ? "" : before + " · ")
        start.foregroundColor = beforeColor
        var link = AttributedString(label + (places.count > 1 ? " · +\(places.count - 1)" : ""))
        link.foregroundColor = reachable ? Theme.gold : color
        if reachable { link.link = Self.jump }
        return start + link
    }

    var body: some View {
        Text(line)
            .font(.caption)
            .tint(Theme.gold)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url == Self.jump else { return .systemAction }
                let places = places
                if places.count > 1 { choosing = true } else if let place = places.first { go(place) }
                return .handled
            })
            .help(places.contains { $0.item != nil } ? "Shows it in the record" : "Opens it in Mail")
            .confirmationDialog("Every mail that asked for it", isPresented: $choosing, titleVisibility: .visible) {
                ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                    if place.item != nil || outside(place.source) != nil {
                        Button((index == 0 ? "First: " : "") + Sources.origin(place.source)) { go(place) }
                    }
                }
            }
    }

    private func go(_ place: (source: Source, item: PersistentIdentifier?)) {
        if let item = place.item { navigation.showing = item } else if let url = outside(place.source) { openURL(url) }
    }
}

/// Under a mail or a file of the record: what came from it — "2 tasks · 1 date · 1 deadline" —,
/// each a way to those things. Nothing at all when it brought nothing: quiet means "only to know".
struct MadeChips: View {
    let made: RecordLinks.Made
    @State private var open: Kind?

    enum Kind: String, Identifiable {
        case todos, appointments, deadlines
        var id: String { rawValue }
    }

    var body: some View {
        if !made.isEmpty {
            HStack(spacing: 6) {
                chip(.todos, made.todos.count, "task", "tasks", "checklist")
                chip(.appointments, made.appointments.count, "date", "dates", "calendar")
                chip(.deadlines, made.deadlines.count, "deadline", "deadlines", "flag")
            }
            #if os(macOS)
            .popover(item: $open, arrowEdge: .bottom) { kind in MadeList(made: made, kind: kind) { open = nil }.frame(width: 340) }
            #else
            .sheet(item: $open) { kind in
                NavigationStack { MadeList(made: made, kind: kind) { open = nil } }.presentationDetents([.medium, .large])
            }
            #endif
        }
    }

    @ViewBuilder
    private func chip(_ kind: Kind, _ count: Int, _ one: String, _ many: String, _ sign: String) -> some View {
        if count > 0 {
            Button { open = kind } label: {
                Label("\(count) \(count == 1 ? one : many)", systemImage: sign)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.box, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("The \(count == 1 ? one : many) that came from it")
        }
    }
}

/// The tasks, dates or deadlines that came from one thing of the record, each with "Show".
struct MadeList: View {
    let made: RecordLinks.Made
    let kind: MadeChips.Kind
    let close: () -> Void
    @Environment(Navigation.self) private var navigation

    private struct Line: Identifiable {
        let id: PersistentIdentifier
        let text: String
        let detail: String
        let done: Bool
    }

    private var lines: [Line] {
        switch kind {
        case .todos:
            made.todos.map { todo in
                Line(id: todo.persistentModelID, text: todo.text,
                     detail: todo.isDone ? "done" : todo.isInfo ? "only to know" : todo.due.map { "by \(Dates.short($0))" } ?? "open",
                     done: todo.isDone)
            }
        case .appointments:
            made.appointments.map { Line(id: $0.persistentModelID, text: $0.what, detail: Dates.short($0.day) + ($0.time.map { " at \($0)" } ?? ""), done: false) }
        case .deadlines:
            made.deadlines.map { Line(id: $0.persistentModelID, text: $0.what, detail: "by " + Dates.short($0.day), done: false) }
        }
    }

    private var title: String {
        switch kind {
        case .todos: "Tasks from it"
        case .appointments: "Dates from it"
        case .deadlines: "Deadlines from it"
        }
    }

    var body: some View {
        let list = VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                if index > 0 { Divider() }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.text).strikethrough(line.done, color: .secondary)
                            .foregroundStyle(line.done ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line.detail).font(.caption).foregroundStyle(line.done ? Theme.done : .secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Show") { close(); navigation.showing = line.id }
                        .buttonStyle(.gold).font(.callout)
                }
                .padding(.vertical, 8)
            }
        }
        #if os(macOS)
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            list
        }
        .padding(14)
        #else
        ScrollView { list.padding(.horizontal, 20) }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) } }
        #endif
    }
}
