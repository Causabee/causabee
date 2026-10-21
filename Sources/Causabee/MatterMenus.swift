import MatterCore
import SwiftData
import SwiftUI

/// One menu for a matter, wherever it is held or right-clicked — a card, a row, the sidebar, the
/// matter's ⋯ — on the Mac, the iPhone and the iPad: pin, rename, its icon, merge. The questions
/// they ask are the window's, so they are asked the same way from wherever the menu is.
struct MatterMenuItems: View {
    let matter: Matter
    /// The matters, when the one holding the menu has them; nil: fetched when one is needed.
    let all: [Matter]?
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if matter.isPinned {
            Button(Say.unpin, systemImage: "pin.slash") { matter.pinnedAt = nil; try? context.save() }
        } else if !matter.isClosed {
            Button(Say.pinToTop, systemImage: "pin") {
                // Full: which one it replaces is asked.
                let all = all ?? ((try? context.fetch(FetchDescriptor<Matter>())) ?? [])
                if Pins.pinned(all).count >= Pins.most { navigation.pinning = matter } else { matter.pinnedAt = Date(); try? context.save() }
            }
        }
        Button(Say.rename, systemImage: "pencil") { navigation.renaming = matter }
        // The icons and the matters to merge with are chosen in a window of their own: as lists in
        // the menu, they were made for every row's menu each time the sidebar drew — thousands of
        // items with fifty matters, and most of a moment's wait on the iPad.
        Button(Say.icon, systemImage: matter.shownIcon) { navigation.choosingIcon = matter }
        Button(Say.mergeWith, systemImage: "arrow.triangle.merge") { navigation.choosingMerge = matter }
    }
}

/// "Merge With …": the matters going on, to choose the one this matter goes into — then asked once
/// more, as before. Only into one going on: a closed one is opened again first.
struct MergeChooser: View {
    let matter: Matter
    let all: [Matter]
    let navigation: Navigation
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var others: [Matter] {
        all.filter { $0 !== matter && !$0.isClosed && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List(others) { other in
                Button {
                    dismiss()
                    // The question comes once this window has gone.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { navigation.merging = (matter, other) }
                } label: {
                    HStack(spacing: 10) {
                        MatterIconTile(matter: other, size: 26)
                        Text(other.name).foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $search, prompt: "Find a matter")
            .navigationTitle("Merge “\(matter.name)” with")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 440)
        #endif
    }
}

extension View {
    /// The icon and the merge, chosen from a matter's menu: the same windows on every device. The
    /// navigation handed in: where this is put, it may not be in the environment yet.
    func matterChoosers(all: [Matter], navigation: Navigation) -> some View { modifier(MatterChoosers(all: all, navigation: navigation)) }
}

private struct MatterChoosers: ViewModifier {
    let all: [Matter]
    let navigation: Navigation

    func body(content: Content) -> some View {
        @Bindable var navigation = navigation
        content
            .sheet(item: $navigation.choosingIcon) { matter in
                MatterIconPicker(matter: matter)
                    #if os(iOS)
                    .presentationDetents([.height(470)]).presentationDragIndicator(.visible)
                    #else
                    .frame(width: 330)
                    #endif
            }
            .sheet(item: $navigation.choosingMerge) { matter in MergeChooser(matter: matter, all: all, navigation: navigation) }
    }
}

/// The words of the menus and buttons, one list for every device: a menu item in Title Case, and
/// "…" where it asks something more before it does it.
enum Say {
    // A matter
    static let pinToTop = "Pin to Top"
    static let unpin = "Unpin"
    static let rename = "Rename …"
    static let mergeWith = "Merge With …"
    static let icon = "Icon …"
    static let openAgain = "Open Again"
    static let closeMatter = "Close Matter …"
    static let exportRTF = "Export as RTF"
    // A task, a date, a person, a link, a file
    static let edit = "Edit …"
    static let delete = "Delete …"
    static let moveToInfo = "Move to Info"
    static let waitsFor = "Waits For"
    static let waitsForChoose = "Waits For …"
    static let stopWaiting = "Stop Waiting"
    static let removeFromMatter = "Remove From Matter"
    static let removeLink = "Remove Link"
    static let nameFromContent = "Name From Content"
    static let useFileName = "Use File Name"
    static let showAgain = "Show Again"
    static let hide = "Hide"
}

/// "Waits For …": the matter's other open tasks, to choose the one this one can only follow. A
/// window of its own: as a list in every task's menu, each row made all the others' names each
/// time the page drew.
struct WaitsForChooser: View {
    let todo: Todo
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var others: [Todo] {
        (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text.localizedStandardCompare($1.text) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List(others, id: \.persistentModelID) { other in
                Button {
                    withAnimation { _ = todo.wait(for: other) }
                    try? context.save()
                    dismiss()
                } label: {
                    HStack {
                        Text(other.text).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if other === todo.waitsFor { Image(systemName: "checkmark").foregroundStyle(Theme.gold) }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Can only be done after")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }
}
