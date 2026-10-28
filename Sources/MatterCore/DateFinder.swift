import Foundation

/// The dates a mail names, found by rule — Apple's date detector, in German, English and French —
/// before any model reads it: a small model read an invitation's day as the day it was sent, and
/// missed a booking's arrival and departure. Only dates that name their day: "tomorrow" and
/// "Friday" mean something else when a mail is read days later. A year left out is the one
/// nearest to when the mail was sent.
public enum DateFinder {
    public struct Found: Equatable, Sendable {
        public var day: String
        /// `HH:MM`, when the words give a time.
        public var time: String?
        /// The words it was found in.
        public var quote: String
    }

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let months = "jan|feb|mär|mar|apr|mai|may|jun|jul|aug|sep|okt|oct|nov|dez|dec|janv|févr|fevr|mars|avr|juin|juil|août|aout|sept|déc"
    /// A day with its month: "9. Okt", "October 9", "16/10/2026", "31.10."
    private static let namesDay = try! NSRegularExpression(pattern:
        #"\b\d{1,2}\s*[./]\s*\d{1,2}\b|\b\d{1,2}\.?\s+(?:"# + months + #")|(?:"# + months + #")[a-zäéû]*\.?\s+\d{1,2}\b|\b\d{4}-\d{2}-\d{2}\b"#,
        options: [.caseInsensitive])
    private static let namesTime = try! NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b|\b\d{1,2}(?:\.\d{2})?\s*(?:am|pm|uhr|h)\b"#, options: [.caseInsensitive])
    private static let namesYear = try! NSRegularExpression(pattern: #"\b20\d{2}\b"#)
    /// "Friday at 10:00": a weekday names its day too — the next one after the mail was sent.
    private static let weekday = try! NSRegularExpression(pattern:
        #"\b(mon|tues|wednes|thurs|fri|satur|sun)day\b|\b(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)\b|\b(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\b"#,
        options: [.caseInsensitive])
    /// The line a quoted earlier mail begins with: its date is when that was written, not a date to keep.
    private static let quotedHeader = try! NSRegularExpression(pattern:
        #"schrieb|wrote|a écrit|gesendet|sent:|envoyé|date:|datum:|von:|from:"#, options: [.caseInsensitive])
    private static let until = try! NSRegularExpression(pattern: #"^\s*(?:bis|until|till|by|jusqu)"#, options: [.caseInsensitive])

    public static func dates(in text: String, sent: Date?, calendar: Calendar = .current) -> [Found] {
        guard let detector else { return [] }
        let sent = sent ?? Date()
        var found: [Found] = []
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        found += missed(in: text, besides: matches.map(\.range), sent: sent, calendar: calendar)
        for match in matches {
            guard let range = Range(match.range, in: text), var date = match.date else { continue }
            let quote = String(text[range])
            let whole = NSRange(quote.startIndex..., in: quote)
            // The line it stands in: a quoted mail's "Am 14.10.2026 um 11:26 schrieb" is no date to keep.
            let line = text.lineRange(for: range)
            let lineText = String(text[line])
            if quotedHeader.firstMatch(in: lineText, range: NSRange(lineText.startIndex..., in: lineText)) != nil { continue }
            if namesDay.firstMatch(in: quote, range: whole) == nil {
                // Only a weekday: the next one after the mail, at the time the words give.
                guard let name = weekday.firstMatch(in: quote, range: whole), let day = Self.next(weekdayIn: (quote as NSString).substring(with: name.range), after: sent, calendar: calendar) else { continue }
                let time = calendar.dateComponents([.hour, .minute], from: date)
                date = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
            }
            // "bis 31.10." is read as from now until then: the date is its end.
            if until.firstMatch(in: quote, range: whole) != nil, match.duration > 0 { date = date.addingTimeInterval(match.duration) }
            // No year in the words: the one that puts the date nearest to the mail.
            if namesYear.firstMatch(in: quote, range: whole) == nil {
                var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let year = calendar.component(.year, from: sent)
                date = (year - 1...year + 1).compactMap { y -> Date? in parts.year = y; return calendar.date(from: parts) }
                    .min { abs($0.timeIntervalSince(sent)) < abs($1.timeIntervalSince(sent)) } ?? date
            }
            // What lies before the mail was written is over: a booking's day of last week is no appointment.
            guard MatterStatus.day(date) >= MatterStatus.day(sent) else { continue }
            let hasTime = namesTime.firstMatch(in: quote, range: whole) != nil
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let item = Found(day: MatterStatus.day(date),
                             time: hasTime ? String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0) : nil,
                             quote: quote.trimmingCharacters(in: .whitespacesAndNewlines))
            if !found.contains(where: { $0.day == item.day && $0.time == item.time }) { found.append(item) }
        }
        // A day found with its time and without: the one with the time.
        let timed = Set(found.filter { $0.time != nil }.map(\.day))
        found.removeAll { $0.time == nil && timed.contains($0.day) }
        // A day whose time stands apart — "Anreise: 16. Oktober" and "ab 17:00 Uhr" under it — is
        // given the time said on its line or the next.
        let lines = text.components(separatedBy: .newlines)
        found.sort { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
        return found.map { item in
            guard item.time == nil, let at = lines.firstIndex(where: { $0.contains(item.quote) }) else { return item }
            let near = lines[at...].prefix(2).joined(separator: " ")
            guard let hit = namesTime.firstMatch(in: near, range: NSRange(near.startIndex..., in: near)),
                  let clock = Self.clock((near as NSString).substring(with: hit.range)) else { return item }
            var withTime = item
            withTime.time = clock
            return withTime
        }
    }

    /// "26. Oktober" that Apple's detector passed over — since macOS 27 it misses the second day
    /// of "Anreise … am 16. Oktober, Abreise bis 10:00 Uhr am 26. Oktober". Read by rule, with a
    /// time said just before it in the same clause.
    private static let dayMonth = try! NSRegularExpression(pattern:
        #"\b(\d{1,2})\.?\s+("# + months + #")[a-zäéû]*\.?(?:\s+(20\d{2}))?"#, options: [.caseInsensitive])

    static func missed(in text: String, besides seen: [NSRange], sent: Date, calendar: Calendar) -> [Found] {
        let monthStarts = ["jan", "feb", "mär|mar", "apr|avr", "mai|may", "jun|juin", "jul|juil", "aug|aoû|aou", "sep", "okt|oct", "nov", "dez|dec|déc"]
        var out: [Found] = []
        for hit in dayMonth.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard !seen.contains(where: { NSIntersectionRange($0, hit.range).length > 0 }), let range = Range(hit.range, in: text) else { continue }
            let lineText = String(text[text.lineRange(for: range)])
            if quotedHeader.firstMatch(in: lineText, range: NSRange(lineText.startIndex..., in: lineText)) != nil { continue }
            let ns = text as NSString
            let word = ns.substring(with: hit.range(at: 2)).lowercased()
            guard let day = Int(ns.substring(with: hit.range(at: 1))), (1...31).contains(day),
                  let month = monthStarts.firstIndex(where: { $0.split(separator: "|").contains { word.hasPrefix($0) } }).map({ $0 + 1 }) else { continue }
            let named = hit.range(at: 3).location == NSNotFound ? nil : Int(ns.substring(with: hit.range(at: 3)))
            let year = calendar.component(.year, from: sent)
            let candidates = (named.map { [$0] } ?? [year - 1, year, year + 1]).compactMap { calendar.date(from: DateComponents(year: $0, month: month, day: day)) }
            guard let date = candidates.min(by: { abs($0.timeIntervalSince(sent)) < abs($1.timeIntervalSince(sent)) }),
                  MatterStatus.day(date) >= MatterStatus.day(sent) else { continue }
            // The clause before it: back to the last comma or full stop, at most forty characters.
            let start = max(0, hit.range.location - 40)
            var before = ns.substring(with: NSRange(location: start, length: hit.range.location - start))
            if let cut = before.lastIndex(where: { ",;\n".contains($0) }) { before = String(before[before.index(after: cut)...]) }
            let time = namesTime.matches(in: before, range: NSRange(before.startIndex..., in: before)).last
                .flatMap { clock((before as NSString).substring(with: $0.range)) }
            let quote = (before + ns.substring(with: hit.range)).trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(Found(day: MatterStatus.day(date), time: time, quote: quote))
        }
        return out
    }

    static func next(weekdayIn word: String, after sent: Date, calendar: Calendar) -> Date? {
        let names = [["sun", "sonntag", "dimanche"], ["mon", "montag", "lundi"], ["tue", "dienstag", "mardi"], ["wed", "mittwoch", "mercredi"],
                     ["thu", "donnerstag", "jeudi"], ["fri", "freitag", "vendredi"], ["sat", "samstag", "samedi"]]
        let lowered = word.lowercased()
        guard let index = names.firstIndex(where: { $0.contains { lowered.hasPrefix($0) } }) else { return nil }
        return calendar.nextDate(after: sent, matching: DateComponents(weekday: index + 1), matchingPolicy: .nextTime)
    }

    /// "17:00", "17 Uhr", "5 pm" as `HH:MM`.
    static func clock(_ words: String) -> String? {
        let digits = words.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard var hour = digits.first, hour < 24 else { return nil }
        if words.lowercased().contains("pm"), hour < 12 { hour += 12 }
        return String(format: "%02d:%02d", hour, digits.count > 1 ? digits[1] : 0)
    }
}
