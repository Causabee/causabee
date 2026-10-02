#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import EventKit
import MatterCore
import SwiftUI

/// The sign beside an appointment, a deadline or a task: connected to the owner's Calendar or
/// Reminders, found there and to connect, or not there and to add — on a click, never by itself.
struct CalendarChip: View {
    enum Kind { case event, reminder }
    let kind: Kind
    let linkedID: String?
    let title: String
    var day: String? = nil
    var time: String? = nil
    var place: String? = nil
    var note: String? = nil
    let matterName: String
    var reminders: [Calendars.Reminder] = []
    /// Changes when the calendars change, so what is shown is found again.
    var tick = 0
    let connect: (String?) -> Void
    @State private var error: String?

    private var calendars: Calendars { Calendars.shared }
    private var allowed: Bool { kind == .event ? calendars.canReadEvents : calendars.canReadReminders }
    private var where_: String { kind == .event ? "Calendar" : "Reminders" }

    @Environment(\.reading) private var reading

    var body: some View {
        // While reading, only a connection that is there is shown, not the offer to make one.
        if allowed, !(reading && linkedID == nil) {
            HStack(spacing: 6) {
                if let id = linkedID {
                    if let found = linked(id) {
                        Button { open(id) } label: {
                            Label("in \(where_)" + (found.isEmpty ? "" : " · \(found)"), systemImage: kind == .event ? "calendar.badge.checkmark" : "checklist.checked")
                                .font(.caption).foregroundStyle(Theme.done)
                        }
                        .buttonStyle(.plain)
                        .help("Connected and kept in step. Click to open it in \(where_).")
                        .contextMenu { Button("Open in \(where_)") { open(id) }; Button("Disconnect") { connect(nil) } }
                    } else {
                        Label("no longer in \(where_)", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warning)
                        Button("Add again", action: add).buttonStyle(.gold).font(.caption)
                        Button("Disconnect") { connect(nil) }.buttonStyle(.gold).font(.caption)
                    }
                } else if let match = found() {
                    // Which list or calendar it is in, first: a connection to the wrong one is seen before it is made.
                    Label("found in \(match.list.isEmpty ? where_ : match.list): \(match.title)", systemImage: "link")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button("Connect") { connect(match.id) }.buttonStyle(.gold).font(.caption)
                        .help("It is there already: connect to it instead of adding a second one.")
                } else {
                    Button(action: add) { Label("Add to \(where_)", systemImage: "plus") }
                        .buttonStyle(.gold).font(.caption)
                        .help(kind == .event ? "Into the calendar chosen in Settings" : "Into the list chosen in Settings")
                }
                if let error { Text(error).font(.caption).foregroundStyle(Theme.warning).lineLimit(1) }
            }
            .id(tick)
        }
    }

    /// Calendar at that event, Reminders at that reminder — the one door out, on a click.
    private func open(_ id: String) {
        #if canImport(AppKit)
        switch kind {
        case .event:
            guard let event = calendars.event(id) else { return }
            let local = event.eventIdentifier ?? ""
            if let url = URL(string: "ical://ekevent/\(local)?method=show&options=more"), NSWorkspace.shared.open(url) { return }
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        case .reminder:
            guard let reminder = calendars.reminder(id) else { return }
            if let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"), NSWorkspace.shared.open(url) { return }
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
        }
        #else
        // The iPhone's Calendar opens at the event's day; Reminders at the reminder.
        switch kind {
        case .event:
            guard let event = calendars.event(id), let start = event.startDate,
                  let url = URL(string: "calshow:\(start.timeIntervalSinceReferenceDate)") else { return }
            UIApplication.shared.open(url)
        case .reminder:
            guard let reminder = calendars.reminder(id),
                  let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)") else { return }
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// What the connected entry is called now, or nil when it is gone.
    private func linked(_ id: String) -> String? {
        switch kind {
        case .event: return calendars.event(id).map { $0.calendar?.title ?? "" }
        case .reminder:
            if let reminder = reminders.first(where: { $0.id == id }) { return reminder.list + (reminder.isDone ? " · done" : "") }
            return calendars.reminder(id).map { $0.calendar?.title ?? "" }
        }
    }

    private func found() -> (id: String, title: String, list: String)? {
        switch kind {
        case .event:
            guard let day, let event = calendars.findEvent(day: day, time: time, what: title) else { return nil }
            return (event.calendarItemExternalIdentifier, event.title ?? "", event.calendar?.title ?? "")
        case .reminder:
            return Calendars.findReminder(title, in: reminders, ownLists: calendars.ownLists).map { ($0.id, $0.title, $0.list) }
        }
    }

    private func add() {
        do {
            let id = kind == .event
                ? try calendars.addEvent(what: title, day: day ?? "", time: time, place: place, matter: matterName)
                : try calendars.addReminder(text: title, due: day, time: time, note: note, matter: matterName)
            error = nil
            connect(id)
        } catch {
            self.error = "Not added: \(error.localizedDescription)"
        }
    }
}

/// Once, where the dates are: Causabee asks to read the calendars and reminders only on a click.
struct CalendarAccessBanner: View {
    let done: () -> Void
    @State private var asking = false

    var body: some View {
        if !Calendars.shared.asked {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Calendar and Reminders").font(.callout.weight(.semibold))
                    #if os(iOS)
                    Text("To see which appointments and tasks are there already — nothing is added unless you tap.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    #else
                    Text("To see which appointments and tasks are there already — nothing is added unless you click.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    #endif
                }
                Spacer()
                Button("Connect") {
                    asking = true
                    Task { _ = await Calendars.shared.requestAccess(); asking = false; done() }
                }
                .disabled(asking)
            }
            .padding(12)
            .box()
        }
    }
}

/// ⌘, · where new appointments and tasks go.
struct CalendarSettings: View {
    #if os(iOS)
    static let press = "tap"
    #else
    static let press = "click"
    #endif
    @AppStorage(Calendars.calendarKey) private var calendar = ""
    @AppStorage(Calendars.listKey) private var list = ""
    @State private var tick = 0

    var body: some View {
        let store = Calendars.shared.store
        if Calendars.shared.canReadEvents || Calendars.shared.canReadReminders {
            if Calendars.shared.canReadEvents {
                Picker("Add appointments to", selection: $calendar) {
                    Text("“Causabee” (made when first needed)").tag("")
                    ForEach(store.calendars(for: .event).filter(\.allowsContentModifications), id: \.calendarIdentifier) {
                        Text("\($0.title) · \($0.source?.title ?? "")").tag($0.calendarIdentifier)
                    }
                }
            }
            if Calendars.shared.canReadReminders {
                Picker("Add tasks to", selection: $list) {
                    Text("“Causabee” (made when first needed)").tag("")
                    ForEach(store.calendars(for: .reminder).filter(\.allowsContentModifications), id: \.calendarIdentifier) {
                        Text("\($0.title) · \($0.source?.title ?? "")").tag($0.calendarIdentifier)
                    }
                }
            }
        } else {
            HStack {
                #if os(iOS)
                let settings = "Settings → Privacy & Security → Calendars / Reminders"
                #else
                let settings = "System Settings → Privacy & Security → Calendars / Reminders"
                #endif
                Text(Calendars.shared.asked ? "No access. Allow it in \(settings)." : "Not connected yet.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !Calendars.shared.asked {
                    Button("Connect") { Task { _ = await Calendars.shared.requestAccess(); tick += 1 } }
                }
            }
            .id(tick)
        }
        if let at = MirrorRunner.shared.lastAt, let last = MirrorRunner.shared.last {
            Text("Last kept in step at \(at.formatted(date: .omitted, time: .shortened)): \(last.pulled) taken in, \(last.pushed) written out.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Text("Causabee reads your calendars and reminders to show what is there already. It adds only when you \(Self.press) “Add”. What is connected is kept in step both ways: ticked off, moved, renamed.")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
