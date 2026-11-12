import Foundation
import Testing
@testable import MatterCore

/// Fix, 12 November 2026: the owner's iPhone said "Causabee Pro" five days after Pro ended there
/// (7 November), while the beeserver and the Mac said it had ended. The iCloud copy of the purchase
/// counts a week past its end, for a device that has not seen the renewal — but the iPhone had: its
/// own App Store knew the end. Against F007 AC-2: the page says what is bought.
@Suite("The plan held: the App Store's word first, iCloud's week only where it has none")
struct PlanHeldTests {
    static func day(_ text: String) -> Date { MatterStatus.date(of: text)! }
    static let ended = day("2026-11-07"), now = day("2026-11-12")

    @Test("The device that saw Pro end says it ended, not Pro for another week")
    func buyingDevice() {
        #expect(Plan.held(bought: .free, shared: .pro, sharedUntil: Self.ended, ownEnd: Self.ended, now: Self.now) == .free)
    }

    @Test("A device with no word from the App Store keeps iCloud's week")
    func otherDevice() {
        #expect(Plan.held(bought: .free, shared: .pro, sharedUntil: Self.ended, ownEnd: nil, now: Self.now) == .pro)
        #expect(Plan.held(bought: .free, shared: .pro, sharedUntil: Self.ended, ownEnd: nil, now: Self.day("2026-11-15")) == .free)
    }

    @Test("Renewed elsewhere, later than this device last saw: iCloud's copy counts")
    func renewedElsewhere() {
        #expect(Plan.held(bought: .free, shared: .pro, sharedUntil: Self.day("2026-12-07"), ownEnd: Self.ended, now: Self.now) == .pro)
    }

    @Test("What is bought here always counts")
    func boughtHere() {
        #expect(Plan.held(bought: .pro, shared: .free, sharedUntil: nil, ownEnd: Self.ended, now: Self.now) == .pro)
        #expect(Plan.held(bought: .matters, shared: .pro, sharedUntil: Self.ended, ownEnd: Self.ended, now: Self.now) == .matters)
    }
}
