import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Principle 13 — she writes as you do: how each message opens and closes reaches the draft.
@Suite("How a message is written: its opening and its sign-off")
@MainActor
struct RegisterTests {
    struct Sample: Sendable, CustomTestStringConvertible {
        let name: String
        let body: String
        let opens: String
        let closes: String
        var testDescription: String { name }
    }

    nonisolated static let samples: [Sample] = [
        Sample(name: "a casual dealer, with a signature block",
               body: "Hallo Ralf,\n\nder Volvo ist Freitag fertig. Passt dir 10 Uhr?\n\nGruß\nJens\n\nAutohaus Nord GmbH\nHafenstraße 12, 20457 Hamburg\nTel. 040 123456\nwww.autohaus-nord.example",
               opens: "Hallo Ralf,", closes: "Gruß / Jens"),
        Sample(name: "a formal insurer",
               body: "Sehr geehrter Herr Chille,\n\nanbei erhalten Sie Ihre Police.\n\nMit freundlichen Grüßen\nIhre Hansa Versicherung AG\nKundenservice",
               opens: "Sehr geehrter Herr Chille,", closes: "Mit freundlichen Grüßen / Ihre Hansa Versicherung AG"),
        Sample(name: "an English colleague",
               body: "Hi Ralf,\n\nGreat to have you on board. Let's meet the team next week.\n\nCheers,\nIsabel",
               opens: "Hi Ralf,", closes: "Cheers, / Isabel"),
        Sample(name: "a reply above quoted history",
               body: "Hey,\nFreitag passt.\nLG Anna\n\nAm 9. Nov. 2026 um 10:12 schrieb Ralf <ralf@example.org>:\n> Passt dir Freitag?\n> Gruß Ralf",
               opens: "Hey,", closes: "LG Anna"),
        Sample(name: "the owner's own short mail",
               body: "Moin Jens,\nFreitag passt.\nViele Grüße, Ralf",
               opens: "Moin Jens,", closes: "Viele Grüße, Ralf"),
        Sample(name: "French",
               body: "Bonjour Monsieur,\n\nVotre dossier est complet.\n\nCordialement,\nMarie Dupont",
               opens: "Bonjour Monsieur,", closes: "Cordialement, / Marie Dupont"),
    ]

    @Test("Opening and sign-off, not the signature block or the history", arguments: samples)
    func lines(sample: Sample) {
        let register = Register.of(sample.body)
        #expect(register?.opens == sample.opens, "\(sample.name): opens \(register?.opens ?? "nil")")
        #expect(register?.closes == sample.closes, "\(sample.name): closes \(register?.closes ?? "nil")")
    }

    @Test("Too little to tell: nothing made up", arguments: ["", "Ok", "\n\n  \n"])
    func nothing(body: String) {
        #expect(Register.of(body) == nil)
    }

    @Test("A draft is told how the newest mails are written; a screenshot gives its own words")
    func reachesTheDraft() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car", name: "Volvo or VW")
        context.insert(matter)
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "jens@example", date: Date())
        let entry = Entry(title: "Probefahrt", from: "Jens Hansen <jens@autohaus.example>", date: Date(), source: source)
        entry.matter = matter
        context.insert(entry)
        try context.save()
        let body = "Hallo Ralf,\n\nder Volvo ist Freitag fertig.\n\nGruß\nJens\n\nAutohaus Nord GmbH\nTel. 040 123456"
        let facts = FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), keptText: { _ in body })
        #expect(facts.text.contains("written: opens \"Hallo Ralf,\", closes \"Gruß / Jens\""), "\(facts.text)")
        #expect(!facts.text.contains("Tel. 040"), "The signature block went along.")
    }

    @Test("The rules for writing in the owner's voice are in what the bee is told")
    func rules() {
        let prompt = AssistantPrompt.system
        for words in ["How the owner writes", "Never more formal than they are", "is a reply, not a letter", "Freitag passt", "Mit freundlichen Grüßen\" only when they write so themselves"] {
            #expect(prompt.contains(words), "Missing: \(words)")
        }
    }
}
