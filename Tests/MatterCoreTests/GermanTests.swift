import Foundation
import Testing
@testable import MatterCore

/// F009: Causabee speaks the device's language, and a matter keeps its own. These read the two
/// String Catalogues in the repository — the words themselves, not a screen — so a word missing in
/// German, a German word doing two jobs, or a "Sie" slipped in, stops the build.
@Suite("F009 · Causabee in German")
struct GermanTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// Three: the words all three devices share, the apps' own, and the share sheet's — which runs
    /// in a bundle of its own, so it carries its own words (F009).
    static let catalogues = ["Sources/MatterCore/Resources/Localizable.xcstrings",
                             "App/Resources/Localizable.xcstrings",
                             "Sources/CausabeeShare/Localizable.xcstrings"]

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
        "korrigieren",    // "Correct" and "Correct it"
        "anliegen",       // "matter" and "matters": German's word is the same in one and in many,
                          // which is why the owner chose it (13 November)
        "weiter",         // "Next" and "Continue": the one button that goes on
        "datei hinzufügen", "datei hinzufügen …", "dokument hinzufügen",  // "Add a file" / "Add file"
        "unklar, wessen", // "Unclear whose" and "whose is not clear"
        "termin ändern",  // "Change date" and "Change appointment": German's Termin is both
        "bis %@",         // "by" and "until": German says bis for both
        "in „%@“",        // "in" and "into"
        "datei öffnen",   // "Open document" and "Open the file": one thing, two English words
        "wartet auf",     // "Waits For", the menu that makes a task wait, and "Waiting for", how a
                          // task that waits is marked: one thing in German, and the owner's word
        "neues anliegen", // "New matter" and "Start a new matter": the same thing, and German says
                          // it in two words where English takes four (the owner, 13 November:
                          // "Only Neues Anliegen")
    ]

    /// Two jobs for one English word, where the capital letter is what tells them apart. Each line
    /// is a word whose two uses are different things, not an inconsistency.
    static let twoJobs: Set<String> = [
        "open",           // "open", how a task stands, and "Open", the button that opens a file
    ]

    @Test("F009 AC-4 · One word for one thing")
    func oneWordForOneThing() throws {
        let words = try Self.all()
        // The same English thing, said two ways in German: the app would name it twice.
        var germanFor: [String: Set<String>] = [:]
        for word in words where !word.german.isEmpty {
            // Case alone is not two words: "WHOSE" over a column and "Whose" in a line are one.
            // Each catalogue on its own: the apps' "Call" is the button, MatterCore's "call" the
            // kind of source — two meanings of one English word, in two bundles.
            germanFor[word.catalogue + "|" + word.englishWords.lowercased(), default: []].insert(word.german.lowercased())
        }
        let twice = germanFor.filter { pair in
            pair.value.count > 1 && !Self.twoJobs.contains(pair.key.split(separator: "|").last.map(String.init) ?? "")
        }
        #expect(twice.isEmpty, "one English word, two German: \(twice.prefix(4).map { "\($0.key) → \($0.value)" })")
        // Two different English things sharing one German word: a menu would read the same twice.
        var englishFor: [String: Set<String>] = [:]
        for word in words where !word.german.isEmpty && word.german.count > 3 {
            englishFor[word.catalogue + "|" + word.german.lowercased(), default: []].insert(word.englishWords.lowercased())
        }
        let shared = englishFor.filter { pair in
            pair.value.count > 1 && !Self.sameThing.contains(pair.key.split(separator: "|").last.map(String.init) ?? "")
        }
        #expect(shared.isEmpty, "one German word, two English: \(shared.prefix(4).map { "\($0.key) ← \($0.value)" })")
    }

    @Test("F009 AC-11 · Causabee says du")
    func saysDu() throws {
        // "Sie" as an address, not "sie" meaning she, it or they. German capitalises the first word
        // of a sentence, so "Sie liest nur" — of the bee — looks the same as the formal address;
        // only a capital in the middle of a sentence gives the address away. Same for "Ihre".
        let formal = ["Sie ", "Ihnen", "Ihre ", "Ihrem", "Ihren", "Ihrer", "Ihres", "Ihr "]
        for word in try Self.all() where !word.german.isEmpty {
            // Where a sentence begins: the start, and after what ends one.
            var starts: Set<String.Index> = [word.german.startIndex]
            for (at, character) in zip(word.german.indices, word.german) where ".!?:;—\n".contains(character) {
                var next = word.german.index(after: at)
                while next < word.german.endIndex, word.german[next] == " " { next = word.german.index(after: next) }
                if next < word.german.endIndex { starts.insert(next) }
            }
            for form in formal {
                for found in word.german.ranges(of: form) where !starts.contains(found.lowerBound) {
                    #expect(Bool(false), "\(word.key): German says “\(form.trimmingCharacters(in: .whitespaces))” in the middle of a sentence — Causabee says du")
                }
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

    /// Where the room is fixed and a longer word cannot wrap into it: a pill in a row of pills, a
    /// chip, the short button on a card. German is the longer language, so these break a layout
    /// first. The budget is what was seen to fit on the iPhone at the usual text size, with a letter
    /// or two in hand — not a guess (AC-5).
    static let tightPlaces: [(word: String, letters: Int, place: String)] = [
        ("Digest", 10, "a pill, one of the overview's six in a row"),
        ("Mail", 10, "a pill, one of the overview's six in a row"),
        ("Files", 10, "a pill, one of the overview's six in a row"),
        ("People", 10, "a pill, one of the overview's six in a row"),
        ("Notes", 10, "a pill, one of the overview's six in a row"),
        ("Plan", 10, "a pill, one of the overview's six in a row"),
        ("Overview", 10, "a pill, one of a matter's four in a row"),
        ("All", 10, "a pill"),
        ("NEW", 4, "the chip on a new card, beside the matter's name"),
        ("This week", 14, "a when-chip under a task"),
        ("Next week", 14, "a when-chip under a task"),
        ("Later", 14, "a when-chip under a task"),
        ("No day yet", 14, "a when-chip under a task"),
        ("Comment", 12, "a card's own short button"),
        ("Seen", 12, "a card's own short button"),
        ("Change", 12, "a card's own short button"),
        ("Undo", 12, "a card's own short button"),
        ("Open", 12, "a card's own short button"),
        ("Set day", 14, "where a task's day would stand"),
        ("Sort in", 14, "the button on what came in"),
        ("Take in", 14, "the button on what came in"),
        // Two buttons side by side under a closed matter's banner, on the iPhone's width.
        ("Start a new matter", 14, "a button beside “Open Again”, under a closed matter"),
        ("Open Again", 14, "a button beside “Start a new matter”, under a closed matter"),
    ]

    /// An English word with two senses, said in German in the sense the app never meant. Each line
    /// here was wrong once, and the German it must not say again — a dictionary's first answer is
    /// not the app's (13 November: "When you leave", where the bee waits for the owner to leave the
    /// matter's page before it writes, read "Wenn du losfährst", which is leaving by car).
    static let notThisSense: [(word: String, mustNotSay: [String], means: String)] = [
        ("When you leave", ["fahr", "fähr"], "leaving the page, not driving off"),
    ]

    @Test("F009 AC-1 · German says the sense the app meant")
    func germanSaysTheSense() throws {
        let words = try Self.all()
        var wrong: [String] = []
        for line in Self.notThisSense {
            let said = words.filter { $0.key == line.word }
            #expect(!said.isEmpty, "“\(line.word)” is in no catalogue any more — the line it guarded is gone or renamed.")
            for word in said where line.mustNotSay.contains(where: { word.german.lowercased().contains($0) }) {
                wrong.append("“\(word.key)” → “\(word.german)” · it means \(line.means)")
            }
        }
        #expect(wrong.isEmpty, "German in a sense the app never meant:\n\(wrong.joined(separator: "\n"))")
    }

    @Test("F009 AC-5 · German fits where the room is fixed")
    func germanFitsTheTightPlaces() throws {
        let words = try Self.all()
        var tooLong: [String] = []
        for place in Self.tightPlaces {
            let said = words.filter { $0.key == place.word }
            #expect(!said.isEmpty, "“\(place.word)” is in no catalogue any more — \(place.place) says something else now, and nothing holds its room.")
            for word in said where word.german.count > place.letters {
                tooLong.append("“\(word.german)” (\(word.german.count) letters, \(place.letters) fit) · \(place.place)")
            }
        }
        #expect(tooLong.isEmpty, "too long for the room there is — say it shorter:\n\(tooLong.joined(separator: "\n"))")
    }

    @Test("F009 AC-9 · English stays as it is")
    func englishStaysAsItIs() throws {
        let words = try Self.all()
        // In a String Catalogue the key is the English the source wrote. An English value of its own
        // would quietly say something else, and the words' tests — which read the sources — would
        // not see it. So no key carries an English value that differs from itself.
        let changed = words.filter { !$0.english.isEmpty && $0.english != $0.key }
        #expect(changed.isEmpty, "the English was rewritten in the catalogue: \(changed.prefix(8).map { "\($0.key) → \($0.english)" })")
        // And the words' own tests are all still there to read it.
        let theWordsTests = ["SaidAsItIsTests", "PlanWordsTests", "StoreCopyTests", "OwnCopyTests",
                             "PlainWordsTests", "WelcomeTests", "ProMeterTests", "ManifestoTests"]
        for suite in theWordsTests {
            let file = Self.root.appendingPathComponent("Tests/MatterCoreTests/\(suite).swift")
            #expect(FileManager.default.fileExists(atPath: file.path), "\(suite) is gone — the English words have no guard.")
        }
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

/// F009: the net. Every word the app says of its own must be in a catalogue — and a word built in
/// code, out of pieces, is invisible to SwiftUI and to the extractor alike. So the sources are read
/// whole: every string literal that reads like words a person could be shown must be a catalogue
/// key, or be named in `scripts/words-machine.txt` as something else — a key, a symbol, a mark in a
/// mail, what a model is told. `scripts/words.py --escaped` is the one net, used here and by hand.
@Suite("F009 · No English slips through")
struct EveryWordTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Runs the script and gives back what it said and how it ended.
    static func sweep(_ arguments: [String]) throws -> (said: String, ok: Bool) {
        let python = Process()
        python.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        python.arguments = ["python3", "-I", "scripts/words.py"] + arguments
        python.currentDirectoryURL = root
        let pipe = Pipe()
        python.standardOutput = pipe
        python.standardError = pipe
        try python.run()
        let said = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        python.waitUntilExit()
        return (said, python.terminationStatus == 0)
    }

    @Test("F009 AC-1 · No word a person reads escapes the catalogue")
    func nothingEscapes() throws {
        let run = try Self.sweep(["--escaped"])
        // The script names each one with its file and line; its last line counts them.
        #expect(run.ok, "words a person reads are in no catalogue:\n\(run.said)")
    }

    @Test("F009 AC-1 · Every word is looked up in its own catalogue")
    func ownCatalogue() throws {
        // MatterCore's words are in its own bundle, the apps' in theirs. A lookup with the wrong
        // bundle finds nothing and shows the English, quietly — so each folder is checked.
        var wrong: [String] = []
        for (folder, needsModule) in [("Sources/MatterCore", true), ("Sources/Causabee", false),
                                      ("Sources/CausabeePhone", false), ("Sources/CausabeeShare", false)] {
            let base = Self.root.appendingPathComponent(folder)
            let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    guard line.contains("String(localized:") else { continue }
                    let says = line.contains("bundle: .module")
                    guard says != needsModule else { continue }
                    let place = "\(file.lastPathComponent):\(number + 1)"
                    wrong.append(needsModule ? "\(place) · needs bundle: .module" : "\(place) · must not say bundle: .module")
                }
            }
        }
        #expect(wrong.isEmpty, "these look a word up in the wrong catalogue: \(wrong)")
    }
}

/// F009: the catalogue read as a German device reads it — not as JSON, but through the compiled
/// German side of MatterCore's bundle. This is what proves the whole chain: the catalogue is built
/// into the bundle, the key the code asks for is the key that is in there, and German comes back.
/// Foundation picks the language from the device, not from a locale handed to a call, so the German
/// side is opened by itself here; that a German device picks it is Apple's part, and the owner's own
/// look on three devices (AC-6).
@Suite("F009 · German as a German device reads it")
struct GermanAtRuntimeTests {
    /// The German side of the shared words, as the build compiled it.
    static let german: Bundle? = Bundle.words.url(forResource: "de", withExtension: "lproj").flatMap(Bundle.init(url:))

    /// What a German device would read for this word; the key itself when nothing is there for it.
    static func said(_ key: String) -> String {
        german?.localizedString(forKey: key, value: "", table: "Localizable") ?? key
    }

    @Test("F009 AC-1 · A word of the app's own comes back in German")
    func wordsComeBackGerman() throws {
        #expect(Self.german != nil, "MatterCore's bundle holds a German side")
        #expect(Self.said("Overdue") == "Überfällig")
        #expect(Self.said("Digest") == "Überblick")
        #expect(Self.said("Deadline") == "Frist")
        #expect(Self.said("Matter") == "Anliegen")
        // And a word of several lines, with its new line kept.
        #expect(Self.said("Every matter.\nIn its place.") == "Jedes Anliegen.\nAn seinem Platz.")
    }

    @Test("F009 AC-1 · A word that carries a value puts it where German wants it")
    func valuesLandRight() {
        // A short German day carries a full stop of its own, so the German says none and the app
        // closes the sentence — one stop after "12. Nov.", one added after a year (F009).
        #expect(MatterStatus.sentence(String(format: Self.said("Overdue since %@"), "12. Nov.")) == "Überfällig seit 12. Nov.")
        #expect(MatterStatus.sentence(String(format: Self.said("Overdue since %@"), "12. Nov. 2027")) == "Überfällig seit 12. Nov. 2027.")
        #expect(String(format: Self.said("%lld mails sorted into %@"), 3, "Umzug") == "3 Mails in Umzug einsortiert")
        #expect(String(format: Self.said("%lld h %lld min"), 1, 30) == "1 Std. 30 Min.")
    }

    @Test("F009 AC-2 · What the bee wrote is not looked up")
    func whatWasWrittenStays() {
        // A word that is not the app's own comes back as it was asked for, so a matter's own words
        // handed to the same call by mistake could never be turned into something else.
        let mine = "Der Umzug ist für den 1. Februar geplant."
        #expect(Self.said(mine) == mine)
    }

    @Test("F009 AC-1 · Every shared word comes back in German, not in English")
    func noneFallsBackToEnglish() throws {
        // The strongest form: ask the bundle for every key the catalogue holds and see that what
        // comes back is the German written there. A key the build did not take in, or one whose
        // German is missing, comes back as the English itself.
        var english: [String] = []
        for word in try GermanTests.words(of: "Sources/MatterCore/Resources/Localizable.xcstrings") {
            let said = Self.said(word.key)
            if said != word.german { english.append("\(word.key) → \(said)") }
        }
        #expect(english.isEmpty, "these did not come back as the catalogue says: \(english.prefix(8))")
    }

    @Test("F009 AC-1 · A value lands in German where the English put it")
    func placeholdersMatch() throws {
        // The dangerous one: a German word with a placeholder the English has not, or of another
        // kind, puts the wrong value in — or crashes the app. Both catalogues, read as text.
        var wrong: [String] = []
        for word in try GermanTests.all() where !word.german.isEmpty {
            let holes = { (text: String) in
                text.matches(of: /%(?:[0-9]+\$)?(?:lld|ld|d|@|lf|f|%)/).map { String($0.output) }
            }
            let mine = holes(word.englishWords), theirs = holes(word.german)
            // Numbered (%1$@) may be reordered; unnumbered must stand in the same order.
            let numbered = theirs.contains { $0.contains("$") }
            if numbered ? mine.count != theirs.count : mine != theirs {
                wrong.append("\(word.key) · \(mine) vs \(theirs)")
            }
        }
        #expect(wrong.isEmpty, "the German does not carry the same values: \(wrong.prefix(8))")
    }
}

/// F009: the two things German needs outside the catalogue — the device, where a person picks the
/// language, and the App Store, where they read about Causabee before they have it. Neither can be
/// seen from a unit test; what can be held here is what makes each one possible, so it cannot be
/// lost again without a word of warning.
@Suite("F009 · German beyond the app's own words")
struct GermanBeyondTheAppTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("F009 AC-6 · German can be picked for Causabee alone")
    func germanForCausabeeAlone() throws {
        // iOS and macOS offer "Language" inside an app's own settings only when the app carries more
        // than one. Three things make that true, and all three are ours to keep:
        // the project knows the region,
        let project = try String(contentsOf: Self.root.appendingPathComponent("App/Causabee.xcodeproj/project.pbxproj"), encoding: .utf8)
        let regions = project.components(separatedBy: "knownRegions = (").dropFirst().first?
            .components(separatedBy: ");").first ?? ""
        #expect(regions.contains("de"), "the project does not know the German region: the per-app language is not offered.")
        #expect(regions.contains("en"), "English is no longer a region of its own.")
        // the shared words are built with a German side beside the English — which is the bundle's
        // own region, where a key says itself and no table is written,
        #expect(Bundle.words.url(forResource: "de", withExtension: "lproj") != nil, "no German side in the shared bundle.")
        #expect(Bundle.words.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String == "en",
                "English is no longer the shared bundle's own region: a key would stop saying itself.")
        // and there is no switch inside Causabee: nothing in the app picks a language for itself, so
        // the device's own setting is the only one there is (the owner, 13 November).
        var picks: [String] = []
        for folder in ["Sources/MatterCore", "Sources/Causabee", "Sources/CausabeePhone", "Sources/CausabeeShare"] {
            let base = Self.root.appendingPathComponent(folder)
            let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                if text.contains("AppleLanguages") || text.contains("preferredLocalizations") {
                    picks.append(file.lastPathComponent)
                }
            }
        }
        #expect(picks.isEmpty, "these pick a language inside the app, instead of following the device: \(picks)")
    }

    @Test("F009 AC-7 · The App Store page in German is written and fits")
    func theStorePageInGerman() throws {
        // The page itself is posted by hand with the release. What is held here is its words: every
        // field written, inside Apple's own limit, German, and no field that names mail as the one
        // source Causabee has.
        let page = try String(contentsOf: Self.root.appendingPathComponent("docs/features/009-causabee-in-german/store-de.md"), encoding: .utf8)
        let fields = page.components(separatedBy: "\n## ").dropFirst()
        var said: [String: String] = [:]
        for field in fields {
            let heading = field.components(separatedBy: "\n").first ?? ""
            let words = field.dropFirst(heading.count).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let limit = heading.components(separatedBy: "höchstens ").dropFirst().first?
                .components(separatedBy: " ").first.flatMap(Int.init) else { continue }
            let name = heading.components(separatedBy: " · ").first ?? heading
            said[name] = words
            #expect(!words.isEmpty, "“\(name)” is empty.")
            #expect(words.count <= limit, "“\(name)” is \(words.count) letters; Apple takes \(limit).")
        }
        for name in ["Name", "Untertitel", "Werbetext", "Schlüsselwörter", "Beschreibung", "Was getestet werden soll"] {
            #expect(said[name] != nil, "the German page has no “\(name)”.")
        }
        // German, not English with a German heading over it.
        let readable = (said["Beschreibung"] ?? "") + " " + (said["Was getestet werden soll"] ?? "")
        for english in [" the ", " and ", " your ", " with ", " that ", "Mail is", "reads your mail"] {
            #expect(!readable.contains(english), "the German page still says “\(english.trimmingCharacters(in: .whitespaces))”.")
        }
        #expect(readable.contains("du") || readable.contains("dein"), "the German page does not say du.")
        // Causabee is not a mail app: where the page says what comes in, it names more than mail.
        if let description = said["Beschreibung"], description.contains("Mails") {
            for source in ["Screenshots", "Fotos", "Dateien", "Notizen", "Chat"] {
                #expect(description.contains(source), "the page names mail but not \(source).")
            }
        }
    }
}
