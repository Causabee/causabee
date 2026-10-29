import Foundation
import Testing
@testable import MatterCore

@Suite("Reply prefixes taken off by hand, as the expression did")
struct ReplyPrefixTests {
    static let subjects = [
        "Re: AW: SperrMüll in der Mühle", "AW: Re:Antrag", "Fwd: Rechnung März", "FW: Termin", "WG: Unterlagen",
        "Antw: Frage", "[Ticket #12] Re: Störung", "Re :  Abstand", "Rechnung 2026", "Antwort auf Ihre Frage",
        "Re: ", "re:re:re: drei", "Fwdx: no", "  Re: spaced", "Reise nach Rom", "[x]", "Aw:Aw:AW: kurz",
    ]

    @Test("The same as the regular expression, for clean and for the subject key")
    func same() {
        for subject in Self.subjects {
            var text = subject.trimmingCharacters(in: .whitespaces)
            while let prefix = text.firstMatch(of: /^(?i:re|aw|antw|wg|fwd?)\s*:\s*/), !prefix.output.isEmpty {
                text = String(text[prefix.range.upperBound...])
            }
            #expect(MailThreads.clean(subject) == (text.isEmpty ? subject : text), "\(subject)")
            var key = subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            while let prefix = key.firstMatch(of: /^(re|aw|antw|wg|fwd?|\[[^\]]*\])\s*:?\s*/), !prefix.output.0.isEmpty {
                key = String(key[prefix.range.upperBound...])
            }
            #expect(ThreadMemory.subjectKey(subject) == (key.count >= 12 ? key : nil), "\(subject)")
        }
    }
}
