import CryptoKit
import MatterCore
import ImageIO
import SwiftData
import UniformTypeIdentifiers
import SwiftUI
#if os(iOS)
import QuickLook
#endif
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
                let me = OwnerMe.current
                let joined = MailThreads.joined(thread.rows, deepest: ThreadMailRow.deepest)
                ForEach(thread.rows) { row in
                    ThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1, sent: me.sent(row.entry.from), subject: thread.subject,
                                  made: links?.made(from: row.entry) ?? RecordLinks.Made(), joinsNext: joined.contains(row.id)) { talk(row.entry) }
                        // Marked when shown from a task or found: a little room around it, the
                        // mail itself where it was.
                        .padding(.horizontal, 10)
                        .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                        .padding(.horizontal, -10)
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
    /// The conversation's subject, on its card: a mail whose own differs says its own.
    var subject = ""
    var made = RecordLinks.Made()
    /// At the deepest indent and answered: its line goes on down to its answer.
    var joinsNext = false
    let talk: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var naming = false
    @State private var newName = ""
    /// The digest whole, not cut at five lines.
    @State private var opened = false
    /// Whether its own words are kept on this device — looked at once — and, shown, the words.
    @State private var hasText = false
    @State private var whole: String?
    /// A scan or a file brought in, opened here: shown in place on the iPhone and iPad.
    @State private var preview: URL?
    @State private var cannotOpen = false

    /// The file a scan or a dropped mail is, when it is an entry of its own: the same on every device —
    /// here, or in the matter's folder in iCloud Drive.
    private var ownFile: MatterCore.Document? {
        guard row.entry.source.kind != .mail || row.entry.source.fileURL != nil else { return nil }
        return (row.entry.matter?.documents ?? []).first { $0.messageID == row.entry.messageID && $0.isOwnFile }
    }

    private func openOwn(_ document: MatterCore.Document) {
        Task {
            var url: URL?
            if let file = document.source.fileURL, FileManager.default.fileExists(atPath: file.path) { url = file }
            else if let kept = MatterFolders.kept(document) { url = try? await MatterFolders.fetched(kept) }
            guard let url else { cannotOpen = true; return }
            #if os(macOS)
            openURL(url)
            #else
            preview = url
            #endif
        }
    }

    /// The words each task, date or deadline that came from it was read out of.
    private var quotes: [(sign: String, text: String)] {
        let id = row.entry.messageID
        func quote(_ sources: [Source]) -> String? {
            guard let text = sources.first(where: { $0.messageID == id })?.quote?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        let all = made.todos.compactMap { todo in quote(todo.sources + [todo.doneSource].compactMap { $0 }).map { ("checklist", $0) } }
            + made.appointments.compactMap { quote($0.sources).map { ("calendar", $0) } }
            + made.deadlines.compactMap { quote($0.sources).map { ("flag", $0) } }
        var seen = Set<String>()
        return Array(all.filter { seen.insert($0.1).inserted }.prefix(3))
    }

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
        // To see the mail itself: first in its menu, as "Open" is for a file. A scan or a file
        // brought in opens as the file, on every device.
        if let document = ownFile {
            Button(Self.openLabel(row.entry.source.kind), systemImage: "arrow.up.forward.app") { openOwn(document) }
        } else if let url = outside {
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // Centred on the name, not sat on its baseline: the dot and the arrow are signs
                    // beside a word, and on the baseline they hung low.
                    HStack(alignment: .center, spacing: 5) {
                        // Still unread in the mailbox: a gold dot, as Mail has a blue one.
                        if entry.isUnread == true {
                            Circle().fill(Theme.gold).frame(width: 7, height: 7)
                                .accessibilityLabel("unread")
                        }
                        Text(sent ? "You" : entry.matter?.writerName(entry.from) ?? Email.address(in: entry.from))
                            .fontWeight(entry.isUnread == true ? .semibold : .medium).lineLimit(1)
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
                // A reply that changed the subject says its own.
                if !subject.isEmpty, !entry.title.isEmpty,
                   MailThreads.clean(entry.title).localizedCaseInsensitiveCompare(MailThreads.clean(subject)) != .orderedSame {
                    Text(entry.title).font(.callout.weight(.medium)).lineLimit(2)
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.subheadline)
                        #endif
                        .foregroundStyle(entry.isUnread == true ? Color.primary : Color.secondary).lineLimit(opened ? nil : 5).fixedSize(horizontal: false, vertical: true)
                    if !opened, digest.count > 320 {
                        Button("more") { withAnimation(.snappy) { opened = true } }.buttonStyle(.gold).font(.caption)
                    }
                }
                MadeChips(made: made).padding(.top, made.isEmpty ? 0 : 2)
                // What each of them was read out of, in its own words: a quiet quote, a thin line
                // on its left — the chips above already say what came of it.
                let quotes = quotes
                if !quotes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(quotes.enumerated()), id: \.offset) { _, quote in
                            Text("“\(quote.text)”").italic().lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) { Capsule().fill(Theme.line).frame(width: 2) }
                }
                if hasText {
                    Button(whole == nil ? (entry.source.kind == .mail ? "Show the whole mail" : "Show the whole text") : "Hide it again") {
                        withAnimation(.snappy) {
                            whole = whole == nil ? KeptTexts.store.flatMap { MailText.load(entry.messageID, besides: $0)?.body } ?? "" : nil
                        }
                    }
                    .buttonStyle(.gold).font(.caption)
                    .help("Its own words, kept on this device — without opening Mail")
                }
                if let whole {
                    Text(whole.isEmpty ? "Its words are not on this device yet." : whole)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.subheadline)
                        #endif
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.vertical, 10)
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
        .task(id: row.entry.messageID) { hasText = KeptTexts.store.map { MailText.has(row.entry.messageID, besides: $0) } ?? false }
        #if os(iOS)
        .quickLookPreview($preview)
        #endif
        .alertWhenAsked("The file is not here", isPresented: $cannotOpen) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It is neither on this device nor in the matter's folder in iCloud Drive yet. What it said is here.")
        }
        // The same in the right click, as on every row: no button that comes and goes.
        #if os(macOS)
        .contextMenu { items }
        #else
        .contextMenu { Group { items }.menuSigns() }
        #endif
        .alertWhenAsked("Move to a new matter", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Move") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let from = row.entry.matter else { return }
                guard Store.shared.mayStartMatter(in: context) else { return }
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
        let turn: CGFloat = 20
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

    private func line(_ places: [(source: Source, item: PersistentIdentifier?)]) -> AttributedString {
        let reachable = places.contains { $0.item != nil || outside($0.source) != nil }
        var start = AttributedString(before.isEmpty ? "" : before + " · ")
        start.foregroundColor = beforeColor
        var link = AttributedString(label + (places.count > 1 ? " · +\(places.count - 1)" : ""))
        link.foregroundColor = reachable ? Theme.gold : color
        if reachable { link.link = Self.jump }
        return start + link
    }

    var body: some View {
        // Looked up once for this drawing: each source's place in the record.
        let places = places
        Text(line(places))
            .font(.caption)
            .tint(Theme.gold)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url == Self.jump else { return .systemAction }
                if places.count > 1 { choosing = true } else if let place = places.first { go(place) }
                return .handled
            })
            .help(places.contains { $0.item != nil } ? "Shows it in the record" : "Opens it in Mail")
            .confirmationDialogWhenAsked("Every mail that asked for it", isPresented: $choosing, titleVisibility: .visible) {
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

// MARK: Files — read or kept

/// One file: its sign, its name, where it came from — and either what it says, when Causabee has
/// read it, or that it is only kept, with "Read" right on it, not in a menu. The same on every
/// device; what opening and reading do — the file out of its mail, or out of iCloud Drive — each
/// device does its own way.
struct FileFace<Items: View>: View {
    let document: MatterCore.Document
    let sender: String?
    /// Getting it, or what went wrong.
    let state: String?
    /// A tap on the card: open it, or — while choosing several — choose it.
    let tap: () -> Void
    let read: () -> Void
    let nameIt: () -> Void
    /// Nil, or whether it is chosen while several are being chosen.
    var chosen: Bool? = nil
    @ViewBuilder let items: Items

    static func icon(_ document: MatterCore.Document) -> String {
        let type = document.contentType.lowercased(), name = document.name.lowercased()
        if type.hasPrefix("image/") { return "photo" }
        if type == "application/pdf" || name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".xlsx") || name.hasSuffix(".csv") { return "tablecells" }
        return "doc"
    }

    private var isPDF: Bool { document.contentType == "application/pdf" || document.name.lowercased().hasSuffix(".pdf") }

    /// Visible on the card, not in a menu: reading is one tap.
    private var readButton: some View {
        Button("Read", action: read)
            .quietButton().fixedSize()
            .help("Reads it on this device and shows it in the assistant. Nothing is sent until “Sort in” (≈ 4 cents).")
    }

    /// Where it is and where it came from — its own name too, when it has a name of ours.
    private var line: String {
        if document.isOwnFile {
            let at = MatterFolders.kept(document) != nil ? "added on \(document.source.addedOn) · in the matter's folder"
                : document.source.fileURL != nil && MatterFolders.root == nil ? "only on this \(ThisDevice.name) — switch on iCloud Drive for Causabee"
                : document.source.fileURL != nil ? "on this \(ThisDevice.name), in Causabee's folder"
                : MatterFolders.root == nil ? "added on \(document.source.addedOn) · to open it here, switch on iCloud Drive for Causabee"
                : "added on \(document.source.addedOn) · not in the matter's folder yet"
            return [document.title == nil ? nil : document.name, at].compactMap { $0 }.joined(separator: " · ")
        }
        return [document.title == nil ? nil : document.name, Sources.origin(document.source), sender,
                ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file)]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FileThumbnail(document: document, symbol: Self.icon(document), state: state)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.shownName).lineLimit(2).multilineTextAlignment(.leading)
                (Text(line) + Text(document.readAt.map { " · read \(Dates.short($0))" } ?? "").foregroundColor(Theme.done))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if let says = document.says {
                    Text(says)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.footnote)
                        #endif
                        .foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                }
                if let kept = document.keptWords {
                    Text(kept).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                    #if os(iOS)
                    // Under its words on a narrow screen, so the name keeps the card's width.
                    if chosen == nil, document.reading == .kept, state == nil { readButton.padding(.top, 6) }
                    #endif
                }
                if document.title == nil, isPDF, DocumentTitle.looksMachineMade(document.name), state == nil {
                    Button(Say.nameFromContent, action: nameIt)
                        .buttonStyle(.gold).font(.caption)
                        .tool()
                        .help("Reads the heading of the first page on this device and takes it as the name. Costs nothing, sends nothing.")
                }
                if let state {
                    Text(state).font(.caption).foregroundStyle(state.hasPrefix("Getting") ? Color.secondary : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let chosen {
                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(chosen ? Theme.ink : Color.secondary)
                    .accessibilityLabel(chosen ? "Chosen" : "Not chosen")
            } else {
                #if os(macOS)
                if document.reading == .kept, state == nil { readButton }
                #endif
                if state?.hasPrefix("Getting") == true { ProgressView().controlSize(.small) }
                #if os(macOS)
                MoreMenu { items }
                #else
                Menu { items } label: {
                    Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
                }
                .tint(.secondary)
                .accessibilityLabel("More")
                .tool()
                #endif
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        .opacity(document.isHidden ? 0.55 : 1)
        #if os(macOS)
        .contextMenu { items }
        #else
        .contextMenu { Group { items }.menuSigns() }
        #endif
    }
}

/// A picture or a PDF as a small picture of itself: from the file on this device — one of ours,
/// or one from a mail opened before — or taken out of its mail for it, read-only. Its sign until then.
struct FileThumbnail: View {
    let document: MatterCore.Document
    let symbol: String
    /// Changes when a file has just been fetched, so the picture is looked for again.
    let state: String?
    @State private var picture: CGImage?
    @Environment(\.displayScale) private var scale

    static let size = CGSize(width: 40, height: 48)
    private static let made = NSCache<NSString, CGImageBox>()

    private var shows: Bool {
        let type = document.contentType.lowercased(), name = document.name.lowercased()
        return type.hasPrefix("image/") || type == "application/pdf" || name.hasSuffix(".pdf")
    }

    var body: some View {
        Group {
            if let picture {
                Image(decorative: picture, scale: scale)
                    .resizable().scaledToFill()
                    .frame(width: Self.size.width, height: Self.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.25), lineWidth: 0.5))
            } else {
                Image(systemName: symbol).font(.title3).foregroundStyle(.secondary)
                    .frame(width: Self.size.width, height: shows ? Self.size.height : nil)
            }
        }
        .task(id: "\(document.name)|\(state ?? "")") { await load() }
    }

    private func load() async {
        guard shows else { return }
        var found = Self.onDevice(document)
        // In its matter's folder, not downloaded yet: brought down from iCloud Drive.
        if found == nil, document.isOwnFile, let kept = MatterFolders.kept(document) { found = try? await MatterFolders.fetched(kept) }
        if found == nil { found = await MailPreviews.fetch(document) }
        guard let file = found else { return }
        let key = file.path as NSString
        if let known = Self.made.object(forKey: key) { picture = known.image; return }
        // Made here, not by Quick Look: its service made none for some files the app keeps.
        let longest = max(Self.size.width, Self.size.height) * scale * 2
        guard let made = await Task.detached(priority: .utility, operation: { Self.picture(of: file, longest: longest) }).value else { return }
        Self.made.setObject(CGImageBox(made), forKey: key)
        picture = made
    }

    /// A PDF's first page, or the picture itself, small: never the whole of a large file in memory.
    nonisolated static func picture(of file: URL, longest: CGFloat) -> CGImage? {
        if file.pathExtension.lowercased() == "pdf" {
            guard let page = CGPDFDocument(file as CFURL)?.page(at: 1) else { return nil }
            let box = page.getBoxRect(.cropBox)
            let turned = page.rotationAngle % 180 != 0
            let (width, height) = turned ? (box.height, box.width) : (box.width, box.height)
            guard width > 0, height > 0 else { return nil }
            let factor = longest / max(width, height)
            let (w, h) = (Int(width * factor), Int(height * factor))
            guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: w, height: h), rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            return context.makeImage()
        }
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: longest]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Where the file is on this device, if it is: never a placeholder of iCloud Drive's.
    static func onDevice(_ document: MatterCore.Document) -> URL? {
        let files = FileManager.default
        if document.isOwnFile {
            return [document.source.fileURL, MatterFolders.kept(document)].compactMap { $0 }.first { files.fileExists(atPath: $0.path) }
        }
        // Taken out of its mail before: in the cache, under a digest of the mail's id.
        let caches = files.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let name = document.name.replacingOccurrences(of: "/", with: "-")
        let hash = SHA256.hash(data: Data(document.messageID.utf8))
        for (folder, length) in [("Causabee/Anhänge", 6), ("Mail files", 8), ("Causabee/Anhänge", 8)] {
            let digest = hash.prefix(length).map { String(format: "%02x", $0) }.joined()
            let file = caches.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(digest).appendingPathComponent(name)
            if files.fileExists(atPath: file.path) { return file }
        }
        return nil
    }
}

/// Pictures and PDFs still in their mail, taken out one at a time so their small picture can show:
/// read-only, only that one mail, and kept where opening the file looks first — so it opens at once
/// too. Each is tried once a launch; a large one is left until it is opened.
@MainActor
enum MailPreviews {
    private static var last: Task<Void, Never>?
    private static var tried = Set<String>()
    static let largest = 15_000_000

    static func fetch(_ document: MatterCore.Document) async -> URL? {
        let pointer = document.source.pointer
        guard !document.isOwnFile, pointer.hasPrefix("imap://"), document.byteCount <= largest,
              tried.insert(document.messageID + "/" + document.name).inserted else { return nil }
        // The account on the mail's server, so a password only ever goes where it belongs.
        let host = pointer.firstMatch(of: /^imap:\/\/([^\/]+)\//).map { String($0.output.1) }
        let accounts = Keychain.accounts()
        guard let account = accounts.first(where: { $0.host == host }) ?? (host == nil ? accounts.first : nil) else { return nil }
        let (name, messageID) = (document.name, document.messageID)
        let before = last
        let fetching = Task { () -> URL? in
            await before?.value
            guard let password = try? await MailSecret.secret(for: account) else { return nil }
            return try? await MailFetch.file(name, pointer: pointer, messageID: messageID, account: account, password: password, cache: cache)
        }
        last = Task { _ = await fetching.value }
        return await fetching.value
    }

    private static var cache: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #if os(macOS)
        return caches.appendingPathComponent("Causabee/Anhänge", isDirectory: true)
        #else
        return MailFiles.cache
        #endif
    }
}

final class CGImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

extension View {
    /// A file as a card of the record. Read: white, with its line. Kept only: no ground, and a
    /// dashed line — stored, not read, never sent.
    func fileCardFrame(kept: Bool) -> some View {
        #if os(macOS)
        let corner: CGFloat = 10
        #else
        let corner: CGFloat = 12
        #endif
        return frame(maxWidth: .infinity, alignment: .leading)
            .background(kept ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner)
                .strokeBorder(kept ? Theme.strongLine : Theme.line, style: StrokeStyle(lineWidth: 1, dash: kept ? [5, 4] : [])))
    }
}

/// "Read all 3 attachments": over a mail's files that are kept only and can be read.
struct ReadAllLine: View {
    let count: Int
    let read: () -> Void

    var body: some View {
        if count > 1 {
            Button("Read all \(count) attachments · ≈ \(count * 4) cents", action: read)
                .buttonStyle(.gold).font(.caption)
                .help("Reads each on this device and shows it in the assistant. Nothing is sent until “Sort in”.")
                .padding(.horizontal, 4)
        }
    }
}

/// While choosing several kept files: how many, what reading them costs, and the button.
struct ChooseBar: View {
    let chosen: Int
    let readable: Int
    let all: () -> Void
    let read: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(chosen == 0 ? "Choose files" : "\(chosen) · ≈ \(chosen * 4) cents")
                .font(.callout).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            if chosen < readable { Button("All", action: all).buttonStyle(.gold).font(.callout) }
            Button("Cancel", action: cancel).quietButton()
            Button(chosen == 1 ? "Read 1" : "Read \(chosen)", action: read).filledButton().disabled(chosen == 0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: Browsing

/// The record's line: what kind of thing, which of them, in which order — three small menus, the
/// same on every device, in the same order. One person chosen in People stands beside them.
struct RecordBar<Trailing: View>: View {
    @Binding var kind: RecordBrowse.Kind
    @Binding var show: RecordBrowse.Show
    @Binding var sort: RecordBrowse.Sort
    /// How many there are for each "Show".
    let counts: [RecordBrowse.Show: Int]
    var person: String? = nil
    var clearPerson: () -> Void = {}
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            menu("Kind", kind.label) {
                Picker("Kind", selection: $kind) {
                    ForEach(RecordBrowse.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            if kind != .details {
                menu("Show", show.label) {
                    Picker("Show", selection: $show) {
                        ForEach(RecordBrowse.Show.allCases, id: \.self) { item in
                            Text(counts[item].map { "\(item.label) · \($0)" } ?? item.label).tag(item)
                        }
                    }
                }
                menu("Sort", sort.label) {
                    Picker("Sort", selection: $sort) {
                        ForEach(RecordBrowse.Sort.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            }
            if let person {
                Button(action: clearPerson) { Label(person, systemImage: "xmark.circle.fill").lineLimit(1) }
                    #if os(macOS)
                    .buttonStyle(.bordered).controlSize(.small)
                    #else
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small).tint(.primary)
                    #endif
                    .help("Only what \(person) wrote or is named in. Click to show everyone's again.")
            }
            Spacer(minLength: 0)
            trailing
        }
    }

    @ViewBuilder
    private func menu(_ name: String, _ value: String, @ViewBuilder picker: () -> some View) -> some View {
        Menu {
            picker().pickerStyle(.inline).labelsHidden()
        } label: {
            #if os(macOS)
            Text(value).font(.callout)
            #else
            HStack(spacing: 3) {
                Text(value)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline)
            .padding(.vertical, 4).contentShape(Rectangle())
            #endif
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        #endif
        .tint(.secondary)
        .accessibilityLabel("\(name): \(value)")
        .help(name)
    }
}

/// "also under Nina Voss": over a thing that stands under several people.
struct AlsoUnder: View {
    let names: [String]

    var body: some View {
        if !names.isEmpty {
            Text("also under " + names.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
    }
}

/// Who each mail names, worked out once per mail and kept while Causabee runs: its kept words are
/// read from the disk for it. By id and name, not the party itself, which may go.
@MainActor
enum NamedPeople {
    private static var cache: [String: [(id: PersistentIdentifier, name: String)]] = [:]

    static func of(_ entry: Entry, in matter: Matter) -> [(id: PersistentIdentifier, name: String)] {
        let key = entry.messageID + "|" + matter.parties.map(\.name).joined(separator: ",")
        if let known = cache[key] { return known }
        let found = RecordBrowse.people(in: entry, of: matter) { mail in
            KeptTexts.store.flatMap { MailText.load(mail.messageID, besides: $0) }
        }.map { (id: $0.persistentModelID, name: $0.name) }
        cache[key] = found
        return found
    }

    /// Everyone a thing of the record names, in order, each once.
    static func of(_ item: RecordBrowse.Item, in matter: Matter) -> [(id: PersistentIdentifier, name: String)] {
        let entries: [Entry]
        switch item {
        case .thread(let thread): entries = thread.rows.map(\.entry)
        case .document(let document): entries = matter.entry(messageID: document.messageID).map { [$0] } ?? []
        case .link: entries = []
        }
        var seen = Set<PersistentIdentifier>()
        return entries.flatMap { of($0, in: matter) }.filter { seen.insert($0.id).inserted }
    }
}

// MARK: Unread

/// "Matters with unread mail": a filter over the overview, not a count on each matter — folded,
/// one line; open, the matters, each a way to its newest unread mail. Nothing when none has any.
struct UnreadMatters: View {
    let matters: [Matter]
    let open: (Matter, PersistentIdentifier?) -> Void
    @State private var shown = false
    /// Only the mails still unread, asked of the store — not every mail of every matter, read again
    /// each time the overview is drawn.
    @Query(filter: #Predicate<Entry> { $0.isUnread == true }) private var unreadMails: [Entry]

    /// Each open matter with unread mail, and its newest unread one, the newest first.
    private var unread: [(Matter, Entry?)] {
        var newest: [PersistentIdentifier: Entry] = [:]
        for mail in unreadMails {
            guard let matter = mail.matter, !matter.isClosed else { continue }
            if newest[matter.persistentModelID] == nil || (mail.date ?? .distantPast) > (newest[matter.persistentModelID]?.date ?? .distantPast) {
                newest[matter.persistentModelID] = mail
            }
        }
        return newest.values.compactMap { mail in mail.matter.map { ($0, Optional(mail)) } }
            .sorted { ($0.1?.date ?? .distantPast) > ($1.1?.date ?? .distantPast) }
    }

    var body: some View {
        let unread = unread
        if !unread.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button { withAnimation(.snappy) { shown.toggle() } } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.gold).frame(width: 7, height: 7)
                        Text("Matters with unread mail")
                        Image(systemName: shown ? "chevron.up" : "chevron.down").font(.caption2)
                    }
                    .font(.callout).foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(shown ? "Fold them away" : "Show the matters with mail you haven't read in your mailbox")
                if shown {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(unread, id: \.0.persistentModelID) { matter, newest in
                            Button { open(matter, newest?.persistentModelID) } label: {
                                HStack(spacing: 10) {
                                    Text(matter.name).foregroundStyle(.primary).lineLimit(1)
                                    Spacer(minLength: 8)
                                    if let day = newest?.date {
                                        Text(Dates.short(day)).font(.caption).foregroundStyle(.secondary).fixedSize()
                                    }
                                }
                                .padding(.vertical, 8).padding(.leading, 15)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Opens the matter at its newest unread mail")
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: Adding to a matter

/// What can be added to the open matter: the same six, in the same words and order, in the
/// matter's ⋯ on every device and in the Mac's Matter menu.
enum MatterAction: String, CaseIterable {
    case newTask, writeNote, addFile, addContact, addDetail, addLink

    var title: String {
        switch self {
        case .newTask: "New Task …"
        case .writeNote: "Add Note …"
        case .addFile: "Add File …"
        case .addContact: "Add Contact …"
        case .addDetail: "Add Detail …"
        case .addLink: "Add Link …"
        }
    }
    var symbol: String {
        switch self {
        case .newTask: "checklist"
        case .writeNote: "note.text"
        case .addFile: "doc"
        case .addContact: "person.badge.plus"
        case .addDetail: "info.circle"
        case .addLink: "link"
        }
    }
}


/// The matter's ⋯, its first part: the next step and summary written again. What is added to a
/// matter is added by the plus — the bee held, or beside the assistant's field — not here.
struct MatterAddItems: View {
    /// Nil where nothing is written: the demo on the Mac.
    let writeAgain: (() -> Void)?

    var body: some View {
        if let writeAgain {
            // ⌘R in the Matter menu, on the Mac and on the iPad's keyboard.
            Button("Write Next Step and Summary Again", systemImage: "arrow.clockwise", action: writeAgain)
            Divider()
        }
    }
}

/// How much of the assistant's thread is shown at first, and how many more each "Show earlier"
/// brings: the same on every device.
enum AssistantPage {
    static let size = 20
}

// MARK: Brought in by drop, paste or camera

/// A screenshot, a picture, a scan or a PDF dropped, pasted, or taken with an iPhone's camera
/// from the Mac: its bytes, and a name to keep it under. The same way in on every device.
struct BroughtFile: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .pdf) { BroughtFile(data: try Data(contentsOf: $0.file), name: $0.file.lastPathComponent) }
        FileRepresentation(importedContentType: .image) { BroughtFile(data: try Data(contentsOf: $0.file), name: $0.file.lastPathComponent) }
        DataRepresentation(importedContentType: .pdf) { BroughtFile(data: $0, name: named("Scan", "pdf")) }
        DataRepresentation(importedContentType: .png) { BroughtFile(data: $0, name: named("Screenshot", "png")) }
        DataRepresentation(importedContentType: .jpeg) { BroughtFile(data: $0, name: named("Photo", "jpg")) }
        DataRepresentation(importedContentType: .heic) { BroughtFile(data: $0, name: named("Photo", "heic")) }
    }

    /// As the devices name their own: "Screenshot 2026-10-20 at 09.41.00.png", in local time.
    static func named(_ kind: String, _ ending: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "\(kind) \(formatter.string(from: Date())).\(ending)"
    }
}

/// The brief under the summary — the same on every device: what Causabee understands of the
/// matter, folded until opened; what the owner said of it, which every brief is written around;
/// and the adviser's proposals for the to-do list, each taken with a tap or put away.
struct BriefDetails: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @State private var opens = false

    var body: some View {
        if let brief = matter.shownBrief {
            VStack(alignment: .leading, spacing: 12) {
                if let news = brief.news, !news.seen {
                    // What the new mail changes, first: on a pale honey, until it is seen.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            BeeChip(text: "NEW")
                            Text("\(news.mails == 1 ? "1 mail" : "\(news.mails) mails") since \(Dates.short(news.since))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Button("Seen") { withAnimation { matter.sawNews(); try? context.save() } }
                                .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Theme.gold)
                                .accessibilityIdentifier("brief.seen")
                        }
                        ForEach(Array(news.lines.enumerated()), id: \.offset) { _, line in
                            Text(line).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 10))
                    // A notification of news tapped goes here.
                    .id("news")
                }
                if !brief.lines.isEmpty || !brief.answeredHere.isEmpty {
                    DisclosureGroup(isExpanded: $opens) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Brief.Part.allCases, id: \.self) { part in
                                let lines = brief.lines(part)
                                if !lines.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(Self.title(part)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                            Text(line).fixedSize(horizontal: false, vertical: true)
                                                .findable(.section("brief-\(part.rawValue)-\(index)"), line)
                                        }
                                    }
                                }
                            }
                            // What was looked up on the web: kept to read, folded with the rest — it
                            // waits for nothing, and under the brief it stood in the way.
                            if !brief.answeredHere.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Looked up").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    ForEach(brief.answeredHere) { lookup in FoundRow(lookup: lookup) }
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(opens ? "The brief" : "The brief · what Causabee understands").font(.callout.weight(.medium))
                    }
                    .accessibilityIdentifier("brief.open")
                }
                if !brief.said.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You said").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(brief.said) { said in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(said.text).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Button {
                                    matter.unsay(said.id)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "xmark").font(.caption2)
                                }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                                .help("Take it back: the next brief is written without it.")
                                .accessibilityLabel("Take back")
                            }
                        }
                    }
                }
                let proposals = Adviser.worthReading(brief.open, in: matter, context: context)
                if !proposals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("For the list").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(proposals) { proposal in
                            ProposalRow(proposal: proposal, matter: matter)
                        }
                    }
                }
                if !brief.openLookups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Look up?").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        // Said once, over them: what goes out, and what does not.
                        Text("Only this question goes to the web — nothing of the matter.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(brief.openLookups) { lookup in
                            LookupRow(lookup: lookup, matter: matter)
                        }
                    }
                }

            }
        }
    }

    static func title(_ part: Brief.Part) -> String {
        switch part {
        case .about: "What it is about"
        case .goal: "What you want from it"
        case .people: "Who is who"
        case .agreed: "Agreed"
        case .open: "Still to do"
        case .waiting: "Waiting for"
        case .risks: "Watch out"
        case .decision: "To decide"
        }
    }
}

/// One change to the to-do list the adviser proposes: what it does, why, and a tap to take it.
private struct ProposalRow: View {
    let proposal: Brief.Proposal
    let matter: Matter
    @Environment(\.modelContext) private var context
    @State private var gone = false
    @State private var why = false

    var body: some View {
        let card = proposal.card
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.gold).frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(what).fixedSize(horizontal: false, vertical: true)
                // Why, in one line: the whole of it on a tap — the proposal itself is what to read.
                if !card.reason.isEmpty {
                    Text(card.reason).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(why ? nil : 1).fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { why.toggle() } }
                }
                if gone { Text("What it was about is no longer there.").font(.caption).foregroundStyle(Theme.warning) }
                HStack(spacing: 12) {
                    Button(take) {
                        withAnimation { gone = !Adviser.take(proposal, in: matter, context: context) }
                    }
                    .takeStyle()
                    .accessibilityIdentifier("brief.take")
                    Button("Put away") {
                        withAnimation { Adviser.dismiss(proposal, in: matter, context: context) }
                    }
                    .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    private var refs: [String: FactRef] { CardActions.local(proposal.refs, keys: proposal.keys, matter: matter, in: context) }

    /// A task by its whole text — it stands alone here, not as a chip; anything else by its label.
    private func name(_ id: String?) -> String {
        guard let ref = id.flatMap({ refs[$0] }) else { return "a task" }
        if case .todo = ref, let todo = CardActions.live(ref, as: Todo.self, in: context) { return todo.text }
        return CardActions.label(ref, in: context)
    }

    private var what: String {
        let card = proposal.card
        switch card.kind {
        case .newTodo: return card.text + (card.due.map { " · by " + Dates.short($0) } ?? "")
        case .markDone: return "Done: " + name(card.todo)
        case .correctText: return "“\(card.from ?? "")” → “\(card.text)”"
        case .waitsFor: return name(card.todo) + " — only after " + name(card.into)
        case .changeOwner: return name(card.todo) + " — " + (Todo.Owner(rawValue: card.owner).map(Self.whose) ?? card.owner)
        case .changeDate: return name(card.todo) + (card.due.map { " — " + Dates.short($0) } ?? "")
        default: return card.text
        }
    }

    private static func whose(_ owner: Todo.Owner) -> String {
        switch owner {
        case .me: "yours"
        case .we: "yours, together with others"
        case .other: "someone else's — you wait for it"
        case .unknown: "whose is not clear"
        }
    }

    private var symbol: String {
        switch proposal.card.kind {
        case .newTodo: "plus.circle"
        case .markDone: "checkmark.circle"
        case .correctText: "pencil"
        case .waitsFor: "arrow.turn.down.right"
        case .changeOwner: "person.2"
        case .changeDate: "calendar"
        default: "sparkles"
        }
    }

    private var take: String {
        switch proposal.card.kind {
        case .newTodo: "Add"
        case .markDone: "Tick off"
        default: "Change"
        }
    }
}

extension View {
    /// The button that takes a proposal: the filled one of each device.
    @ViewBuilder func takeStyle() -> some View {
        #if os(iOS)
        buttonStyle(.phoneFilled)
        #else
        buttonStyle(.ink).font(.callout)
        #endif
    }
}

/// A general question the adviser would like looked up: word for word what would go out, and a
/// tap to send it — alone, without the matter.
private struct LookupRow: View {
    let lookup: WebLookup.Lookup
    let matter: Matter
    @Environment(\.modelContext) private var context
    @State private var looking = false
    @State private var problem: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "globe").foregroundStyle(Theme.gold).frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text("“\(lookup.question)”").fixedSize(horizontal: false, vertical: true)
                if let problem { Text(problem).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
                HStack(spacing: 12) {
                    if looking {
                        BeeLoader(size: 9)
                        Text("Looking it up …").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Look up") { look() }
                            .takeStyle()
                            .accessibilityIdentifier("brief.lookup")
                        Button("Put away") {
                            withAnimation { matter.settle(lookup.id, dismissed: true); try? context.save() }
                        }
                        .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func look() {
        looking = true
        problem = nil
        Task {
            do { try await Adviser.lookUp(lookup, in: matter, context: context) }
            catch { problem = plainWords(error) }
            looking = false
        }
    }
}

/// What was found: the question, the answer, and where it comes from — to check before relying on it.
struct FoundRow: View {
    let lookup: WebLookup.Lookup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lookup.question).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            // The services mark what matters in bold, as Markdown: shown bold, not as stars.
            Text((try? AttributedString(markdown: lookup.answer ?? "", options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                 ?? AttributedString(lookup.answer ?? ""))
                .fixedSize(horizontal: false, vertical: true)
                .findable(.section("lookup-\(lookup.id)"), lookup.answer ?? "")
            ForEach(Array(lookup.sources.enumerated()), id: \.offset) { _, source in
                if let url = URL(string: source.url) {
                    Link(destination: url) {
                        Label(source.title, systemImage: "link").font(.caption).lineLimit(1)
                    }
                    .tint(Theme.gold)
                }
            }
            if let date = lookup.date {
                Text("From the web, \(Dates.short(date)) · general, not about this matter — check the source")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

/// A matter with news the owner has not seen: a small honey dot beside its name — the same in the
/// sidebar, on the overview's cards and rows, on every device.
struct NewsDot: View {
    var body: some View {
        Circle().fill(Theme.bee).frame(width: 8, height: 8)
            .overlay(Circle().stroke(Theme.gold.opacity(0.6), lineWidth: 0.5))
            .accessibilityLabel("New")
    }
}

/// On a card: the dot, and the first line of what is new.
struct NewsLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            NewsDot().alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text(text).lineLimit(2).multilineTextAlignment(.leading)
        }
        .font(.callout)
        .foregroundStyle(.primary)
    }
}

/// The assistant's "Look up on the web?": the general question, word for word, as it would go out —
/// checked on the device for anything personal first — and a tap to send it, alone, without the
/// matter. What is found stands in the card, and with the matter's brief. The same on every device.
struct LookUpCard: View {
    let question: String
    let reason: String
    let matter: Matter?
    var dismissed = false
    var setDismissed: (Bool) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @State private var looking = false
    @State private var problem: String?
    @State private var found: WebLookup.Lookup?

    /// Counted up when a name is marked public here: the card looks again.
    @State private var marked = 0

    /// The person or company of the matter the question names, when that is what stopped it.
    private var namedParty: String? {
        let lower = question.lowercased()
        return (matter?.parties ?? []).map(\.name).filter { $0.count >= 3 }.sorted { $0.count > $1.count }
            .first { lower.contains($0.lowercased()) }
    }

    /// Why it may not go out: a name of the matter or the owner in it, a number, an address.
    private var refusal: String? {
        _ = marked
        let owner = ((try? context.fetch(FetchDescriptor<Profile>())) ?? []).flatMap(\.names)
        let people = (matter?.parties ?? []).flatMap { [$0.name] + $0.spellings }
        return WebLookup.refusal(question, personal: WebLookup.personal(people + owner.filter { !$0.contains("@") }))
    }

    var body: some View {
        let shown = found ?? matter?.found(for: question)
        if dismissed, shown == nil {
            HStack(spacing: 8) {
                Text("You put away a question to look up").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(Say.showAgain) { setDismissed(false) }.buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "globe").foregroundStyle(Theme.gold)
                    Text(shown == nil ? "Look up on the web?" : "Looked up on the web").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                if let shown {
                    FoundRow(lookup: shown)
                } else {
                    Text("“\(question)”").fixedSize(horizontal: false, vertical: true)
                    if !reason.isEmpty { Text(reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    if let refusal {
                        // Said, not sent: the check on the device found something personal in it.
                        Text("Not sent: \(refusal)").font(.caption).foregroundStyle(Theme.warning)
                        // A big company or a brand is nothing personal: marked public, the question may go.
                        if let name = namedParty {
                            Button("“\(name)” is a public name — not disguised") { PublicNames.mark(name, public: true, in: context); marked += 1 }
                                .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Theme.gold)
                        }
                    } else {
                        Text("Only this question goes to the web — nothing of the matter.").font(.caption).foregroundStyle(.secondary)
                        if let problem { Text(problem).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
                        HStack(spacing: 12) {
                            if looking {
                                BeeLoader(size: 9)
                                Text("Looking it up …").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("Look up") { look() }.takeStyle().accessibilityIdentifier("assistant.lookup")
                                Button("Put away") { setDismissed(true) }
                                    .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func look() {
        looking = true
        problem = nil
        Task {
            do {
                let result = try await Adviser.lookUp(question: question, in: matter, context: context)
                var lookup = WebLookup.Lookup(question: question)
                lookup.state = .answered
                lookup.answer = result.answer
                lookup.sources = result.sources
                lookup.date = Date()
                found = lookup
            } catch {
                problem = plainWords(error)
            }
            looking = false
        }
    }
}

/// "Public name": a big company or a brand, never disguised, and allowed in a question looked up on
/// the web — in a person's or a company's menu, ticked when it is so. The same on every device.
struct PublicNameItem: View {
    let party: Party
    @Environment(\.modelContext) private var context

    var body: some View {
        let isPublic = PublicNames.covers(party.name)
        Toggle(isOn: Binding(get: { isPublic }, set: { PublicNames.mark(party.name, public: $0, in: context) })) {
            Label("Public Name — Not Disguised", systemImage: "globe")
        }
        .help("For a big company or a brand: its name goes to the AI as it is, and may be named in a question looked up on the web.")
    }
}

/// Settings › Public names: every name marked as public, to take back, and one to add by hand —
/// the same list on every device.
struct PublicNamesSettings: View {
    @Environment(\.modelContext) private var context
    @State private var names: [String] = []
    @State private var typed = ""

    var body: some View {
        ForEach(names, id: \.self) { name in
            HStack {
                Text(name)
                Spacer()
                Button { PublicNames.mark(name, public: false, in: context); load() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Disguise “\(name)” again")
            }
        }
        HStack {
            TextField("Add a company or brand", text: $typed)
                .onSubmit(add)
            Button("Add", action: add).disabled(typed.trimmingCharacters(in: .whitespaces).count < 2)
        }
        .onAppear(perform: load)
    }

    private func add() {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return }
        PublicNames.mark(name, public: true, in: context)
        typed = ""
        load()
    }

    private func load() { names = PublicNames.names(in: context) }
}

/// After a public name in People: a small globe — not disguised, and may be named in a question
/// looked up on the web. The same on every device.
struct PublicNameMark: View {
    let party: Party

    var body: some View {
        // Drawn again when a name is marked or unmarked, here or on another device.
        let _ = StoredChanges.shared.count
        if PublicNames.covers(party.name) {
            Image(systemName: "globe").font(.caption).foregroundStyle(Theme.gold)
                .help("Public name — not disguised")
                .accessibilityLabel("Public name — not disguised")
        }
    }
}
