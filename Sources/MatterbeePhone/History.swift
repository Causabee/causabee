import MatterCore
import SwiftData
import SwiftUI

/// One conversation of a matter, as the Mac's card: its subject once, the first mail on top, and
/// each reply under the mail it answers, joined by a line.
struct PhoneThreadCard: View {
    let thread: MailThreads.Thread
    let matter: Matter

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
                    PhoneThreadMailRow(row: row, started: row.depth == 0 && thread.count > 1, matter: matter)
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

/// One mail in a conversation, set in by how deep it answers, with the lines to the mail it answers
/// on its left. To see the mail itself, it opens in Mail.
struct PhoneThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.openURL) private var openURL

    static let step: CGFloat = 16
    static let deepest = 3

    var body: some View {
        let depth = min(row.depth, Self.deepest)
        let entry = row.entry
        HStack(alignment: .top, spacing: 0) {
            if depth > 0 {
                PhoneThreadRails(depth: depth, rails: Array(row.rails.suffix(depth - 1)), isLast: row.isLast)
                    .stroke(Theme.strongLine, lineWidth: 1.5)
                    .frame(width: CGFloat(depth) * Self.step)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Email.displayName(in: entry.from) ?? Email.address(in: entry.from)).fontWeight(.medium).lineLimit(1)
                    if started { BeeChip(text: "started") }
                    Spacer(minLength: 4)
                    Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if let digest = entry.digest, !digest.isEmpty {
                    Text(digest).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                if let url = entry.mailURL {
                    Button(label(entry.source.kind)) { openURL(url) }
                        .font(.caption).foregroundStyle(Theme.gold)
                }
            }
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .contextMenu {
            AskMatterbeeButton { navigation.talk(entry.title, kind: "Mail", in: matter) }
        }
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
