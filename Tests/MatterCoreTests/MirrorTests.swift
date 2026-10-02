import Foundation
import Testing
@testable import MatterCore

@Suite("Keeping a task and its reminder in step, field by field")
@MainActor
struct MirrorTests {
    // Text, day, time, done — as the mirror compares them.
    let local = ["Hotel in Lyon buchen", "2026-10-01", "", ""]
    let remote = ["Hotel buchen", "2026-10-01", "", ""]

    @Test("Just connected: each side keeps its own wording, nothing moves")
    func connect() {
        let merge = Mirror.merge(local: local, remote: remote, stamp: nil)
        #expect(!merge.pushed && !merge.pulled && merge.local == local && merge.remote == remote)
    }

    @Test("Ticked off in Reminders: done in Causabee, and Causabee's wording stays")
    func tickedThere() {
        let start = Mirror.merge(local: local, remote: remote, stamp: nil).stamp
        let merge = Mirror.merge(local: local, remote: ["Hotel buchen", "2026-10-01", "", "done"], stamp: start)
        #expect(merge.pulled && !merge.pushed)
        #expect(merge.local == ["Hotel in Lyon buchen", "2026-10-01", "", "done"])
    }

    @Test("Moved in Causabee: the reminder gets the new day, and keeps its own wording")
    func movedHere() {
        let start = Mirror.merge(local: local, remote: remote, stamp: nil).stamp
        let merge = Mirror.merge(local: ["Hotel in Lyon buchen", "2026-10-03", "09:00", ""], remote: remote, stamp: start)
        #expect(merge.pushed && !merge.pulled)
        #expect(merge.remote == ["Hotel buchen", "2026-10-03", "09:00", ""])
    }

    @Test("Changed on both sides: the Reminders side wins for that field; other fields still go across")
    func both() {
        let start = Mirror.merge(local: local, remote: remote, stamp: nil).stamp
        let merge = Mirror.merge(local: ["Hotel in Lyon buchen", "2026-10-05", "", "done"],
                                 remote: ["Hotel buchen", "2026-10-04", "", ""], stamp: start)
        #expect(merge.local == ["Hotel in Lyon buchen", "2026-10-04", "", "done"])
        #expect(merge.remote == ["Hotel buchen", "2026-10-04", "", "done"])
        let again = Mirror.merge(local: merge.local, remote: merge.remote, stamp: merge.stamp)
        #expect(!again.pushed && !again.pulled)
    }
}
