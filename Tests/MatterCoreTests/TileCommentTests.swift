import Foundation
import Testing
@testable import MatterCore

@Suite("A comment on what Causabee proposed")
struct TileCommentTests {
    @Test("Said to a proposal, it names the proposal for the writing; said of the matter, it stands alone")
    func namesWhatItIsAbout() {
        var brief = Brief()
        brief.said = [Brief.Said(text: "Nina signs, not me", about: "Read and sign the Sunrise contract"), Brief.Said(text: "Mum hates mornings")]
        let facts = brief.forFacts ?? ""
        #expect(facts.contains("- On “Read and sign the Sunrise contract”: Nina signs, not me"))
        #expect(facts.contains("- Mum hates mornings"))
    }

    @Test("A brief kept before comments reads as before, and a comment survives being written again")
    func keptAcrossVersions() throws {
        let old = #"{"lines":[],"said":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","text":"Call before noon","date":0}],"proposals":[],"lookups":[]}"#
        let brief = try JSONDecoder().decode(Brief.self, from: Data(old.utf8))
        #expect(brief.said.first?.text == "Call before noon" && brief.said.first?.about == nil)
        var commented = brief
        commented.said.append(Brief.Said(text: "Not before the 10th", about: "Physio on Thursday"))
        let again = commented.rewritten(lines: [], proposals: [])
        #expect(again.said.map(\.about) == [nil, "Physio on Thursday"])
        let back = try JSONDecoder().decode(Brief.self, from: JSONEncoder().encode(again))
        #expect(back.said == again.said)
    }
}
