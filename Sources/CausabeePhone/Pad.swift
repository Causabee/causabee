import MatterCore
import SwiftData
import SwiftUI

/// The iPad's own numbers: the iPhone's parts in the Mac's three columns.
enum PadMetrics {
    static let sidebar: CGFloat = 300
    /// How far the sidebar's glass panel floats in from the window's edges, as Journal's.
    static let inset: CGFloat = 10
    /// The panel's corners.
    static let panelRadius: CGFloat = 26
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
    /// The room the sidebar's capsule takes of the page's bar while the sidebar is put away: 16 in
    /// from the edge, the capsule round the sidebar's button (38 and 3 around it), and 12 to the
    /// matter's icon. It held three buttons once, and the name stood 100 points off to the right.
    static let controls: CGFloat = 16 + 44 + 12
    /// What the bar puts before its first item by itself.
    static let barInset: CGFloat = 10
}

/// The iPad's sidebar, as Journal's: on a floating panel of glass, plain rows — a dark sign and
/// the name, a grey count on the right of what asks for a look — and a soft grey mark on the one
/// that is open. No tiles, no white cards, no gold (8 November).
struct PadSidebar: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    /// The closed matters, unfolded; folded away until asked for, and remembered.
    @AppStorage("pad.showsClosed") private var showsClosed = false

    private func heading(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 2)
    }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let sorted = sidebarOrder(matters)
        let pinned = Pins.pinned(sorted)
        let rest = sorted.filter { !$0.isClosed && !$0.isPinned }
        let closed = sorted.filter(\.isClosed)
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Button { navigation.go([]) } label: {
                    PadSidebarLine(symbol: "square.grid.2x2", name: "Overview", marked: navigation.path.isEmpty) { PadMailSign() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar.overview")
                if !pinned.isEmpty { heading("Pinned"); rows(pinned, all: sorted) }
                if !rest.isEmpty { heading("Matters"); rows(rest, all: sorted) }
                if !closed.isEmpty {
                    Button { withAnimation(.snappy(duration: 0.2)) { showsClosed.toggle() } } label: {
                        HStack(spacing: 6) {
                            Text("Closed").font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(showsClosed ? 90 : 0))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.closed")
                    .accessibilityHint(showsClosed ? "Hides the closed matters" : "Shows the closed matters")
                    if showsClosed { rows(closed, all: sorted) }
                }
            }
            .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .top, alignment: .leading, spacing: 0) {
            // The sidebar's button inside the panel, at its top, as Journal's.
            PadControls()
                .padding(.leading, 10)
                .frame(height: PadMetrics.bar + 8)
        }
    }

    private func rows(_ list: [Matter], all: [Matter]) -> some View {
        ForEach(list, id: \.persistentModelID) { matter in
            Button { navigation.open(matter) } label: {
                PadSidebarRow(matter: matter, marked: navigation.path.last == matter.persistentModelID)
            }
            .buttonStyle(.plain)
            .contextMenu { MatterMenuItems(matter: matter, all: all).menuSigns() }
        }
    }
}

/// One line of the sidebar: a sign, a name, what stands on the right, and the soft mark when open.
struct PadSidebarLine<Trailing: View>: View {
    let symbol: String
    let name: String
    var marked = false
    var quiet = false
    var dot = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17))
                .foregroundStyle(quiet ? .secondary : .primary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(name).lineLimit(1).foregroundStyle(quiet ? .secondary : .primary)
            if dot { NewsDot() }
            Spacer(minLength: 8)
            trailing()
        }
        .font(.body.weight(marked ? .semibold : .regular))
        .padding(.horizontal, 12).frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if marked { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.07)) }
        }
        .contentShape(Rectangle())
    }
}

/// A matter in the sidebar: what asks for a look as a grey count on the right — what is overdue,
/// new mail in a closed matter — and news not seen yet as its dot.
struct PadSidebarRow: View {
    let matter: Matter
    var marked = false

    var body: some View {
        let summary = StoredChanges.shared.summary(matter)
        let new = matter.isClosed ? summary.newMailsSinceClosed : 0
        let late = matter.isClosed ? 0 : summary.overdue.count
        PadSidebarLine(symbol: matter.shownIcon, name: matter.name, marked: marked, quiet: matter.isClosed, dot: summary.news != nil) {
            if late > 0 {
                Text("\(late)").monospacedDigit().foregroundStyle(.secondary).accessibilityLabel("\(late) overdue")
            } else if new > 0 {
                Text("\(new)").monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel("\(new) new \(new == 1 ? "mail" : "mails")")
            }
        }
    }
}

/// The sidebar's button on glass, as by the Mac's window buttons — a finger high. Reading mode is in
/// the matter's ⋯ menu, and Pro is the bee's colour in the corner, as on the iPhone.
struct PadControls: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        HStack(spacing: 10) {
            PadSidebarButton()
        }
        // The yellow round of one that is on sits in the capsule's own curve.
        // As high as the page's own find and ⋯, and as black: beside them a smaller, greyer
        // capsule looked like something else.
        // The yellow round of one that is on sits in the capsule's own curve: 3 from its end as
        // from its top and bottom.
        .padding(3)
        .onGlass(Capsule())
    }

    private func round(_ symbol: String, on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                .foregroundStyle(on ? Color.black : Color.primary)
                .frame(width: 38, height: 38)
                .background { if on { Circle().fill(Theme.bee) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Shows the sidebar and puts it away.
struct PadSidebarButton: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { navigation.showsSidebar.toggle() }
        } label: {
            Image(systemName: "sidebar.left").font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 38, height: 38).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(navigation.showsSidebar ? "Hide Sidebar" : "Show Sidebar")
        .accessibilityIdentifier("sidebar.toggle")
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
        Text("\(number)").monospacedDigit().foregroundStyle(.secondary)
            .accessibilityLabel("\(number) new \(number == 1 ? "mail" : "mails")")
    }
}
