import Foundation
import Testing
@testable import MatterCore

@Suite("Step 8: measuring against the golden set")
struct ReportTests {
    @Test("The same to-do in other words is paired; a different one is not")
    func pairing() {
        #expect(Report.similarity("Eigentümerliste schicken", "Die Eigentümerliste an Frau Lindner schicken") >= Report.threshold)
        #expect(Report.similarity("Unterlagen schicken", "Unterlagen schickt") >= Report.threshold)
        #expect(Report.similarity("Eigentümerliste schicken", "Termin für die Begehung bestätigen") < Report.threshold)
        #expect(Report.similarity("Bitte an", "") == 0)
    }

    @Test("A short to-do inside a long one is the same to-do; half of a short one is not")
    func containment() {
        #expect(Report.score("Feedbackgespräch", "Bestätigen, ob Mittwoch 10 Uhr für das Feedbackgespräch passt") != nil)
        #expect(Report.score("Angebot prüfen", "Termin für die Begehung bestätigen") == nil)
        // The matcher's known limit: a different verb for the same object pairs, whether it is
        // the same to-do ("Vollmacht schicken" / "zusenden") or not ("prüfen" / "annehmen").
        #expect(Report.score("Angebot prüfen", "Angebot annehmen") != nil)
    }

    @Test("A mail exported twice counts once, and the tap on either copy counts")
    func duplicates() {
        var decision = Spike(detector: EntityDetector(runsTagger: false)).run(on: mail("01", "From: a@example.net")).judgement
        decision.extraction = .init(model: "m", servedBy: "m", mode: "placeholder", prompt: "v")
        decision.todos = [.init(text: "Liste schicken", owner: .me, due: nil, sourceQuote: "")]
        let labels = GoldenSet.read("""
        file;email_id;tapped;matter;todos
        01.eml;<a@x>;no;hv;Liste schicken (me)
        01 2.eml;<a@x>;yes;hv;Liste schicken (me)
        """).labels
        let result = Report.measure(decisions: [decision], labels: labels, emails: [])
        #expect(result.duplicates == 1)
        #expect(result.todos.expected == 1)
    }

    @Test("Each to-do is used once, and the best pairs win")
    func greedy() {
        let pairs = Report.pair(["Liste schicken", "Termin bestätigen"],
                                ["Termin am Montag bestätigen", "Liste an Lindner schicken", "Liste nochmal schicken"])
        #expect(pairs.count == 2)
        #expect(Set(pairs.map(\.0)) == [0, 1])
    }

    func mail(_ name: String, _ headers: String) -> Email {
        EMLParser.parse(source: headers + "\n\nx", url: URL(fileURLWithPath: "/tmp/\(name).eml"))
    }

    @Test("Recall, precision and the owner are counted per paired to-do")
    func todos() {
        var decision = Spike(detector: EntityDetector(runsTagger: false)).run(on: mail("01", "From: a@example.net")).judgement
        decision.extraction = .init(model: "claude-haiku-4-5", servedBy: "claude-haiku-4-5", mode: "placeholder", prompt: "v")
        decision.todos = [.init(text: "Eigentümerliste an Lindner schicken", owner: .me, due: nil, sourceQuote: ""),
                          .init(text: "Kaffee trinken", owner: .other, due: nil, sourceQuote: "")]
        let label = GoldenSet.read("file;tapped;matter;todos\n01.eml;yes;hv;Eigentümerliste schicken (me) | Begehung bestätigen (me)\n").labels
        let result = Report.measure(decisions: [decision], labels: label, emails: [])
        #expect(result.todos.expected == 2 && result.todos.found == 2 && result.todos.matched == 1)
        #expect(result.myTodos.matched == 1)
        #expect(result.ownerRight == 1 && result.ownerJudged == 1)
    }

    @Test("A reply reaches its matter from the tap on the thread's first mail; a new thread does not")
    func reach() {
        let emails = [
            mail("a", "Message-ID: <a@x>\nDate: Mon, 1 Sep 2026 10:00:00 +0200\nFrom: harz@hv.example\nSubject: Hausverwaltung Honigtauer"),
            mail("b", "Message-ID: <b@x>\nDate: Tue, 2 Sep 2026 10:00:00 +0200\nFrom: me@example.net\nIn-Reply-To: <a@x>\nSubject: Re: Hausverwaltung Honigtauer"),
            mail("c", "Message-ID: <c@x>\nDate: Wed, 3 Sep 2026 10:00:00 +0200\nFrom: harz@hv.example\nSubject: Tagesordnung für die Versammlung"),
        ]
        let labels = GoldenSet.read("file;tapped;matter\na.eml;yes;hv\nb.eml;no;hv\nc.eml;no;hv\n").labels
        let reach = Report.reach(labels: labels, emails: emails)
        #expect(reach.taps == 1 && reach.followers == 2)
        #expect(reach.reached == 1)
        #expect(reach.missed.map(\.subject) == ["Tagesordnung für die Versammlung"])
        #expect(reach.byKnownParty == 1)  // Lindner wrote the tapped mail
    }

    @Test("The judge's numbering is checked: out of range and used twice are dropped")
    func judgeNumbering() throws {
        let json = Data(#"{"pairs":[{"owner_item":1,"software_item":2,"reason":"gleich"},{"owner_item":1,"software_item":1,"reason":"doppelt"},{"owner_item":3,"software_item":9,"reason":"außerhalb"},{"owner_item":2,"software_item":1,"reason":"gleich"}]}"#.utf8)
        let pairs = try Judge.pairs(from: json, expected: 2, found: 2)
        #expect(pairs.map { [$0.expected, $0.found] } == [[0, 1], [1, 0]])
    }

    @Test("Judged pairs replace the word stems, reasons and all")
    func judgedPairs() {
        var decision = Spike(detector: EntityDetector(runsTagger: false)).run(on: mail("01", "From: a@example.net")).judgement
        decision.extraction = .init(model: "m", servedBy: "m", mode: "placeholder", prompt: "v")
        decision.todos = [.init(text: "Send the signed documents", owner: .me, due: nil, sourceQuote: "")]
        let labels = GoldenSet.read("file;tapped;matter;todos\n01.eml;yes;job;Unterschriebene Unterlagen zurückschicken (me)\n").labels
        #expect(Report.measure(decisions: [decision], labels: labels, emails: []).todos.matched == 0)
        let judged: Report.Judged = ["01.eml": [(0, 0, "dasselbe, auf Englisch")]]
        let result = Report.measure(decisions: [decision], labels: labels, emails: [], judged: judged)
        #expect(result.todos.matched == 1 && result.myTodos.matched == 1)
        #expect(result.pairs.first?.reason == "dasselbe, auf Englisch")
    }

    @Test("`we` is read from a label, and counts as mine; `other` counts as waiting")
    func weAndWaiting() {
        var decision = Spike(detector: EntityDetector(runsTagger: false)).run(on: mail("01", "From: a@example.net")).judgement
        decision.extraction = .init(model: "m", servedBy: "m", mode: "placeholder", prompt: "v")
        decision.todos = [.init(text: "Verwaltung zur Einberufung auffordern", owner: .we, due: nil, sourceQuote: ""),
                          .init(text: "Einladung zur Versammlung verschicken", owner: .other, due: nil, sourceQuote: "")]
        let labels = GoldenSet.read("file;tapped;matter;todos\n01.eml;yes;hv;Verwaltung zur Einberufung auffordern (we) | Einladung zur Versammlung verschicken (other)\n").labels
        #expect(labels[0].todos.map(\.owner) == [.we, .other])
        let result = Report.measure(decisions: [decision], labels: labels, emails: [])
        #expect(result.myTodos.matched == 1 && result.waiting.matched == 1)
        #expect(result.ownerRight == 2)
    }
}
