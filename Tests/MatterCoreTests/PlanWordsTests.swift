import Foundation
import Testing
@testable import MatterCore

/// F007: what you have and whether you use it — the row, the page, the switch, on every device.
@Suite("F007 · Plan and usage, the same on every device")
struct PlanWordsTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
    static func day(_ text: String) -> Date { MatterStatus.date(of: text)! }

    /// Pro with 41 % used and a third of a month in top-ups, unless said otherwise.
    static func words(plan: Plan = .pro, used: Double? = 0.41, extra: Double = 0.33, credit: Bool? = nil, on: Bool = true,
                      renewal: PlanWords.Renewal? = nil, ended: Date? = nil, counted: Bool = true, wait: ProWait = .none) -> PlanWords {
        let meter = ProMeter(monthUsed: used, extraShare: extra, kind: "apple", renewsOn: "2026-11-28", pro: plan == .pro, inUse: on, counted: counted)
        return PlanWords(plan: plan, renewal: renewal, proEnded: ended, meter: meter, credit: credit ?? (extra > 0), useOn: on, wait: wait,
                         reader: "GPT-6.1 Sol", now: day("2026-11-12"))
    }

    @Test("F007 AC-1 · One row says the plan in one line")
    func row() throws {
        #expect(Self.words().row == "Causabee Pro · 59 % left · 33 % in top-ups")
        #expect(Self.words(extra: 0).row == "Causabee Pro · 59 % left")
        #expect(Self.words(plan: .free, used: 1, extra: 0.37).row == "Causabee · 37 % in top-ups")
        #expect(Self.words(plan: .matters, used: nil, extra: 0.37).row == "Causabee Plus · 37 % in top-ups")
        #expect(Self.words(plan: .free, used: nil, extra: 0, on: false).row == "Causabee · Free")
        #expect(Self.words(plan: .matters, used: nil, extra: 0, on: false).row == "Causabee Plus")
        #expect(Self.words(used: 1, extra: 0).row == "Causabee Pro · used for this month")
        // At the top of Settings on the iPhone and the iPad, before Mail; a pane of its own on the Mac.
        let phone = try Self.source("Sources/CausabeePhone/SettingsSheet.swift")
        let rows = try #require(phone.range(of: "PlanUsageRows()")), mail = try #require(phone.range(of: "Text(\"Mail\")"))
        #expect(rows.lowerBound < mail.lowerBound)
        #expect(!phone.contains("                PlanSettings()"))
        let mac = try Self.source("Sources/Causabee/ModelChoice.swift")
        #expect(mac.contains("TabView") && mac.contains("Label(\"Plan\"") && mac.contains("Label(\"General\""))
    }

    @Test("F007 AC-2 · The page's name and corner say what is bought")
    func corner() {
        #expect(Self.words(plan: .free, used: nil, extra: 0).name == "Causabee")
        #expect(Self.words(plan: .free, used: nil, extra: 0).corner == "Free")
        #expect(Self.words(plan: .matters, renewal: .renews(Self.day("2026-11-14"))).corner == "renews 14 November")
        #expect(Self.words(renewal: .renews(Self.day("2026-11-28"))).corner == "renews 28 November")
        #expect(Self.words(renewal: .ends(Self.day("2026-11-28"))).corner == "ends 28 November")
        #expect(Self.words(renewal: .billingProblem(nil)).corner == "payment problem")
        // Pro ended, top-ups left: the corner says why the plan is Free.
        #expect(Self.words(plan: .free, used: 1, extra: 0.37, ended: Self.day("2026-11-07")).corner == "Pro ended 7 November")
        // Ended and nothing left: Free, as it is.
        #expect(Self.words(plan: .free, used: nil, extra: 0, ended: Self.day("2026-11-07")).corner == "Free")
    }

    @Test("F007 AC-3 · Pro or top-ups: a bar, empty until counted")
    func uncounted() {
        let meter = ProMeter(monthUsed: nil, extraShare: 0, kind: "hand", renewsOn: nil, pro: true, counted: false)
        #expect(meter.bars.count == 1 && meter.bars[0].number == "–" && meter.bars[0].words == "not counted yet")
        #expect(meter.line == "Shown once Causabee reaches its server." && !meter.runsLow)
        #expect(Self.words(used: nil, extra: 0, counted: false).row == "Causabee Pro · not counted yet")
        // A top-up known, not counted yet: its bar, empty.
        let topUps = ProMeter(monthUsed: nil, extraShare: 0, kind: "credit", renewsOn: nil, pro: false, counted: false)
        #expect(topUps.bars.map(\.kind) == [.topUps] && topUps.bars[0].number == "–")
        // Nothing bought: no bar, counted or not.
        #expect(ProMeter(monthUsed: nil, extraShare: 0, kind: "hand", renewsOn: nil, pro: false, counted: false).bars.isEmpty)
    }

    @Test("F007 AC-4 · Off keeps the plan and greys the bars")
    func off() {
        let off = ProMeter(monthUsed: 0.41, extraShare: 0.33, kind: "apple", renewsOn: "2026-11-28", pro: true, inUse: false)
        #expect(off.bars.map(\.number) == ["59 %", "33 %"])
        #expect(off.bars.map(\.words) == ["left · not in use", "of a Pro month in top-ups · not in use"])
        #expect(off.bars.allSatisfy { !$0.inUse })
        #expect(off.bars[0].spoken == "This month's Pro: 59 percent left, not in use")
        let words = Self.words(on: false)
        #expect(words.row == "Causabee Pro · 59 % left · 33 % in top-ups · not in use")
        #expect(words.switchLine == "Off: Apple's model on this device reads what comes in. Nothing leaves it.")
        #expect(words.name == "Causabee Pro" && !words.switchShownOn)
        #expect(Self.words().switchLine == "GPT-6.1 Sol reads what comes in, as it comes, names disguised first.")
    }

    @Test("F007 AC-5 · Nothing to use: the switch leads to the plans")
    func nothingToUse() throws {
        let free = Self.words(plan: .free, used: nil, extra: 0, on: true)
        #expect(!free.canUse && !free.switchShownOn)
        #expect(free.switchLine == "Needs Pro or a top-up.")
        let store = try Self.source("Sources/Causabee/Store.swift")
        #expect(store.contains("asks = .pro"))
    }

    @Test("F007 AC-6 · A top-up from the page, whatever the plan")
    func topUp() {
        #expect(Self.words().topUp == "Add a top-up" && !Self.words().seesPlans)
        #expect(Self.words(plan: .matters, used: nil, extra: 0).topUp == "Pro, now and then")
        let freeWithTopUps = Self.words(plan: .free, used: 1, extra: 0.37)
        #expect(freeWithTopUps.topUp == "Pro, now and then" && !freeWithTopUps.seesPlans)
        let nothing = Self.words(plan: .free, used: nil, extra: 0)
        #expect(nothing.topUp == nil && nothing.seesPlans)
    }

    @Test("F007 AC-7 · Used up or ended, the switch waits and nothing is sent")
    func waits() throws {
        let used = ProWait.after("allowance_used", renewsOn: "2026-11-28")
        #expect(used.holds(now: Self.day("2026-11-20")) && !used.holds(now: Self.day("2026-11-29")))
        #expect(used.over(monthUsed: 0.2, extraShare: 0) && used.over(monthUsed: 1, extraShare: 0.33) && !used.over(monthUsed: 1, extraShare: 0))
        let ended = ProWait.after("subscription_ended", renewsOn: "2026-11-28")
        #expect(ended.holds(now: Self.day("2027-01-01")))
        // An ended Pro still counts a month on the server: only a top-up ends its wait.
        #expect(!ended.over(monthUsed: 0.2, extraShare: 0) && ended.over(monthUsed: 0.2, extraShare: 0.33))
        let waiting = Self.words(used: 1, extra: 0, wait: used)
        #expect(waiting.switchShownOn && waiting.switchLine == "On, waiting: nothing left to use until 28 November.")
        #expect(Self.words(plan: .free, used: nil, extra: 0, wait: ended).switchLine == "On, waiting: Pro has ended. A top-up goes on at once.")
        // The switch is no longer turned off by itself; while it waits, nothing is sent.
        let bee = try Self.source("Sources/Causabee/BeeServer.swift")
        #expect(!bee.contains("UserDefaults.standard.set(false, forKey: AutoMode.key)"))
        #expect(bee.contains("ProWait.after("))
        let theme = try Self.source("Sources/Causabee/Theme.swift")
        #expect(theme.contains("ProWait.stored.holds("))
    }

    @Test("F007 AC-8 · The same words wherever Pro is used or stopped")
    func sameWords() throws {
        for path in ["Sources/Causabee/Components.swift", "Sources/CausabeePhone/Parts.swift", "Sources/Causabee/ChatAdding.swift",
                     "Sources/Causabee/ModelChoice.swift", "Sources/Causabee/PlanSheet.swift", "Sources/MatterCore/Model/DeviceTask.swift",
                     "Sources/Causabee/BeeServer.swift"] {
            let text = try Self.source(path)
            for old in ["\"Turn on Pro", "\"Turn off Pro\"", "\"Start Pro\"", "\"Turn Pro On\"", "\"Pro on\"", "\"Pro off\"", "Start Pro on top", "so Pro is off"] {
                #expect(!text.contains(old), "\(path) still says \(old)")
            }
        }
        let bee = try Self.source("Sources/Causabee/Components.swift"), phone = try Self.source("Sources/CausabeePhone/Parts.swift")
        for text in [bee, phone] {
            #expect(text.contains("\"Use Pro\"") && text.contains("\"Stop using Pro\"") && text.contains("\"Using Pro\""))
        }
        #expect(try Self.source("Sources/Causabee/ModelChoice.swift").contains("\"Use Pro?\""))
    }

    @Test("F007 AC-9 · A top-up bought is used, and ends the wait")
    func topUpBought() throws {
        let store = try Self.source("Sources/Causabee/Store.swift")
        #expect(store.contains("UserDefaults.standard.set(true, forKey: AutoMode.key)"))
        #expect(store.contains("ProWait.clear()"))
    }

    @Test("F007 AC-10 · The same words on every device")
    func everyDevice() throws {
        // One page and one set of words for the Mac, the iPhone and the iPad.
        let page = try Self.source("Sources/Causabee/PlanSheet.swift")
        #expect(page.contains("PlanWords(") && page.contains("struct PlanUsageRows"))
        #expect(!page.contains("#if os(macOS)\n                    Text(\"Use Pro\")"))
    }
}
