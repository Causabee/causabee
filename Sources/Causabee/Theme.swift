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
    /// The top-ups' bar in the plan, under the month's yellow (F006): a step of the yellow ladder darker
    /// than the bee, a step less dark in the dark. Never for anything else.
    static let topUp = adaptive("topUp", light: Palette.yellowDark[3], dark: Palette.yellowDark[2])
    /// What the owner said to the assistant: #FFE23E, in both modes, with black words.
    static let honey = fixed(0xFFE23E)
    /// Late, missing, not done: an orange of its own, so a warning is not mistaken for the accent.
    static let warning = adaptive("warning", light: 0xC76600, dark: 0xFF9E33)
    /// Done, taken in, read: a dark step of the grey — no green, no blue anywhere.
    static let done = adaptive("done", light: Palette.greyDark[3], dark: Palette.greyLight[5])

    /// The window and its cards: white in light mode; in dark mode the warm grey's dark end.
    static let canvas = adaptive("canvas", light: 0xFFFFFF, dark: 0x141310)
    static let card = adaptive("card", light: 0xFFFFFF, dark: Palette.greyDark[5])
    /// Under a matter's cards and the overview's: a soft grey, so that white cards stand on it.
    static let page = adaptive("page", light: Palette.greyLight[9], dark: 0x141310)
    /// Boxes that stand out from the cards — "Next" and "Summary" among them.
    static let box = adaptive("box", light: Palette.greyLight[9], dark: Palette.greyDark[4])
    /// A search result or a task one jumped to, and the open row of the sidebar.
    static let mark = adaptive("mark", light: Palette.greyLight[8], dark: Palette.greyDark[4])
    /// Filled buttons: near-black with white words, in dark mode the other way round.
    static let ink = adaptive("ink", light: Palette.greyDark[5], dark: Palette.greyLight[8])
    static let onInk = adaptive("onInk", light: 0xFFFFFF, dark: Palette.greyDark[6])
    static let line = adaptive("line", light: Palette.greyLight[7], dark: Palette.greyDark[4])
    static let strongLine = adaptive("strongLine", light: Palette.greyLight[4], dark: Palette.greyDark[2])

    /// What the Mac's text is larger by than the system sets it; the iPhone's follows its own setting.
    #if os(macOS)
    static var textScale: CGFloat { TextSize.scale }
    #else
    static let textScale: CGFloat = 1
    #endif

    /// A matter's name on top of its page: Source Serif 4, regular, the size of a large title.
    static let titleFont = Font.custom("Source Serif 4", size: 26 * Theme.textScale, relativeTo: .largeTitle)
    /// A matter's name on its overview card: the same face, the size of a title (Figma "Title 1 Serif").
    static let cardTitleFont = Font.custom("Source Serif 4", size: 22 * Theme.textScale, relativeTo: .title)
    /// What is left of the month's Pro, the one big number of the plan.
    static let planNumberFont = Font.custom("Source Serif 4", size: 34 * Theme.textScale, relativeTo: .largeTitle)
    /// A matter's name on its one line in the overview: the cards' serif, smaller — so a matter
    /// never looks like one of its tasks.
    static let rowTitleFont = Font.custom("Source Serif 4", size: 17 * Theme.textScale, relativeTo: .headline)

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
    enum Tone { case bee, warning, quiet }
    let text: String
    var tone: Tone = .bee
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            // On the orange: white in light mode, near-black on the lighter orange of dark mode.
            .foregroundStyle(tone == .bee ? Color.black : tone == .quiet ? Color.secondary : Theme.onInk)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(tone == .bee ? Theme.bee : tone == .quiet ? Color.secondary.opacity(0.14) : Theme.warning, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// What is happening with a file: on its way here, or why it could not be got. Both are said in a
/// line under the row — the first quiet, with a spinner, the second in the warning colour — so the
/// two are told apart by what they are, never by their words, which change with the language (F009:
/// the line used to be known by its "Getting" prefix, which German never has).
enum Fetching: Equatable {
    case onTheWay(String)
    case failed(String)

    var words: String { switch self { case .onTheWay(let said), .failed(let said): said } }
    var isOnTheWay: Bool { if case .onTheWay = self { true } else { false } }
}

enum Dates {
    /// A day in the device's own order: `Oct 23` in English, `23. Okt.` in German. The template
    /// says which parts are wanted — the month's name and the day — and the language says how
    /// they are put together (F009 AC-3).
    private static let dayAndMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()
    private static let withYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdyyyy")
        return formatter
    }()
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// `31 October`, `31. Oktober`: the day and the month's name, as the device writes them.
    static func long(_ date: Date) -> String { date.formatted(.dateTime.day().month(.wide)) }

    /// `2026-10-13` → `Oct 13`, `13. Okt.`
    static func short(_ day: String) -> String { parser.date(from: day).map(short) ?? day }
    static func short(_ date: Date) -> String {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? dayAndMonth.string(from: date) : withYear.string(from: date)
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
        guard let source else { return String(localized: "Source unknown") }
        let day = source.date.map(Dates.short) ?? "?"
        switch source.kind {
        case .mail: return String(format: String(localized: "from the mail of %@"), day)
        case .screenshot: return String(format: String(localized: "from the screenshot of %@"), day)
        case .conversation:
            // The pointer is stored with the fact, so it stays English; only the word is looked up.
            switch source.pointer {
            case "matter-closed": return String(format: String(localized: "marked done when closing, %@"), day)
            case "you": return String(format: String(localized: "added by you, %@"), day)
            case "brief": return String(format: String(localized: "proposed in the brief, %@"), day)
            default: return String(format: String(localized: "from you in the assistant, %@"), day)
            }
        case .spokenNote: return String(format: String(localized: "spoken on %@"), day)
        case .photo: return String(format: String(localized: "from the photo of %@"), day)
        case .phoneCall: return String(format: String(localized: "from the phone call of %@"), day)
        case .document: return String(format: String(localized: "from the document of %@"), day)
        }
    }

    /// The same thing in a menu, where it stands as a line of its own: "Mail of Oct 8". Its own
    /// words, not `origin` with its first words cut off — in German there is nothing to cut (F009).
    static func inAMenu(_ source: Source?) -> String {
        guard let source else { return String(localized: "Source unknown") }
        let day = source.date.map(Dates.short) ?? "?"
        switch source.kind {
        case .mail: return String(format: String(localized: "Mail of %@"), day)
        case .screenshot: return String(format: String(localized: "Screenshot of %@"), day)
        case .conversation:
            switch source.pointer {
            case "matter-closed": return String(format: String(localized: "Marked done when closing, %@"), day)
            case "you": return String(format: String(localized: "Added by you, %@"), day)
            case "brief": return String(format: String(localized: "Proposed in the brief, %@"), day)
            default: return String(format: String(localized: "From you in the assistant, %@"), day)
            }
        case .spokenNote: return String(format: String(localized: "Spoken on %@"), day)
        case .photo: return String(format: String(localized: "Photo of %@"), day)
        case .phoneCall: return String(format: String(localized: "Phone call of %@"), day)
        case .document: return String(format: String(localized: "Document of %@"), day)
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

    /// Glass behind what is here, not around it: a field's words stay as sharp as they are, and
    /// what scrolls under the field is seen through it. A thin material before glass came.
    @ViewBuilder func glassBehind<S: Shape>(_ shape: S) -> some View {
        if #available(macOS 26, iOS 26, *) {
            background { shape.fill(.clear).glassEffect(.regular, in: shape) }
        } else {
            background(.thinMaterial, in: shape).overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
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
    /// Nothing is written and nothing is on its way: the bee may come out of this yellow, glad of
    /// a task ticked, when its own button is not in sight.
    var mayHostBee = false
    private let joy = BeeJoy.shared

    var body: some View {
        ZStack {
            Circle().fill(Theme.bee)
            if stops {
                RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: 11, height: 11)
            } else {
                // The arrow and the bee change places softly: one fades as the other comes — cut
                // from one to the other, the bee's landing was harsh.
                let bee = mayHostBee && joy.beesInSight == 0 ? joy.beat : nil
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .regular)).foregroundStyle(.black)
                    .opacity(bee == nil ? 1 : 0)
                    .scaleEffect(bee == nil ? 1 : 0.7)
                if let bee { BeeJoyView(beat: bee, size: 17).transition(.opacity.combined(with: .scale(scale: 0.8))) }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: joy.beat)
        .frame(width: 34, height: 34)
        .contentShape(Circle())
    }
}

/// A matter's icon on a small grey tile: in front of its name wherever matters are listed.
struct MatterIconTile: View {
    let matter: Matter
    var size: CGFloat = 30
    /// Its ground: the grey of a box — lighter where the row it is in lies on that grey itself.
    var ground: Color = Theme.box

    var body: some View {
        Image(systemName: matter.shownIcon)
            .font(.system(size: size * 0.5))
            .foregroundStyle(matter.isClosed ? .secondary : .primary)
            .frame(width: size, height: size)
            .background(ground, in: RoundedRectangle(cornerRadius: size * 0.27))
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
                // The menu's own tick, in its own column.
                Toggle(isOn: Binding(get: { matter.shownIcon == icon.symbol }, set: { _ in choose(icon.symbol) })) {
                    Label(icon.label, systemImage: icon.symbol)
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

    /// What the field says while the words are written down — or while they wait for the speech
    /// model to come into memory first.
    var writingWords: String { Transcriber.shared.state == .warming ? String(localized: "Getting speech ready …") : String(localized: "Writing it down …") }

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
                PlainWords.prepare()
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
                // Written down by Whisper, then set right on the device as Utterclip does: "äh" and
                // the mishearings gone, the words kept. Where that cannot be done, Whisper's words.
                let words = await PlainWords.corrected(try await Transcriber.shared.words(in: recording))
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
                    // While the speech model comes into memory, the microphone says so: paler, with a
                    // small wheel. It can be tapped all the same — what is said waits for the model.
                    let warming = Transcriber.shared.state == .warming
                    Group {
                        #if os(iOS)
                        Image(systemName: "mic").font(.system(size: 19))
                        #else
                        Image(systemName: "mic").font(.system(size: 15))
                        #endif
                    }
                    .opacity(warming ? 0.45 : 1)
                    .overlay(alignment: .topTrailing) {
                        if warming { ProgressView().controlSize(.mini).scaleEffect(0.7).offset(x: 7, y: -6).transition(.opacity) }
                    }
                    .animation(.easeInOut(duration: 0.2), value: warming)
                    .accessibilityHint(warming ? String(localized: "Speech is getting ready") : "")
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
            Text("Speech is written down on this \(ThisDevice.name)").font(.headline)
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
            .macBody()
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

/// What the assistant suggests, as a card: what it is, small; what it is about — a drafted mail's
/// subject is its title, plain, and still a field —; its words on a writing area only a touch
/// darker than the card and as tall as they are; and one button. The × in its corner puts it aside.
struct CardFace: View {
    let label: String
    /// A draft's subject: the title, to change.
    var subject: Binding<String>? = nil
    /// What the card is about, when that is all it says.
    var headline: String? = nil
    var sub: String? = nil
    /// The words to change before taking it in.
    var text: Binding<String>? = nil
    /// A written message stands in the serif; a task or a name in the app's own face.
    var serif = false
    /// Small lines under it: why, what goes along. Each with its sign, or none.
    var notes: [(text: String, symbol: String?)] = []
    /// A draft's way to choose the matter's files to send along: "Attach …" under its lines.
    var attach: (() -> Void)? = nil
    let verb: String
    let closeLabel: String
    let close: () -> Void
    let take: () -> Void

    var body: some View {
        #if os(iOS)
        let disc: CGFloat = 30
        #else
        let disc: CGFloat = 24
        #endif
        VStack(alignment: .leading, spacing: 0) {
            // Every line wraps and the card grows with it: one line under the other, nothing beside
            // them but the × on the first. No measuring, no field laid on hidden words.
            HStack(alignment: .center, spacing: 12) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: disc * 0.4, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: disc, height: disc)
                        .background(Color.primary.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(closeLabel)
            }
            .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 2) {
                if let subject {
                    TextField("Subject", text: subject, axis: .vertical).textFieldStyle(.plain).font(.headline)
                }
                if let headline { Text(headline).font(.headline) }
                if let sub { Text(sub).font(.subheadline).foregroundStyle(.secondary) }
            }
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, subject == nil && headline == nil && sub == nil ? 0 : 4)
            if let text {
                TextField("", text: text, axis: .vertical).textFieldStyle(.plain)
                    .font(serif ? Theme.rowTitleFont : .body)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 14)
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Group {
                    if let symbol = note.symbol { Label(note.text, systemImage: symbol) } else { Text(note.text) }
                }
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).padding(.leading, 4)
            }
            if let attach {
                // As "Connect …" under an item: a dashed chip, quiet beside the card's one button.
                Button(action: attach) {
                    Label("Attach …", systemImage: "paperclip").font(.footnote)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(.secondary))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("draft.attach")
                .padding(.top, 10).padding(.leading, 4)
            }
            HStack {
                Spacer(minLength: 0)
                #if os(iOS)
                Button(verb, action: take).buttonStyle(.phoneFilled)
                #else
                Button(verb, action: take).inkButton()
                #endif
                Spacer(minLength: 0)
            }
            .padding(.top, 18)
        }
    }
}

/// The Mac's grey button, drawn by us as the black one is, so the two sit on one line at one height.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .macBody()
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

/// Pro, the ⚡ button (Auto before): the bigger AI. For now, as Auto was: the two steps that only wait for a yes are done by themselves — new mail and files are
/// loaded, and read by the AI, as soon as they are there. The third stays the owner's: what of it
/// is taken in, and into which matter. The same on every device (through the profile), off until the owner turns it on:
/// reading sends the mail, pseudonymised, and costs what it costs.
enum AutoMode {
    static let key = "mail.auto"
    /// On, with Pro or a top-up left: without either the switch stays as the owner left it, and nothing is read.
    /// F007: and not waiting — the month used up, or Pro ended — so nothing is sent that would be refused.
    static var isOn: Bool {
        Plan.proIsOn(switched: UserDefaults.standard.bool(forKey: key), plan: Plan.cached, credit: UserDefaults.standard.bool(forKey: "beeserver.credit"))
            && !ProWait.stored.holds(now: Date())
    }
    /// The owner has been told once what Auto does, and said yes.
    static let agreedKey = "auto.agreed"
    /// The bolt was pressed to turn Auto on, and what Auto does has not been said and agreed to
    /// yet: it is asked first.
    static var asksFirst: Bool { !isOn && !UserDefaults.standard.bool(forKey: agreedKey) }
    /// Whose tasks are whose, read where a view is not at hand to say it.
    @MainActor static func owner(in context: ModelContext) -> [String] {
        ((try? context.fetch(FetchDescriptor<Profile>())) ?? []).first?.names ?? []
    }
}

/// A file brought in sorts itself in — bringing it in is the yes (docs/digest-and-chat.md). The
/// same on every device: when it is sure enough of the matter, and the line that says what it brought.
@MainActor
enum SortsIn {
    /// How sure the cloud model's answer has to be of an existing matter to file it there without
    /// asking.
    static let sureEnough = 0.6

    /// The matter a file surely goes into — the one it was brought in from, or the open one the
    /// cloud model names with confidence — or none, when the owner has to say. The device's model
    /// is not trusted with the matter: its 0.7 says only that the matter was on its list, so what
    /// it reads with no matter given is asked (the owner, 6 November 2026).
    static func matter(for judgement: Judgement, from: PersistentIdentifier?, in context: ModelContext) -> Matter? {
        let open = ((try? context.fetch(FetchDescriptor<Matter>())) ?? []).filter { !$0.isClosed }
        if let from, let matter = open.first(where: { $0.persistentModelID == from }) { return matter }
        guard judgement.decidedBy == .claude, judgement.matterConfidence >= sureEnough, let key = judgement.matter else { return nil }
        return open.first { $0.answers(to: key) }
    }

    /// What it brought, a line each: the tasks, the dates, who wrote and its numbers.
    static func lines(of judgement: Judgement, offers: VaultOffers) -> [String] {
        judgement.todos.map(\.text)
            + judgement.appointments.map { "\(Dates.short($0.date))\($0.time.map { " \($0)" } ?? "") \($0.what)" }
            + judgement.deadlines.map { String(format: String(localized: "by %@ %@"), Dates.short($0.date), $0.what) }
            + offers.lines.map(\.text)
    }

    /// What the matter has already, by its place in the answer — "t0", "a1", "d0": left out
    /// when it sorts itself in, so nothing is in the matter twice.
    static func doubles(_ judgement: Judgement, in matter: Matter) -> Set<String> {
        var out: Set<String> = []
        for (index, todo) in judgement.todos.enumerated() where Duplicates.todo(todo.text, in: matter) != nil { out.insert("t\(index)") }
        for (index, item) in judgement.appointments.enumerated() where Duplicates.appointment(on: item.date, at: item.time, item.what, in: matter) != nil {
            out.insert("a\(index)")
        }
        for (index, item) in judgement.deadlines.enumerated() where Duplicates.deadline(on: item.date, item.what, in: matter) != nil { out.insert("d\(index)") }
        return out
    }

    /// The line's first words: "Kita · Pay €120 by 20 Nov", or "Kita · filed".
    static func headline(_ name: String, _ made: [String]?) -> String {
        "\(name) · \(made == nil ? String(localized: "taken in") : made?.first ?? String(localized: "filed"))"
    }
}

/// Mail that was read and found no matter, or that the owner left out: put aside on this device —
/// and in the store too (`SortedMails.setAside`), for the others.
enum UnplacedAside {
    static let key = "unplaced.setAside"
    static var all: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data((UserDefaults.standard.string(forKey: key) ?? "[]").utf8))) ?? [])
    }
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
    /// Mails the owner starts a new matter with, and its name, by the mail's id.
    @Binding var named: [String: String]
    /// The tasks and dates the owner leaves out, by the mail's id and their key in it.
    @Binding var skipped: [String: Set<String>]
    /// The Mac's sidebar is narrow: its words are small.
    var small = false
    @Query private var matters: [Matter]
    /// The mail whose new matter is being named, and the name so far.
    @State private var naming: String?
    @State private var newName = ""

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
                    .accessibilityLabel(on ? String(localized: "Take in") : String(localized: "Leave out"))
                    .accessibilityAddTraits(on ? .isSelected : [])
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.subject).font(small ? .caption : .subheadline)
                            .strikethrough(!on).foregroundStyle(on ? .primary : .secondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        if on {
                            HStack(spacing: 6) {
                                let newMatter = String(localized: "New matter: %@")
                                Text("→ " + (named[offer.id].map { String(format: newMatter, $0) } ?? target?.name ?? offer.matter.map { offer.isNew ? String(format: newMatter, $0) : $0 } ?? String(localized: "No matter found")))
                                    .foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 4)
                                // Nothing to change where none was found: there it is chosen.
                                Menu(target == nil && named[offer.id] == nil && offer.matter == nil ? String(localized: "Choose") : String(localized: "Change")) {
                                    // First: with many matters the end of the list is out of sight.
                                    #if os(macOS)
                                    Button("New Matter …") { newName = named[offer.id] ?? Matter.cleanSubject(offer.subject); naming = offer.id }
                                    #else
                                    Button("A new matter", systemImage: "plus.circle") { newName = named[offer.id] ?? Matter.cleanSubject(offer.subject); naming = offer.id }
                                    #endif
                                    if target != nil || named[offer.id] != nil {
                                        Button("As suggested") { moved[offer.id] = nil; named[offer.id] = nil }
                                    }
                                    Divider()
                                    ForEach(open) { matter in
                                        Button(matter.name) { moved[offer.id] = matter.persistentModelID; named[offer.id] = nil }
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
        .alertWhenAsked(String(localized: "A new matter"), isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Start") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let id = naming, !name.isEmpty else { return }
                named[id] = name
                moved[id] = nil
            }
        } message: {
            Text("Taking the mail in starts it, with what you left ticked.")
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

extension View {
    /// A button's words at the size of the Mac's text: a button sets its own, the system's, and
    /// stood small beside the lines around it. The iPhone's buttons keep theirs.
    @ViewBuilder func macBody() -> some View {
        #if os(macOS)
        font(.body)
        #else
        self
        #endif
    }
}

/// The parts of a matter as pills, as Mail's categories: a sign each, and the open one filled and
/// wide with its word — one word in the bar where there were four. The others say theirs when the
/// pointer rests on them, and to VoiceOver. In greys, the open one a step darker: no colour of
/// their own, and not the ink of a button. On the iPhone the open pill takes the room that is left, and the pills are a finger high.
struct PartTabs<Value: Hashable>: View {
    struct Tab {
        let value: Value
        let title: String
        let symbol: String
    }

    let tabs: [Tab]
    @Binding var selection: Value
    #if os(iOS)
    // On the iPhone the open pill takes the room that is left, as in Mail, and the row is as wide as
    // the page. On the iPad each pill is as wide as what is in it, as on the Mac: a pill across a
    // wide page is a bar, not a pill.
    private let fills = UIDevice.current.userInterfaceIdiom != .pad
    private let height: CGFloat = 44, sign: CGFloat = 17
    private let word = Font.subheadline.weight(.semibold)
    #else
    // On the Mac the open pill is as wide as its word, no wider: stretched to fill a row it looked
    // heavy there (tried, and taken back the same day).
    private let height: CGFloat = 32, sign: CGFloat = 14, fills = false
    private let word = Font.callout.weight(.semibold)
    #endif

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.value) { tab in
                let chosen = tab.value == selection
                Button { selection = tab.value } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbol).symbolVariant(chosen ? .fill : .none)
                            .font(.system(size: sign, weight: .medium)).frame(width: sign + 8, height: sign + 4)
                        // As in Mail: the pill opens first, with its sign alone; the word comes when
                        // there is room for it, and goes at once when another part is chosen.
                        if chosen {
                            Text(tab.title).font(word).fixedSize()
                                .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.16).delay(0.1)),
                                                        removal: .opacity.animation(.easeOut(duration: 0.06))))
                        }
                    }
                    .padding(.horizontal, chosen ? 16 : 14)
                    .frame(maxWidth: chosen && fills ? .infinity : nil)
                    .frame(height: height)
                    // The open part lies on the same light grey as the others; only its sign and its
                    // word are black, where theirs are grey. Not the ink of the app's filled buttons:
                    // it says where one is, not what to press — and the bee stays the strongest thing
                    // on the page.
                    .foregroundStyle(chosen ? Color.primary : Color.secondary)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
                .accessibilityIdentifier("part." + tab.title)
            }
        }
        // The pills and the words move; the page under them changes at once, as before.
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Part of the matter")
    }
}

// MARK: Asked-for presentations

/// A row's dialog, sheet, alert or popover, there only while it is asked for. Attached to every row
/// — each task, date, person, mail and source — they were worked out again at every frame of a
/// scroll (a quarter of the main thread's time on a long page, measured): a dialog resolves its
/// colours, a sheet its presentation, whether shown or not. Hung on a clear background, so the
/// row itself stays the same view and keeps what it holds.
extension View {
    /// `onDismiss` is called as the sheet goes: when what shows it says it is no longer shown.
    func sheetWhenAsked<Sheet: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                     @ViewBuilder content: @escaping () -> Sheet) -> some View {
        background { if isPresented.wrappedValue { Color.clear.sheet(isPresented: isPresented, content: content) } }
            .onChange(of: isPresented.wrappedValue) { was, now in if was, !now { onDismiss?() } }
    }

    func confirmationDialogWhenAsked<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                                                  @ViewBuilder actions: @escaping () -> Actions,
                                                                  @ViewBuilder message: @escaping () -> Message) -> some View {
        background {
            if isPresented.wrappedValue {
                Color.clear.confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
            }
        }
    }

    func confirmationDialogWhenAsked<Actions: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                                   @ViewBuilder actions: @escaping () -> Actions) -> some View {
        background {
            if isPresented.wrappedValue {
                Color.clear.confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
            }
        }
    }

    func alertWhenAsked<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>,
                                                     @ViewBuilder actions: @escaping () -> Actions,
                                                     @ViewBuilder message: @escaping () -> Message) -> some View {
        background { if isPresented.wrappedValue { Color.clear.alert(title, isPresented: isPresented, actions: actions, message: message) } }
    }

    func alertWhenAsked<Actions: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> Actions) -> some View {
        background { if isPresented.wrappedValue { Color.clear.alert(title, isPresented: isPresented, actions: actions) } }
    }

    func popoverWhenAsked<Content: View>(isPresented: Binding<Bool>, arrowEdge: Edge = .top, @ViewBuilder content: @escaping () -> Content) -> some View {
        background { if isPresented.wrappedValue { Color.clear.popover(isPresented: isPresented, arrowEdge: arrowEdge, content: content) } }
    }
}

extension UserDefaults {
    /// Written only when it is another: every write tells every view that keeps a setting whose
    /// name has a dot in it — "mail.auto" — to draw again, and a matter's whole page was drawn
    /// again each second while Auto wrote down what it had seen (measured).
    func setIfChanged(_ value: Any?, forKey key: String) {
        let now = object(forKey: key) as? NSObject
        if let value = value as? NSObject, now?.isEqual(value) == true { return }
        if value == nil, now == nil { return }
        set(value, forKey: key)
    }
}

/// A part of a page drawn on its own: what it reads while it is drawn — where the page has scrolled
/// to, say — draws it again, not the page around it.
struct DrawnApart<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }
    var body: some View { content() }
}

// MARK: A sheet's bar

/// What saves or ends a sheet, in its bar: on the iPhone and iPad the system's check on prominent
/// glass, as Apple's own sheets have it; on the Mac its word, on Return. Called by its word still,
/// for VoiceOver and the tests.
struct SheetConfirm: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }

    var body: some View {
        #if os(iOS)
        Button(role: .confirm, action: action).accessibilityLabel(title)
        #else
        Button(title, action: action).keyboardShortcut(.defaultAction)
        #endif
    }
}

/// What leaves a sheet without keeping anything: the system's cross on glass on the iPhone and
/// iPad, "Cancel" on Esc on the Mac.
struct SheetCancel: View {
    var title = String(localized: "Cancel")
    let action: () -> Void

    var body: some View {
        #if os(iOS)
        Button(role: .cancel, action: action).accessibilityLabel(title)
        #else
        Button(title, action: action).keyboardShortcut(.cancelAction)
        #endif
    }
}
