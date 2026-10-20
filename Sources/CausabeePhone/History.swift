import MatterCore
import SwiftData
import SwiftUI

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
