import MatterCore
import SwiftData
import SwiftUI

/// The Mac's sidebar order: what is going on, then the quiet ones by their newest mail, then the
/// closed ones, the last closed first.
@MainActor func sidebarOrder(_ matters: [Matter]) -> [Matter] {
    Once.worked("order", for: matters) { workOutSidebarOrder(matters) }
}

@MainActor private func workOutSidebarOrder(_ matters: [Matter]) -> [Matter] {
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
        // A pinned one is on top already, even when it is quiet.
        let quiet = sorted.filter { !$0.isClosed && !$0.isPinned && !active.contains($0.persistentModelID) }
        let closed = sorted.filter(\.isClosed)
        if !quiet.isEmpty || !closed.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !quiet.isEmpty {
                    DisclosureGroup(isExpanded: $showsQuiet) {
                        PhoneMatterRows(matters: quiet, all: sorted).padding(.top, 6)
                    } label: {
                        Text("Quiet · \(quiet.count)\(Text("  nothing open, no date").font(.footnote).foregroundStyle(.secondary))")
                    }
                }
                if !closed.isEmpty {
                    DisclosureGroup("Closed · \(closed.count)", isExpanded: $showsClosed) {
                        PhoneMatterRows(matters: closed, all: sorted).padding(.top, 6)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .tint(.primary)
        }
    }
}

/// Matters one line each, in a card: each opens with a tap; held, it can be pinned, renamed or merged.
struct PhoneMatterRows: View {
    let matters: [Matter]
    /// Every matter, for "Merge with".
    let all: [Matter]
    /// The matter that is open, in the iPad's sidebar: its row is marked.
    var chosen: PersistentIdentifier? = nil
    /// In the iPad's sidebar: no lines between the rows — beside the marked one they ran into its
    /// grey and tied it to its neighbours — and the mark lies 4 inside the card, clear of its outline.
    var inSidebar = false
    @Environment(Navigation.self) private var navigation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(matters.enumerated()), id: \.element.persistentModelID) { index, matter in
                let isChosen = chosen == matter.persistentModelID
                if index > 0, !inSidebar { Divider().padding(.leading, 62) }
                Button { navigation.open(matter) } label: {
                    // On the mark's grey the icon's own grey would be gone: there it is on white.
                    PhoneMatterRow(matter: matter, tile: isChosen ? Theme.card : Theme.box)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            if isChosen { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.box).padding(4) }
                        }
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
    /// The ground of its icon.
    var tile: Color = Theme.box

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let status = MatterStatus(matter)
        HStack(spacing: 12) {
        MatterIconTile(matter: matter, size: 36, ground: tile)
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
}

/// "Pin to top", then "Rename …" and "Merge with …", as the Mac's sidebar menu has them; the
/// questions they ask are the root's, so they are asked the same way from wherever the menu is.
struct MatterMenuItems: View {
    let matter: Matter
    let all: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if matter.isPinned {
            Button("Unpin", systemImage: "pin.slash") { matter.pinnedAt = nil; try? context.save() }
        } else if !matter.isClosed {
            Button("Pin to top", systemImage: "pin") {
                // Full: which one it replaces is asked.
                if Pins.pinned(all).count >= Pins.most { navigation.pinning = matter } else { matter.pinnedAt = Date(); try? context.save() }
            }
        }
        Button("Rename", systemImage: "pencil") { navigation.renaming = matter }
        MatterIconMenu(matter: matter)
        Menu("Merge with", systemImage: "arrow.triangle.merge") {
            // Only into a matter that is going on: a closed one is opened again first.
            ForEach(all.filter { $0 !== matter && !$0.isClosed }) { other in
                Button(other.name) { navigation.merging = (matter, other) }
            }
        }
    }
}

/// The Mac's two questions: a new name, and whether to merge — with its words. And which pinned
/// matter makes room when as many as fit are pinned.
struct MatterQuestions: ViewModifier {
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Query private var matters: [Matter]
    @State private var newName = ""

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Pin “\(navigation.pinning?.name ?? "")” instead of …", isPresented: Binding(get: { navigation.pinning != nil }, set: { if !$0 { navigation.pinning = nil } }),
                                titleVisibility: .visible) {
                ForEach(Pins.pinned(matters)) { pinned in
                    Button(pinned.name) {
                        pinned.pinnedAt = nil
                        navigation.pinning?.pinnedAt = Date()
                        try? context.save()
                        navigation.pinning = nil
                    }
                }
                Button("Cancel", role: .cancel) { navigation.pinning = nil }
            } message: {
                Text("Up to \(Pins.most) matters stay on top of the overview.")
            }
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
