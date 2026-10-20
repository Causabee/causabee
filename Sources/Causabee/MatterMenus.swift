import MatterCore
import SwiftData
import SwiftUI

/// One menu for a matter, wherever it is held or right-clicked — a card, a row, the sidebar, the
/// matter's ⋯ — on the Mac, the iPhone and the iPad: pin, rename, its icon, merge. The questions
/// they ask are the window's, so they are asked the same way from wherever the menu is.
struct MatterMenuItems: View {
    let matter: Matter
    let all: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if matter.isPinned {
            Button(Say.unpin, systemImage: "pin.slash") { matter.pinnedAt = nil; try? context.save() }
        } else if !matter.isClosed {
            Button(Say.pinToTop, systemImage: "pin") {
                // Full: which one it replaces is asked.
                if Pins.pinned(all).count >= Pins.most { navigation.pinning = matter } else { matter.pinnedAt = Date(); try? context.save() }
            }
        }
        Button(Say.rename, systemImage: "pencil") { navigation.renaming = matter }
        MatterIconMenu(matter: matter)
        Menu(Say.mergeWith, systemImage: "arrow.triangle.merge") {
            // Only into a matter that is going on: a closed one is opened again first.
            ForEach(all.filter { $0 !== matter && !$0.isClosed }) { other in
                Button(other.name) { navigation.merging = (matter, other) }
            }
        }
    }
}

/// The words of the menus and buttons, one list for every device: a menu item in Title Case, and
/// "…" where it asks something more before it does it.
enum Say {
    // A matter
    static let pinToTop = "Pin to Top"
    static let unpin = "Unpin"
    static let rename = "Rename …"
    static let mergeWith = "Merge With"
    static let openAgain = "Open Again"
    static let closeMatter = "Close Matter …"
    static let exportRTF = "Export as RTF"
    // A task, a date, a person, a link, a file
    static let edit = "Edit …"
    static let delete = "Delete …"
    static let moveToInfo = "Move to Info"
    static let waitsFor = "Waits For"
    static let stopWaiting = "Stop Waiting"
    static let removeFromMatter = "Remove From Matter"
    static let removeLink = "Remove Link"
    static let nameFromContent = "Name From Content"
    static let useFileName = "Use File Name"
    static let showAgain = "Show Again"
    static let hide = "Hide"
}
