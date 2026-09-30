import Foundation
import Testing
@testable import MatterCore

private func email(_ headers: String) -> Email {
    EMLParser.parse(source: headers + "\n\nHallo", url: URL(fileURLWithPath: "/tmp/test.eml"))
}

@Suite("Throwing out mail nobody addressed")
struct BulkFilterTests {
    @Test("A List-Unsubscribe header settles it")
    func listUnsubscribe() {
        let verdict = BulkFilter.verdict(for: email("""
        From: Baumarkt <newsletter@example.com>
        List-Unsubscribe: <https://example.com/abmelden?id=1>
        """))
        #expect(verdict.isBulk)
        #expect(verdict.rule == .listUnsubscribe)
        #expect(verdict.reason == "List-Unsubscribe header")
    }

    @Test("So does a List-Id, a bulk precedence, or an Auto-Submitted",
          arguments: [("List-Id: verein <v.example.com>", BulkFilter.Rule.listId),
                      ("Precedence: bulk", .precedenceBulk),
                      ("Precedence: list", .precedenceBulk),
                      ("Auto-Submitted: auto-generated", .autoSubmitted)])
    func headers(header: String, rule: BulkFilter.Rule) {
        let verdict = BulkFilter.verdict(for: email("From: x@example.com\n" + header))
        #expect(verdict.isBulk)
        #expect(verdict.rule == rule)
    }

    @Test("`Auto-Submitted: no` is what an ordinary mail says, and means no")
    func autoSubmittedNo() {
        #expect(!BulkFilter.verdict(for: email("From: a@example.net\nAuto-Submitted: no")).isBulk)
    }

    @Test("A noreply sender counts, in its several spellings",
          arguments: ["noreply@example.com", "no-reply@example.com", "no.reply@example.com",
                      "donotreply@example.com", "noreply-abc123@example.com",
                      "nicht-antworten@example.com", "mailer-daemon@example.com",
                      "bounces+4711@example.com"])
    func noreply(address: String) {
        #expect(BulkFilter.isNoreply(address))
    }

    @Test("The mailboxes a small company actually writes from do not",
          arguments: ["info@berger-hv.example", "post@berger-hv.example", "service@example.com",
                      "kontakt@example.com", "informationen@example.com", "a.berger@example.com",
                      "bounce.tracking.team@example.com", "noreplacement@example.com"])
    func notNoreply(address: String) {
        #expect(!BulkFilter.isNoreply(address))
    }

    @Test("A letter from a person is kept, and says nothing about why")
    func keepsRealMail() {
        let verdict = BulkFilter.verdict(for: email("From: Annegret Berger <post@berger-hv.example>"))
        #expect(!verdict.isBulk)
        #expect(verdict.rule == nil)
        #expect(verdict.reason == nil)
    }

    @Test("Every rule can say what it did, because the report has to name it")
    func everyRuleExplainsItself() {
        for rule in BulkFilter.Rule.allCases {
            #expect(!rule.reason.isEmpty)
        }
    }
}
