import MatterCore
import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

// What the Mac and the iPhone draw alike: the colours, the serif, the chips, the dates.
// Part of both apps — the iPhone's target takes this file in beside its own.

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
    /// counts) and the send button — always with black words.
    static let bee = fixed(Palette.yellowLight[0])
    /// The working bee (`BeeLoader`), as the icon draws its stripes: ink in the light, the bee's yellow in the dark.
    static let beeMark = adaptive("beeMark", light: Palette.greyDark[5], dark: Palette.yellowLight[0])
    /// Where the Mac would put its blue — links, "Add to Reminders", focus rings: the yellow far enough
    /// down its ladder that words in it read on white; in dark mode a step up from the bee.
    /// The thing in hand above the field: pale honey in the light, a warm honey-grey in the dark —
    /// calm, so the send button stays the one yellow thing (Figma "bg/bee-soft").
    static let beeSoft = adaptive("beeSoft", light: Palette.yellowLight[8], dark: 0x3A3528)
    static let gold = adaptive("gold", light: Palette.yellowDark[5], dark: Palette.yellowLight[2])
    /// What the owner said to the assistant: #FFE23E, in both modes, with black words.
    static let honey = fixed(0xFFE23E)
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
    /// A matter's name on its one line in the overview: the cards' serif, smaller — so a matter
    /// never looks like one of its tasks.
    static let rowTitleFont = Font.custom("Source Serif 4", size: 17, relativeTo: .headline)

    /// The serif ships with the app; made known to it once, at start.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "SourceSerif4", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    #if canImport(AppKit)
    private static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    private static func fixed(_ hex: Int) -> Color { Color(nsColor: rgb(hex)) }
    private static func adaptive(_ name: String, light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            rgb(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }
    #else
    private static func rgb(_ hex: Int) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    private static func fixed(_ hex: Int) -> Color { Color(uiColor: rgb(hex)) }
    private static func adaptive(_ name: String, light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in rgb(traits.userInterfaceStyle == .dark ? dark : light) })
    }
    #endif
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

/// The overview's first line, the same on the Mac and the iPhone: how many matters are going on,
/// and the task overdue the longest by name — the one line that says where to start.
enum OverviewSummary {
    static func text(_ going: [Matter]) -> String {
        var text = going.count == 1 ? "One matter is going on." : "\(going.count) matters are going on."
        let overdue = going.flatMap { MatterStatus($0).overdue }.sorted { ($0.due ?? "", $0.text) < ($1.due ?? "", $1.text) }
        if let first = overdue.first {
            text += " Overdue since \(first.due.map(Dates.short) ?? ""): “\(first.text)”"
            text += overdue.count == 1 ? "." : overdue.count == 2 ? ", and 1 more." : ", and \(overdue.count - 1) more."
        }
        return text
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

/// Where a fact came from, in words: a mail, a screenshot, or the owner in the assistant.
enum Sources {
    static func origin(_ source: Source?) -> String {
        guard let source else { return "Source unknown" }
        let day = source.date.map(Dates.short) ?? "?"
        switch source.kind {
        case .mail: return "from the mail of \(day)"
        case .screenshot: return "from the screenshot of \(day)"
        case .conversation:
            switch source.pointer {
            case "matter-closed": return "marked done when closing, \(day)"
            case "you": return "added by you, \(day)"
            default: return "from you in the assistant, \(day)"
            }
        case .spokenNote: return "spoken on \(day)"
        case .photo: return "from the photo of \(day)"
        case .phoneCall: return "from the phone call of \(day)"
        case .document: return "from the document of \(day)"
        }
    }
}

extension EnvironmentValues {
    /// Reading: the small actions and the AI's explanations are put away; what is left is the
    /// matter itself. The right-click menus still have everything — on the iPhone, each row's ⋯.
    @Entry var reading = false
}

extension View {
    /// A control on glass, as the system's own toolbars have them; a thin material before glass came.
    @ViewBuilder func onGlass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(macOS 26, iOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            background(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.thinMaterial), in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

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

extension View {
    /// A box that asks for you — a card to take in, a merge to decide: grey, with a firmer frame.
    func box(radius: CGFloat = 10) -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.strongLine))
    }

    /// A box of what is already done or on its way — a draft opened in Mail, a card taken in, what
    /// came with the mail: the same grey, framed by a plain line, so it asks for nothing.
    func quietBox(radius: CGFloat = 10) -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line))
    }
}

/// The face of the send button in the assistant's field, on the Mac and the iPhone: a black arrow
/// on the bee's yellow, in a light line — or a black square, to stop an answer on its way.
struct SendGlyph: View {
    let stops: Bool

    var body: some View {
        ZStack {
            Circle().fill(Theme.bee)
            if stops {
                RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: 11, height: 11)
            } else {
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .regular)).foregroundStyle(.black)
            }
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
    }
}

/// A matter's icon on a small grey tile: in front of its name wherever matters are listed.
struct MatterIconTile: View {
    let matter: Matter
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: matter.shownIcon)
            .font(.system(size: size * 0.5))
            .foregroundStyle(matter.isClosed ? .secondary : .primary)
            .frame(width: size, height: size)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }
}

/// "Icon", in a matter's menu: every icon by its name, the chosen one ticked, and back to the one
/// Causabee suggests.
struct MatterIconMenu: View {
    let matter: Matter
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Icon", systemImage: matter.shownIcon) {
            ForEach(MatterIcons.all) { icon in
                Button { choose(icon.symbol) } label: {
                    Label(icon.label + (matter.shownIcon == icon.symbol ? "  ✓" : ""), systemImage: icon.symbol)
                }
            }
            if matter.icon != nil {
                Divider()
                Button("Let Causabee choose", systemImage: "sparkles") { choose(nil) }
            }
        }
    }

    private func choose(_ symbol: String?) {
        matter.icon = symbol
        try? context.save()
    }
}

/// The icons as a grid, as Reminders shows them: a click on a matter's tile on its page opens it.
/// A popover on the Mac; on the iPhone a sheet, with a larger heading in the middle and more room.
struct MatterIconPicker: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    #if os(iOS)
    private let tile: CGFloat = 46, gap: CGFloat = 12, glyph: CGFloat = 22
    #else
    private let tile: CGFloat = 38, gap: CGFloat = 8, glyph: CGFloat = 19
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            #if os(iOS)
            Text("Icon for this matter").font(.title3.weight(.semibold)).padding(.top, 30).padding(.bottom, 24)
            #else
            Text("Icon for this matter").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 14)
            #endif
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile), spacing: gap), count: 6), spacing: gap) {
                ForEach(MatterIcons.all) { icon in
                    Button { choose(icon.symbol) } label: {
                        Image(systemName: icon.symbol).font(.system(size: glyph))
                            .frame(width: tile, height: tile)
                            .background(Theme.box, in: RoundedRectangle(cornerRadius: tile * 0.25))
                            .overlay {
                                if matter.shownIcon == icon.symbol { RoundedRectangle(cornerRadius: tile * 0.25).stroke(Color.primary, lineWidth: 1.5) }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: tile * 0.25))
                    }
                    .buttonStyle(.plain)
                    .help(icon.label)
                    .accessibilityLabel(icon.label)
                }
            }
            Group {
                if matter.icon != nil {
                    Button("Let Causabee choose") { choose(nil) }
                        .buttonStyle(.plain).foregroundStyle(Theme.gold)
                } else {
                    Text("Causabee chose this one from the name.").foregroundStyle(.secondary)
                }
            }
            #if os(iOS)
            .font(.subheadline).padding(.top, 24)
            #else
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            #endif
            #if os(iOS)
            Spacer(minLength: 0)
            #endif
        }
        #if os(iOS)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        #else
        .padding(16)
        #endif
        .tint(.primary)
    }

    private func choose(_ symbol: String?) {
        matter.icon = symbol
        try? context.save()
        dismiss()
    }
}

/// A matter's icon small in front of its name, in a line of text: closer together than a label's own.
struct SmallIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

// MARK: Voice

/// Speaking into a field: the microphone listens, the words are written down on the device, and
/// they land in the field — never sent by themselves.
@Observable
@MainActor
final class VoiceInput {
    enum Phase { case idle, listening, writing }
    private(set) var phase = Phase.idle
    /// The speech model is not on the device: the card that offers to load it is shown.
    var asksModel = false
    /// What went wrong, said under the field for a moment.
    var problem: String?
    let recorder = VoiceRecorder()
    private var deliver: ((String) -> Void)?

    /// Starts listening; `deliver` gets the words. Without the model, the card to load it comes first.
    func start(deliver: @escaping (String) -> Void) {
        guard phase == .idle else { return }
        problem = nil
        switch Transcriber.shared.state {
        case .missing, .downloading, .failed:
            withAnimation(.snappy) { asksModel = true }
            return
        case .cold, .warming, .ready:
            break
        }
        self.deliver = deliver
        // The model into memory while the owner speaks.
        Task { await Transcriber.shared.warmUp() }
        Task {
            do {
                recorder.ended = { [weak self] in self?.finish() }
                try await recorder.start()
                withAnimation(.snappy) { phase = .listening }
                feel()
            } catch {
                say(error.localizedDescription)
            }
        }
    }

    /// `--demo --shot listening`: the field as it listens, for the website's picture.
    func stageListening() {
        let wave: [Float] = [0.2, 0.5, 0.8, 0.35, 0.95, 0.6, 0.25, 0.7, 1, 0.45, 0.85, 0.3, 0.55, 0.9, 0.4, 0.75, 0.2, 0.5, 0.88, 0.35,
                             0.65, 0.97, 0.45, 0.25, 0.6, 0.8, 0.3, 0.5, 0.7, 0.4, 0.9, 0.55]
        recorder.stage(levels: wave, secondsAgo: 7)
        phase = .listening
    }

    /// Ends the recording and has it written down.
    func finish() {
        guard phase == .listening else { return }
        guard let recording = recorder.stop() else {
            withAnimation(.snappy) { phase = .idle }
            say(VoiceError.heardNothing.localizedDescription)
            return
        }
        withAnimation(.snappy) { phase = .writing }
        Task {
            do {
                let words = try await Transcriber.shared.words(in: recording)
                if words.isEmpty { say(VoiceError.heardNothing.localizedDescription) } else { deliver?(words); feel() }
            } catch {
                say(error.localizedDescription)
            }
            withAnimation(.snappy) { phase = .idle }
        }
    }

    /// Throws the recording away.
    func cancel() {
        recorder.cancel()
        withAnimation(.snappy) { phase = .idle }
    }

    private func say(_ text: String) {
        problem = text
        Task { try? await Task.sleep(for: .seconds(4)); if problem == text { problem = nil } }
    }

    private func feel() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Words spoken, put where the cursor is — in place of what is selected — or, without a cursor,
    /// after what the field holds already. A space is put between them and their neighbours.
    static func add(_ words: String, to text: inout String, at selection: inout TextSelection?) {
        if case .selection(let range)? = selection?.indices,
           range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex {
            let before = text[..<range.lowerBound], after = text[range.upperBound...]
            let lead = before.isEmpty || before.last?.isWhitespace == true ? "" : " "
            let trail = after.isEmpty || after.first?.isWhitespace == true ? "" : " "
            let put = lead + words + trail
            let offset = text.distance(from: text.startIndex, to: range.lowerBound) + put.count
            text.replaceSubrange(range, with: put)
            let end = text.index(text.startIndex, offsetBy: min(offset, text.count))
            selection = TextSelection(insertionPoint: end)
        } else {
            let before = text.trimmingCharacters(in: .whitespaces)
            text = before.isEmpty ? words : before + " " + words
            selection = TextSelection(insertionPoint: text.endIndex)
        }
    }

    /// Starts listening for a field: the words go to its cursor.
    func start(text: Binding<String>, selection: Binding<TextSelection?>) {
        start { words in VoiceInput.add(words, to: &text.wrappedValue, at: &selection.wrappedValue) }
    }
}

#if os(macOS)
/// ⌥ Space speaks into the assistant's field. Held, it listens for as long as it is held; pressed
/// shortly, it listens until it is pressed again, or until the tick.
struct SpeakKey: ViewModifier {
    let voice: VoiceInput
    let start: () -> Void
    @State private var monitor: Any?
    @State private var pressedAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
                    guard event.keyCode == 49 else { return event }
                    let option = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
                    if event.type == .keyDown {
                        guard option else { return event }
                        if event.isARepeat { return nil }
                        MainActor.assumeIsolated {
                            if voice.phase == .listening { voice.finish(); pressedAt = nil } else if voice.phase == .idle { pressedAt = Date(); start() }
                        }
                        return nil
                    }
                    // Let go after holding: that was the whole of it. A short press keeps listening.
                    let ours = MainActor.assumeIsolated { () -> Bool in
                        guard let pressed = pressedAt else { return false }
                        pressedAt = nil
                        if Date().timeIntervalSince(pressed) > 0.5, voice.phase == .listening { voice.finish() }
                        return true
                    }
                    return ours ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}
#endif

/// The microphone in a field. A click listens; while the words are written down it waits.
struct MicButton: View {
    let voice: VoiceInput
    @Binding var text: String
    /// Where the cursor is in the field: the words go there.
    @Binding var selection: TextSelection?
    /// Done in the moment of the tap, before the listening starts: on the iPhone the field lets the
    /// keyboard go — it gave way to the recording a second later, and the keyboard only then.
    var willListen: () -> Void = {}

    var body: some View {
        Button {
            willListen()
            voice.start(text: $text, selection: $selection)
        } label: {
            Group {
                if voice.phase == .writing {
                    ProgressView().controlSize(.small)
                } else {
                    #if os(iOS)
                    Image(systemName: "mic").font(.system(size: 19))
                    #else
                    Image(systemName: "mic").font(.system(size: 15))
                    #endif
                }
            }
            .frame(width: 34, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(voice.phase != .idle)
        .help("Speak (⌥ Space): it is written down on this device, and you send it")
        .accessibilityLabel("Speak")
    }
}

/// The field while it listens: a cross that throws the recording away, how loud it is, how long,
/// and a tick that ends it.
struct ListeningBar: View {
    let voice: VoiceInput

    var body: some View {
        HStack(spacing: 6) {
            Button { voice.cancel() } label: {
                Image(systemName: "xmark").font(.system(size: 13)).frame(width: 34, height: 34).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .keyboardShortcut(.cancelAction)
            .help("Throw the recording away (esc)")
            .accessibilityLabel("Cancel")
            // The bars lie over the room there is, the newest at the right: however many there are,
            // they never make the field wider.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
                .overlay(alignment: .trailing) {
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(Array(voice.recorder.levels.enumerated()), id: \.offset) { _, level in
                            Capsule().fill(Color.primary).frame(width: 2.5, height: 4 + CGFloat(level) * 20)
                        }
                    }
                    .fixedSize()
                }
                .clipped()
                .accessibilityHidden(true)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let seconds = Int(context.date.timeIntervalSince(voice.recorder.startedAt ?? context.date))
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            Button { voice.finish() } label: {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.card)
                    .frame(width: 34, height: 34).background(Color.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .help("Done: write it down (↩)")
            .accessibilityLabel("Done")
        }
    }
}

/// Asked the first time the microphone is used: the speech model is loaded once. Grey — it waits
/// for a decision — and then says how far the loading is.
struct SpeechModelCard: View {
    let voice: VoiceInput

    var body: some View {
        let state = Transcriber.shared.state
        VStack(alignment: .leading, spacing: 8) {
            #if os(iOS)
            Text("Speech is written down on this iPhone").font(.headline)
            #else
            Text("Speech is written down on this Mac").font(.body.weight(.semibold))
            #endif
            Text("For that Causabee loads a speech model once: \(Transcriber.megabytes) MB, best on Wi-Fi. After that it works without a connection, and no sound is sent anywhere.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            switch state {
            case .downloading(let done):
                ProgressView(value: done).tint(.primary)
                Text("\(Int(done * Double(Transcriber.megabytes))) of \(Transcriber.megabytes) MB").font(.caption).foregroundStyle(.secondary)
            case .warming, .cold:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Getting it ready …").font(.caption).foregroundStyle(.secondary) }
            case .ready:
                Text("Ready. Click the microphone and speak.").font(.caption).foregroundStyle(.secondary)
            case .missing, .failed:
                if case .failed(let why) = state { Text(why).font(.caption).foregroundStyle(Theme.warning) }
                HStack {
                    Spacer()
                    Button("Not now") { withAnimation(.snappy) { voice.asksModel = false } }.quietButton()
                    Button("Load") { Task { await Transcriber.shared.download() } }.filledButton()
                }
            }
        }
        .padding(14)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
        .tint(.primary)
        .onChange(of: state) { if state == .ready { Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation(.snappy) { voice.asksModel = false } } } }
    }
}

/// The filled button of a place — "Add", "Save": near-black, white words. Drawn by us: the
/// system's prominent button takes its words from the tint, which is black here too, and greys
/// out whenever the window is not in front. Shared by the Mac and the iPhone.
struct InkButtonStyle: ButtonStyle {
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

// MARK: Buttons
//
// The buttons there are — use these, do not make another:
//   .filledButton()   the one thing to do here: black, white words ("Add", "Save", "Load")
//   .quietButton()    what stands beside it ("Cancel", "Not now")
//   .buttonStyle(.gold)   a link in a line of text ("Edit", "Show again")
//   .buttonStyle(.plain)  an icon, or a whole row that is a button
// Never `.borderedProminent`: its words take the tint, which is black here — black on black.
// Each is the platform's own behind one name, so a view both apps share looks right on both.

extension View {
    /// The filled button: black with white words. On the iPhone a capsule, on the Mac a small rounded one.
    @ViewBuilder func filledButton() -> some View {
        #if os(iOS)
        buttonStyle(PhoneButtonStyle(filled: true))
        #else
        buttonStyle(InkButtonStyle())
        #endif
    }

    /// The grey button beside the filled one.
    @ViewBuilder func quietButton() -> some View {
        #if os(iOS)
        buttonStyle(PhoneButtonStyle())
        #else
        buttonStyle(QuietButtonStyle())
        #endif
    }
}

#if os(iOS)
/// The filled button and the grey one beside it: "Write message", "Done", "Show".
struct PhoneButtonStyle: ButtonStyle {
    var filled = false
    var wide = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: wide ? .infinity : nil)
            .foregroundStyle(filled ? Theme.onInk : isEnabled ? Color.primary : Color.secondary)
            .background(filled ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Color.secondary.opacity(0.12)), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : isEnabled ? 1 : 0.6)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PhoneButtonStyle {
    static var phone: PhoneButtonStyle { PhoneButtonStyle() }
    static var phoneFilled: PhoneButtonStyle { PhoneButtonStyle(filled: true) }
    static func phone(filled: Bool = false, wide: Bool) -> PhoneButtonStyle { PhoneButtonStyle(filled: filled, wide: wide) }
}
#endif

/// The Mac's grey button, drawn by us as the black one is, so the two sit on one line at one height.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
}

/// What this build is called, as its release says it — "Beta 0.5 (19)": in Settings on the iPhone
/// and in the Mac's About panel. The release scripts hand the stage and the number in
/// (CAUSABEE_STAGE, CAUSABEE_NUMBER); a build from Xcode has neither.
enum AppRelease {
    private static func info(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else { return nil }
        return value
    }

    /// "Beta 0.5", or "0.5" once it is no beta.
    static var name: String { [info("CausabeeStage"), info("CFBundleShortVersionString")].compactMap { $0 }.joined(separator: " ") }
    /// "19": the beta's number on the Mac, the build's on the iPhone.
    static var number: String? { info("CausabeeNumber") }
    static var label: String { "\(name) (\(number ?? "development build"))" }
}

/// Where the assistant's thread is: scrolled up from its newest or not, and how much of it shows.
struct ThreadPlace: Equatable {
    var up: Bool
    var height: CGFloat
    /// More of the thread lies under the lower edge: what came after the newest.
    var below = false
}

/// Auto: the two steps that only wait for a yes are done by themselves — new mail and files are
/// loaded, and read by the AI, as soon as they are there. The third stays the owner's: what of it
/// is taken in, and into which matter. Chosen on each device, off until the owner turns it on:
/// reading sends the mail, pseudonymised, and costs what it costs.
enum AutoMode {
    static let key = "mail.auto"
    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }
    /// Whose tasks are whose, read where a view is not at hand to say it.
    @MainActor static func owner(in context: ModelContext) -> [String] {
        ((try? context.fetch(FetchDescriptor<Profile>())) ?? []).first?.names ?? []
    }
}

/// Mail that was read and found no matter, or that the owner left out: put aside on this device.
enum UnplacedAside {
    static let key = "unplaced.setAside"
    static func add(_ ids: some Sequence<String>) {
        var all = Set((try? JSONDecoder().decode([String].self, from: Data((UserDefaults.standard.string(forKey: key) ?? "[]").utf8))) ?? [])
        all.formUnion(ids)
        UserDefaults.standard.set(String(decoding: (try? JSONEncoder().encode(all.sorted())) ?? Data("[]".utf8), as: UTF8.self), forKey: key)
    }
}

/// What a round of mail offers, mail by mail, before anything is in a matter: a tick for taking it
/// in, the matter it would go into — changed here when it is the wrong one — and what it brings.
struct MailOffers: View {
    let offers: [IntakeSummary.Offer]
    @Binding var chosen: Set<String>
    /// Mails the owner sends elsewhere than suggested, by the mail's id.
    @Binding var moved: [String: PersistentIdentifier]
    /// The tasks and dates the owner leaves out, by the mail's id and their key in it.
    @Binding var skipped: [String: Set<String>]
    /// The Mac's sidebar is narrow: its words are small.
    var small = false
    @Query private var matters: [Matter]

    var body: some View {
        let open = matters.filter { !$0.isClosed }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        VStack(alignment: .leading, spacing: small ? 8 : 12) {
            ForEach(offers) { offer in
                let on = chosen.contains(offer.id)
                let target = moved[offer.id].flatMap { id in matters.first { $0.persistentModelID == id } }
                HStack(alignment: .firstTextBaseline, spacing: small ? 8 : 10) {
                    Button {
                        if on { chosen.remove(offer.id) } else { chosen.insert(offer.id) }
                    } label: {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(small ? .caption : .title3)
                            .foregroundStyle(on ? Theme.gold : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(on ? "Take in" : "Leave out")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.subject).font(small ? .caption : .subheadline)
                            .strikethrough(!on).foregroundStyle(on ? .primary : .secondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        if on {
                            HStack(spacing: 6) {
                                Text("→ " + (target?.name ?? offer.matter.map { offer.isNew ? "New matter: \($0)" : $0 } ?? "No matter found"))
                                    .foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 4)
                                // Nothing to change where none was found: there it is chosen.
                                Menu(target == nil && offer.matter == nil ? "Choose" : "Change") {
                                    ForEach(open) { matter in
                                        Button(matter.name) { moved[offer.id] = matter.persistentModelID }
                                    }
                                    if target != nil {
                                        Divider()
                                        Button("As suggested") { moved[offer.id] = nil }
                                    }
                                }
                                #if os(macOS)
                                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                                #endif
                                .fixedSize()
                                .foregroundStyle(Theme.gold).tint(Theme.gold)
                            }
                            .font(small ? .caption : .footnote)
                            // What it brings, each to take or to leave: the mail comes in either way.
                            ForEach(offer.items) { item in
                                let takes = !(skipped[offer.id] ?? []).contains(item.key)
                                Button {
                                    if takes { skipped[offer.id, default: []].insert(item.key) } else { skipped[offer.id]?.remove(item.key) }
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Image(systemName: takes ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(takes ? Theme.gold : .secondary)
                                        Label(item.text, systemImage: item.symbol)
                                            .strikethrough(!takes).foregroundStyle(takes ? .primary : .secondary)
                                            .lineLimit(3).multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                    .font(small ? .caption : .footnote)
                                    .padding(.vertical, small ? 1 : 3)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.text)
                                .accessibilityAddTraits(takes ? .isSelected : [])
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The matters opened last on this device, the newest first: offered under "Find or start a matter"
/// before anything is typed. Kept by their keys, apart for the demo; one that is gone is left out.
enum RecentMatters {
    static let most = 5
    /// As DemoData asks it — which the share sheet, built from this file too, does not know.
    private static var isDemo: Bool {
        CommandLine.arguments.contains("--demo") || UserDefaults.standard.bool(forKey: "demo.chosen")
            || Bundle.main.bundleIdentifier?.hasSuffix(".demo") == true
    }
    private static var key: String { isDemo ? "matters.recent.demo" : "matters.recent" }
    private static var keys: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func note(_ matter: Matter) {
        var keys = keys.filter { $0 != matter.key }
        keys.insert(matter.key, at: 0)
        UserDefaults.standard.set(Array(keys.prefix(most)), forKey: key)
    }

    /// Those opened last; while there are fewer than three — a device that has not opened much yet —
    /// filled up to three from `others`, the matters with the newest in them.
    static func list(in matters: [Matter], fillingFrom others: [Matter] = []) -> [Matter] {
        var list = keys.compactMap { key in matters.first { $0.key == key } }
        for matter in others where list.count < 3 && !list.contains(where: { $0 === matter }) { list.append(matter) }
        return list
    }
}
