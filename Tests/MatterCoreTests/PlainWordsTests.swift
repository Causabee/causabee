import Foundation
import Testing
@testable import MatterCore

@Suite("What was said, set right on the device — or left as Whisper wrote it")
struct PlainWordsTests {
    @Test("The same words set right are kept; an answer, a translation or nothing is not")
    func trusted() {
        let raw = "äh also ich muss bis freitag dem bernd die unterlagen schicken oder"
        #expect(PlainWords.trusted("Also, ich muss bis Freitag Bernd die Unterlagen schicken, oder?", for: raw))
        #expect(!PlainWords.trusted("", for: raw))
        #expect(!PlainWords.trusted("Ja.", for: raw))
        #expect(!PlainWords.trusted("So I have to send Bernd the documents by Friday, right?", for: raw))
    }

    @Test("A line about the rewrite in front, or quotation marks around it, go")
    func chatter() {
        #expect(PlainWords.withoutChatter("Here is the corrected text:\nIch komme morgen.") == "Ich komme morgen.")
        #expect(PlainWords.withoutChatter("„Ich komme morgen.“") == "Ich komme morgen.")
        #expect(PlainWords.withoutChatter("Er sagte: \"ja\" und ging.") == "Er sagte: \"ja\" und ging.")
    }

    /// The real model on this device: CAUSABEE_PLAIN=1.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_PLAIN"] != nil))
    func live() async {
        print("PLAIN available:", PlainWords.isAvailable)
        for raw in ["äh also ich muss äh bis freitag dem bernd berger die unterlagen schicken und und ihn fragen ob der termin am dienstag noch steht",
                    "um so can you can you add a task to call the the landlord tomorrow about the uh the heating"] {
            let start = Date()
            let fixed = await PlainWords.corrected(raw)
            print(String(format: "PLAIN %.1fs\n  in:  %@\n  out: %@", Date().timeIntervalSince(start), raw, fixed))
        }
    }
}
