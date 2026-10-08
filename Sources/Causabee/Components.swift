import AppKit
import MatterCore
import SwiftUI

extension View {
    /// A text field on a card: white, no border — open or taken in alike.
    func cardField() -> some View {
        textFieldStyle(.plain)
            .padding(.vertical, 4).padding(.horizontal, 6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 5))
    }

    /// The filled button of a place: near-black, white words. While it cannot be pressed yet it
    /// is grey with grey words — a faded black one could not be read. Drawn by us rather than
    /// by AppKit, which greys a prominent button out whenever the window is not in front and
    /// left the white words on light grey.
    func inkButton() -> some View { filledButton() }
}

extension View {
    /// A row of the sidebar that opens something: the whole width is the target, and the one that
    /// is open lies on a light grey — secondary.opacity(0.08), radius 6.
    func sidebarRow(selected: Bool, open: @escaping () -> Void) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.secondary.opacity(0.08) : .clear)
                    .padding(.horizontal, 10)
            )
    }
}

/// Shows or hides the sidebar: a small plain icon, no round button.
struct SidebarButton: View {
    @Environment(Navigation.self) private var navigation
    var body: some View {
        Button {
            // One movement for all of it: the sidebar, the pages, the assistant's bar.
            withAnimation(.easeInOut(duration: 0.25)) { navigation.sidebarHidden.toggle() }
        } label: {
            Image(systemName: "sidebar.left").font(.title3).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .quickLabel(navigation.sidebarHidden ? "Show Sidebar" : "Hide Sidebar")
        .accessibilityLabel("Sidebar").accessibilityIdentifier("window.sidebar")
    }
}


extension View {
    /// The system's soft scroll edge on top: what scrolls up blurs and fades out there.
    @ViewBuilder
    func softTopEdge() -> some View {
        if #available(macOS 26.0, *) { scrollEdgeEffectStyle(.soft, for: .top) } else { self }
    }
}

extension View {
    /// A small dark label under a window button, sooner than the Mac's own tooltip, which waits
    /// about a second.
    func quickLabel(_ text: String) -> some View { modifier(QuickLabel(text: text)) }
}

private struct QuickLabel: ViewModifier {
    let text: String
    @State private var hovering = false
    @State private var shows = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                if inside {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if hovering { withAnimation(.easeOut(duration: 0.1)) { shows = true } }
                    }
                } else {
                    shows = false
                }
            }
            .overlay(alignment: .topLeading) {
                if shows {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(Theme.onInk)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 5))
                        .offset(y: 32)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
    }
}

/// Beside the glasses: Auto on and off — new mail and files read by the AI as soon as they are
/// there, or only when the owner says so; what is taken in stays theirs either way. Theirs to
/// choose, and plain to see which it is.
struct AutoButton: View {
    @AppStorage(AutoMode.key) private var auto = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { auto.toggle() }
        } label: {
            // On: a black bolt on the bee's yellow, round, as the glasses while reading.
            Image(systemName: auto ? "bolt.fill" : "bolt").font(.body)
                .foregroundStyle(auto ? Color.black : Color.secondary)
                .frame(width: 26, height: 26)
                .background { if auto { Circle().fill(Theme.bee) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .quickLabel(auto ? "Turn Auto Off: mail and files wait for “Sort in”, next steps and summaries for a click"
                         : "Turn Auto On: mail and files are read at once, and a matter’s next step and summary are written again when its record changes; you decide what is taken in")
        // What it has spent today, for the asking.
        .help(AutoUpdate.spentWords ?? (auto ? "Auto has spent nothing today on next steps and summaries" : "Auto is off"))
        .accessibilityLabel("Auto")
        .accessibilityValue(auto ? "On" : "Off")
        .accessibilityIdentifier("window.auto")
    }
}

/// Beside the sidebar's button: reading on and off. Its label comes quicker than the Mac's own
/// tooltip, which waits about a second.
struct ReadingButton: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
        } label: {
            // On: black glasses on the bee's yellow, round — plain to see that reading is on.
            Image(systemName: "eyeglasses").font(.title3)
                .foregroundStyle(navigation.reading ? Color.black : Color.secondary)
                .frame(width: 26, height: 26)
                .background { if navigation.reading { Circle().fill(Theme.bee) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .quickLabel(navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode")
    }
}

/// The window's own frame, in one place: the numbers the sidebar, its button and the assistant's
/// bar are laid out by.
enum WindowMetrics {
    /// The top line the window's three buttons sit in the middle of (the empty toolbar's height).
    static let topLine: CGFloat = 52
    static let sidebarWidth: CGFloat = 270
    /// The sidebar's button: 12 right of the green button, in the middle of the top line.
    static let sidebarButtonX: CGFloat = 87
    static let sidebarButtonTop: CGFloat = (topLine - 26) / 2
}

/// The window without the Mac's bar showing: an empty toolbar of its own makes the title bar 52 high,
/// and AppKit itself then sets the three buttons in its middle, as far in from the left as from the
/// top. Nothing of the toolbar is seen; Causabee draws everything under it.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Setter() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class Setter: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            if window.toolbar == nil {
                let toolbar = NSToolbar(identifier: "causabee.window")
                window.toolbar = toolbar
            }
            window.toolbarStyle = .unified
            // A test asks for a window of a width — the narrowest, where a page's name comes to
            // stand by the window's controls.
            if let width = ProcessInfo.processInfo.environment["CAUSABEE_WINDOW_WIDTH"].flatMap(Double.init) {
                var frame = window.frame
                frame.size.width = width
                DispatchQueue.main.async { window.setFrame(frame, display: true) }
            }
        }
    }
}

/// The Mac's sidebar material, under Causabee's own sidebar.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}


/// Rows in one rounded box, with lines between them.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}

struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

/// The ⋯ at the end of a row: what can be done with it — edit, move, remove — in one menu.
struct MoreMenu<Items: View>: View {
    @ViewBuilder let items: Items

    var body: some View {
        Menu { items } label: { Image(systemName: "ellipsis") }
            .menuStyle(.button)
            .buttonStyle(.rowIcon)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .tool()
    }
}

/// A small tool at the end of a row — edit, info, pin: one size, grey, and a target big
/// enough to hit.
struct RowIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == RowIconStyle {
    static var rowIcon: RowIconStyle { RowIconStyle() }
}

/// Opens where a fact came from, in Mail. A door out, so it opens only on a click.
struct SourceLink: View {
    let source: Source?
    let label: String

    var body: some View {
        if let file = source?.fileURL {
            Button(label) { NSWorkspace.shared.open(file) }
                .buttonStyle(.gold)
                .font(.caption)
                .help(file.pathExtension.lowercased().hasPrefix("eml") ? "Open the mail file in Mail" : "Open the file")
                .tool()
        } else if let url = source?.mailURL {
            Button(label) { NSWorkspace.shared.open(url) }
                .buttonStyle(.gold)
                .font(.caption)
                .help("Open the mail in Mail")
                .tool()
        } else {
            Text(label).font(.caption).foregroundStyle(.secondary).tool()
        }
    }
}
