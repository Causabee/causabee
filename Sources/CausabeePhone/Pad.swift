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
}

/// The iPad's sidebar: its controls on top, the overview, and every matter that is going on — the
/// iPhone's rows. A tap opens the matter beside it.
struct PadSidebar: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let sorted = sidebarOrder(matters)
        let open = sorted.filter { !$0.isClosed }
        // The controls lie over the list, on nothing of their own: the list goes under them, as
        // under the system's bars.
        ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Button { navigation.path = [] } label: {
                        Text("Overview").font(.headline)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(navigation.path.isEmpty ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.overview")
                    if !open.isEmpty {
                        Text("Matters").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 14).padding(.top, 10)
                        PhoneMatterRows(matters: open, all: sorted, chosen: navigation.path.last)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 24)
        }
        .safeAreaBar(edge: .top, alignment: .leading, spacing: 0) {
            // On the line of the page's bar: the sheet begins 4 under the screen's safe edge.
            PadControls()
                .padding(.leading, 12)
                .frame(height: PadMetrics.bar - 8)
        }
        // A sheet of glass lying on the page's ground, clear of the screen's edges — as the
        // iPad's own sidebars.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.leading, 8).padding(.top, 4).padding(.bottom, 8)
    }
}

/// The sidebar's button, reading and Auto side by side on the sidebar's own glass — no glass of
/// their own on it; one that is on has the bee's yellow round.
struct PadControls: View {
    @Environment(Navigation.self) private var navigation
    @AppStorage(AutoMode.key) private var auto = false
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 4) {
            PadSidebarButton()
            round("eyeglasses", on: navigation.reading, label: navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode") {
                withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
            }
            round(auto ? "bolt.fill" : "bolt", on: auto, label: "Auto") {
                auto.toggle()
                Haptics.tap()
                if auto { PhoneMailCheck.shared.autoTurnedOn(context: context) }
            }
            .accessibilityValue(auto ? "On" : "Off")
        }
    }

    private func round(_ symbol: String, on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .foregroundStyle(on ? Color.black : Color.secondary)
                .frame(width: 34, height: 34)
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
            Image(systemName: "sidebar.left").font(.system(size: 17, weight: .medium))
                .foregroundStyle(navigation.showsSidebar ? Color.secondary : Color.primary)
                .frame(width: 34, height: 34).contentShape(Rectangle())
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
        if navigation.isPad, navigation.pageWidth > 0 {
            // The room is said by the columns' own row: measured here, the page kept the width it
            // had before the assistant came in beside it.
            content.frame(width: min(navigation.pageWidth, most)).frame(width: navigation.pageWidth)
        } else {
            content.containerRelativeFrame(.horizontal)
        }
    }
}

extension View {
    func pageWide(_ most: CGFloat) -> some View { modifier(PageWide(most: most)) }
}
