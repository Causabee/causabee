import MatterCore
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
    /// counts) and what is in hand above the composer — always with black words.
    static let bee = fixed(Palette.yellowLight[0])
    /// The working bee (`BeeLoader`), as the icon draws its stripes: ink in the light, the bee's yellow in the dark.
    static let beeMark = adaptive("beeMark", light: Palette.greyDark[5], dark: Palette.yellowLight[0])
    /// Where the Mac would put its blue — links, "Add to Reminders", focus rings: the yellow far enough
    /// down its ladder that words in it read on white; in dark mode a step up from the bee.
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
        case .conversation: return source.pointer == "matter-closed" ? "marked done when closing, \(day)" : "from you in the assistant, \(day)"
        case .spokenNote: return "spoken on \(day)"
        case .photo: return "from the photo of \(day)"
        case .phoneCall: return "from the phone call of \(day)"
        case .document: return "from the document of \(day)"
        }
    }
}
