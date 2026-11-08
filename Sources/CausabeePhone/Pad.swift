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

/// The iPad's sidebar: its controls on top, the overview, and every matter that is going on — the
/// iPhone's rows. A tap opens the matter beside it.
struct PadSidebar: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    /// The closed matters, unfolded; folded away until asked for, and remembered.
    @AppStorage("pad.showsClosed") private var showsClosed = false

    private func heading(_ title: String) -> some View {
        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.top, 10)
    }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let sorted = sidebarOrder(matters)
        let open = sorted.filter { !$0.isClosed }
        ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Button { navigation.go([]) } label: {
                        // With a tile of its own, as every matter under it has — and as on the Mac.
                        // On the sidebar's grey the tile is white; on the mark's white, grey.
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 18))
                                .frame(width: 36, height: 36)
                                .background(navigation.path.isEmpty ? Theme.box : Theme.card, in: RoundedRectangle(cornerRadius: 36 * 0.27))
                                .accessibilityHidden(true)
                            Text("Overview").font(.headline)
                            Spacer(minLength: 8)
                            PadMailSign()
                        }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(navigation.path.isEmpty ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.overview")
                    // The Mac's sections: what is pinned, the matters, and the closed ones folded away.
                    let pinned = Pins.pinned(sorted)
                    if !pinned.isEmpty {
                        heading("Pinned")
                        PhoneMatterRows(matters: pinned, all: sorted, chosen: navigation.path.last, inSidebar: true)
                    }
                    let rest = open.filter { !$0.isPinned }
                    if !rest.isEmpty {
                        heading("Matters")
                        PhoneMatterRows(matters: rest, all: sorted, chosen: navigation.path.last, inSidebar: true)
                    }
                    let closed = sorted.filter(\.isClosed)
                    if !closed.isEmpty {
                        Button { withAnimation(.snappy(duration: 0.2)) { showsClosed.toggle() } } label: {
                            HStack(spacing: 6) {
                                Text("Closed · \(closed.count)").font(.footnote.weight(.semibold))
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                    .rotationEffect(.degrees(showsClosed ? 90 : 0))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sidebar.closed")
                        .accessibilityHint(showsClosed ? "Hides the closed matters" : "Shows the closed matters")
                        if showsClosed { PhoneMatterRows(matters: closed, all: sorted, chosen: navigation.path.last, inSidebar: true) }
                    }
                }
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 24)
        }
        // No ground of its own: the split view's glass shows through, and its bar holds the
        // system's button to put the sidebar away.
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
