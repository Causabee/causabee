import Foundation
import Testing
@testable import MatterCore

/// F006: the plan's bars — this month's Pro, and the top-ups' in a bar of their own, on the month's scale.
@Suite("F006 · The top-up in the bar")
struct ProMeterTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("F006 AC-1 · Pro and a top-up: two bars, the month's alone and the top-ups'")
    func twoBars() {
        let meter = ProMeter(monthUsed: 0.6, extraShare: 0.667, kind: "apple", renewsOn: "2026-12-01")
        #expect(meter.bars.map(\.kind) == [.month, .topUps])
        #expect(meter.bars[0].number == "40 %" && meter.bars[0].words == "left")
        #expect(meter.bars[1].number == "67 %" && meter.bars[1].words == "of a Pro month in top-ups")
        #expect(meter.bars.allSatisfy { !$0.low })
    }

    @Test("F006 AC-2 · The month is used first: the top-ups' bar waits")
    func monthFirst() {
        let early = ProMeter(monthUsed: 0.2, extraShare: 0.333, kind: "apple", renewsOn: "2026-12-01")
        let later = ProMeter(monthUsed: 0.7, extraShare: 0.333, kind: "apple", renewsOn: "2026-12-01")
        #expect(early.bars[1].left == later.bars[1].left)
        #expect(later.bars[0].left < early.bars[0].left)
        let used = ProMeter(monthUsed: 1, extraShare: 0.2, kind: "apple", renewsOn: "2026-12-01")
        #expect(used.bars[0].number == "0 %" && used.bars[1].number == "20 %")
        #expect(used.inUse == .topUps && early.inUse == .month)
    }

    @Test("F006 AC-3 · A new month: the month full again, the top-up where it was, and the line says it carries over")
    func carriesOver() {
        let last = ProMeter(monthUsed: 1, extraShare: 0.25, kind: "apple", renewsOn: "2026-12-01")
        let first = ProMeter(monthUsed: 0, extraShare: 0.25, kind: "apple", renewsOn: "2027-01-01")
        #expect(first.bars[0].length == 1 && first.bars[1].left == last.bars[1].left)
        #expect(last.line == "Starts anew on 1 December · top-ups carry over")
        #expect(ProMeter(monthUsed: 0.5, extraShare: 0, kind: "apple", renewsOn: "2026-12-01").line == "Starts anew on 1 December")
    }

    @Test("F006 AC-4 · Top-ups add up on the month's scale, the number past 100 %")
    func addUp() {
        let one = ProMeter(monthUsed: 0, extraShare: 0.333, kind: "apple", renewsOn: nil).bars[1]
        let two = ProMeter(monthUsed: 0, extraShare: 0.667, kind: "apple", renewsOn: nil).bars[1]
        let four = ProMeter(monthUsed: 0, extraShare: 1.333, kind: "credit", renewsOn: nil).bars[0]
        #expect(abs(one.length - 1.0 / 3) < 0.01 && abs(two.length - 2.0 / 3) < 0.01)
        #expect(four.length == 1 && four.number == "133 %")
    }

    @Test("F006 AC-5 · Top-ups alone: only their bar")
    func topUpsAlone() {
        let meter = ProMeter(monthUsed: nil, extraShare: 0.333, kind: "credit", renewsOn: nil)
        #expect(meter.bars.map(\.kind) == [.topUps] && meter.bars[0].number == "33 %")
        #expect(meter.line == "Top-ups carry over from month to month.")
        let used = ProMeter(monthUsed: nil, extraShare: 0, kind: "credit", renewsOn: nil)
        #expect(used.bars.map(\.kind) == [.topUps])
        #expect(used.note == "Used. Apple's model on this device reads what comes in — or buy another top-up.")
        // An account the server has not answered for: no bar, as today.
        #expect(ProMeter(monthUsed: nil, extraShare: 0, kind: "hand", renewsOn: nil).bars.isEmpty)
    }

    @Test("F006 AC-6 · No top-up left: the month's bar alone, its note as today")
    func monthAlone() {
        let meter = ProMeter(monthUsed: 0.3, extraShare: 0, kind: "apple", renewsOn: "2026-12-01")
        #expect(meter.bars.map(\.kind) == [.month] && meter.note == nil)
        let used = ProMeter(monthUsed: 1, extraShare: 0, kind: "apple", renewsOn: "2026-12-01")
        #expect(used.note == "Used for this month. Causabee goes on with Apple's model on this device until it starts anew — or with a top-up.")
        #expect(ProMeter(monthUsed: 1, extraShare: 0.1, kind: "apple", renewsOn: nil).note == nil)
    }

    @Test("F006 AC-7 · Running low: the bar in use turns, the other keeps its colour")
    func runsLow() {
        let month = ProMeter(monthUsed: 0.9, extraShare: 0.05, kind: "apple", renewsOn: nil)
        #expect(month.runsLow && month.bars.map(\.low) == [true, false])
        let topUps = ProMeter(monthUsed: 1, extraShare: 0.15, kind: "apple", renewsOn: nil)
        #expect(topUps.runsLow && topUps.bars.map(\.low) == [false, true])
        #expect(!ProMeter(monthUsed: 0.9, extraShare: 0.333, kind: "apple", renewsOn: nil).runsLow)
        #expect(ProMeter(monthUsed: nil, extraShare: 0.1, kind: "credit", renewsOn: nil).bars[0].low)
    }

    @Test("F006 AC-8 · VoiceOver reads each bar on its own")
    func readAloud() {
        let meter = ProMeter(monthUsed: 0.6, extraShare: 0.667, kind: "apple", renewsOn: nil)
        #expect(meter.bars.map(\.spoken) == ["This month's Pro: 40 percent left", "Top-ups: 67 percent of a Pro month left"])
    }

    @Test("F006 AC-9 · With Pro the top-up is added, not for this month")
    func addATopUp() throws {
        let sheet = try String(contentsOf: Self.root.appendingPathComponent("Sources/Causabee/PlanSheet.swift"), encoding: .utf8)
        #expect(!sheet.contains("Top up this month"))
        #expect(sheet.contains("\"Add a top-up\""))
        #expect(sheet.contains("Adds a third of a month's Pro use, kept until it is used."))
        // The bar draws the meter, the colour is its own.
        let bar = try String(contentsOf: Self.root.appendingPathComponent("Sources/Causabee/BeeServer.swift"), encoding: .utf8)
        #expect(bar.contains("ProMeter(") && bar.contains("Theme.topUp"))
    }
}
