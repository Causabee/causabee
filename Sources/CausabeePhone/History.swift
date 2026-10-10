import MatterCore
import SwiftData
import SwiftUI

/// One conversation of a matter, as the Mac's card: its subject once, the first mail on top, and
/// each reply under the mail it answers, joined by a line.
struct PhoneThreadCard: View {
    let thread: MailThreads.Thread
    let matter: Matter
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
                let joined = MailThreads.joined(thread.rows, deepest: PhoneThreadMailRow.deepest)
                ForEach(thread.rows) { row in
                    PhoneThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1, sent: me.sent(row.entry.from), matter: matter, joinsNext: joined.contains(row.id))
                        .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                }
            }
        }
        .padding(14)
        .phoneCard()
    }

    private var span: String {
        let first = thread.first.map(Dates.short) ?? "", last = thread.last.map(Dates.short) ?? ""
        return first == last ? first : "\(first) – \(last)"
    }
}

/// Which way a mail went: in to the owner, or out from them.
struct PhoneMailWay: View {
    let sent: Bool

    var body: some View {
        Image(systemName: sent ? "arrow.up.right" : "arrow.down.left")
            .font(.caption.weight(.semibold))
            .foregroundStyle(sent ? Theme.gold : Color.secondary)
            .accessibilityLabel(sent ? "sent" : "came in")
    }
}

/// One mail in a conversation, set in by how deep it answers, with the lines to the mail it answers
/// on its left. To see the mail itself, it opens in Mail — from the menu a long press brings.
struct PhoneThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    /// The owner wrote it: it went out, the others came in.
    let sent: Bool
    let matter: Matter
    /// At the deepest indent and answered: its line goes on down to its answer.
    var joinsNext = false
    @Environment(Navigation.self) private var navigation
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @State private var naming = false
    @State private var newName = ""

    nonisolated static let step: CGFloat = 16
    static let deepest = 3

    var body: some View {
        let depth = min(row.depth, Self.deepest)
        let entry = row.entry
        // The lines to the mail it answers are drawn behind the row, as tall as the row is — as on
        // the Mac, where set beside it they asked for all the height there was.
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(sent ? "You" : entry.matter?.writerName(entry.from) ?? Email.address(in: entry.from)).fontWeight(.medium).lineLimit(1)
                        if entry.source.kind == .mail { PhoneMailWay(sent: sent) }
                    }
                    .accessibilityElement(children: .combine)
                    if started { BeeChip(text: "started") }
                    Spacer(minLength: 4)
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    // As a file's row has it: everything the mail can do, behind its dots.
                    Menu { items(entry) } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
                    }
                    .tint(.secondary)
                    .accessibilityLabel("More")
                    // While reading, a long press still has everything.
                    .tool()
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, depth > 0 ? 6 : 0)
        }
        .padding(.leading, CGFloat(depth) * Self.step)
        .background(alignment: .topLeading) {
            if depth > 0 {
                PhoneThreadRails(depth: depth, rails: Array(row.rails.prefix(depth - 1)), isLast: row.isLast && !joinsNext)
                    .stroke(Theme.strongLine, lineWidth: 1.5)
                    .frame(width: CGFloat(depth) * Self.step)
            }
        }
        .contentShape(Rectangle())
        .contextMenu { Group { items(entry) }.menuSigns() }
        .alert("Move to a new matter", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Move") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let from = entry.matter else { return }
                _ = try? from.split([entry], intoNewMatterNamed: name, turnsSince: nil, in: context)
            }
        } message: {
            Text("The mail goes, with the tasks, dates and files only it brought.")
        }
    }

    /// What the dots and a long press both bring.
    @ViewBuilder
    private func items(_ entry: Entry) -> some View {
        // To see the mail itself: first in its menu, as "Open" is for a file.
        if let url = entry.mailURL {
            Button(label(entry.source.kind), systemImage: entry.source.kind == .mail ? "envelope" : "arrow.up.forward.app") { openURL(url) }
        }
        AskCausabeeButton { navigation.talk(entry.title, kind: "Mail", in: matter) }
        PhoneMoveMail(entry: entry) { newName = Matter.suggestedName(for: [entry]); naming = true }
    }

    /// A letter scanned and taken in is no mail: the button says what it opens.
    private func label(_ kind: Source.Kind) -> String {
        switch kind {
        case .screenshot: "Open screenshot"
        case .document: "Open document"
        case .photo: "Open photo"
        default: "Open mail"
        }
    }
}

/// The lines left of a reply, as the Mac draws them.
struct PhoneThreadRails: Shape {
    let depth: Int
    let rails: [Bool]
    let isLast: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = PhoneThreadMailRow.step
        func x(_ level: Int) -> CGFloat { CGFloat(level - 1) * step + 6 }
        for (index, goesOn) in rails.enumerated() where goesOn {
            path.move(to: CGPoint(x: x(index + 1), y: rect.minY))
            path.addLine(to: CGPoint(x: x(index + 1), y: rect.maxY))
        }
        let turn: CGFloat = 16
        path.move(to: CGPoint(x: x(depth), y: rect.minY))
        path.addLine(to: CGPoint(x: x(depth), y: isLast ? turn : rect.maxY))
        path.move(to: CGPoint(x: x(depth), y: turn))
        path.addLine(to: CGPoint(x: x(depth) + step - 6, y: turn))
        return path
    }
}

/// "Move to another matter": the open matters, the newest mail first, the one it is in ticked; and
/// a new one. The mail goes with what only it brought — its tasks, dates, decisions, files and links.
struct PhoneMoveMail: View {
    let entry: Entry
    let newMatter: () -> Void
    @Query private var matters: [Matter]
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu {
            ForEach(Self.order(matters, current: entry.matter)) { matter in
                if matter === entry.matter {
                    Button(matter.name, systemImage: "checkmark") { }.disabled(true)
                } else {
                    Button(matter.name) { Self.move(entry, to: matter, in: context) }
                }
            }
            Divider()
            Button("A new matter", systemImage: "plus.circle", action: newMatter)
        } label: {
            Label("Move to another matter", systemImage: "folder")
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
