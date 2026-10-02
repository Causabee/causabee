import MatterCore
import SwiftData
import SwiftUI

/// The overview's week (Figma "Overview with many matters", 3 + 4): the next seven days across
/// all matters, a dot for each thing on a day — orange on today while anything is overdue — and
/// under it the chosen day's things, each a door into its matter. Today is chosen at first.
struct PhoneWeek: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @State private var chosen: String?

    var body: some View {
        let days = Week.days()
        let today = days[0]
        let day = chosen.flatMap { days.contains($0) ? $0 : nil } ?? today
        let late = matters.contains { !$0.isClosed && !MatterStatus($0).overdue.isEmpty }
        let things = Week.things(on: day, in: matters)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { each in
                    cell(each, isToday: each == today, isChosen: each == day,
                         count: Week.things(on: each, in: matters).count, late: each == today && late)
                }
            }
            SectionHeader(title: day == today ? "Today · " + Self.heading(day) : Self.heading(day),
                          detail: things.isEmpty ? "nothing" : things.count == 1 ? "1 thing" : "\(things.count) things")
                .padding(.top, 4)
            if things.isEmpty {
                nothing(on: day, isToday: day == today)
            } else {
                list(things)
            }
        }
    }

    private func cell(_ day: String, isToday: Bool, isChosen: Bool, count: Int, late: Bool) -> some View {
        let date = MatterStatus.date(of: day) ?? Date()
        return Button { chosen = day } label: {
            VStack(spacing: 3) {
                Text(Self.weekday.string(from: date).uppercased()).font(.caption2.weight(.medium))
                    .foregroundStyle(isChosen ? Theme.onInk : .secondary)
                Text(Self.dayOfMonth.string(from: date)).font(.body.weight(.medium))
                    .foregroundStyle(isChosen ? Theme.onInk : .primary)
                // A dot a thing, three at most; the orange one first, for what is overdue.
                HStack(spacing: 3) {
                    if late { Circle().fill(Theme.warning).frame(width: 5, height: 5) }
                    ForEach(0..<min(count, late ? 2 : 3), id: \.self) { _ in
                        Circle().fill(Theme.bee).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isChosen ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.card), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isToday && !isChosen ? Theme.ink : Theme.line, lineWidth: isToday && !isChosen ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.spoken.string(from: date) + (count == 0 ? ", nothing" : count == 1 ? ", 1 thing" : ", \(count) things"))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func list(_ things: [DayThing]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(things.enumerated()), id: \.offset) { index, thing in
                if index > 0 { Divider().padding(.leading, 30) }
                Button { navigation.open(thing.matter, showing: thing.todo?.persistentModelID) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Theme.bee).frame(width: 6, height: 6).padding(.top, 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((thing.time.map { "\($0) · " } ?? "") + thing.what)
                                .font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(thing.matter.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .phoneCard()
    }

    /// A day without anything says so, and what comes next — a tap is never a dead end.
    private func nothing(on day: String, isToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isToday ? "Nothing today." : "Nothing on \(Self.weekdayWide.string(from: MatterStatus.date(of: day) ?? Date())).")
                .font(.subheadline).foregroundStyle(.secondary)
            if let next = Week.next(after: day, in: matters) {
                Button { navigation.open(next.thing.matter, showing: next.thing.todo?.persistentModelID) } label: {
                    Text("Next: \(Self.heading(next.day)) — \((next.thing.time.map { "\($0) · " } ?? "") + next.thing.what) · \(next.thing.matter.name)")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .phoneCard()
    }

    /// "Thu, Oct 8"
    static func heading(_ day: String) -> String { MatterStatus.date(of: day).map(dayHeading.string) ?? day }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = format
        return formatter
    }
    private static let weekday = formatter("EEE")
    private static let weekdayWide = formatter("EEEE")
    private static let dayOfMonth = formatter("d")
    private static let dayHeading = formatter("EEE, MMM d")
    private static let spoken = formatter("EEEE, MMMM d")
}
