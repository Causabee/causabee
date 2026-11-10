import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import Testing
import Vision

/// F001 · Polish, week 46: the website (docs/features/001-polish-week-46-the-website). What the
/// website shows is the product as it is today, in its own type.
@Suite("The website's look: the film's serif, the pictures, the privacy page's date")
struct WebsiteLookTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let film = root.appendingPathComponent("site/film/walkthrough")
    static let page = film.appendingPathComponent("index.html")

    /// The film's style rules: selectors and what they declare.
    static func rules(of html: String) -> [(selectors: [String], body: String)] {
        let styles = html.matches(of: /<style>(?<css>[\s\S]*?)<\/style>/).map { String($0.output.css) }.joined(separator: "\n")
        let css = styles.replacing(/\/\*[\s\S]*?\*\//, with: "")
        return css.matches(of: /(?<sel>[^{}]+)\{(?<body>[^{}]*)\}/).map { match in
            (String(match.output.sel).split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, String(match.output.body))
        }
    }

    // F001 AC-1
    @Test("F001 AC-1 · Every serif line of the film is Source Serif 4, 400, in its text shape")
    func filmSerifIsTheWebsites() throws {
        let rules = Self.rules(of: try String(contentsOf: Self.page, encoding: .utf8))
        let serif = rules.filter { $0.body.contains("var(--serif)") && !$0.body.contains("--serif:") }
        #expect(!serif.isEmpty, "No serif rule found: the test no longer reads the page")
        let textShape = Set(rules.filter { $0.body.contains("font-optical-sizing: none") }.flatMap(\.selectors))
        for rule in serif {
            let font = rule.body.firstMatch(of: /font:\s*(?<weight>\d{3})?[^;]*var\(--serif\)/)
            #expect(font?.output.weight.map(String.init) == "400", "\(rule.selectors): the serif is not weight 400")
            #expect(rule.body.firstMatch(of: /font:[^;]*\d+px(\/[\d.]+)?\s+var\(--serif\)/) != nil,
                    "\(rule.selectors): another typeface is named before the serif")
            for selector in rule.selectors {
                #expect(textShape.contains(selector), "\(selector): not in the text shape (font-optical-sizing: none)")
            }
        }
        // A serif element's own style may not set another weight or face: "Be organized. Be
        // private." was 500 in its style attribute, past every rule.
        let classes = Set(serif.flatMap(\.selectors).compactMap { $0.wholeMatch(of: /\.([\w-]+)/).map { String($0.output.1) } })
        let html = try String(contentsOf: Self.page, encoding: .utf8)
        for tag in html.matches(of: /<\w+[^>]*\bclass="(?<cls>[^"]*)"[^>]*\bstyle="(?<style>[^"]*)"/) {
            let theirs = Set(tag.output.cls.split(separator: " ").map(String.init))
            guard !theirs.isDisjoint(with: classes) else { continue }
            let style = String(tag.output.style)
            if let weight = style.firstMatch(of: /font-weight:\s*(\d+)/)?.output.1 {
                #expect(weight == "400", "class=\"\(tag.output.cls)\": its style sets weight \(weight)")
            }
            #expect(style.firstMatch(of: /font(-family)?:[^;]*var\(--sans\)|font-family:/) == nil, "class=\"\(tag.output.cls)\": its style sets another face")
        }
    }

    // F001 AC-2
    @Test("F001 AC-2 · Both films are drawn from today's page, with their sound and their length",
          arguments: ["walkthrough.mp4", "walkthrough-720.mp4"])
    func filmIsRenderedFromThePage(name: String) async throws {
        let asset = AVURLAsset(url: Self.film.appendingPathComponent(name))
        let seconds = try await asset.load(.duration).seconds
        // Its length is its timing's (F002: the voice and the picture are timed in one place).
        let total = try FilmAnewTests.timing().total
        #expect(abs(seconds - total) <= 0.1, "\(name) lasts \(seconds) s, not \(total): the voice would drift")
        #expect(try await asset.loadTracks(withMediaType: .audio).count == 1, "\(name) has no sound track")
        // The page the frames were drawn from, by its fingerprint: written by scripts/film/walkthrough.sh.
        let digest = SHA256.hash(data: try Data(contentsOf: Self.page)).map { String(format: "%02x", $0) }.joined()
        var said: [String] = []
        for format in try await asset.load(.availableMetadataFormats) {
            for item in try await asset.loadMetadata(for: format) {
                if let text = try? await item.load(.stringValue) { said.append(text) }
            }
        }
        #expect(said.contains { $0.contains("page-sha256:" + digest) }, "\(name) was not drawn from today's page")
    }

    // F001 AC-3
    @Test("F001 AC-3 · No picture names an AI other than GPT-6.1 Sol")
    func noPictureNamesAnotherAI() throws {
        let folder = Self.root.appendingPathComponent("site/assets/img")
        let pictures = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { ["webp", "png", "jpg"].contains($0.pathExtension) } + [Self.film.appendingPathComponent("poster.webp")]
        #expect(pictures.count > 10, "The pictures were not found")
        for picture in pictures {
            guard let source = CGImageSourceCreateWithURL(picture as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                Issue.record("\(picture.lastPathComponent) cannot be read"); continue
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            let words = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            for name in ["Claude", "Opus", "Haiku", "Mistral", "Anthropic"] {
                #expect(!words.localizedCaseInsensitiveContains(name), "\(picture.lastPathComponent) names \(name)")
            }
        }
    }

    // F001 AC-4
    @Test("F001 AC-4 · The privacy page's date is the day its text last changed")
    func privacyDateIsItsLastChange() throws {
        let page = Self.root.appendingPathComponent("site/privacy.html")
        let text = try String(contentsOf: page, encoding: .utf8)
        let said = try #require(text.firstMatch(of: /Effective (?<day>\d{1,2} \w+ \d{4})/)?.output.day, "No “Effective …” on the page")
        let reading = DateFormatter()
        reading.locale = Locale(identifier: "en_GB")
        reading.dateFormat = "d MMMM yyyy"
        let effective = try #require(reading.date(from: String(said)))
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"

        func git(_ arguments: [String]) -> (status: Int32, out: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", Self.root.path] + arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return (-1, "") }
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        }
        // Being changed now: today. Otherwise the day of the last commit that changed it.
        let changing = git(["diff", "--quiet", "HEAD", "--", "site/privacy.html"]).status == 1
        let last = git(["log", "-1", "--format=%cs", "--", "site/privacy.html"])
        try #require(last.status == 0 || changing, "git cannot be asked here")
        let expected = changing ? day.string(from: Date()) : last.out.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(day.string(from: effective) == expected, "The page says \(said); it last changed on \(expected)")
    }
}
