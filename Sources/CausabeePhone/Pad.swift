import MatterCore
import SwiftData
import SwiftUI

/// The iPad's own numbers: the iPhone's parts in the Mac's three columns.
enum PadMetrics {
    static let sidebar: CGFloat = 300
    static let assistant: CGFloat = 360
    /// A page of a matter is no wider than is good to read.
    static let page: CGFloat = 700
    /// What is ahead, in a column of its own beside a matter's page on a wide iPad.
    static let column: CGFloat = 330
    /// The overview with its cards side by side.
    static let widePage: CGFloat = 1000
    static let twoColumns: CGFloat = 720
    /// From this width on the sidebar, the page and the assistant fit side by side: the iPad on its side.
    static let wide: CGFloat = 1000
    /// The line the sidebar's controls, the page's bar and the assistant's name stand on.
    static let bar: CGFloat = 44
    /// The system's sidebar button, before a page's first item while the sidebar is put away.
    static let toggle: CGFloat = 92
    /// What the bar puts before its first item by itself.
    static let barInset: CGFloat = 10
}

/// The iPad's sidebar, as Mail's: the system's own sidebar list on Liquid Glass — a large title,
/// a tinted sign and the name on each row, what asks for a look on the right, sections that fold,
/// and the system's mark on the one that is open (8 November: white cards on the glass, and tiles).
struct PadSidebar: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    /// The closed matters, unfolded; folded away until asked for, and remembered.
    @AppStorage("pad.showsClosed") private var showsClosed = false

    /// What a row of the sidebar stands for.
    enum Place: Hashable { case overview, matter(PersistentIdentifier) }

    private var chosen: Binding<Place?> {
        Binding(
            get: { navigation.path.last.map { .matter($0) } ?? .overview },
            set: { place in
                switch place {
                case .matter(let id): if let matter = matters.first(where: { $0.persistentModelID == id }) { navigation.open(matter) }
                case .overview, nil: navigation.go([])
                }
            })
    }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let sorted = sidebarOrder(matters)
        let pinned = Pins.pinned(sorted)
        let rest = sorted.filter { !$0.isClosed && !$0.isPinned }
        let closed = sorted.filter(\.isClosed)
        List(selection: chosen) {
            Label { HStack { Text("Overview"); Spacer(minLength: 8); PadMailSign() } } icon: {
                Image(systemName: "square.grid.2x2")
            }
            .tag(Place.overview)
            .accessibilityIdentifier("sidebar.overview")
            if !pinned.isEmpty {
                Section("Pinned") { rows(pinned, all: sorted) }
            }
            if !rest.isEmpty {
                Section("Matters") { rows(rest, all: sorted) }
            }
            if !closed.isEmpty {
                Section("Closed", isExpanded: $showsClosed) { rows(closed, all: sorted) }
                    .accessibilityIdentifier("sidebar.closed")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .navigationTitle("Causabee")
    }

    private func rows(_ list: [Matter], all: [Matter]) -> some View {
        ForEach(list, id: \.persistentModelID) { matter in
            PadSidebarRow(matter: matter)
                .tag(Place.matter(matter.persistentModelID))
                .contextMenu { MatterMenuItems(matter: matter, all: all).menuSigns() }
        }
    }
}

/// A matter in the sidebar, as a mailbox in Mail's: its sign tinted, its name, and on the right
/// only what asks for a look — what is overdue, new mail in a closed matter, news not seen yet.
struct PadSidebarRow: View {
    let matter: Matter

    var body: some View {
        let summary = StoredChanges.shared.summary(matter)
        let new = matter.isClosed ? summary.newMailsSinceClosed : 0
        let late = matter.isClosed ? 0 : summary.overdue.count
        Label {
            HStack(spacing: 6) {
                Text(matter.name).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary)
                if summary.news != nil { NewsDot() }
                Spacer(minLength: 8)
                if late > 0 {
                    Text("\(late)").monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityLabel("\(late) overdue")
                } else if new > 0 {
                    Text("\(new)").monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityLabel("\(new) new \(new == 1 ? "mail" : "mails")")
                }
            }
        } icon: {
            // Tinted by the list itself, which turns it white on the marked row, as Mail's signs.
            Image(systemName: matter.shownIcon)
        }
    }
}

/// A page exactly as wide as its place — nothing on it, a long address, a word without a break,
/// can make it wider and let it slide sideways — and on an iPad no wider than is good to read.
private struct PageWide: ViewModifier {
    let most: CGFloat
    /// What stands beside the page in its row: left in, the row is wider than its room, and
    /// stands cut off on both sides.
    var beside: CGFloat = 0
    @Environment(Navigation.self) private var navigation

    func body(content: Content) -> some View {
        // The room is said in points, from the window as it was measured: beside the columns on a
        // wide iPad, the whole window on the iPhone and in an iPad's narrow window. Asked of its
        // container instead (containerRelativeFrame), a page kept the width it had before an
        // iPad's window was made smaller, and stood cut off on both sides. One view for both, so
        // nothing on the page starts anew when a window crosses from wide to narrow.
        let room: CGFloat? = navigation.whole > 0 ? (navigation.isPad ? navigation.pageWidth - beside : navigation.whole) : nil
        content.frame(width: room.map { min($0, most) }).frame(width: room)
    }
}

extension View {
    func pageWide(_ most: CGFloat, beside: CGFloat = 0) -> some View { modifier(PageWide(most: most, beside: beside)) }
}

/// Beside the sidebar's Overview: the bee while mail is read, and how many new mails wait there.
/// With a matter open the overview's own line is out of sight — the Mac's sidebar shows it too.
struct PadMailSign: View {
    var body: some View {
        switch PhoneMailCheck.shared.state {
        case .reading, .sending:
            BeeLoader(size: 13).accessibilityLabel("Looking for mail")
        case .newMail(let look, _), .ready(let look, _):
            count(look.pending)
        case .demoNew:
            count(DemoData.newMail.count)
        case .answered:
            Circle().fill(Theme.bee).frame(width: 8, height: 8).accessibilityLabel("Mail read, to take in")
        default:
            EmptyView()
        }
    }

    private func count(_ number: Int) -> some View {
        Text("\(number)").font(.footnote.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Theme.bee, in: Capsule())
            .foregroundStyle(.black)
            .accessibilityLabel("\(number) new \(number == 1 ? "mail" : "mails")")
    }
}
