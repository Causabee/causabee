import Testing
@testable import MatterCore

@Suite struct MeTests {
    let me = Me(names: ["Mara Voss", "mara.voss@mail.example"], addresses: ["Mara@Work.example"])

    @Test func sentByAddressOrFullName() {
        #expect(me.sent("Mara Voss <mara.voss@mail.example>"))
        #expect(me.sent("M. <mara@work.example>"))
        #expect(me.sent("Voss, Mara <other@mail.example>"))
        #expect(me.sent("mara.voss@mail.example"))
    }

    @Test func othersCameIn() {
        #expect(!me.sent("Nina Voss <nina.voss@mail.example>"))
        #expect(!me.sent("Mara <mara@elsewhere.example>"))
        #expect(!me.sent("Voss <voss@elsewhere.example>"))
    }
}
