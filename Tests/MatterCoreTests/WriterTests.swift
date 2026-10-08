import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Who of a matter's people wrote a mail")
struct WriterTests {
    @Test("A sender line that is an address alone is the one person here whose name is in it")
    func addressAlone() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "ausklang")
        context.insert(matter)
        func member(_ name: String) -> Party {
            let party = Party(name: name)
            context.insert(party)
            let membership = Membership()
            membership.party = party
            membership.matter = matter
            context.insert(membership)
            return party
        }
        let barbara = member("Barbara"), carolin = member("Carolin Hochleichter"), bettina = member("Bettina Grahs")
        let jan = member("Jan"), other = member("Jan Kramer")
        _ = other

        #expect(matter.writer("lutz.barbara@gmx.net") === barbara)
        #expect(matter.writerName("lutz.barbara@gmx.net") == "Barbara")
        #expect(matter.writer("carolin@hochleichter.de") === carolin)
        // By the name in the line, as before.
        #expect(matter.writer("Bettina Grahs <bettinagrahs@web.de>") === bettina)
        #expect(matter.writerName("Bettina Grahs <bettinagrahs@web.de>") == "Bettina Grahs")
        // Nobody's name in it: the address stays what is shown.
        #expect(matter.writer("info@example.org") == nil)
        #expect(matter.writerName("info@example.org") == "info@example.org")
        // Two it could be: nobody.
        #expect(matter.writer("jan.kramer@example.org") == nil)
        #expect(jan.name == "Jan")
        // The address the owner put in by hand decides.
        jan.address = "jk@example.org"
        #expect(matter.writer("jk@example.org") === jan)
    }
}
