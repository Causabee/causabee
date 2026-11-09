import Foundation

/// The times of day a person writes — "14:30", "14.30 Uhr", "14 Uhr", "14h30", "2 pm", "2:30 p.m.",
/// and as a span: "14:30 bis 17:30", "von 14 bis 17 Uhr", "2–5 pm", "11–1 pm", "2 p.m. to 5 p.m.",
/// an end alone ("bis 17 Uhr"), a move ("von 14:30 auf 16:00") — as HH:MM. A date such as "13.11.",
/// a length such as "2 h lang", the German "am Freitag": never a time.
public enum TimeWords {
    public struct Span: Equatable, Sendable {
        /// Nil when only an end was said: "bis 17 Uhr".
        public var start: String?
        public var end: String?
        public init(start: String?, end: String?) { self.start = start; self.end = end }
    }

    /// "uhr", "pm", "a.m." — and "am" only when it is not the German "am Freitag", "am 13.".
    private static let unit = #"(?:uhr\b|pm\b|p\.\s?m\.|a\.\s?m\.|am\b(?!\s*(?:[a-zäöüß]|\d)))"#
    private static let joiner = #"\s*(?:–|—|-|bis|to|until|till)\s*"#

    public static func span(in text: String) -> Span? {
        var lower = text.lowercased().replacingOccurrences(of: #"(\d{1,2})h(\d{2})\b"#, with: "$1:$2", options: .regularExpression)
        // A move: "von 14:30 auf 16:00", "from 2 pm to 4 pm" is a span — only "auf" moves.
        if let auf = lower.range(of: #"\bauf\b"#, options: [.regularExpression, .backwards]), single(in: String(lower[auf.upperBound...])) != nil,
           single(in: String(lower[..<auf.lowerBound])) != nil {
            lower = String(lower[auf.upperBound...])
        }
        let dotted = lower.contains("uhr")
        if let span = pair(in: lower, dotted: dotted) { return span }
        // An end alone.
        if let to = lower.range(of: #"\b(?:bis|until|till)\s+(?=\d)"#, options: .regularExpression),
           let end = single(in: String(lower[to.upperBound...].prefix(12))),
           single(in: String(lower[..<to.lowerBound])) == nil {
            return Span(start: nil, end: end)
        }
        return single(in: lower).map { Span(start: $0, end: nil) }
    }

    /// Two times joined: each a time by its colon, its unit, or the unit said once after both.
    private static func pair(in text: String, dotted: Bool) -> Span? {
        let side = #"(\d{1,2})(?:([:.])(\d{2}))?\s*("# + unit + #")?"#
        let pattern = #"(?<![\d.:])"# + side + joiner + side + #"(?![\d])"#
        guard let match = first(pattern, in: text) else { return nil }
        let (h1, s1, m1, u1) = (group(match, 1, text), group(match, 2, text), group(match, 3, text), group(match, 4, text))
        let (h2, s2, m2, u2) = (group(match, 5, text), group(match, 6, text), group(match, 7, text), group(match, 8, text))
        // Each side a time: by its colon, its unit, the unit said once after both ("14 bis 17 Uhr"), or
        // — "14.30 bis 17.30 Uhr" — a dot on both sides with "Uhr" in the words. "13.11 – 14 Uhr" and
        // "13.11. bis 15.11." are days.
        let first = s1 == ":" || u1 != nil || (s1 == "." && dotted && s2 != nil) || (s1 == nil && u2 != nil)
        let second = s2 == ":" || u2 != nil || (s2 == "." && dotted && s1 != nil) || (s2 == nil && u1 != nil)
        guard first, second else { return nil }
        guard let end = clock(h2, m2, u2 ?? u1) else { return nil }
        // "11–1 pm": the end's pm does not make the start 23:00.
        var start = clock(h1, m1, u1 ?? u2)
        if u1 == nil, let s = start, s >= end, let plain = clock(h1, m1, nil), plain < end { start = plain }
        guard let start else { return nil }
        return Span(start: start, end: end)
    }

    /// One time: "14:30", "14.30 Uhr", "9 Uhr", "2 pm".
    private static func single(in text: String) -> String? {
        let colon = #"(?<![\d.:])(\d{1,2}):(\d{2})(?![\d])\s*("# + unit + #")?"#
        let withUnit = #"(?<![\d.:])(\d{1,2})(?:\.(\d{2}))?\s*("# + unit + #")"#
        return [colon, withUnit].compactMap { pattern -> (Int, String)? in
            guard let match = first(pattern, in: text),
                  let time = clock(group(match, 1, text), group(match, 2, text), group(match, 3, text)) else { return nil }
            return (match.range.location, time)
        }.min { $0.0 < $1.0 }?.1
    }

    private static func first(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ text: String) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swift = Range(range, in: text) else { return nil }
        return String(text[swift])
    }

    private static func clock(_ hour: String?, _ minute: String?, _ unit: String?) -> String? {
        guard var h = hour.flatMap(Int.init) else { return nil }
        let m = minute.flatMap(Int.init) ?? 0
        let unit = unit?.replacingOccurrences(of: " ", with: "")
        if unit == "pm" || unit == "p.m." { if h < 12 { h += 12 } }
        if unit == "am" || unit == "a.m." { if h == 12 { h = 0 } }
        guard (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }
}
