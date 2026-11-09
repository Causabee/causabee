import Foundation
import Testing
@testable import MatterCore

/// Found by writing messages with the bee (9 November, docs/message-pressure-test.md): a subject
/// came back as "care level For Helga Mara Voss".
@Suite("What writing messages showed about the disguise")
struct DisguiseFindingsTests {
    @Test("“For” at the start of a title is no company", arguments: ["For", "Of", "To", "Your", "About"])
    func notANameWord(word: String) {
        var p = Pseudonymizer(mode: .placeholder, entries: [])
        p.learn(.organization, word)
        let subject = "Application received: care level \(word.lowercased()) Helga"
        #expect(p.restore(p.disguiser.apply(subject).text) == subject)
        #expect(!p.entries.contains { $0.original == word }, "\(word) was learned as a name")
    }

    @Test("A surname the owner shares — “Helga Voss”, her mother — comes back as Helga Voss")
    func sharedSurname() throws {
        var p = Pseudonymizer(mode: .placeholder, entries: [])
        p.learn(.person, "Mara Voss")
        let text = "Application received: care level for Helga Voss. Regards, Mara Voss"
        let disguiser = p.disguiser
        let sent = disguiser.apply(text).text
        #expect(!sent.contains("Voss"))
        let notes = disguiser.surnameNotes(in: text)
        let back = p.restorer.apply(notes.reduce(sent) { $0.replacingOccurrences(of: $1.key, with: $1.value) }).text
        #expect(back == text, "\(back)")
    }

    @Test("A capitalised word that is not a first name changes nothing: “Meine Mutter Greta Kramer”")
    func germanNounsStay() {
        var p = Pseudonymizer(mode: .placeholder, entries: [])
        p.learn(.person, "Greta Kramer")
        let text = "Meine Mutter Greta Kramer kommt."
        let disguiser = p.disguiser
        #expect(disguiser.surnameNotes(in: text).isEmpty)
        #expect(p.restore(disguiser.apply(text).text) == text)
    }
}
