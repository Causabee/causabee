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

@Suite("One event or reminder connected to several: one of them is kept in step")
@MainActor
struct MirrorSharedTests {
    // As on the iPhone on 30 October: two test appointments in two matters, both connected to one event.
    let a = ["Causabee test session — ends at 11:45 am", "2026-10-30", "10:00", ""]
    let b = ["Test session", "2026-10-30", "10:15", ""]

    /// One sync of both against the event: how many writes it made.
    func sync(_ kept: Set<Int>, event: inout [String], stamps: inout [String: String]) -> Int {
        var writes = 0
        for (key, local) in [(1, a), (2, b)] where kept.contains(key) {
            let merge = Mirror.merge(local: local, remote: event, stamp: stamps["e"])
            if merge.pushed { event = merge.remote; writes += 1 }
            stamps["e"] = merge.stamp
        }
        return writes
    }

    @Test("Both kept in step, as before: each sync writes the event twice, without end")
    func bothWrite() {
        var event = b, stamps = ["e": Mirror.merge(local: b, remote: b, stamp: nil).stamp]
        #expect(sync([1, 2], event: &event, stamps: &stamps) == 2)
        #expect(sync([1, 2], event: &event, stamps: &stamps) == 2)
    }

    @Test("One kept — the one in step last time: nothing is written, now or next time")
    func oneWrites() {
        var event = b, stamps = ["e": Mirror.merge(local: b, remote: b, stamp: nil).stamp]
        let items = [(key: 1, id: "e", local: a), (key: 2, id: "e", local: b)]
        let kept = Mirror.oneEach(items, stamp: { stamps[$0] }, remote: { _ in event })
        #expect(kept == [2])
        #expect(sync(kept, event: &event, stamps: &stamps) == 0)
        #expect(sync(Mirror.oneEach(items, stamp: { stamps[$0] }, remote: { _ in event }), event: &event, stamps: &stamps) == 0)
        #expect(event == b)
    }

    @Test("None in step last time: the one Calendar shows, else the first; one connected once is always kept")
    func choice() {
        let items = [(key: 1, id: "e", local: a), (key: 2, id: "e", local: b), (key: 3, id: "f", local: a)]
        #expect(Mirror.oneEach(items, stamp: { _ in nil }, remote: { _ in self.b }) == [2, 3])
        #expect(Mirror.oneEach(items, stamp: { _ in nil }, remote: { _ in nil }) == [1, 3])
        // A deadline knows only what and the day: compared with as much of the event.
        let deadline = [(key: 4, id: "g", local: ["Abgabe", "2026-11-02"]), (key: 5, id: "g", local: ["Termin", "2026-11-02", "09:00", ""])]
        #expect(Mirror.oneEach(deadline, stamp: { _ in nil }, remote: { _ in ["Abgabe", "2026-11-02", "", ""] }) == [4])
    }
}
