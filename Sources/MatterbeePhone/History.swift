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
/// on its left; "Read" takes its text out of the mailbox — read-only, this one mail.
struct PhoneThreadMailRow: View {
    let row: MailThreads.Row
    let started: Bool
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.openURL) private var openURL
    @State private var reading = false

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
                HStack(spacing: 14) {
                    if entry.source.pointer.hasPrefix("imap://") {
                        Button("Read") { reading = true }.tool()
                    }
                    if let url = entry.mailURL {
                        Button(label(entry.source.kind)) { openURL(url) }
                    }
                }
                .font(.caption).foregroundStyle(Theme.gold)
            }
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Ask the assistant", systemImage: "bubble.left.and.bubble.right") { navigation.talk(entry.title, kind: "Mail", in: matter) }
        }
        .sheet(isPresented: $reading) { PhoneMailReader(entry: entry) }
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

/// A mail's own words, as the Mac's reader shows them: here taken out of the mailbox when opened —
/// read-only, only this one mail — and kept nowhere.
struct PhoneMailReader: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @State private var text: String?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title.isEmpty ? "(no subject)" : entry.title).font(.headline)
                    if let digest = entry.digest, !digest.isEmpty {
                        Text(digest).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    if let text {
                        Text(Linked.text(text)).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    } else if let failure {
                        Text(failure).font(.callout).foregroundStyle(Theme.warning)
                    } else {
                        HStack(spacing: 8) { BeeLoader(size: 15); Text("Getting the mail …").foregroundStyle(.secondary) }
                    }
                }
                .padding(16)
                .containerRelativeFrame(.horizontal)
            }
            .navigationTitle("Mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        let host = entry.source.pointer.firstMatch(of: /^imap:\/\/([^\/]+)\//).map { String($0.output.1) }
        let saved = Keychain.accounts().filter { !$0.usesGoogle }
        guard let account = saved.first(where: { $0.host == host }) ?? saved.first else {
            failure = "Add your mail account first: Settings (⋯ on the overview)."
            return
        }
        do {
            guard let password = try Keychain.password(for: account.user) else { throw MailFetch.Failure.gone(account.user) }
            let client = try await IMAPClient.connect(to: account, password: password)
            let data: Data
            do { data = try await MailFetch.message(pointer: entry.source.pointer, messageID: entry.messageID, from: client) }
            catch { await client.logout(); throw error }
            await client.logout()
            let email = EMLParser.parse(data: data, url: URL(string: entry.source.pointer) ?? URL(fileURLWithPath: "/"))
            text = "From: \(email.from)\n\n" + email.body
        } catch {
            failure = "\(error)"
        }
    }
}
