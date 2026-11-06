import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Good to know is Pro's: the adviser gives the facts as they are now, and the matter follows —
/// new ones come, ones given again stay, ones no longer given go, and what the owner hid stays hidden.
@Suite("Good to know")
@MainActor
struct GoodToKnowTests {
    private let mail = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<1@x>")

    private func matter() throws -> (Matter, ModelContext) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "move", name: "Move")
        context.insert(matter)
        return (matter, context)
    }

    @Test("Facts come in as worth knowing, with their source and the day they hold until")
    func comeIn() throws {
        let (matter, context) = try matter()
        matter.putFacts([GoodToKnowFact(text: "The offer holds until the 13th.", sources: [mail], until: "2026-11-13"),
                         GoodToKnowFact(text: "Mrs. Adler has the spare key.", sources: [mail])], in: context)
        #expect(matter.infos.count == 2 && matter.openTodos.isEmpty)
        let offer = try #require(matter.infos.first { $0.text.hasPrefix("The offer") })
        #expect(offer.isFact && offer.holdsUntil == "2026-11-13" && offer.factSources == [mail])
        #expect(offer.mayBeOutdated(today: "2026-11-14") && !offer.mayBeOutdated(today: "2026-11-13"))
        let facts = FactSheet.facts(for: [matter], today: "2026-11-06")
        #expect(facts.text.contains("(holds until 2026-11-13)"))
    }

    @Test("Given again it stays, in the new words; no longer given it goes")
    func stayAndGo() throws {
        let (matter, context) = try matter()
        matter.putFacts([GoodToKnowFact(text: "The visit is on the 6th.", sources: [mail]),
                         GoodToKnowFact(text: "Mrs. Adler has the spare key.", sources: [mail])], in: context)
        let key = try #require(matter.infos.first { $0.text.contains("key") })
        matter.putFacts([GoodToKnowFact(text: "Mrs. Adler from number 4 has the spare key.", sources: [mail], same: key.persistentModelID)], in: context)
        #expect(matter.infos.map(\.text) == ["Mrs. Adler from number 4 has the spare key."])
        #expect(matter.infos.first?.persistentModelID == key.persistentModelID)
    }

    @Test("Hidden by the owner, it stays hidden when given again, and is said to the adviser")
    func hiddenStays() throws {
        let (matter, context) = try matter()
        matter.putFacts([GoodToKnowFact(text: "The insurer asked twice.", sources: [mail])], in: context)
        let fact = try #require(matter.infos.first)
        matter.setHidden(.task(fact), true)
        matter.putFacts([GoodToKnowFact(text: "The insurer asked twice.", sources: [mail])], in: context)
        #expect(matter.infos.isEmpty)
        #expect(matter.hiddenFacts == ["The insurer asked twice."])
        // Not given any more, the hidden one is kept all the same: it is what keeps it away.
        matter.putFacts([], in: context)
        #expect(matter.hiddenFacts.count == 1)
    }

    @Test("What the owner keeps by hand is the owner's: not removed, not given twice")
    func ownersStay() throws {
        let (matter, context) = try matter()
        let own = Todo(text: "Mrs. Adler has the spare key.", owner: .unknown, due: nil, source: mail, origin: "<1@x>#mrs. adler has the spare key.")
        own.isInfo = true
        context.insert(own)
        own.matter = matter
        matter.putFacts([GoodToKnowFact(text: "Mrs. Adler has the spare key.", sources: [mail])], in: context)
        #expect(matter.infos.count == 1 && !(matter.infos.first?.isFact ?? true))
        matter.putFacts([], in: context)
        #expect(matter.infos.count == 1)
    }

    @Test("The adviser's facts in real names; a same_as it does not know is a new one")
    func adviserReply() throws {
        let json = """
        {"brief": [], "summary": [], "step": "Wait", "why": "", "todo": null, "step_cites": [], "proposals": [],
         "research": [], "news": [], "facts": [{"text": "[Person A] has the key.", "cites": ["E1"], "same_as": "T9", "until": null}]}
        """
        let reply = try JSONDecoder().decode(AdviserPrompt.Reply.self, from: Data(json.utf8))
        let advice = AssistantAsk.advice(from: reply, restorer: Replacer([("[Person A]", "Mrs. Adler")]), links: [:], refs: [:], cost: 0)
        #expect(advice.facts?.first?.text == "Mrs. Adler has the key.")
        #expect(advice.facts?.first?.sameAs == nil)
        // An adviser from before facts gave none: nothing is touched.
        let old = try JSONDecoder().decode(AdviserPrompt.Reply.self, from: Data(json.replacingOccurrences(of: #", "facts": [{"text": "[Person A] has the key.", "cites": ["E1"], "same_as": "T9", "until": null}]"#, with: "").utf8))
        #expect(AssistantAsk.advice(from: old, restorer: Replacer([]), links: [:], refs: [:], cost: 0).facts == nil)
    }
}
