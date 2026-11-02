import Testing
@testable import MatterCore

struct ReachTests {
    @Test func aKeyOrProOnReachesEverything() {
        #expect(Reach.of(asks: true, holdsPro: false, usedUp: false, onDevice: false) == .pro)
        #expect(Reach.of(asks: true, holdsPro: true, usedUp: true, onDevice: true) == .pro)
        #expect(Reach.pro.line(mails: 12) == nil)
    }

    @Test func proHeldButNotAtWork() {
        #expect(Reach.of(asks: false, holdsPro: true, usedUp: false, onDevice: true) == .proOff)
        #expect(Reach.of(asks: false, holdsPro: true, usedUp: true, onDevice: true) == .proUsedUp)
        #expect(Reach.proOff.line(mails: 12)?.action == .turnOn)
        #expect(Reach.proUsedUp.line(mails: 12, anew: "28 November")?.words == "This month's Pro starts anew on 28 November.")
        #expect(Reach.proUsedUp.line(mails: 12)?.action == .topUp)
    }

    @Test func aQuestionBeyondOneMatterIsCounted() {
        #expect(DeviceWriter.weekWords(tasks: 4, dates: 1) == "This week you have 4 tasks and 1 date. For more, ask in a matter: on this device I see one at a time.")
    }

    @Test func anAnswerHasNoTaskIDs() {
        let page = DeviceWriter.Page(text: "T1 Call the bank\nT2 Sign (only after T1)", language: nil)
        #expect(DeviceWriter.plain(page) == "Call the bank\nSign (waits for another task)")
    }

    @Test func withoutProTheDeviceDecides() {
        #expect(Reach.of(asks: false, holdsPro: false, usedUp: false, onDevice: true) == .device)
        #expect(Reach.of(asks: false, holdsPro: false, usedUp: false, onDevice: false) == .rules)
        #expect(Reach.device.line(mails: 12)?.words == "Pro reads all 12 mails for this.")
        #expect(Reach.device.line(mails: 1)?.words == "Pro reads every mail for this.")
        #expect(Reach.rules.line(mails: 12)?.action == .seePro)
    }
}
