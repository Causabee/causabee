import Foundation
import Testing
@testable import MatterCore

struct WebLookupTests {
    @Test func aGeneralQuestionMayGoOut() {
        #expect(WebLookup.refusal("Wie lange ist die Widerspruchsfrist gegen einen Pflegegrad-Bescheid in Deutschland?") == nil)
        #expect(WebLookup.refusal("What does § 18c SGB XI say about the decision period?") == nil)
    }

    @Test func anythingPersonalStopsIt() {
        #expect(WebLookup.refusal("Can [Person A] object to the decision?") != nil)
        #expect(WebLookup.refusal("Status of claim 4711-2025-88213?") != nil)
        #expect(WebLookup.refusal("Is pflege@healthbridge.example the right address?") != nil)
        let personal = WebLookup.personal(["Helga Voss", "Healthbridge Care Fund"])
        #expect(WebLookup.refusal("How long does Healthbridge take to decide?", personal: personal) != nil)
        #expect(WebLookup.refusal("Does Helga get a care level after a fall?", personal: personal) != nil)
        #expect(WebLookup.refusal("How long do German care insurers take to decide?", personal: personal) == nil)
    }

    @Test func aBriefKeptBeforeLookupsStillReads() throws {
        let old = #"{"lines":[{"part":"about","text":"x"}],"said":[],"proposals":[]}"#
        let brief = try JSONDecoder().decode(Brief.self, from: Data(old.utf8))
        #expect(brief.lines.count == 1)
        #expect(brief.lookups.isEmpty)
    }

    @Test func whatWasLookedUpStaysAndIsNotAskedAgain() {
        var answered = WebLookup.Lookup(question: "Frist für den Widerspruch?")
        answered.state = .answered
        answered.answer = "Ein Monat."
        let brief = Brief(lookups: [answered, WebLookup.Lookup(question: "Alte offene Frage?")])
        let next = brief.rewritten(lines: [], proposals: [], questions: ["frist für den widerspruch?", "Wer zahlt den Pflegedienst?"])
        #expect(next.answered.map(\.answer) == ["Ein Monat."])
        #expect(next.openLookups.map(\.question) == ["Wer zahlt den Pflegedienst?"])
        #expect(next.forFacts?.contains("Ein Monat.") == true)
    }

    @Test func theInlineLinksAndTrackersGo() {
        #expect(WebLookup.answer(["Es sind 25 Arbeitstage. ([gesetze-im-internet.de](https://x.de/a?utm_source=openai))"]) == "Es sind 25 Arbeitstage.")
        let sources = WebLookup.unique([.init(title: "a", url: "https://x.de/a?utm_source=openai"), .init(title: "a", url: "https://x.de/a")])
        #expect(sources.map(\.url) == ["https://x.de/a"])
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_LIVE_KEY"] != nil))
    func aQuestionIsLookedUp() async throws {
        let env = ProcessInfo.processInfo.environment
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .opus
        let found = try await WebLookup.ask("Wie lange hat die Pflegekasse in Deutschland Zeit, über einen Antrag auf einen Pflegegrad zu entscheiden?",
                                            language: "German", country: "DE", claude: Claude(key: env["CAUSABEE_LIVE_KEY"]!), model: model)
        print("LIVE LOOKUP \(found.answer) | \(found.sources.map(\.url)) | cost \(found.cost)")
        #expect(!found.answer.isEmpty)
    }
}
