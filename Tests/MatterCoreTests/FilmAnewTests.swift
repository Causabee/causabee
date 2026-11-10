import AVFoundation
import Foundation
import ImageIO
import Testing
import Vision

/// F002 · The film anew from today's app (docs/features/002-the-film-anew-from-today-s-app).
/// The film shows Causabee as it is today, in words that are true. AC-2 and AC-5 read the page's
/// moments, and are added with the page's new way of writing them (5-plan.md, step 7).
@Suite("The film anew: today's pictures, true words, one timing")
struct FilmAnewTests {
    static let root = WebsiteLookTests.root
    static let film = WebsiteLookTests.film
    static let feature = root.appendingPathComponent("docs/features/002-the-film-anew-from-today-s-app")

    /// The voice's lines, one per line of voiceover.txt; blank lines are not lines.
    static func lines() throws -> [String] {
        try String(contentsOf: film.appendingPathComponent("voiceover.txt"), encoding: .utf8)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func git(_ arguments: [String]) -> (status: Int32, data: Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return (-1, Data()) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, data)
    }

    struct Timing: Decodable {
        struct Line: Decodable { let text: String; let start: Double; let end: Double }
        let voice: String
        let total: Double
        let lines: [Line]
    }

    static func timing() throws -> Timing {
        try JSONDecoder().decode(Timing.self, from: Data(contentsOf: film.appendingPathComponent("timing.json")))
    }

    /// Words only: lower case, without punctuation, dashes or quotes.
    static func words(_ text: String) -> [String] {
        text.lowercased().replacing("’", with: "'")
            .split { !($0.isLetter || $0.isNumber || $0 == "'") }.map(String.init)
    }

    /// A caption file's cues: start, end (seconds) and text, in order. Reads WebVTT and SubRip.
    static func cues(_ name: String) throws -> [(start: Double, end: Double, text: String)] {
        let text = try String(contentsOf: film.appendingPathComponent(name), encoding: .utf8)
        func seconds(_ s: Substring) -> Double {
            let parts = s.replacing(",", with: ".").split(separator: ":").compactMap { Double($0) }
            return parts.reduce(0) { $0 * 60 + $1 }
        }
        return text.components(separatedBy: "\n\n").compactMap { block in
            let rows = block.split(separator: "\n")
            guard let at = rows.firstIndex(where: { $0.contains("-->") }) else { return nil }
            let ends = rows[at].components(separatedBy: "-->").map { Substring($0.trimmingCharacters(in: .whitespaces)) }
            return (seconds(ends[0]), seconds(ends[1]), rows[(at + 1)...].joined(separator: " "))
        }
    }

    /// What a page says in words: its text without tags, styles, scripts and comments.
    static func pageText() throws -> String {
        try String(contentsOf: WebsiteLookTests.page, encoding: .utf8)
            .replacing(/<style>[\s\S]*?<\/style>|<script>[\s\S]*?<\/script>|<!--[\s\S]*?-->/, with: " ")
            .replacing(/<[^>]+>/, with: " ")
            .replacing("&amp;", with: "&").replacing("&nbsp;", with: " ")
    }

    // F002 AC-1
    @Test("F002 AC-1 · The film's pictures show today's app")
    func picturesAreToday() throws {
        let folder = Self.film.appendingPathComponent("img")
        let pictures = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { ["webp", "png", "jpg"].contains($0.pathExtension) }
        #expect(pictures.count >= 6, "The film's pictures were not found")
        for picture in pictures {
            // Taken anew: not the picture of 14 October the film was drawn on until now.
            let old = Self.git(["show", "62e8b21:site/assets/img/\(picture.lastPathComponent)"])
            let new = try Data(contentsOf: picture)
            #expect(old.status != 0 || old.data != new, "\(picture.lastPathComponent) is still the picture of 14 October")
            guard let source = CGImageSourceCreateWithURL(picture as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                Issue.record("\(picture.lastPathComponent) cannot be read"); continue
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            let words = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            for name in ["Claude", "Opus", "Haiku", "Mistral", "Anthropic", "Auto mode"] {
                #expect(!words.localizedCaseInsensitiveContains(name), "\(picture.lastPathComponent) shows “\(name)”")
            }
            #expect(words.firstMatch(of: /\$\s?\d/) == nil, "\(picture.lastPathComponent) shows a cost")
        }
    }

    // F002 AC-3
    @Test("F002 AC-3 · The film's words are true and name every source")
    func wordsAreTrue() throws {
        let said = try [
            ("the voice", Self.lines().joined(separator: "\n")),
            ("the captions", Self.cues("walkthrough.vtt").map(\.text).joined(separator: "\n")),
            ("the SubRip captions", Self.cues("walkthrough.srt").map(\.text).joined(separator: "\n")),
            ("the page", Self.pageText()),
        ]
        let gone = ["fetched the new mail", "which mail it came from", "fetches your mail", "your mail stays in your mail account",
                    "mails read", "read for $", "read on this iphone for $", "with auto on", "the two mails land"]
        let sources = ["screenshot", "photo", "letter", "note", "file", "document", "scan", "chat"]
        for (what, text) in said {
            let plain = text.lowercased().replacing("’", with: "'")
            for phrase in gone { #expect(!plain.contains(phrase), "\(what) still says “\(phrase)”") }
            // Mail alone, where it holds for everything that comes in: a sentence naming mail names
            // another source too. "Fetching mail …" is the app's own text where only mail is fetched.
            let sentences = plain.replacing("fetching mail …", with: "").split { ".!?\n".contains($0) }
            for sentence in sentences where sentence.firstMatch(of: /\bmails?\b/) != nil {
                #expect(sources.contains { sentence.contains($0) }, "\(what): “\(sentence.trimmingCharacters(in: .whitespaces))” names mail alone")
            }
        }
    }

    // F002 AC-4
    @Test("F002 AC-4 · Captions, timing and reading are the same words")
    func captionsAreTheReading() throws {
        let lines = try Self.lines()
        let timing = try Self.timing()
        #expect(timing.lines.map(\.text) == lines, "timing.json is not the lines of voiceover.txt")
        for name in ["walkthrough.vtt", "walkthrough.srt"] {
            let cues = try Self.cues(name)
            #expect(cues.map { Self.words($0.text) } == lines.map(Self.words), "\(name) is not voiceover.txt, line for line")
            for (cue, line) in zip(cues, timing.lines) {
                #expect(abs(cue.start - line.start) <= 0.05 && abs(cue.end - line.end) <= 0.05,
                        "\(name): “\(cue.text)” is at \(cue.start)–\(cue.end), its line at \(line.start)–\(line.end)")
            }
        }
        // What the reading says, written down by ElevenLabs from voice.mp3 (5-plan.md, step 4).
        let heard = try String(contentsOf: Self.feature.appendingPathComponent("voice-transcript.txt"), encoding: .utf8)
        #expect(Self.words(heard) == lines.flatMap(Self.words), "The reading does not say the words of voiceover.txt")
    }

    // F002 AC-6
    @Test("F002 AC-6 · Both films last as long as their timing, at most 129.6 s, drawn from today's page",
          arguments: ["walkthrough.mp4", "walkthrough-720.mp4"])
    func filmLastsItsTiming(name: String) async throws {
        let total = try Self.timing().total
        #expect(total <= 129.6, "The timing makes the film \(total) s, longer than today's 129.6")
        let asset = AVURLAsset(url: Self.film.appendingPathComponent(name))
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - total) <= 0.1, "\(name) lasts \(seconds) s, its timing \(total)")
    }
}
