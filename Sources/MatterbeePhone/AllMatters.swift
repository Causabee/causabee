import MatterCore
import SwiftData
import SwiftUI

/// The Mac's sidebar order: what is going on, then the quiet ones by their newest mail, then the
/// closed ones, the last closed first.
func sidebarOrder(_ matters: [Matter]) -> [Matter] {
    let active = activeMatters(matters)
    let shown = Set(active.map(\.persistentModelID))
    let byNewestMail = { (list: [Matter]) in
        list.map { ($0, MatterStatus($0).lastDate ?? .distantPast) }.sorted { $0.1 > $1.1 }.map(\.0)
    }
    let quiet = byNewestMail(matters.filter { !$0.isClosed && !shown.contains($0.persistentModelID) })
    let closed = matters.filter(\.isClosed).sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
    return active + quiet + closed
}

/// Under the overview's cards, only what the cards do not show: the quiet matters — nothing open,
/// no date — and the closed ones, each folded away until opened. Not the Mac's sidebar again: the
/// matters going on are the cards above. Each opens with a tap; held, it can be renamed or merged.
struct OtherMattersList: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @State private var showsQuiet = false
    @State private var showsClosed = false

    var body: some View {
        let sorted = sidebarOrder(matters)
        let active = Set(activeMatters(matters).map(\.persistentModelID))
        let quiet = sorted.filter { !$0.isClosed && !active.contains($0.persistentModelID) }
        let closed = sorted.filter(\.isClosed)
        if !quiet.isEmpty || !closed.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !quiet.isEmpty {
                    DisclosureGroup(isExpanded: $showsQuiet) {
                        rows(quiet, all: sorted).padding(.top, 6)
                    } label: {
                        Text("Quiet · \(quiet.count)") + Text("  nothing open, no date").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !closed.isEmpty {
                    DisclosureGroup("Closed · \(closed.count)", isExpanded: $showsClosed) {
                        rows(closed, all: sorted).padding(.top, 6)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .tint(.primary)
        }
    }

    private func rows(_ list: [Matter], all: [Matter]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.persistentModelID) { index, matter in
                if index > 0 { Divider().padding(.leading, 14) }
                Button { navigation.open(matter) } label: {
                    PhoneMatterRow(matter: matter)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { MatterMenuItems(matter: matter, all: all) }
            }
        }
        .phoneCard()
    }
}

/// A matter in the list, as the Mac's sidebar row: its name, and how many are open, the next day
/// and what is overdue — or when it was closed, and new mail since.
struct PhoneMatterRow: View {
    let matter: Matter

    var body: some View {
        let status = MatterStatus(matter)
        VStack(alignment: .leading, spacing: 2) {
            Text(matter.name).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary)
            HStack(spacing: 4) {
                if matter.isClosed {
                    Text("closed \(matter.closedAt.map(Dates.short) ?? "")")
                    let new = status.mailsSinceClosed.count
                    if new > 0 { Text("· \(new) new \(new == 1 ? "mail" : "mails")").foregroundStyle(Theme.warning) }
                } else {
                    Text("\(matter.openTodos.count) open")
                    if let next = status.next { Text("· \(Dates.short(next.day))") }
                    if !status.overdue.isEmpty { Text("· \(status.overdue.count) overdue").foregroundStyle(Theme.warning) }
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// "Rename …" and "Merge with …", as the Mac's sidebar menu has them; the questions they ask are
/// the root's, so they are asked the same way from wherever the menu is.
struct MatterMenuItems: View {
    let matter: Matter
    let all: [Matter]
    @Environment(Navigation.self) private var navigation

    var body: some View {
        Button("Rename …") { navigation.renaming = matter }
        Menu("Merge with …") {
            ForEach(all.filter { $0 !== matter }) { other in
                Button(other.name + (other.isClosed ? " (closed)" : "")) { navigation.merging = (matter, other) }
            }
        }
    }
}

/// The Mac's two questions: a new name, and whether to merge — with its words.
struct MatterQuestions: ViewModifier {
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var newName = ""

    func body(content: Content) -> some View {
        content
            .confirmationDialog(mergeQuestion, isPresented: Binding(get: { navigation.merging != nil }, set: { if !$0 { navigation.merging = nil } }),
                                titleVisibility: .visible) {
                Button("Merge") {
                    if let (from, into) = navigation.merging {
                        let gone = from.persistentModelID
                        into.absorb(from, in: context)
                        try? context.save()
                        // The page of the one merged away shows the one it went into.
                        navigation.path = navigation.path.map { $0 == gone ? into.persistentModelID : $0 }
                        if navigation.path.last != into.persistentModelID { navigation.open(into) }
                    }
                    navigation.merging = nil
                }
                Button("Cancel", role: .cancel) { navigation.merging = nil }
            } message: {
                Text("All mails, tasks, appointments and people come along. The old name stays as an alias, so new mail still arrives. You cannot split it again later.")
            }
            .alert("Rename matter", isPresented: Binding(get: { navigation.renaming != nil }, set: { if !$0 { navigation.renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Save") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let matter = navigation.renaming, !name.isEmpty, name != matter.name { matter.rename(to: name); try? context.save() }
                    navigation.renaming = nil
                }
                Button("Cancel", role: .cancel) { navigation.renaming = nil }
            } message: {
                Text("The old name stays as an alias, so new mail still finds the matter.")
            }
            .onChange(of: navigation.renaming?.persistentModelID) { newName = navigation.renaming?.name ?? "" }
    }

    private var mergeQuestion: String {
        guard let (from, into) = navigation.merging else { return "" }
        return "Merge “\(from.name)” into “\(into.name)”?"
    }
}
