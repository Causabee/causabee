import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("What a round of mail offers before any of it is taken in")
struct IntakeOfferTests {
    func judgement(_ id: String, matter: String?, title: String? = nil, bulk: Bool = false) throws -> Judgement {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let key = matter.map { "\"\($0)\"" } ?? "null"
        var judgement = try decoder.decode(Judgement.self, from: Data(#"{"email_id":"\#(id)","source":"imap://x","date":"2026-09-30T07:00:00Z","subject":"Kaufvertrag","from":"Petra Lindner <p@example.org>","is_bulk":\#(bulk),"matter":\#(key),"matter_confidence":1,"matter_reason":"","decided_by":"pending","parties":[],"todos":[],"deadlines":[]}"#.utf8))
        judgement.matterTitle = title
        return judgement
    }

    @Test("A mail with no matter starts a new one under the owner's name, with what it brought; a like name is not joined")
    @MainActor
    func intoNew() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let closed = Matter(key: "freundeskreis", name: "Freundeskreis")
        closed.closedAt = Date()
        context.insert(closed)
        try context.save()

        var mails = [try judgement("a", matter: nil), try judgement("b", matter: "wohnung")]
        for index in mails.indices { mails[index].decidedBy = .claude }
        let started = mails.map { IntakeSummary.intoNew($0, named: " Freundeskreis ", existing: [closed]) }
        #expect(started[0].matter == "freundeskreis2" && started[0].matterTitle == "Freundeskreis")
        #expect(started[1].matter == started[0].matter)
        _ = try MatterImport.apply(started, to: context, owner: [])
        let new = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "freundeskreis2" })
        #expect(new.name == "Freundeskreis")
        #expect(Set((new.entries ?? []).map(\.messageID)) == ["a", "b"])
        #expect((closed.entries ?? []).isEmpty)
    }

    @Test("Each mail that is no newsletter is offered with the matter it would go into")
    func offers() throws {
        let offers = IntakeSummary.offers([
            try judgement("a", matter: "wohnung"),
            try judgement("b", matter: "umzug", title: "Moving to Birch Road 12"),
            try judgement("c", matter: "sperrmuell"),
            try judgement("d", matter: nil),
            try judgement("e", matter: "wohnung", bulk: true),
        ]) { $0 == "wohnung" ? "Buying the flat" : nil }
        #expect(offers.map(\.id) == ["a", "b", "c", "d"])
        #expect(offers[0].matter == "Buying the flat" && !offers[0].isNew)
        // A matter that is not there yet is named as the answer names it, or by its key.
        #expect(offers[1].matter == "Moving to Birch Road 12" && offers[1].isNew)
        #expect(offers[2].matter == "Sperrmuell" && offers[2].isNew)
        #expect(offers[3].matter == nil && !offers[3].isNew)
    }

    @Test("What a mail brings is taken or left, one by one")
    func leavingOut() throws {
        var mail = try judgement("a", matter: "wohnung")
        mail.todos = [.init(text: "Sign the draft", owner: .me, due: nil, sourceQuote: ""), .init(text: "Call the notary", owner: .me, due: nil, sourceQuote: "")]
        #expect(IntakeSummary.found(in: mail).map(\.key) == ["t0", "t1"])
        let kept = IntakeSummary.leaving(out: ["t0"], of: mail)
        #expect(kept.todos.map(\.text) == ["Call the notary"])
        #expect(IntakeSummary.leaving(out: [], of: mail).todos.count == 2)
    }
}

@Suite("The line after a check of mail")
struct IntakeLineTests {
    @Test("Nought is not said; a failed mail says it is tried again")
    func line() {
        #expect(IntakeSummary.line(mails: 0, matters: [], tasks: 0, dates: 0, unplaced: 1, failed: 1)
                == "1 without a matter, below · 1 could not be read, tried again next time")
        #expect(IntakeSummary.line(mails: 2, matters: ["Kita"], tasks: 1, dates: 0) == "2 mails sorted into Kita · 1 new task")
        #expect(IntakeSummary.line(mails: 0, matters: [], tasks: 0, dates: 0) == "Nothing new")
    }
}
