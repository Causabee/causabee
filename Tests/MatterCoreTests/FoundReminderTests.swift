import Testing
@testable import MatterCore

@MainActor @Suite struct FoundReminderTests {
    let reminders = [
        Calendars.Reminder(id: "a", title: "Online-Antrag durchführen", isDone: false, list: "Anschlussfinanzierung"),
        Calendars.Reminder(id: "b", title: "Check-in bei easyJet", isDone: false, list: "Causabee"),
    ]

    @Test func looseOnlyInOwnList() {
        #expect(Calendars.findReminder("Online Check-in bei easyJet durchführen", in: reminders)?.id == "b")
        #expect(Calendars.findReminder("Online Antrag stellen und durchführen", in: [reminders[0]]) == nil)
    }

    @Test func nearlySameElsewhere() {
        #expect(Calendars.findReminder("Online-Antrag durchführen!", in: [reminders[0]])?.id == "a")
    }
}
