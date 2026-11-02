import Foundation
import Testing
@testable import MatterCore

@Suite("When Auto writes a matter again")
struct AutoPaceTests {
    let changed = Date(timeIntervalSince1970: 1_000_000)

    func due(after seconds: TimeInterval, open: Bool = true, newMail: Bool = false, asked: Bool = false) -> Bool {
        AutoPace.isDue(changed: changed, now: changed.addingTimeInterval(seconds), open: open, newMail: newMail, asked: asked)
    }

    @Test("While the owner works in a matter it waits, whatever changed")
    func waitsWhileOpen() {
        #expect(!due(after: 60))
        #expect(!due(after: 60, newMail: true))
        #expect(due(after: AutoPace.quiet))
    }

    @Test("Asked for, or left, it is written at once")
    func asked() {
        #expect(due(after: 0, asked: true))
    }

    @Test("New mail for a matter nobody has open is written soon; another device's tick waits")
    func notOpen() {
        #expect(!due(after: 1, open: false, newMail: true))
        #expect(due(after: AutoPace.settle, open: false, newMail: true))
        #expect(!due(after: 60, open: false))
    }
}
