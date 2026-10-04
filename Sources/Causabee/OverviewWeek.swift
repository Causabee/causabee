import MatterCore
import SwiftData
import SwiftUI

/// The overview's week on the Mac: the next seven days as a strip — how many things each has, and
/// on today how many are overdue — and under it only the chosen day's things, side by side across
/// the width. Today is chosen at first. A click on a thing opens its matter at it.
struct OverviewWeek: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @State private var chosen: String?
    @State private var showsOverdue = false
    /// How wide the week is: how many of a day's tiles fit side by side.
    @State private var width: CGFloat = 800

    var body: some View {
        let days = Week.days()
        let today = days[0]
        let day = chosen.flatMap { days.contains($0) ? $0 : nil } ?? today
        let things = Week.things(on: day, in: matters)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { each in
                    cell(each, isToday: each == today, isChosen: each == day,
                         count: Week.things(on: each, in: matters).count, late: each == today ? overdue.count : 0)
                }
            }
            SectionHeader(title: day == today ? "Today · " + Self.heading(day) : Self.heading(day),
                          detail: things.isEmpty ? "nothing" : things.count == 1 ? "1 thing" : "\(things.count) things")
            // As high as the chosen day needs: an empty today leaves no hole over the matters. Going
            // to a fuller day, what is under it moves down, and up again, gently.
            dayGrid(day, today: today, isShown: true)
                .id(day)
                .transition(.opacity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// A tile of the day: what is overdue, first on today, or one thing.
    private enum Item {
        case overdue([Todo])
        case thing(DayThing)
        case nothing(String)
    }

    private func dayGrid(_ day: String, today: String, isShown: Bool) -> some View {
        let things = Week.things(on: day, in: matters)
        let late = day == today ? overdue : []
        // A day without anything is one tile too, a column wide, saying what comes next.
        let items = things.isEmpty && late.isEmpty ? [Item.nothing(day)]
            : (late.isEmpty ? [] : [Item.overdue(late)]) + things.map(Item.thing)
        // As many columns as fit at 260 points; in a row, every tile as high as the highest.
        let columns = max(1, Int((width + 8) / 268))
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return Grid(alignment: .topLeading, horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { index in
                        if index < row.count {
                            switch row[index] {
                            case .overdue(let late): overdueTile(late, isShown: isShown)
                            case .thing(let thing): tile(thing)
                            case .nothing(let day): nothing(after: day, isToday: day == today)
                            }
                        } else {
                            Color.clear.frame(height: 0)
                        }
                    }
                }
            }
        }
        // Rows as high as their tiles: the room kept for the fullest day stays empty under them.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ day: String, isToday: Bool, isChosen: Bool, count: Int, late: Int) -> some View {
        let date = MatterStatus.date(of: day) ?? Date()
        return Button { withAnimation(.smooth(duration: 0.3)) { chosen = day } } label: {
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Self.weekday.string(from: date).uppercased()).font(.caption.weight(.semibold))
                        .foregroundStyle(isChosen ? Theme.onInk : .secondary)
                    Text(Self.dayOfMonth.string(from: date)).font(.title3.weight(.semibold))
                        .foregroundStyle(isChosen ? Theme.onInk : .primary)
                }
                // How many things, as every day says it; on today an orange dot while anything is
                // overdue — how many is said once, on the day's first tile.
                HStack(spacing: 4) {
                    if late > 0 { Circle().fill(Theme.warning).frame(width: 6, height: 6) }
                    Text(count == 0 ? "—" : count == 1 ? "1 thing" : "\(count) things")
                        .foregroundStyle(isChosen ? Theme.onInk.opacity(0.8) : .secondary)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isChosen ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.card), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isToday && !isChosen ? Theme.ink : Theme.line, lineWidth: isToday && !isChosen ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(Self.spoken.string(from: date) + (late > 0 ? " — \(late) overdue" : ""))
    }

    private func tile(_ thing: DayThing) -> some View {
        Button { navigation.open(thing.matter, showing: thing.todo?.persistentModelID) } label: {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(Theme.bee).frame(width: 6, height: 6).padding(.top, 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text((thing.time.map { "\($0) · " } ?? "") + thing.what).lineLimit(2)
                    Label(thing.matter.name, systemImage: thing.matter.shownIcon).labelStyle(SmallIconLabel())
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            // Grey and without a line: a task of the day, quieter than the matters' white cards.
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("\(thing.what) — \(thing.matter.name)")
    }

    /// What is overdue in the open matters, the longest first.
    private var overdue: [Todo] {
        matters.filter { !$0.isClosed }.flatMap { MatterStatus($0).overdue }.sorted { ($0.due ?? "") < ($1.due ?? "") }
    }

    /// First on today: how many are overdue — a click lists them, each a door to its task. Only
    /// the day that is shown has the list; the unseen ones only take up room.
    private func overdueTile(_ late: [Todo], isShown: Bool) -> some View {
        Button { showsOverdue = true } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle").font(.caption).padding(.top, 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(late.count) overdue").fontWeight(.semibold)
                    Text("the longest since \(late.first?.due.map(Dates.short) ?? "")").font(.caption)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: isShown ? $showsOverdue : .constant(false), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(late) { todo in
                    Button {
                        showsOverdue = false
                        if let matter = todo.matter { navigation.open(matter, showing: todo.persistentModelID) }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(todo.text).lineLimit(2)
                            Text("since \(todo.due.map(Dates.short) ?? "") · \(todo.matter?.name ?? "")")
                                .font(.caption).foregroundStyle(Theme.warning).lineLimit(1)
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(width: 340)
        }
    }

    /// A day without anything says so, and what comes next — a click is never a dead end.
    private func nothing(after day: String, isToday: Bool) -> some View {
        let next = Week.next(after: day, in: matters)
        return Button {
            if let next { navigation.open(next.thing.matter, showing: next.thing.todo?.persistentModelID) }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(isToday ? "Nothing today." : "Nothing on \(Self.weekdayWide.string(from: MatterStatus.date(of: day) ?? Date())).")
                if let next {
                    Text("Next: \(Self.heading(next.day)) — \((next.thing.time.map { "\($0) · " } ?? "") + next.thing.what) · \(next.thing.matter.name)")
                        .font(.caption).lineLimit(2)
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(next == nil)
    }

    /// "Fri, Oct 2"
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

/// Every other matter going on, one line each, in as many columns as fit: each opens with a click.
struct OverviewRows: View {
    let matters: [Matter]
    let all: [Matter]
    @Environment(Navigation.self) private var navigation

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
            ForEach(matters) { matter in
                Button { navigation.open(matter) } label: {
                    line(matter)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contextMenu { PinMenuItem(matter: matter, all: all) }
            }
        }
    }

    /// The matter's name in the cards' serif, and under it how many are open, the next day and
    /// what is overdue — as the sidebar's row says it.
    private func line(_ matter: Matter) -> some View {
        let status = MatterStatus(matter)
        return HStack(spacing: 10) {
            MatterIconTile(matter: matter, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(matter.name).font(Theme.rowTitleFont).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(matter.openTodos.count) open")
                    if let next = status.next { Text("· next \(Dates.short(next.day))") }
                    if !status.overdue.isEmpty { Text("· \(status.overdue.count) overdue").foregroundStyle(Theme.warning) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// "Pin to Top", or "Unpin": first in the right-click menu of a card, a line or a sidebar row.
struct PinMenuItem: View {
    let matter: Matter
    /// Every matter, to count the pinned ones.
    let all: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if matter.isPinned {
            Button("Unpin") { matter.pinnedAt = nil; try? context.save() }
        } else if !matter.isClosed {
            Button("Pin to Top") {
                // Full: which one it replaces is asked.
                if Pins.pinned(all).count >= Pins.most { navigation.pinning = matter } else { matter.pinnedAt = Date(); try? context.save() }
            }
        }
        MatterIconMenu(matter: matter)
    }
}

/// Which pinned matter makes room, when as many as fit are pinned — as on the iPhone.
struct PinQuestion: ViewModifier {
    let matters: [Matter]
    /// Handed over: the root asks it outside the environment it gives the window.
    let navigation: Navigation
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Pin “\(navigation.pinning?.name ?? "")” instead of …",
                                isPresented: Binding(get: { navigation.pinning != nil }, set: { if !$0 { navigation.pinning = nil } })) {
                ForEach(Pins.pinned(matters)) { pinned in
                    Button(pinned.name) {
                        pinned.pinnedAt = nil
                        navigation.pinning?.pinnedAt = Date()
                        try? context.save()
                        navigation.pinning = nil
                    }
                }
                Button("Cancel", role: .cancel) { navigation.pinning = nil }
            } message: {
                Text("Up to \(Pins.most) matters stay on top of the overview.")
            }
    }
}
