import AppKit
import MatterCore
import SwiftUI

/// The owner's two ladders, ten steps each: the bee's yellow out to white and down to a dark
/// brown, and a warm grey out to white and down to black. The colours below are their steps, with
/// three of their own: the chat bubble's honey, the warning's orange and the dark window.
enum Palette {
    static let yellowLight = [0xFFDB0D, 0xFFDD24, 0xFFE03A, 0xFFE350, 0xFFE666, 0xFFEA7D, 0xFFED93, 0xFFF1AA, 0xFFF5C8, 0xFFF9E6]
    static let yellowDark  = [0xFFDB0D, 0xE6C000, 0xCCA800, 0xB38F00, 0x997700, 0x7F5E00, 0x664200, 0x4D2A00, 0x331300, 0x1A0000]
    static let greyLight   = [0xA3A29B, 0xACABA5, 0xB5B4AF, 0xBEBDB8, 0xC7C6C2, 0xD0D0CC, 0xDAD9D5, 0xE3E3E0, 0xECECEA, 0xF5F5F4]
    static let greyDark    = [0xA3A29B, 0x87867E, 0x6C6B63, 0x53524A, 0x3A3932, 0x22211B, 0x0B0A05, 0x050402, 0x020201, 0x000000]
}

enum Theme {
    /// The yellow of the bee's body in the icon, #FFDB0D: the pills (Next, Summary, an overview card's
    /// counts) and what is in hand above the composer — always with black words.
    static let bee = Color(nsColor: rgb(Palette.yellowLight[0]))
    /// The working bee (`BeeLoader`), as the icon draws its stripes: ink in the light, the bee's yellow in the dark.
    static let beeMark = adaptive("beeMark", light: Palette.greyDark[5], dark: Palette.yellowLight[0])
    /// Where the Mac would put its blue — links, "Add to Reminders", focus rings: the yellow far enough
    /// down its ladder that words in it read on white; in dark mode a step up from the bee.
    static let gold = adaptive("gold", light: Palette.yellowDark[5], dark: Palette.yellowLight[2])
    /// What the owner said to the assistant: #FFE23E, in both modes, with black words.
    static let honey = Color(nsColor: rgb(0xFFE23E))
    /// Late, missing, not done: an orange of its own, so a warning is not mistaken for the accent.
    static let warning = adaptive("warning", light: 0xC76600, dark: 0xFF9E33)
    /// Done, taken in, read: a dark step of the grey — no green, no blue anywhere.
    static let done = adaptive("done", light: Palette.greyDark[3], dark: Palette.greyLight[5])

    /// The window and its cards: white in light mode; in dark mode the warm grey's dark end.
    static let canvas = adaptive("canvas", light: 0xFFFFFF, dark: 0x141310)
    static let card = adaptive("card", light: 0xFFFFFF, dark: Palette.greyDark[5])
    /// Boxes that stand out from the cards — "Next" and "Summary" among them.
    static let box = adaptive("box", light: Palette.greyLight[9], dark: Palette.greyDark[4])
    /// A search result or a task one jumped to, and the open row of the sidebar.
    static let mark = adaptive("mark", light: Palette.greyLight[8], dark: Palette.greyDark[4])
    /// Filled buttons: near-black with white words, in dark mode the other way round.
    static let ink = adaptive("ink", light: Palette.greyDark[5], dark: Palette.greyLight[8])
    static let onInk = adaptive("onInk", light: 0xFFFFFF, dark: Palette.greyDark[6])
    static let line = adaptive("line", light: Palette.greyLight[7], dark: Palette.greyDark[4])
    static let strongLine = adaptive("strongLine", light: Palette.greyLight[4], dark: Palette.greyDark[2])

    /// A matter's name on top of its page: Source Serif 4, regular, the size of a large title.
    static let titleFont = Font.custom("Source Serif 4", size: 26, relativeTo: .largeTitle)
    /// A matter's name on its overview card: the same face, the size of a title (Figma "Title 1 Serif").
    static let cardTitleFont = Font.custom("Source Serif 4", size: 22, relativeTo: .title)

    /// The serif ships with the app; made known to it once, at start.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "SourceSerif4", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    private static func adaptive(_ name: String, light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            rgb(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }
}

extension View {
    /// A box that asks for you — a card to take in, a merge to decide: grey, with a firmer frame.
    func box(radius: CGFloat = 10) -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.strongLine))
    }

    /// A box of what is already done or on its way — a draft put in Gmail, a card taken in, what
    /// came with the mail: the same grey, framed by a plain line, so it asks for nothing.
    func quietBox(radius: CGFloat = 10) -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line))
    }

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
    func inkButton() -> some View { buttonStyle(InkButtonStyle()) }
}

private struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(isEnabled ? Theme.onInk : Color.secondary)
            .background(isEnabled ? AnyShapeStyle(Theme.ink.opacity(configuration.isPressed ? 0.75 : 1))
                                  : AnyShapeStyle(Color.secondary.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
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
    }
}

extension EnvironmentValues {
    /// Reading: the small actions and the AI's explanations are put away; what is left is the
    /// matter itself. The right-click menus still have everything.
    @Entry var reading = false
}

extension View {
    /// A small action — a link, a ⋯, a pin, a button that asks the AI — gone while reading.
    func tool() -> some View { modifier(PutAwayWhileReading()) }
    /// What the AI says about why, what it cost, where it looked — gone while reading.
    func explanation() -> some View { modifier(PutAwayWhileReading()) }
}

private struct PutAwayWhileReading: ViewModifier {
    @Environment(\.reading) private var reading
    func body(content: Content) -> some View {
        if !reading { content }
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
    /// Where the assistant's bar starts with the sidebar folded away: past the window's buttons
    /// and the sidebar's.
    static let clearOfWindowButtons: CGFloat = sidebarButtonX + 26 + 8 + 26 + 12
}

/// The window without the Mac's bar showing: an empty toolbar of its own makes the title bar 52 high,
/// and AppKit itself then sets the three buttons in its middle, as far in from the left as from the
/// top. Nothing of the toolbar is seen; Matterbee draws everything under it.
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
                let toolbar = NSToolbar(identifier: "matterbee.window")
                window.toolbar = toolbar
            }
            window.toolbarStyle = .unified
        }
    }
}

/// The Mac's sidebar material, under Matterbee's own sidebar.
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

/// A link-like button in the gold, in place of the Mac's blue one.
struct GoldLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.gold)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == GoldLinkStyle {
    static var gold: GoldLinkStyle { GoldLinkStyle() }
}

/// A label on the yellow, black words: "NEXT", "SUMMARY"; on the orange for "OVERDUE" and "FOLLOW UP".
struct BeeChip: View {
    enum Tone { case bee, warning }
    let text: String
    var tone: Tone = .bee
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            // On the orange: white in light mode, near-black on the lighter orange of dark mode.
            .foregroundStyle(tone == .bee ? Color.black : Theme.onInk)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(tone == .bee ? Theme.bee : Theme.warning, in: RoundedRectangle(cornerRadius: 5))
    }
}

enum Dates {
    private static let english: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    private static let withYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// `2026-10-13` → `Oct 13`
    static func short(_ day: String) -> String { parser.date(from: day).map(short) ?? day }
    static func short(_ date: Date) -> String {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? english.string(from: date) : withYear.string(from: date)
    }
}

/// Text with its web addresses made into links, to open in the browser with a click.
enum Linked {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func text(_ string: String) -> AttributedString {
        guard let detector else { return AttributedString(string) }
        var out = AttributedString()
        var last = string.startIndex
        for match in detector.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
            guard let range = Range(match.range, in: string), let url = match.url, ["http", "https"].contains(url.scheme ?? "") else { continue }
            out += AttributedString(string[last..<range.lowerBound])
            var link = AttributedString(string[range])
            link.link = url
            out += link
            last = range.upperBound
        }
        out += AttributedString(string[last...])
        return out
    }
}

/// A heading in small capitals with a count on the right, as in the wireframes.
struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 4)
    }
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

/// The door back into the assistant, on every row: with this item already in hand.
/// Pins the row's item to the assistant, so the next question is about it.
struct PinButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: "pin") }
            .buttonStyle(.rowIcon)
            .help("Pin it to the assistant, to ask about it")
            .tool()
    }
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

/// Where a fact came from, in words: a mail, a screenshot, or the owner in the assistant.
enum Sources {
    static func origin(_ source: Source?) -> String {
        guard let source else { return "Source unknown" }
        let day = source.date.map(Dates.short) ?? "?"
        switch source.kind {
        case .mail: return "from the mail of \(day)"
        case .screenshot: return "from the screenshot of \(day)"
        case .conversation: return source.pointer == "matter-closed" ? "marked done when closing, \(day)" : "from you in the assistant, \(day)"
        case .spokenNote: return "spoken on \(day)"
        case .photo: return "from the photo of \(day)"
        case .phoneCall: return "from the phone call of \(day)"
        case .document: return "from the document of \(day)"
        }
    }
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
