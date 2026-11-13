import Foundation
import Testing
@testable import MatterCore

/// F009 AC-3: a day a person reads is written as their device writes it; a day a machine reads —
/// parsed from a mail, given to a model, kept in the store — stays as it was, or what is read and
/// sent would change meaning.
@Suite("F009 · Dates as the device writes them")
struct DateLocaleTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func sources(_ folder: String) throws -> [(path: String, text: String)] {
        let base = root.appendingPathComponent(folder)
        let found = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        return try found.map { (String($0.path.dropFirst(root.path.count + 1)), try String(contentsOf: $0, encoding: .utf8)) }
    }

    @Test("F009 AC-3 · No day a person reads is forced into English")
    func noForcedEnglish() throws {
        var forced: [String] = []
        for folder in ["Sources/MatterCore", "Sources/Causabee", "Sources/CausabeePhone", "Sources/CausabeeShare"] {
            for file in try Self.sources(folder) {
                let lines = file.text.split(separator: "\n", omittingEmptySubsequences: false)
                for (number, line) in lines.enumerated() {
                    guard line.contains("Locale(identifier: \"en_US\")") || line.contains("Locale(identifier: \"en_GB\")") else { continue }
                    // A line said to be for a machine, in the line above it, is allowed to stay English.
                    let why = number > 0 ? lines[number - 1] : ""
                    if why.contains("for the model:") || why.contains("for the store:") { continue }
                    forced.append("\(file.path):\(number + 1)")
                }
            }
        }
        #expect(forced.isEmpty, "these force English on something a person reads: \(forced)")
    }

    @Test("F009 AC-3 · What a machine reads stays as it was")
    func machineDatesStay() throws {
        // A mail's own date, the day given to Apple's model, the golden set's days: POSIX, always.
        var posix = 0
        for folder in ["Sources/MatterCore", "Sources/Causabee", "Sources/CausabeePhone", "Sources/CausabeeShare"] {
            for file in try Self.sources(folder) {
                posix += file.text.components(separatedBy: "en_US_POSIX").count - 1
            }
        }
        #expect(posix >= 18, "the machine's dates are still POSIX, \(posix) of them")
    }

    @Test("F009 AC-3 · A German device reads German days")
    func germanDays() {
        let day = DateComponents(calendar: .current, year: 2026, month: 12, day: 1).date!
        let german = Locale(identifier: "de_DE")
        #expect(day.formatted(.dateTime.day().month(.wide).locale(german)) == "1. Dezember")
        #expect(day.formatted(.dateTime.weekday(.wide).locale(german)).contains("Dienstag"))
        // And the same day in English is what it always was.
        let english = Locale(identifier: "en_GB")
        #expect(day.formatted(.dateTime.day().month(.wide).locale(english)) == "1 December")
    }
}
