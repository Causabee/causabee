import Foundation
import Testing

/// What Causabee says about itself is what it does (10 November: the website said the full text
/// of a mail "is never synced", a line after saying it is kept in iCloud; the app said the AI
/// "reads new mail" when it reads whatever comes in; Claude and Mistral were offered long after
/// they were taken out).
@Suite("Said as it is: the app's words and the website")
struct SaidAsItIsTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func files(in folder: String, ending: String) -> [URL] {
        let base = root.appendingPathComponent(folder)
        let all = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return all.filter { $0.pathExtension == ending }
    }

    /// The lines of a file that are not comments.
    static func said(_ url: URL) -> [String] {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    @Test("The app never says the AI reads only mail")
    func appWords() {
        let found = Self.files(in: "Sources", ending: "swift").flatMap { url in
            Self.said(url).filter { $0.contains("\"") && $0.contains("reads new mail") }.map { url.lastPathComponent + ": " + $0 }
        }
        #expect(found.isEmpty, "\(found)")
    }

    @Test("The website offers one AI, and says where full texts go as they go", arguments: ["index.html", "privacy.html"])
    func website(page: String) throws {
        let text = try String(contentsOf: Self.root.appendingPathComponent("site/" + page), encoding: .utf8)
        for old in ["Mistral", "Pick Claude", "never synced", "Sent pseudonymised to Claude"] {
            #expect(!text.contains(old), "site/\(page) still says “\(old)”")
        }
    }
}
