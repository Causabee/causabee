import Foundation
import SwiftData
import Testing
@testable import MatterCore

@MainActor
struct BriefTests {
    private func card(_ kind: AssistantPrompt.Reply.Card.Kind, _ text: String, todo: String? = nil) -> AssistantPrompt.Reply.Card {
        AssistantPrompt.Reply.Card(kind: kind, todo: todo, text: text, owner: "me", due: nil, reason: "", cites: [])
    }

    @Test func whatTheOwnerSaidSurvivesEveryRewrite() {
        let matter = Matter(key: "wohnung")
        matter.say("Das Ziel ist vermieten, nicht verkaufen.")
        let first = matter.shownBrief!
        matter.shownBrief = first.rewritten(lines: [.init(part: .about, text: "Die Wohnung in [Place A]")], proposals: [])
        #expect(matter.shownBrief?.said.map(\.text) == ["Das Ziel ist vermieten, nicht verkaufen."])
        #expect(matter.shownBrief?.lines(.about) == ["Die Wohnung in [Place A]"])
        #expect(matter.briefAt != nil)
    }

    @Test func aProposalPutAwayStaysKnownAndAnOpenOneGivesWay() {
        let matter = Matter(key: "pflege")
        let away = Brief.Proposal(card: card(.newTodo, "Pflegekasse anrufen"), refs: [:])
        let open = Brief.Proposal(card: card(.newTodo, "Formular schicken"), refs: [:])
        matter.shownBrief = Brief(proposals: [away, open])
        matter.decide(away.id, .dismissed)
        let next = Brief.Proposal(card: card(.newTodo, "Gutachter-Termin bestätigen"), refs: [:])
        matter.shownBrief = matter.shownBrief!.rewritten(lines: [], proposals: [next])
        #expect(matter.shownBrief?.dismissed.map(\.card.text) == ["Pflegekasse anrufen"])
        #expect(matter.shownBrief?.open.map(\.card.text) == ["Gutachter-Termin bestätigen"])
    }

    @Test func takingBackWhatWasSaid() {
        let matter = Matter(key: "x")
        matter.say("Georg ist unser Anwalt.")
        matter.unsay(matter.shownBrief!.said[0].id)
        #expect(matter.shownBrief?.said.isEmpty == true)
    }

    @Test func whatTheOwnerSaysChangesTheStampSoTheBriefIsWrittenAgain() {
        let matter = Matter(key: "x")
        let before = matter.recordStamp
        matter.say("Es geht um die Nebenkosten.")
        #expect(matter.recordStamp != before)
    }

    @Test func theAdvisersAnswerComesBackInRealNamesAndOnlyWithKnownFacts() throws {
        let json = """
        {"brief":[{"part":"people","text":"[Person A] ist die Anwältin","cites":["P1"]}],
         "summary":[{"text":"Es hängt an [Person A].","cites":[]}],
         "step":"[Person A] anrufen","why":"Sie hat die Unterlagen.","todo":"T1","step_cites":["T1"],
         "proposals":[
           {"kind":"mark_done","todo":"T1","party":null,"into":null,"from":null,"subject":null,"time":null,"text":"","owner":"me","due":null,"reason":"[Person A] bestätigt es","cites":["E1"],"attach":[]},
           {"kind":"mark_done","todo":"T9","party":null,"into":null,"from":null,"subject":null,"time":null,"text":"","owner":"me","due":null,"reason":"","cites":[],"attach":[]}
         ]}
        """
        let reply = try JSONDecoder().decode(AdviserPrompt.Reply.self, from: Data(json.utf8))
        let context = ModelContext(try MatterSchema.container(at: nil))
        let todo = Todo(text: "Unterlagen", owner: .me, due: nil, source: Source(kind: .mail, pointer: "x"), origin: "o")
        context.insert(todo)
        let refs: [String: FactRef] = ["T1": .todo(todo.persistentModelID)]
        let advice = AssistantAsk.advice(from: reply, restorer: Replacer([("[Person A]", "Maria Kern")]), links: [:], refs: refs, cost: 0.01)
        #expect(advice.lines == [Brief.Line(part: .people, text: "Maria Kern ist die Anwältin")])
        #expect(advice.step == "Maria Kern anrufen")
        #expect(advice.summary == ["Es hängt an Maria Kern."])
        #expect(advice.proposals.count == 1)
        #expect(advice.proposals.first?.reason == "Maria Kern bestätigt es")
    }

    @Test func theAssistantAndTheIntakeReadTheBrief() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "wohnung", name: "Wohnung")
        context.insert(matter)
        matter.shownBrief = Brief(lines: [.init(part: .about, text: "Vermietung der Wohnung")], said: [.init(text: "Kein Verkauf.")])
        let facts = FactSheet.facts(for: [matter], today: "2026-10-20")
        #expect(facts.text.contains("Kein Verkauf."))
        #expect(facts.text.contains("Vermietung der Wohnung"))
        let about = Unplaced.matters(in: context).first { $0.key == "wohnung" }?.about ?? ""
        #expect(about.contains("Vermietung der Wohnung"))
        #expect(about.contains("Kein Verkauf."))
    }
}

struct OutOfCreditTests {
    @Test func anAccountWithNoCreditSaysSoAndIsNotTriedAgain() {
        let body = #"{"error":{"message":"You have no credits remaining.","type":"insufficient_quota","code":"credit_balance_exhausted"}}"#
        #expect(Claude.isOutOfCredit(Data(body.utf8)))
        #expect(Claude.Failure.http(status: 429, body: body).forPeople.contains("no credit left"))
        #expect(Claude.Failure.http(status: 429, body: #"{"error":{"type":"rate_limit_error"}}"#).forPeople.contains("Too many requests"))
    }
}

struct SentDraftTests {
    @Test func aDraftOpenedFromATurnIsRemembered() throws {
        let payload: [String: Any] = ["applied": [1], "answer": ["reply": ["cards": [
            ["kind": "new_todo", "subject": NSNull(), "text": "x"],
            ["kind": "draft_message", "subject": "Rückfrage zur Abrechnung", "text": "Hallo"],
            ["kind": "draft_message", "subject": "Nicht geöffnet", "text": "Hallo"],
        ]]]]
        let data = try JSONSerialization.data(withJSONObject: payload)
        #expect(LabelIntake.SentDraft.opened(in: data) == ["Rückfrage zur Abrechnung"])
    }
}

struct BriefNewsTests {
    @Test func newsStaysUntilSeenAndGoesWithTheNextBrief() {
        var brief = Brief(writtenAt: Date())
        brief.news = Brief.News(lines: ["Neu: der Bescheid ist da."], mails: 1, since: Date())
        let kept = brief.rewritten(lines: [], proposals: [])
        #expect(kept.news?.lines == ["Neu: der Bescheid ist da."])
        var seen = kept
        seen.news?.seen = true
        #expect(seen.rewritten(lines: [], proposals: []).news == nil)
        let fresh = seen.rewritten(lines: [], proposals: [], news: Brief.News(lines: ["Noch neuer."], mails: 2, since: Date()))
        #expect(fresh.news?.lines == ["Noch neuer."])
    }
}
