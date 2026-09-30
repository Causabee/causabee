import Foundation
import Testing
@testable import MatterCore

@Suite("Where a reply stops being new")
struct QuotesTests {
    let longEnough = "Danke für die Unterlagen, ich sehe sie mir bis Freitag an und melde mich dann bei Ihnen."

    @Test("A German reply: everything from `Am … schrieb …:` on is history")
    func german() {
        let body = "\(longEnough)\n\nAm Mo., 1. Sept. 2026 um 10:00 Uhr schrieb Annegret Berger <a@b.example>:\n> alt\n> älter"
        let split = Quotes.newest(of: body, subject: "Re: Heizung")
        #expect(split.newest == longEnough)
        #expect(split.omitted > 0)
    }

    @Test("An English reply with the attribution wrapped onto a second line")
    func englishWrapped() {
        let body = "\(longEnough)\n\nOn Thu 24. Sep 2026 at 15:51 Robin Keller <\nrobbie@example.com> wrote:\n\nold text"
        #expect(Quotes.newest(of: body, subject: "Re: Catch up").newest == longEnough)
    }

    @Test("Outlook's header block, with the line it draws above it")
    func outlook() {
        let body = "\(longEnough)\n\n________________________________\nVon: Sabine Hartwig <s@hv.example>\nGesendet: Montag, 1. September 2026\nAn: Jan\nBetreff: Hausverwaltung\n\nalt"
        #expect(Quotes.newest(of: body, subject: "AW: Hausverwaltung").newest == longEnough)
    }

    @Test("A forward keeps everything: what is below is what was sent", arguments: [
        "Fwd: Angebot", "WG: Angebot", "Fw: Angebot",
    ])
    func forward(subject: String) {
        let body = "\(longEnough)\n\nAm 1. Sept. 2026 schrieb X <x@example.com>:\n> das eigentliche Angebot"
        #expect(Quotes.newest(of: body, subject: subject).omitted == 0)
    }

    @Test("A forwarded-message separator keeps everything, whatever the subject says")
    func forwardSeparator() {
        let body = "\(longEnough)\n\n---------- Forwarded message ---------\nFrom: X\nDate: …\n\nthe content"
        #expect(Quotes.newest(of: body, subject: "Angebot").omitted == 0)
    }

    @Test("`siehe unten` means nothing without what is below it")
    func tooShort() {
        let body = "siehe unten\n\nAm 1. Sept. 2026 schrieb X <x@example.com>:\n> alles Wichtige"
        #expect(Quotes.newest(of: body, subject: "Re: x").omitted == 0)
    }

    @Test("A mail with no history is sent as it is")
    func noHistory() {
        #expect(Quotes.newest(of: longEnough, subject: "Hallo").newest == longEnough)
    }

    @Test("A line that starts with `On` is not history unless it ends in wrote:")
    func notAnAttribution() {
        let body = "\(longEnough)\nOn Tuesday we meet at ten.\nBis dann"
        #expect(Quotes.newest(of: body, subject: "Re: x").omitted == 0)
    }

    @Test("A company is its domain; a person at a free-mail provider or the owner's domain is their address")
    func senderKey() {
        #expect(Extractor.senderKey("x7q2k9zz@mail.vergleich.example", own: []) == "vergleich.example")
        #expect(Extractor.senderKey("erfunden.beispiel@googlemail.com", own: []) == "erfunden.beispiel@googlemail.com")
        #expect(Extractor.senderKey("thomas@kramer.example", own: ["kramer.example"]) == "thomas@kramer.example")
    }
}

@Suite("Remembering which matter a thread belongs to")
struct ThreadMemoryTests {
    func mail(_ headers: String) -> Email {
        EMLParser.parse(source: headers + "\n\nx", url: URL(fileURLWithPath: "/tmp/x.eml"))
    }

    @Test("A reply finds its thread through In-Reply-To")
    func byHeader() {
        var memory = ThreadMemory()
        memory.remember(mail("Message-ID: <a@example.net>\nSubject: Heizung"), matter: "heizung")
        let reply = mail("Message-ID: <b@example.net>\nIn-Reply-To: <a@example.net>\nSubject: Frage")
        #expect(memory.matter(for: reply) == "heizung")
    }

    @Test("Without the headers, a reply finds it by subject — but only a subject long enough to trust")
    func bySubject() {
        var memory = ThreadMemory()
        memory.remember(mail("Subject: Hausverwaltung Honigtauer Str. 14"), matter: "hausverwaltung")
        memory.remember(mail("Subject: Telefonat"), matter: "jobwechsel")
        #expect(memory.matter(for: mail("Subject: AW: Re: Hausverwaltung Honigtauer Str. 14")) == "hausverwaltung")
        #expect(memory.matter(for: mail("Subject: Re: Telefonat")) == nil)
        // Not a reply: the same subject may start a new thread.
        #expect(memory.matter(for: mail("Subject: Hausverwaltung Honigtauer Str. 14")) == nil)
    }

    @Test("A mail with no matter teaches nothing")
    func nothingToRemember() {
        var memory = ThreadMemory()
        memory.remember(mail("Message-ID: <a@example.net>\nSubject: Newsletter vom Montag"), matter: nil)
        #expect(memory.matter(for: mail("In-Reply-To: <a@example.net>\nSubject: Re: Newsletter vom Montag")) == nil)
    }
}
