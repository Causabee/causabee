import MatterCore
import SwiftData
import SwiftUI

/// The iPad's own numbers: the iPhone's parts in the Mac's three columns.
enum PadMetrics {
    static let sidebar: CGFloat = 300
    static let assistant: CGFloat = 360
    /// A page of a matter is no wider than is good to read.
    static let page: CGFloat = 700
    /// The overview with its cards side by side.
    static let widePage: CGFloat = 1000
    static let twoColumns: CGFloat = 720
    /// From this width on the sidebar, the page and the assistant fit side by side: the iPad on its side.
    static let wide: CGFloat = 1000
    /// The line the sidebar's controls, the page's bar and the assistant's name stand on.
    static let bar: CGFloat = 44
    /// The room the sidebar's capsule takes of the page's bar while the sidebar is put away.
    static let controls: CGFloat = 168
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
        // The controls lie over the list, on nothing of their own: the list goes under them, as
        // under the system's bars.
        ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Button { navigation.go([]) } label: {
                        Text("Overview").font(.headline)
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
        .safeAreaBar(edge: .top, alignment: .leading, spacing: 0) {
            // Clear of the window's own three buttons, where the iPad shows them in this corner.
            PadControls()
                .padding(.leading, 16)
                .containerCornerOffset(.leading, sizeToFit: true)
                .frame(height: PadMetrics.bar)
        }
        .background(Color(.secondarySystemBackground))
    }
}

/// The sidebar's button, reading and Auto in one capsule of glass, as by the Mac's window buttons —
/// a finger high. Only they are on glass: the list under them is the sidebar's own ground.
struct PadControls: View {
    @Environment(Navigation.self) private var navigation
    @AppStorage(AutoMode.key) private var auto = false
    @Environment(\.modelContext) private var context
    @State private var asksAuto = false

    var body: some View {
        HStack(spacing: 10) {
            PadSidebarButton()
            round("eyeglasses", on: navigation.reading, label: navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode") {
                withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
            }
            round(auto ? "bolt.fill" : "bolt", on: auto, label: "Auto") {
                // The first time it is turned on, what it does is said and asked.
                if AutoMode.asksFirst { asksAuto = true; return }
                auto.toggle()
                Haptics.tap()
                if auto { PhoneMailCheck.shared.autoTurnedOn(context: context) }
            }
            .accessibilityValue(auto ? "On" : "Off")
            .asksBeforeAuto($asksAuto) {
                auto = true
                Haptics.tap()
                PhoneMailCheck.shared.autoTurnedOn(context: context)
            }
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
    @Environment(Navigation.self) private var navigation

    func body(content: Content) -> some View {
        // The room is said in points, from the window as it was measured: beside the columns on a
        // wide iPad, the whole window on the iPhone and in an iPad's narrow window. Asked of its
        // container instead (containerRelativeFrame), a page kept the width it had before an
        // iPad's window was made smaller, and stood cut off on both sides. One view for both, so
        // nothing on the page starts anew when a window crosses from wide to narrow.
        let room: CGFloat? = navigation.whole > 0 ? (navigation.isPad ? navigation.pageWidth : navigation.whole) : nil
        content.frame(width: room.map { min($0, most) }).frame(width: room)
    }
}

extension View {
    func pageWide(_ most: CGFloat) -> some View { modifier(PageWide(most: most)) }
}
