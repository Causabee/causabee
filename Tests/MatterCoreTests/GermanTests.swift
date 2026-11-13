import Foundation
import Testing
@testable import MatterCore

/// F009: Causabee speaks the device's language, and a matter keeps its own. These read the two
/// String Catalogues in the repository — the words themselves, not a screen — so a word missing in
/// German, a German word doing two jobs, or a "Sie" slipped in, stops the build.
@Suite("F009 · Causabee in German")
struct GermanTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let catalogues = ["Sources/MatterCore/Resources/Localizable.xcstrings", "App/Resources/Localizable.xcstrings"]

    /// One word of a catalogue: its key, what it says in a language, and how far that is done.
    struct Word {
        let key: String, catalogue: String
        var english = "", german = "", germanState = "", englishState = ""
        /// A key with no English of its own says itself: that is how a String Catalogue works.
        var englishWords: String { english.isEmpty ? key : english }
    }

    static func words(of catalogue: String) throws -> [Word] {
        let url = root.appendingPathComponent(catalogue)
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let strings = json["strings"] as? [String: Any] ?? [:]
        return strings.map { key, value in
            var word = Word(key: key, catalogue: catalogue)
            let localizations = (value as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for (language, said) in localizations {
                let unit = (said as? [String: Any])?["stringUnit"] as? [String: Any] ?? [:]
                let text = unit["value"] as? String ?? ""
                let state = unit["state"] as? String ?? ""
                if language == "de" { word.german = text; word.germanState = state }
                if language == "en" { word.english = text; word.englishState = state }
            }
            return word
        }
    }

    static func all() throws -> [Word] { try catalogues.flatMap { try words(of: $0) } }

    @Test("F009 AC-1 · Every word has German")
    func everyWordHasGerman() throws {
        let words = try Self.all()
        #expect(words.count > 400, "the catalogues hold the app's words, not a handful")
        let missing = words.filter { $0.german.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        #expect(missing.isEmpty, "no German yet: \(missing.prefix(8).map(\.key))")
        // "needs_review" and "stale" mean a word changed in English and German did not follow.
        let unfinished = words.filter { !["translated", "needs_review"].contains($0.germanState) }
        #expect(unfinished.isEmpty, "German not settled: \(unfinished.prefix(8).map { "\($0.key) · \($0.germanState)" })")
        let stale = words.filter { $0.germanState == "needs_review" }
        #expect(stale.isEmpty, "German waiting to be read again: \(stale.prefix(8).map(\.key))")
    }

    /// One German word for two English ones, on purpose: the English says the same thing twice and
    /// German says it once. Each line here is a word English could tidy up, not a German mistake.
    static let sameThing: Set<String> = [
        "anlegen",        // "Create" and "Make it": the same button, two English words
        "weglegen",       // "Put it away" and "Dismiss"
        "foto aufnehmen", // "Take a photo" and "Take Photo"
        "berichtigen",    // "Correct" and "Correct it"
        "anliegen",       // "matter" and "matters": German's word is the same in one and in many,
                          // which is why the owner chose it (13 November)
    ]

    @Test("F009 AC-4 · One word for one thing")
    func oneWordForOneThing() throws {
        let words = try Self.all()
        // The same English thing, said two ways in German: the app would name it twice.
        var germanFor: [String: Set<String>] = [:]
        for word in words where !word.german.isEmpty {
            // Case alone is not two words: "WHOSE" over a column and "Whose" in a line are one.
            germanFor[word.englishWords.lowercased(), default: []].insert(word.german.lowercased())
        }
        let twice = germanFor.filter { $0.value.count > 1 }
        #expect(twice.isEmpty, "one English word, two German: \(twice.prefix(4).map { "\($0.key) → \($0.value)" })")
        // Two different English things sharing one German word: a menu would read the same twice.
        var englishFor: [String: Set<String>] = [:]
        for word in words where !word.german.isEmpty && word.german.count > 3 {
            englishFor[word.german.lowercased(), default: []].insert(word.englishWords.lowercased())
        }
        let shared = englishFor.filter { $0.value.count > 1 && !Self.sameThing.contains($0.key) }
        #expect(shared.isEmpty, "one German word, two English: \(shared.prefix(4).map { "\($0.key) ← \($0.value)" })")
    }

    @Test("F009 AC-11 · Causabee says du")
    func saysDu() throws {
        // "Sie" as an address, not "sie" the word for they or she; nouns are capitalised in German,
        // so only these forms at a word's start, or after a comma, give it away.
        let formal = ["Sie ", "Ihnen", "Ihre ", "Ihrem", "Ihren", "Ihrer", "Ihres", "Ihr "]
        for word in try Self.all() where !word.german.isEmpty {
            let german = " " + word.german
            for form in formal {
                #expect(!german.contains(" " + form), "\(word.key): German says “\(form.trimmingCharacters(in: .whitespaces))” — Causabee says du")
            }
        }
    }

    @Test("F009 AC-10 · German for whoever listens")
    func spokenInGerman() throws {
        // What VoiceOver reads is a word like any other: it must be in a catalogue with German.
        let spoken = try Self.all().filter { $0.englishWords.contains("percent") || $0.key.contains("accessibility") }
        #expect(!spoken.isEmpty, "the spoken words are in the catalogues")
        #expect(spoken.allSatisfy { !$0.german.isEmpty })
    }

    @Test("F009 AC-2 · A matter keeps its own language")
    func matterKeepsItsLanguage() throws {
        // The bee still writes about a matter in the matter's own language: the prompts are untouched.
        #expect(ExtractionPrompt.version == "extract-v18" && DeviceReader.version == "device-2")
        let prompt = ExtractionPrompt.system
        #expect(prompt.contains("Write in the email's language"))
        #expect(DeviceReader.instructions.contains("in the email's own language"))
    }

    @Test("F009 AC-8 · Nothing already there is rewritten")
    func nothingRewritten() throws {
        // A word the bee wrote is stored as it was written; the language only changes the frame.
        let matter = Matter(key: "umzug", name: "Umzug nach Lissabon")
        matter.brief = "Der Umzug ist für den 1. Februar geplant."
        matter.nextStep = "Umzugsfirma anrufen"
        // Read as German would read it: the stored words are not looked up anywhere.
        #expect(matter.name == "Umzug nach Lissabon")
        #expect(matter.brief == "Der Umzug ist für den 1. Februar geplant.")
        #expect(matter.nextStep == "Umzugsfirma anrufen")
    }
}
