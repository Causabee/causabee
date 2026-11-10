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

    // MARK: F003 · The website's pictures and content from today's app

    static let site = root.appendingPathComponent("site")
    static func index() throws -> String { try String(contentsOf: site.appendingPathComponent("index.html"), encoding: .utf8) }

    // F003 AC-1
    @Test("F003 AC-1 · The website's pictures are today's app")
    func websitePicturesAreToday() throws {
        let page = try Self.index()
        let folder = Self.site.appendingPathComponent("assets/img")
        // The teasers' own pictures (site/film/teaser) are outside F003: they stay as they are.
        let teasers = try FileManager.default.contentsOfDirectory(at: Self.site.appendingPathComponent("film/teaser"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "html" }.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        let pictures = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "webp" }
            .filter { page.contains("assets/img/\($0.lastPathComponent)") || !teasers.contains($0.lastPathComponent) }
        #expect(pictures.count >= 10, "The pictures were not found")
        for picture in pictures {
            let name = picture.lastPathComponent
            #expect(page.contains("assets/img/\(name)"), "\(name) is on the website but the page does not use it")
            // Taken anew: not the file the website had before F003.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", Self.root.path, "show", "97d5a60:site/assets/img/\(name)"]
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = Pipe()
            try process.run()
            let old = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            let new = try Data(contentsOf: picture)
            #expect(process.terminationStatus != 0 || old != new, "\(name) is still the picture of before F003")
            guard let source = CGImageSourceCreateWithURL(picture as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                Issue.record("\(name) cannot be read"); continue
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            let words = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            for gone in ["Claude", "Opus", "Haiku", "Mistral", "Anthropic", "Auto mode"] {
                #expect(!words.localizedCaseInsensitiveContains(gone), "\(name) shows “\(gone)”")
            }
            #expect(words.firstMatch(of: /\$\s?\d/) == nil, "\(name) shows a cost")
        }
    }

    // F003 AC-2
    @Test("F003 AC-2 · Every sentence on the website is true for the app")
    func websiteSentencesAreTrue() throws {
        let page = try Self.index()
        // Everything the page holds in words, hidden parts too.
        let text = page.replacing(/<style>[\s\S]*?<\/style>|<!--[\s\S]*?-->/, with: " ").replacing(/<[^>]+>/, with: " ")
            .replacing("’", with: "'").replacing("&nbsp;", with: " ")
        for gone in ["$0.", "Oct 12", "journal of cards", "Auto mode", "What can go wrong before we fly",
                     "Apple's model on your Mac sorts what comes in", "set right by Apple Intelligence", "speech on your device."] {
            #expect(!text.contains(gone), "The website still says “\(gone)”")
        }
        // What the Mac needs is said with what works on it.
        for p in page.matches(of: /<p[^>]*>(?<p>[\s\S]*?)<\/p>/) where p.output.p.contains("Sequoia 15") {
            #expect(p.output.p.contains("macOS 26"), "“…Sequoia 15…” without what needs macOS 26: \(p.output.p.prefix(120))")
        }
    }

    // F003 AC-3
    @Test("F003 AC-3 · Every picture of the app says in words what it shows")
    func websitePicturesHaveWords() throws {
        let page = try Self.index()
        let images = page.matches(of: /<img[^>]*src="assets\/img\/[^"]+"[^>]*>/)
        #expect(images.count >= 10, "The page's pictures were not found")
        for img in images {
            let tag = String(img.output)
            let alt = tag.firstMatch(of: /alt="(?<a>[^"]*)"/)?.output.a ?? ""
            #expect(alt.count > 20, "A picture with no words: \(tag.prefix(80))")
            for gone in ["Auto mode", "$0.", "journal"] { #expect(!alt.contains(gone), "An alt text says “\(gone)”: \(alt)") }
        }
    }

    // F003 AC-4
    @Test("F003 AC-4 · The iPhone's and the iPad's pictures show one state of Mum's matter")
    func devicesAgree() throws {
        func words(_ name: String) throws -> String {
            let url = Self.site.appendingPathComponent("assets/img/\(name)")
            let image = try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: image).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
        let phone = try words("iphone-matter.webp"), pad = try words("ipad-matter.webp")
        for both in ["Care for Mum", "Get the bath seat prescription"] {
            #expect(phone.contains(both) && pad.contains(both), "The iPhone's and the iPad's matter do not both show “\(both)”")
        }
        // The iPhone's next step is an open task of the iPad's plan, not another one.
        let next = try #require(phone.components(separatedBy: "\n").drop { !$0.contains("NEXT") }.dropFirst().first, "No next step on the iPhone's picture")
        #expect(pad.contains(next), "The iPhone's next step “\(next)” is not on the iPad's plan")
    }
}
