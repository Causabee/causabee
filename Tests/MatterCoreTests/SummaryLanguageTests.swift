import Testing
@testable import MatterCore

@Suite("A summary and a next step are written in the matter's own language, not the prompt's")
struct SummaryLanguageTests {
    @Test("An English matter is English, a German one German")
    func language() {
        #expect(AssistantAsk.language(of: ["Send the last salary slip to Northbank", "Keep 20,000 euros free for the move and new furniture.",
                                           "Viewing of the flat on Saturday"]) == "English")
        #expect(AssistantAsk.language(of: ["Gehaltsnachweis an die Bank schicken", "Beim Wohnungskauf will ich 20.000 Euro frei halten.",
                                           "Besichtigung der Wohnung am Samstag"]) == "German")
    }

    @Test("The rule names it, and the question is asked in it")
    func rule() {
        #expect(SummaryPrompt.system(writingIn: "English").hasSuffix("Write in English: the language the facts are written in — not the language of these instructions or their examples."))
        var facts = Facts(text: "", refs: [:], seen: "")
        facts.language = "English"
        #expect(AssistantAsk.summaryQuestion(facts) == "Write the summary of this matter.")
        facts.language = "German"
        #expect(AssistantAsk.nextStepQuestion(facts) == "Was ist jetzt der beste nächste Schritt?")
    }
}
