import Foundation
import Testing
@testable import MatterCore

@Suite("A draft that names a file takes it along")
struct DraftAttachmentTests {
    func file(_ name: String, title: String? = nil, hidden: Bool = false) -> Document {
        let document = Document(name: name, contentType: "application/pdf", byteCount: 10,
                                source: Source(kind: .document, pointer: "/tmp/" + name, messageID: "file-" + name, date: Date()))
        document.title = title
        document.isHidden = hidden
        return document
    }

    @Test("The file named in what was asked or in the draft is found, whatever the case; one not named is not")
    func byName() {
        let memo = file("Ralf-Chille-Book-a-Dentist-memo-short-v9.pdf"), other = file("Invoice.pdf")
        let asked = "send the email to tanguy with this file attached: ralf-chille-book-a-dentist-memo-short-v9.pdf"
        #expect(DraftAttachments.named(in: [asked, "Dear Tanguy, …"], among: [other, memo]).map(\.name) == [memo.name])
        #expect(DraftAttachments.named(in: ["Please find attached Invoice.pdf"], among: [other, memo]).map(\.name) == ["Invoice.pdf"])
        #expect(DraftAttachments.named(in: ["Nothing is named here."], among: [other, memo]).isEmpty)
    }

    @Test("By the name the owner gave it, too; a hidden file and a name of three letters are left out")
    func byTitleAndNotHidden() {
        let scan = file("Scan 2026-10-01.pdf", title: "Tax assessment"), hidden = file("Offer.pdf", hidden: true), short = file("a.b")
        #expect(DraftAttachments.named(in: ["I attach the tax assessment."], among: [scan, hidden, short]).map(\.name) == [scan.name])
        #expect(DraftAttachments.named(in: ["Offer.pdf and a.b are attached"], among: [scan, hidden, short]).isEmpty)
    }

    @Test("Named as a person says it: “the Sunrise Contract draft pdf” is Sunrise-contract-draft.pdf — and not a file that only shares a word")
    func asSaid() {
        let draft = file("Sunrise-contract-draft.pdf"), other = file("Contract_2019.pdf"), short = file("Draft.pdf")
        let found = DraftAttachments.named(in: ["Confirmation message with the Sunrise Contract draft pdf attached"], among: [other, draft, short])
        #expect(found.map(\.name) == ["Sunrise-contract-draft.pdf"])
        #expect(DraftAttachments.named(in: ["I attach the sunrise contract draft."], among: [draft]).count == 1)
        #expect(DraftAttachments.named(in: ["About the sunrise contract."], among: [draft]).isEmpty)
    }
}
