import MatterCore
import PhotosUI
import SwiftData
import SwiftUI
#if os(iOS)
import VisionKit
#endif

// The matter's page as one journal: white cards on a grey page, what waits for the owner on a
// yellow tile, and everything else only to read. One code for the Mac, the iPhone and the iPad; the
// rows inside — a task, a date, a file — stay each device's own.

extension Theme {
    static let cardGap: CGFloat = 12
    static let cardInset: CGFloat = 20
    /// How far a tile sits inside its card: its corners stay concentric with the card's.
    static let tileInset: CGFloat = 4
    #if os(iOS)
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    /// How far a plan's first line stands down, to read level with its box or mark.
    static let planTop: CGFloat = 2
    #else
    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
    static let planTop: CGFloat = 4
    #endif
    /// The plan's one grid: a day's tile, and beside it what a task is ticked in and a date marked with.
    static let dayTile: CGFloat = 44
    static let planMark: CGFloat = 26
}

extension View {
    /// A card of the journal: white on the page's grey, with no line round it.
    func journalCard(inset: CGFloat = Theme.cardInset) -> some View {
        padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    /// A card of rows, which keep their own room.
    func journalRows() -> some View { journalCard(inset: 0) }

    /// A row of the plan. One line is as high as a day's tile, so that they stand side by side.
    func planRow() -> some View { padding(.leading, 6).padding(.trailing, 6).padding(.vertical, 10) }

    /// A date on the plan: a block of its own, told from a task at a glance. It is not to tick off.
    func planDate() -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// What waits for the owner: yellow, and only that is. Without `forYou`, the same room with no colour.
    func waitingTile(_ forYou: Bool = true, outOfDate: Bool = false) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(outOfDate ? Theme.box : forYou ? Theme.beeSoft : Color.clear, in: RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
    }
}

/// The filters over a journal: words, the open one on a white pill. Only the ones with something
/// behind them are here; on a narrow screen or with large text the row scrolls.
struct JournalPills<Part: Hashable>: View {
    let parts: [Part]
    let label: (Part) -> String
    @Binding var selection: Part
    /// Onto a second line where they do not fit, not scrolled: in a sheet, whose edge hid the rest.
    var wraps = false

    private var row: some View { HStack(spacing: 6) { pills } }

    @ViewBuilder private var pills: some View {
            ForEach(parts, id: \.self) { part in
                let chosen = part == selection
                Button { selection = part } label: {
                    Text(label(part))
                        #if os(iOS)
                        .font(.subheadline)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        #else
                        .font(.callout)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        #endif
                        .foregroundStyle(chosen ? Color.primary : Color.secondary)
                        .background(chosen ? Theme.card : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                        // A finger's room around the pill, on the iPhone: the pill itself stays small.
                        #if os(iOS)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        #endif
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(label(part))
                .accessibilityAddTraits(chosen ? .isSelected : [])
                .accessibilityIdentifier("part." + label(part))
            }
    }

    var body: some View {
        Group {
            if wraps {
                FlowRow(spacing: 4) { pills }
            } else {
                ViewThatFits(in: .horizontal) {
                    row
                    ScrollView(.horizontal, showsIndicators: false) { row }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter")
    }
}

extension JournalPills where Part == Journal.Part {
    init(parts: [Journal.Part], selection: Binding<Journal.Part>) {
        self.init(parts: parts, label: \.label, selection: selection)
    }
}

/// A day's tile: "THU", "1".
struct DayTile: View {
    let day: String
    /// Its month over its number, not its weekday: for a day that need not be this week's.
    var month = false
    /// Gone by with something still to do.
    var late = false

    var body: some View {
        let tile = Journal.tile(day, month: month)
        VStack(spacing: 0) {
            Text(tile.over).font(.caption2.weight(.semibold)).foregroundStyle(late ? Theme.warning : .secondary)
            Text(tile.number).font(.callout.weight(.medium)).monospacedDigit().foregroundStyle(late ? Theme.warning : .primary)
        }
        .frame(width: Theme.dayTile, height: 46)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "Set day": in a task's place for its day while it has none — dashed, as something still to
/// fill. A calendar to pick it from; the task goes to that day in the plan.
struct SetDayTile: View {
    let todo: Todo
    @Environment(\.modelContext) private var context
    @State private var picking = false
    @State private var day = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

    var body: some View {
        Button { picking = true } label: {
            VStack(spacing: 2) {
                Image(systemName: "calendar.badge.plus").font(.footnote)
                Text("Set day").font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.secondary)
            .frame(width: Theme.dayTile, height: 46)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set a day for \(todo.text)")
        #if os(iOS)
        .sheet(isPresented: $picking) { picker.presentationDetents([.medium, .large]) }
        #else
        .popover(isPresented: $picking, arrowEdge: .trailing) { picker.frame(width: 300) }
        #endif
    }

    private func set() {
        withAnimation { todo.due = MatterStatus.day(day) }
        try? context.save()
        picking = false
    }

    private var calendar: some View {
        DatePicker("Day", selection: $day, displayedComponents: .date)
            .datePickerStyle(.graphical).labelsHidden()
            .tint(Theme.gold)
    }

    /// As every sheet of the app: × and ✓ in its bar, the task's name under its title.
    @ViewBuilder private var picker: some View {
        #if os(iOS)
        NavigationStack {
            ScrollView { calendar.padding(.horizontal, 16) }
            .navigationTitle("Set day")
            .navigationSubtitle(todo.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancel { picking = false } }
                ToolbarItem(placement: .confirmationAction) { SheetConfirm("Set", action: set) }
            }
        }
        #else
        VStack(spacing: 12) {
            Text(todo.text).font(.headline).lineLimit(2).multilineTextAlignment(.center)
            calendar
            HStack {
                Button("Cancel") { picking = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Set Day", action: set).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        #endif
    }
}

/// What comes next, on its tile, with what can be done about it under it on the white.
struct NextCard<Head: View, Foot: View>: View {
    /// There is something for the owner to do: yellow. Nothing is: no colour at all.
    let forYou: Bool
    /// The matter has changed since this was written: grey, whatever it says.
    var outOfDate = false
    @ViewBuilder let head: Head
    @ViewBuilder let foot: Foot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) { head }.waitingTile(forYou, outOfDate: outOfDate)
            VStack(alignment: .leading, spacing: 8) { foot }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .journalCard(inset: Theme.tileInset)
    }
}

/// Causabee's step once the matter has changed under it: still there to read, but it says it may
/// no longer hold. Struck through when it is its own task that was done.
struct OutOfDateStep: View {
    let matter: Matter

    var body: some View {
        let done = matter.nextStepTodo.flatMap { origin in (matter.todos ?? []).shown.first { $0.origin == origin } }?.isDone == true
        BeeChip(text: "OUT OF DATE", tone: .quiet)
        Text(matter.nextStep ?? "").font(Theme.rowTitleFont).foregroundStyle(.secondary)
            .strikethrough(done, color: .secondary)
            .fixedSize(horizontal: false, vertical: true)
        Text("Something changed since this was written.").font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The one button that has Causabee write a matter again, wherever that is offered.
struct UpdateNowButton: View {
    var title = Say.updateNow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.box, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("update.now")
    }
}

/// Where something is out of reach here: it says so before it is tried, and what would do it.
/// Never yellow: yellow means something waits for the owner.
struct ProLine: View {
    let reach: Reach
    var mails = 0
    @AppStorage(AutoMode.key) private var auto = false
    @State private var asks = false

    private var anew: String? {
        BeeServer.shared.renewsOn.map { IntakeSummary.day($0) }
    }

    var body: some View {
        if let line = reach.line(mails: mails, anew: anew) {
            HStack(spacing: 6) {
                Image(systemName: "bolt").font(.caption).foregroundStyle(.secondary)
                Text(line.words).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                UpdateNowButton(title: line.action.title) { run(line.action) }
            }
            .asksBeforeAuto($asks) { auto = true }
        }
    }

    private func run(_ action: Reach.Action) {
        switch action {
        case .seePro: Store.shared.asks = .pro
        case .topUp: Store.shared.asks = .choose
        case .turnOn: if AutoMode.asksFirst { asks = true } else { auto = true }
        }
    }
}

/// Under what Auto writes while the matter has changed: when it will, and the button not to wait.
struct AutoWaitLine: View {
    let matter: Matter
    /// What is said while it is being written.
    let writing: String
    private var loader: CGFloat {
        #if os(iOS)
        12
        #else
        10
        #endif
    }

    var body: some View {
        HStack(spacing: 6) {
            if AutoUpdate.shared.working.contains(matter.key) {
                BeeLoader(size: loader)
                Text(writing).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Image(systemName: "clock").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                Text("When you leave").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                UpdateNowButton { AutoUpdate.shared.updateNow(matter) }
            }
        }
    }
}

/// For as long as a page shows the matter, Auto waits for the owner to finish in it.
private struct ShownToAuto: ViewModifier {
    let key: String

    func body(content: Content) -> some View {
        content.task(id: key) {
            AutoUpdate.shared.show(key)
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(3_600)) }
            AutoUpdate.shared.leave(key)
        }
    }
}

extension View {
    func shownToAuto(_ matter: Matter) -> some View { modifier(ShownToAuto(key: matter.key)) }
}

/// What is ahead, in one card, on the plan's grid: the next days, the first tasks with no day yet,
/// and how much more there is. A task's box ticks it; a tap on a task or a date opens its own
/// editor in place — the Digest is where it is corrected, not Plan; a day or the count opens the plan.
/// The week in one sentence, over the week's days on the overview: "This week: 3 things · waiting
/// on 2 · nothing slipping". The calm answer to "have I forgotten something?" — what is overdue and
/// what has no answer said in orange, when there is any.
struct WeekSentence: View {
    let matters: [Matter]
    let now: Date

    var body: some View {
        let today = MatterStatus.day(now)
        let days = Week.days(from: now, count: Planning.daysLeftInWeek(today: today))
        let things = days.reduce(0) { $0 + Week.asTheDayGoes(StoredChanges.shared.things(on: $1, in: matters), on: $1, now: now).ahead.count }
        let theirs = matters.filter { !$0.isClosed }.flatMap(\.openTodos).filter { $0.owner == .other && !$0.isBlocked }
        let unanswered = theirs.filter { Planning.isBack($0, today: today) }.count
        let parts = Planning.week(things: things, waiting: theirs.count - unanswered,
                                  overdue: StoredChanges.shared.overdue(in: matters).count, unanswered: unanswered)
        parts.enumerated().reduce(Text("")) { line, part in
            line + Text(part.offset == 0 ? "" : " · ") + Text(part.element.text).foregroundColor(part.element.warns ? Theme.warning : nil)
        }
        .font(.subheadline).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("week.sentence")
    }
}

/// "When?" in one tap: this week, next week, later — each a day, so the task is a plan.
struct WhenChips: View {
    let set: (Planning.When) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Planning.When.allCases, id: \.self) { when in
                Button(when.label) { set(when) }
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.gold.opacity(0.14), in: Capsule())
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("when.\(when.rawValue)")
            }
        }
    }
}

struct AheadCard: View {
    let plan: Journal.Plan
    let tick: (Todo) -> Void
    let open: () -> Void
    /// How many days it shows: on the Mac and an iPad the page has the room for more.
    var days = 2
    /// A task's or a date's own editor, each device's; without one a tap opens the plan.
    var editor: ((NewItem, @escaping () -> Void) -> AnyView)? = nil
    /// The tasks with no day it shows, the newest first: what was just added wants its day now.
    static let noDay = 3
    @Environment(\.modelContext) private var context

    private func name(_ text: String) -> some View {
        Text(text).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading).padding(.top, Theme.planTop)
    }

    /// What opens the plan, as wide as its row.
    private func opens<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        Button(action: open) { label().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }

    private func date(_ item: NewItem, _ what: String, isDeadline: Bool, hours: String? = nil, place: String? = nil) -> some View {
        EditsInPlace(item: item, editor: editor, otherwise: open) {
            HStack(alignment: .top, spacing: 10) {
                PlanDateMark(isDeadline: isDeadline)
                VStack(alignment: .leading, spacing: 2) {
                    name(what)
                    PlanDateLine(isDeadline: isDeadline, hours: hours, last: nil, place: place).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .planRow()
            .planDate()
        }
    }

    @ViewBuilder
    private func row(_ item: Journal.Plan.Item) -> some View {
        switch item {
        case .task(let todo):
            task(todo)
        case .appointment(let appointment): date(.appointment(appointment), appointment.what, isDeadline: false, hours: appointment.time, place: appointment.place)
        case .deadline(let deadline): date(.deadline(deadline), deadline.what, isDeadline: true)
        }
    }

    private func task(_ todo: Todo, noDay: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PlanTick(todo: todo) { tick(todo) }
            EditsInPlace(item: .task(todo), editor: editor, otherwise: open) {
                VStack(alignment: .leading, spacing: 2) {
                    name(todo.text)
                    if todo.owner == .we { Text("together").font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        }
        .planRow()
    }

    var body: some View {
        let all = plan.stretches.flatMap(\.days)
        let shown = Array(all.prefix(days))
        let items = all.flatMap(\.items)
        let tasks = plan.openCount - items.filter { if case .task = $0 { false } else { true } }.count
        let dates = items.count - items.filter { if case .task = $0 { true } else { false } }.count
        let moreDates = dates - shown.compactMap(\.items.first).filter { if case .task = $0 { false } else { true } }.count
        VStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { day in
                if let item = day.items.first {
                    HStack(alignment: .top, spacing: 6) {
                        // The day is the item's: a tap changes it, in its own editor.
                        EditsInPlace(item: item.newItem, editor: editor, otherwise: open) { DayTile(day: day.day) }
                            .fixedSize()
                            .accessibilityIdentifier("ahead.day")
                        row(item)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                Divider().padding(.horizontal, 12)
            }
            // What has no day yet, the newest first: a tap opens it; When gives it a day.
            if !plan.noDay.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("No day yet").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 12).padding(.top, 10)
                    // The newest first: what was just added is what wants its day now.
                    ForEach(plan.noDay.reversed().prefix(Self.noDay), id: \.persistentModelID) { todo in
                        VStack(alignment: .leading, spacing: 6) {
                            task(todo, noDay: true)
                            // A day in one tap: then it is a plan, and off the mind.
                            WhenChips { when in
                                todo.due = Planning.day(when, today: MatterStatus.day(Date()))
                                try? context.save()
                            }
                            .padding(.leading, 34)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("noDay.row")
                    }
                }
                .padding(.bottom, 4)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ahead.noDay")
                Divider().padding(.horizontal, 12)
            }
            // Someone else's with no answer by its day: back with the owner, once — wait a week more,
            // or tick it when it came after all.
            if !plan.noAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("No answer yet").font(.caption.weight(.semibold)).foregroundStyle(Theme.warning)
                        .textCase(.uppercase)
                        .padding(.horizontal, 12).padding(.top, 10)
                    ForEach(plan.noAnswer.prefix(Self.noDay), id: \.persistentModelID) { todo in
                        VStack(alignment: .leading, spacing: 6) {
                            task(todo)
                            HStack(spacing: 8) {
                                Text("since \(Dates.short(MatterStatus.day(todo.createdAt)))").font(.footnote).foregroundStyle(.secondary)
                                Button("Wait a week") {
                                    Planning.waitAWeek(todo, today: MatterStatus.day(Date()))
                                    try? context.save()
                                }
                                .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
                                .accessibilityIdentifier("noAnswer.wait")
                            }
                            .padding(.leading, 34)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 4)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ahead.noAnswer")
                Divider().padding(.horizontal, 12)
            }
            opens {
                HStack(spacing: 8) {
                    Group {
                        if plan.overdue.isEmpty {
                            Text(Self.left(tasks: tasks, dates: moreDates))
                        } else {
                            Text("\(plan.overdue.count) overdue").foregroundColor(Theme.warning)
                                + Text(" · " + Self.left(tasks: tasks, dates: moreDates))
                        }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ahead")
    }

    /// "7 tasks open · 2 more dates".
    private static func left(tasks: Int, dates: Int) -> String {
        var words = ["\(tasks) \(tasks == 1 ? "task" : "tasks") open"]
        if dates > 0 { words.append("\(dates) more \(dates == 1 ? "date" : "dates")") }
        return words.joined(separator: " · ")
    }
}

/// A task or a date that opens its own editor where it stands: a sheet on the iPhone and the iPad,
/// a popover on the Mac. Without an editor, a tap does what it did before.
extension Journal.Plan.Item {
    /// The same thing, as its editor knows it.
    var newItem: NewItem {
        switch self {
        case .task(let todo): .task(todo)
        case .appointment(let appointment): .appointment(appointment)
        case .deadline(let deadline): .deadline(deadline)
        }
    }
}

struct EditsInPlace<Label: View>: View {
    let item: NewItem
    let editor: ((NewItem, @escaping () -> Void) -> AnyView)?
    let otherwise: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var editing = false

    var body: some View {
        Button { if editor != nil { editing = true } else { otherwise() } } label: {
            label().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .sheet(isPresented: $editing) { editor?(item) { editing = false } }
        #else
        .popover(isPresented: $editing, arrowEdge: .bottom) { editor?(item) { editing = false } }
        #endif
    }
}

/// The three kinds of thing in the one card for what has no date.
enum AtHandRow: Hashable { case summary, details, info }

/// One card for what has no date: the summary with its brief, the numbers to keep, and what mail
/// said that is worth knowing. Folded rows, each only when it has something; one tap opens one.
struct AtHandCard<SummaryFoot: View>: View {
    let matter: Matter
    @Binding var opened: Set<AtHandRow>
    /// A task's words for the assistant, from a line that is worth knowing.
    var talk: (Todo) -> Void = { _ in }
    /// "Update", Auto's line, "Write the brief": each device writes it its own way.
    @ViewBuilder let summaryFoot: SummaryFoot
    @Environment(PageFind.self) private var find
    @Environment(\.modelContext) private var context

    private var summaryLines: [String] { (matter.summary ?? "").split(separator: "\n").map(String.init) }
    private var hasBrief: Bool { matter.shownBrief.map { !$0.lines.isEmpty || !$0.said.isEmpty || !$0.answeredHere.isEmpty } ?? false }

    var body: some View {
        // Drawn again when Auto has written it.
        let _ = AutoUpdate.shared.done
        // Good to know is Pro's: it fills it from the mail. Without Pro there is none to show —
        // the demo shows what Pro would.
        let details = matter.sortedDetails, infos = AutoMode.isOn || DemoData.isRequested ? matter.infos : []
        let written = !summaryLines.isEmpty || hasBrief
        let closedWithout = matter.isClosed && !written
        if !closedWithout || !details.isEmpty || !infos.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if written {
                    fold(.summary, "Summary", count: nil, line: summaryLines.first ?? "The brief · what Causabee understands") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(summaryLines.enumerated()), id: \.offset) { index, line in
                                Text(line).fixedSize(horizontal: false, vertical: true)
                                    .findable(.section("summary-\(index)"), line)
                            }
                            .opacity(AutoUpdate.shared.updating(matter) ? 0.4 : 1)
                            BriefDetails(matter: matter)
                            Divider()
                            summaryFoot
                        }
                    }
                } else if !closedWithout {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary").font(Theme.rowTitleFont)
                        Text("A brief helps Causabee follow this matter as more mail comes.")
                            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        summaryFoot.padding(.top, 4)
                    }
                    .padding(.vertical, 12)
                }
                if !details.isEmpty {
                    if written || !closedWithout { Divider() }
                    fold(.details, "Details", count: details.count, line: details.prefix(3).map(\.label).joined(separator: ", ")) {
                        DetailsSection(matter: matter, embedded: true)
                    }
                }
                if !infos.isEmpty {
                    if written || !closedWithout || !details.isEmpty { Divider() }
                    fold(.info, "Good to know", count: infos.count, line: infos.prefix(2).map(\.text).joined(separator: " · ")) {
                        VStack(alignment: .leading, spacing: 12) {
                            let today = MatterStatus.day(Date())
                            ForEach(infos, id: \.persistentModelID) { todo in
                                InfoLine(todo: todo, outdated: todo.mayBeOutdated(today: today), hide: {
                                    withAnimation { matter.setHidden(.task(todo), true) }
                                    try? context.save()
                                }, talk: { talk(todo) })
                                    .findable(.model(todo.persistentModelID), todo.text)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.cardInset).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .id("details")
        }
    }

    @ViewBuilder
    private func fold<Content: View>(_ row: AtHandRow, _ title: String, count: Int?, line: String, @ViewBuilder content: () -> Content) -> some View {
        let isOpen = opened.contains(row) || find.isActive
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { if opened.remove(row) == nil { opened.insert(row) } }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(Theme.rowTitleFont).foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if let count { Text("\(count)").font(.footnote).foregroundStyle(.secondary) }
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    if !isOpen {
                        Text(line).font(.footnote).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("athand.\(title)")
            .accessibilityValue(isOpen ? "open" : "folded")
            if isOpen { content() }
        }
        .padding(.vertical, 12)
    }
}

/// One thing worth knowing: where it came from, and Hide — at once in sight when its day has
/// passed and it may no longer be true.
struct InfoLine: View {
    let todo: Todo
    var outdated = false
    let hide: () -> Void
    let talk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(todo.text).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(outdated ? .secondary : .primary)
            HStack(spacing: 10) {
                if outdated, let until = todo.holdsUntil {
                    Text("Held until \(Dates.short(until)) · may be outdated").font(.footnote).foregroundStyle(Theme.warning)
                } else {
                    SourceJump(sources: todo.factSources, label: Sources.origin(todo.factSources.first), matter: todo.matter)
                }
                Button("Hide", action: hide).buttonStyle(.gold).font(.footnote)
                    .modifier(ToolUnless(shown: outdated))
                    .help("Not wanted here: it goes, and is not brought back")
                    .accessibilityIdentifier("info.hide")
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(Say.useInChat, systemImage: "bubble.left", action: talk)
            Button("Hide", systemImage: "eye.slash", action: hide)
        }
    }
}

/// A small action put away while reading — but not when it is the one thing to do.
private struct ToolUnless: ViewModifier {
    let shown: Bool
    func body(content: Content) -> some View {
        if shown { content } else { content.tool() }
    }
}

/// A day's heading in the journal.
struct JournalHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 4).padding(.top, 10)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One conversation as one card: who, its subject, what its newest mail says, and how many answers.
/// A tap opens every mail in it, with all they can do; the card stays where it is.
struct JournalThreadCard<Attached: View>: View {
    let thread: MailThreads.Thread
    var links: RecordLinks? = nil
    /// The names of the files that came with it.
    var files: [String] = []
    let isOpen: Bool
    let toggle: () -> Void
    let talk: (Entry) -> Void
    @ViewBuilder let attached: Attached
    @State private var connecting = false

    private var newest: Entry? {
        thread.rows.map(\.entry).max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// "Nina Voss · you": who wrote in it, in the order they first did.
    private var who: String {
        let me = OwnerMe.current
        var names: [String] = []
        for entry in thread.rows.map(\.entry) {
            let name = me.sent(entry.from) ? "you" : entry.matter?.writerName(entry.from) ?? Email.address(in: entry.from)
            if !names.contains(name) { names.append(name) }
        }
        return names.prefix(2).joined(separator: " · ") + (names.count > 2 ? " · +\(names.count - 2)" : "")
    }

    private var unread: Int { thread.rows.filter { $0.entry.isUnread == true }.count }

    /// "NEW", or how many answers are new.
    private var new: String? {
        guard unread > 0 else { return nil }
        return thread.count == 1 ? "NEW" : "\(unread) NEW \(unread == 1 ? "ANSWER" : "ANSWERS")"
    }

    /// "1 mail", "3 answers".
    private var told: String {
        thread.count == 1 ? "1 mail" : "\(thread.count - 1) \(thread.count == 2 ? "answer" : "answers")"
    }

    private var day: String { (thread.last ?? thread.first).map(Dates.short) ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(who).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        if let new { BeeChip(text: new) }
                    }
                    Text(thread.subject.isEmpty ? "(no subject)" : thread.subject)
                        .font(Theme.rowTitleFont).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    if !isOpen, let digest = newest?.digest, !digest.isEmpty {
                        Text(digest)
                            #if os(macOS)
                            .font(.callout)
                            #else
                            .font(.subheadline)
                            #endif
                            .foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !isOpen {
                        ForEach(files.prefix(2), id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "doc").font(.caption).foregroundStyle(.secondary)
                                Text(name).font(.footnote).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("thread.card")
            .accessibilityValue(isOpen ? "open" : "folded")
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    let me = OwnerMe.current
                    let joined = MailThreads.joined(thread.rows, deepest: ThreadMailRow.deepest)
                    ForEach(thread.rows) { row in
                        ThreadMailRow(row: row, started: false, sent: me.sent(row.entry.from), subject: thread.subject,
                                      made: links?.made(from: row.entry) ?? RecordLinks.Made(), joinsNext: joined.contains(row.id)) { talk(row.entry) }
                            .padding(.horizontal, 10)
                            .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                            .padding(.horizontal, -10)
                    }
                    attached
                }
                .padding(.top, 6)
            }
            Divider().padding(.top, 12)
            HStack(spacing: 8) {
                Text(told)
                Spacer(minLength: 8)
                Text(day).monospacedDigit()
            }
            .font(.footnote).foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .journalCard()
        .contextMenu {
            Button(Say.useInChat, systemImage: "bubble.left") { if let newest { talk(newest) } }
            Button(Say.connect, systemImage: "link") { connecting = true }
        }
        .connectSheet(newest.map(JournalItem.mail), in: nil, isPresented: $connecting)
        .dropsOn(newest.map(JournalItem.mail), in: nil)
    }
}

/// Old days, folded into one card: which month, how much it held, and what about.
struct JournalFoldCard: View {
    let fold: Journal.Fold
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(fold.title).font(Theme.rowTitleFont).foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(fold.count).font(.footnote).foregroundStyle(.secondary)
                    Image(systemName: fold.isOpen ? "chevron.up" : "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
                if !fold.about.isEmpty, !fold.isOpen {
                    Text(fold.about).font(.footnote).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                }
            }
            .journalCard(inset: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.fold")
    }
}

/// A note in the journal, on its day. It is changed under Notes.
struct JournalNoteCard: View {
    let note: MatterNote
    let show: () -> Void

    @State private var connecting = false

    var body: some View {
        // A tap on the card shows it under Notes; the chips' own buttons come first.
        VStack(alignment: .leading, spacing: 0) {
            Text(note.text).foregroundStyle(.primary).lineLimit(6).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            ConnectionChips(item: .note(note))
            Divider().padding(.top, 12)
            HStack {
                Text(note.fromAssistant ? "From the assistant" : "Your note")
                Spacer(minLength: 8)
                Text(Dates.short(note.createdAt)).monospacedDigit()
            }
            .font(.footnote).foregroundStyle(.secondary).padding(.top, 10)
        }
        .journalCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: show)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, show)
        .contextMenu {
            Button(Say.connect, systemImage: "link") { connecting = true }
            MoveAndHide(item: .note(note), matter: note.matter)
        }
        .connectSheet(.note(note), in: note.matter, isPresented: $connecting)
        .dropsOn(.note(note), in: note.matter)
    }
}

/// A decision of the matter: what, and why.
struct JournalDecisionCard: View {
    let decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DECISION · \(Dates.short(decision.decidedAt).uppercased())").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(decision.what).font(Theme.rowTitleFont).fixedSize(horizontal: false, vertical: true)
            if !decision.why.isEmpty {
                Text(decision.why).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .journalCard()
        .findable(.model(decision.persistentModelID), decision.what, decision.why)
    }
}

/// What was ticked off that day: one quiet line.
struct JournalDoneLine: View {
    let todo: Todo

    var body: some View {
        if !todo.isDeleted, todo.modelContext != nil {
            Label { Text("Done: " + todo.text).lineLimit(2) } icon: { Image(systemName: "checkmark.circle") }
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

/// The plan: what is left, by when. Dates and tasks stand together, a day at a time; late tasks
/// first, those without a day and other people's under them, what is done and gone by folded.
struct PlanList<TaskRow: View, DateRow: View, Empty: View>: View {
    let plan: Journal.Plan
    @Binding var showsDone: Bool
    @Binding var showsPast: Bool
    /// A task, and whether its row says whose it is.
    @ViewBuilder let task: (Todo, Bool) -> TaskRow
    /// A date, and whether it has gone by.
    @ViewBuilder let date: (Journal.Plan.Item, Bool) -> DateRow
    /// Over the dates: asks for the calendar when it is needed.
    @ViewBuilder let empty: Empty
    /// The day's own item's editor, each device's: a tap on the day of a day with one item changes it.
    var editor: ((NewItem, @escaping () -> Void) -> AnyView)? = nil
    @Environment(PageFind.self) private var find

    /// A day on the plan's grid: its tile, and beside it what is on it. With no day the tile's place
    /// stays empty: what is ticked stands under what is ticked, in every card.
    private func onDay<Rows: View>(_ day: String?, month: Bool = false, late: Bool = false, only: NewItem? = nil, @ViewBuilder rows: () -> Rows) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let day {
                // One thing on the day: its day is its own, and a tap changes it.
                if let only, editor != nil {
                    EditsInPlace(item: only, editor: editor, otherwise: {}) { DayTile(day: day, month: month, late: late) }
                        .fixedSize()
                        .accessibilityIdentifier("plan.day")
                } else {
                    DayTile(day: day, month: month, late: late)
                }
            } else { Color.clear.frame(width: Theme.dayTile, height: 0) }
            VStack(alignment: .leading, spacing: 2) { rows() }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    /// Tasks in a card of their own, a day at a time.
    private func card(_ todos: [Todo], owner: Bool = false, late: Bool = false) -> some View {
        let days = Journal.Plan.days(of: todos) { $0.due }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if index > 0 { Divider().padding(.horizontal, 12) }
                onDay(day.day, month: true, late: late, only: day.things.count == 1 ? .task(day.things[0]) : nil) {
                    ForEach(day.things, id: \.persistentModelID) { task($0, owner) }
                }
            }
        }
        .journalRows()
    }

    private func item(_ item: Journal.Plan.Item) -> some View {
        Group {
            switch item {
            case .task(let todo): task(todo, false)
            default: date(item, false)
            }
        }
    }

    private func folded<Content: View>(_ title: String, open: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(title, isExpanded: Binding(get: { open.wrappedValue || find.isActive }, set: { open.wrappedValue = $0 })) {
            content().padding(.top, 6)
        }
        .font(.footnote).foregroundStyle(.secondary).tint(.secondary)
        .padding(.horizontal, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardGap) {
            if plan.isEmpty { empty }
            if !plan.overdue.isEmpty {
                JournalHeading(title: "OVERDUE")
                card(plan.overdue, owner: true, late: true)
            }
            ForEach(plan.stretches) { stretch in
                JournalHeading(title: stretch.title.uppercased())
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stretch.days.enumerated()), id: \.element.id) { index, day in
                        if index > 0 { Divider().padding(.horizontal, 12) }
                        onDay(day.day, only: day.items.count == 1 ? day.items[0].newItem : nil) {
                            ForEach(day.items) { entry in self.item(entry) }
                        }
                    }
                }
                .journalRows()
            }
            if !plan.noDay.isEmpty {
                JournalHeading(title: "NO DAY YET")
                // A task at a time, each with "Set day" where its day would stand: the empty
                // column was where to give it one.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(plan.noDay.enumerated()), id: \.element.persistentModelID) { index, todo in
                        if index > 0 { Divider().padding(.horizontal, 12) }
                        HStack(alignment: .top, spacing: 6) {
                            SetDayTile(todo: todo)
                            VStack(alignment: .leading, spacing: 2) { task(todo, true) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                }
                .journalRows()
            }
            if !plan.waiting.isEmpty {
                JournalHeading(title: "WAITING FOR OTHERS")
                card(plan.waiting)
            }
            if !plan.blocked.isEmpty {
                JournalHeading(title: "ONLY AFTER")
                card(plan.blocked, owner: true)
            }
            if !plan.done.isEmpty {
                folded("Done · \(plan.done.count)", open: $showsDone) {
                    onDay(nil) { ForEach(plan.done, id: \.persistentModelID) { task($0, false) } }.journalRows()
                }
            }
            if !plan.past.isEmpty {
                folded("Past · \(plan.past.count)", open: $showsPast) {
                    let days = Journal.Plan.days(of: plan.past) { $0.day }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                            if index > 0 { Divider().padding(.horizontal, 12) }
                            onDay(day.day, month: true) {
                                ForEach(day.things) { date($0, true) }
                            }
                        }
                    }
                    .journalRows()
                }
            }
        }
    }
}

/// A task's box. Ticked by hand the bee is glad: a little more when it was the matter's last open task.
struct PlanTick: View {
    let todo: Todo
    let toggle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            let wasOpen = !todo.isDone
            toggle()
            if wasOpen, todo.isDone {
                BeeJoy.shared.celebrate(big: (todo.matter?.todos ?? []).shown.allSatisfy(\.isDone), still: reduceMotion)
            }
        } label: {
            Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(todo.isDone ? Theme.onInk : .secondary, todo.isDone ? Theme.ink : .secondary)
                .frame(width: Theme.planMark, height: Theme.planMark)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.isDone ? "Open again" : "Mark as done")
        .help(todo.isDone ? "Open again" : "Mark as done")
    }
}

/// Where a task's or a date's ⋯ stood: nothing now, on every device. A row's menu is its long
/// press on the iPhone and the iPad and its right-click on the Mac — a ⋯ on every row only added noise.
struct PlanMore<Items: View>: View {
    @ViewBuilder let items: Items

    var body: some View {
        #if os(macOS)
        // Nothing to see, but where a row's editor opens its popover: at the row's end, as before.
        Color.clear.frame(width: 1, height: Theme.planMark).accessibilityHidden(true)
        #else
        EmptyView()
        #endif
    }
}

/// What stands on a date's row where a task has its box: a date is not ticked off.
struct PlanDateMark: View {
    let isDeadline: Bool

    var body: some View {
        Image(systemName: isDeadline ? "flag.fill" : "calendar")
            .font(.callout)
            .foregroundStyle(isDeadline ? Theme.warning : .secondary)
            .frame(width: Theme.planMark, height: Theme.planMark)
            .accessibilityHidden(true)
    }
}

/// Under a date's name: when and where, or that it is a deadline. The block says it is a date.
struct PlanDateLine: View {
    let isDeadline: Bool
    let hours: String?
    let last: String?
    let place: String?

    static func words(hours: String?, last: String?, place: String?) -> String? {
        let words = [hours, last.map { "until " + Dates.short($0) }, place].compactMap { $0 }
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }

    var body: some View {
        if isDeadline {
            Text("Deadline").font(.footnote).foregroundStyle(Theme.warning)
        } else if let line = Self.words(hours: hours, last: last, place: place) {
            Text(line).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Who has the ball, in a person's card: what they wait for from the owner, or the owner from them.
struct BallTile: View {
    let ball: Journal.Ball

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let waits = ball.waitsForYou {
                Text("Waits for you: " + waits).font(.footnote).lineLimit(2)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let wait = ball.youWaitFor {
                Text("You wait for: " + wait).font(.footnote).lineLimit(2)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// Who has the ball, for the wide page's column: one line for each person it lies with.
struct BallCard: View {
    let matter: Matter

    var body: some View {
        let balls = matter.shownParties.map { ($0.name, Journal.ball(of: $0, in: matter)) }.filter { !$0.1.isEmpty }
        if !balls.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("WHO HAS THE BALL").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(balls, id: \.0) { name, ball in
                    if ball.waitsForYou != nil { Text("\(name) waits for you") }
                    if ball.youWaitFor != nil { Text("You wait for \(name)").foregroundStyle(.secondary) }
                }
            }
            .journalCard()
        }
    }
}

/// The overview's two pages: what happened across all matters, or the matters themselves.
enum OverviewPart: String, CaseIterable {
    case all, matters

    var label: String { self == .all ? "Latest updates" : "Matters" }
}

/// The journal across all matters: a day at a time, each matter once, with what its newest mail says.
struct OverviewJournal: View {
    let matters: [Matter]
    let open: (Matter) -> Void

    private struct Day: Identifiable {
        let id: String
        let title: String
        var summaries: [MatterSummary]
    }

    private func days(_ recent: [MatterSummary]) -> [Day] {
        var days: [Day] = []
        for summary in recent {
            guard let date = summary.latest?.date else { continue }
            let id = MatterStatus.day(date)
            if days.last?.id == id { days[days.count - 1].summaries.append(summary) }
            else { days.append(Day(id: id, title: Journal.dayTitle(date), summaries: [summary])) }
        }
        return days
    }

    var body: some View {
        let recent = StoredChanges.shared.overview(matters).recent
        let byID = Dictionary(matters.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        LazyVStack(alignment: .leading, spacing: Theme.cardGap) {
            ForEach(days(recent)) { day in
                JournalHeading(title: day.title)
                ForEach(day.summaries) { summary in
                    if let matter = byID[summary.id] { OverviewDayCard(summary: summary, matter: matter) { open(matter) } }
                }
            }
        }
    }
}

/// One matter's day: its name, what happened — the news, what is new, or who wrote about what —
/// what came that day and what is left to do.
private struct OverviewDayCard: View {
    let summary: MatterSummary
    let matter: Matter
    let open: () -> Void

    /// "4 mails · 2 files": what is not there is not said.
    private static func came(_ latest: MatterSummary.Latest) -> String {
        func say(_ count: Int, _ one: String) -> String? { count == 0 ? nil : "\(count) \(one)\(count == 1 ? "" : "s")" }
        return [say(latest.mails, "mail"), say(latest.files, "file")].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    MatterIconTile(matter: matter, size: 32)
                    Text(summary.name).font(Theme.rowTitleFont).foregroundStyle(.primary).lineLimit(1)
                    Spacer(minLength: 0)
                }
                if let latest = summary.latest {
                    // What happened, not what the matter is about: the owner knows that.
                    Text(summary.happened ?? latest.title)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.subheadline)
                        #endif
                        // What happened is the card's news: read in the text's own colour, not grey.
                        .foregroundStyle(.primary).lineLimit(3).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().padding(.top, 4)
                    HStack(spacing: 8) {
                        Text([Self.came(latest), summary.newCount > 0 ? "\(summary.newCount) new" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        Spacer(minLength: 8)
                        if summary.openCount > 0 { Text("\(summary.openCount) \(summary.openCount == 1 ? "task" : "tasks") open") }
                    }
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 2)
                }
            }
            .journalCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("overview.day")
    }
}

/// A closed matter is out of the overview, unless mail came for it after it was closed. Held, or
/// right-clicked on the Mac, that mail is ignored here: it stays in the matter and on its row among
/// the closed ones, and the next mail shows here again; or it starts a matter of its own.
struct ClosedMailRows: View {
    let matters: [Matter]
    let open: (Matter) -> Void
    @Environment(\.modelContext) private var context
    @State private var splitting: Matter?
    @State private var name = ""

    private func start() {
        guard let matter = splitting else { return }
        let mails = MatterStatus(matter).mailsSinceClosed
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mails.isEmpty, !name.isEmpty, Store.shared.mayStartMatter(in: context),
              let new = try? matter.split(mails, intoNewMatterNamed: name, turnsSince: matter.closedAt, in: context) else { return }
        open(new)
    }

    private func ignore(_ matter: Matter) {
        withAnimation(.snappy(duration: 0.2)) {
            matter.ignoredMailUntil = StoredChanges.shared.summary(matter).lastDate
            try? context.save()
        }
    }

    var body: some View {
        let waiting = matters.filter { $0.isClosed && StoredChanges.shared.summary($0).mailsToShowSinceClosed > 0 }
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(waiting.enumerated()), id: \.element.persistentModelID) { index, matter in
                    let new = StoredChanges.shared.summary(matter).mailsToShowSinceClosed
                    if index > 0 { Divider().padding(.leading, 44) }
                    Button { open(matter) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "archivebox").foregroundStyle(.secondary)
                            Text("\(new) new \(new == 1 ? "mail" : "mails") in the closed matter “\(matter.name)”")
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        #if os(iOS)
                        .font(.subheadline)
                        #else
                        .font(.callout)
                        #endif
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open the matter")
                    .contextMenu {
                        Button(Say.startNewMatter, systemImage: "plus.circle") {
                            name = Matter.suggestedName(for: MatterStatus(matter).mailsSinceClosed)
                            splitting = matter
                        }
                        .tint(Color.secondary)
                        Button(Say.ignoreNewMail, systemImage: "eye.slash") { ignore(matter) }.tint(Color.secondary)
                    }
                }
            }
            .journalRows()
            .alertWhenAsked(Say.startNewMatter, isPresented: Binding(get: { splitting != nil }, set: { if !$0 { splitting = nil } })) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Start", action: start)
            } message: {
                Text("The new mail goes, with what only it brought. The closed matter stays closed.")
            }
        }
    }
}

/// Chips side by side, wrapping onto the next line when there is no room.
struct FlowRow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    /// Its own size, but never wider than the row: a chip with a long mail's name is shortened —
    /// "Fwd: Ihre Reise Ba…7. Dezember 2026" — instead of running out of its card.
    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let own = subview.sizeThatFits(.unspecified)
        guard width.isFinite, own.width > width else { return own }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = fitted(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] = []
        var items: [Int] = [], x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            if x > 0, x + size.width > width {
                rows.append((items, y, x - spacing, height))
                y += height + spacing
                items = []; x = 0; height = 0
            }
            items.append(index)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !items.isEmpty { rows.append((items, y, x - spacing, height)) }
        return rows
    }
}

// MARK: Connections

extension JournalItem {
    /// The sign it is shown with, in a chip and in the list to connect from.
    var symbol: String {
        switch self {
        case .mail: "envelope"
        case .file: "doc"
        case .task: "checklist"
        case .meeting: "calendar"
        case .deadline: "flag"
        case .note: "note.text"
        case .link: "link"
        case .person: "person"
        case .detail: "key"
        }
    }

    /// What kind of thing it is, in words, for the filter of the list.
    var kindName: String {
        switch self {
        case .mail: "Mail"
        case .file: "Files"
        case .task: "Tasks"
        case .meeting, .deadline: "Dates"
        case .note: "Notes"
        case .link: "Links"
        case .person: "People"
        case .detail: "Details"
        }
    }

    /// The matter it is in. A person can be in several: theirs is given where it is shown.
    var matter: Matter? {
        switch self {
        case .mail(let item): item.matter
        case .file(let item): item.matter
        case .task(let item): item.matter
        case .meeting(let item): item.matter
        case .deadline(let item): item.matter
        case .note(let item): item.matter
        case .link(let item): item.matter
        case .person: nil
        case .detail(let item): item.matter
        }
    }
}

/// "Move to Matter …" and "Hide", the same in every item's menu on every device: the open
/// matters, the newest mail first, the one it is in ticked; and the item put away. A mail moves
/// with its own menu; a file, which had Hide first, passes `hides: false`.
struct MoveAndHide: View {
    let item: JournalItem?
    let matter: Matter?
    var hides = true
    @Query private var matters: [Matter]
    @Environment(\.modelContext) private var context

    var body: some View {
        if let item, let matter {
            Menu {
                ForEach(Self.order(matters, current: matter)) { other in
                    if other === matter {
                        Button(other.name, systemImage: "checkmark") { }.disabled(true)
                    } else {
                        Button(other.name) { withAnimation { try? matter.move(item, to: other, in: context) } }
                    }
                }
            } label: {
                Label(Say.moveToMatter, systemImage: "folder")
            }
            if hides {
                Button(Say.hide, systemImage: "eye.slash") {
                    Self.unlink(item)
                    withAnimation { matter.setHidden(item, true) }
                    try? context.save()
                }
            }
        }
    }

    /// The one it is in first, then the open ones by their newest mail.
    static func order(_ matters: [Matter], current: Matter?) -> [Matter] {
        let open = matters.filter { !$0.isClosed && $0 !== current }
            .map { ($0, MatterStatus($0).lastDate ?? .distantPast) }.sorted { $0.1 > $1.1 }.map(\.0)
        return (current.map { [$0] } ?? []) + open
    }

    /// Hidden, a task leaves Reminders and a date leaves Calendar, as when deleted: put away here,
    /// it is not to remind of anything there. Shown again, it can be added again from its menu.
    static func unlink(_ item: JournalItem) {
        switch item {
        case .task(let todo):
            Calendars.shared.removeReminder(todo.reminderID)
            todo.reminderID = nil
            todo.reminderStamp = nil
        case .meeting(let appointment):
            Calendars.shared.removeEvent(appointment.calendarID)
            appointment.calendarID = nil
            appointment.calendarStamp = nil
        case .deadline(let deadline):
            Calendars.shared.removeEvent(deadline.calendarID)
            deadline.calendarID = nil
            deadline.calendarStamp = nil
        default: break
        }
    }
}

/// What the owner hid in a matter, at the foot of its page: "3 hidden", and a sheet with each to
/// show again. Nothing while nothing is hidden.
struct HiddenItemsLine: View {
    let matter: Matter
    @State private var showing = false

    var body: some View {
        let count = matter.hiddenItems.count
        if count > 0 {
            Button("\(count) hidden · Show") { showing = true }
                .buttonStyle(.plain).font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .sheetWhenAsked(isPresented: $showing) { HiddenItemsSheet(matter: matter) }
        }
    }
}

struct HiddenItemsSheet: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(matter.hiddenItems, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol).foregroundStyle(.secondary).frame(width: 22)
                        Text(item.title).lineLimit(2)
                        Spacer(minLength: 8)
                        Button(Say.showAgain) {
                            withAnimation { matter.setHidden(item, false) }
                            try? context.save()
                            if matter.hiddenItems.isEmpty { dismiss() }
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("Hidden")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetConfirm("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(width: 440, height: 360)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}

/// What an item belongs with, as chips under it: what Causabee read it came from, and what the
/// owner connected, each with × to take it away from both. Nothing at all while there is none:
/// "Connect …" is in the item's menu, and a row of plans stays quiet.
struct ConnectionChips: View {
    let item: JournalItem
    var matter: Matter? = nil
    /// Only what the owner connected: where what Causabee read is shown already, as under a mail.
    var ownOnly = false
    @Environment(\.modelContext) private var context
    /// Optional: a chip in a sheet with no page behind it just stays a chip.
    @Environment(Navigation.self) private var navigation: Navigation?

    private var home: Matter? { matter ?? item.matter }

    var body: some View {
        if let home, case let connected = home.connected(to: item).filter({ !ownOnly || $0.kind == .with }), !connected.isEmpty {
            // Only what it is connected with: "Connect …" is in the item's ⋯ and its held menu — a
            // dashed pill under every row said it once more.
            FlowRow(spacing: 6) {
                ForEach(connected, id: \.self) { other in chip(other, in: home) }
            }
            .padding(.top, 4)
        }
    }

    private func chip(_ other: Connected, in home: Matter) -> some View {
        HStack(spacing: 4) {
            // The chip itself goes to what it is connected with, as "Show" does: its part of the
            // page, scrolled to and marked. Only the × takes the connection away.
            Button { navigation?.showsInItsPart = true; navigation?.showing = other.item.id } label: {
                HStack(spacing: 4) {
                    Image(systemName: other.item.symbol).font(.caption2)
                    Text(other.item.title).lineLimit(1).truncationMode(.middle).frame(maxWidth: 220, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(other.item.title)")
            Button {
                withAnimation { home.disconnect(item, other.item, in: context) }
                try? context.save()
            } label: { Image(systemName: "xmark").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary) }
            .buttonStyle(.plain)
            .accessibilityLabel("Take away")
        }
        .font(.caption)
        .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 3)
        // A touch darker than what it stands on — the white of a task's row or the grey of a
        // date's box: the box's own grey made it vanish in a date.
        .background(Color.primary.opacity(0.07), in: Capsule())
        .help(other.kind == .cameFrom ? "Causabee read it came from this" : "You connected it")
    }
}

extension JournalItem: Identifiable {}

private extension View {
    /// The kinds to filter by, held over the list: on the iPhone and iPad in the bar's own glass —
    /// the list softens under it as it does under the title — on the Mac above it.
    @ViewBuilder func kindPills<Pills: View>(@ViewBuilder _ pills: () -> Pills) -> some View {
        // One line, scrolled sideways, across the sheet's whole width: the margin is inside the
        // scroll, so the last pill scrolls to the same 16 points from the edge as the first stands.
        let line = ScrollView(.horizontal, showsIndicators: false) { pills() }
            .contentMargins(.horizontal, 16, for: .scrollContent)
        #if os(iOS)
        safeAreaBar(edge: .top) { line.padding(.bottom, 4) }
        #else
        safeAreaInset(edge: .top) { line.padding(.vertical, 6).background(.bar) }
        #endif
    }
}

extension View {
    /// The list to connect an item from, for whichever item asked: one sheet for a list of rows.
    func connectSheet(_ item: Binding<JournalItem?>, in matter: Matter) -> some View {
        sheet(item: item) { ConnectSheet(item: $0, matter: matter) }
    }

    /// The list to connect an item from, opened by "Connect …".
    func connectSheet(_ item: JournalItem?, in matter: Matter?, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            if let item, let matter = matter ?? item.matter { ConnectSheet(item: item, matter: matter) }
        }
    }
}

/// "Connect to …": the matter's items, newest first, a tick on what this one belongs with — a
/// tap puts it with it or takes it away. Search and a filter by kind for a matter with much in it.
struct ConnectSheet: View {
    let item: JournalItem
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var kind = "All"
    @State private var photo: PhotosPickerItem?
    @State private var picksPhoto = false
    @State private var picksFile = false
    @State private var scanning = false
    @State private var said: String?
    #if os(macOS)
    @Environment(Navigation.self) private var navigation
    #endif

    private var kinds: [String] { ["All"] + ["Mail", "Files", "Tasks", "Dates", "People", "Details", "Notes", "Links"].filter { name in matter.journalItems.contains { $0 != item && $0.kindName == name } } }

    private var shown: [JournalItem] {
        let words = query.trimmingCharacters(in: .whitespaces).lowercased()
        return matter.journalItems
            .filter { $0 != item && (kind == "All" || $0.kindName == kind) && (words.isEmpty || $0.title.lowercased().contains(words)) }
            .sorted(by: Self.order)
    }

    /// What came and was made lately first, newest on top; then what is ahead, soonest first; the
    /// people last. A date three weeks off is seldom what a photo taken today belongs with.
    static func order(_ a: JournalItem, _ b: JournalItem) -> Bool {
        let now = Date()
        switch (a.when, b.when) {
        case (nil, nil): return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case (nil, _): return false
        case (_, nil): return true
        case let (x?, y?):
            if (x > now) != (y > now) { return y > now }
            return x > now ? x < y : x > y
        }
    }

    var body: some View {
        let all = matter.connected(to: item)
        // Ticked is only what the owner put with it. What Causabee read it came from — a mail's
        // files, tasks and dates — stands apart on top, without a tick: ticked among the rest, a
        // mail opened with half the matter chosen, and a task made by hand with nothing.
        let connected = Set(all.filter { $0.kind == .with }.map(\.item))
        let cameFrom = all.filter { $0.kind == .cameFrom }.map(\.item).filter { shown.contains($0) }
        let rest = shown.filter { !cameFrom.contains($0) }
        // As the system's own sheets are: the title and Done on the glass of the bar, the search in
        // the system's field, the list scrolling under both.
        NavigationStack {
            List {
                if !cameFrom.isEmpty {
                    Section {
                        ForEach(cameFrom, id: \.self) { other in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).frame(width: 22)
                                Image(systemName: other.symbol).foregroundStyle(.secondary).frame(width: 18)
                                Text(other.title).lineLimit(2)
                                Spacer(minLength: 8)
                                if let when = other.when { Text(Dates.short(when)).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    } header: {
                        Text("Read from, by Causabee").font(.footnote).foregroundStyle(.secondary)
                    } footer: {
                        Text("Shown with it already. × on its chip takes one away.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(rest, id: \.self) { other in
                        Button {
                            withAnimation {
                                if connected.contains(other) { matter.disconnect(item, other, in: context) } else { matter.connect(item, other, in: context) }
                            }
                            try? context.save()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: connected.contains(other) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(connected.contains(other) ? Color.primary : Color.secondary)
                                    .frame(width: 22)
                                Image(systemName: other.symbol).foregroundStyle(.secondary).frame(width: 18)
                                Text(other.title).lineLimit(2)
                                Spacer(minLength: 8)
                                if let when = other.when { Text(Dates.short(when)).font(.caption).foregroundStyle(.secondary) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if !cameFrom.isEmpty { Text("Connect").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .listStyle(.plain)
            .kindPills { JournalPills(parts: kinds, label: { $0 }, selection: $kind) }
            .searchable(text: $query, prompt: "Search this matter")
            .navigationTitle("Connect to …")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { newMenu }
                #else
                ToolbarItem(placement: .primaryAction) { newMenu }
                #endif
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirm("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let said {
                    Text(said).font(.footnote).foregroundStyle(.secondary).padding(8)
                        .frame(maxWidth: .infinity).background(.bar)
                }
            }
            .photosPicker(isPresented: $picksPhoto, selection: $photo, matching: .images)
            .onChange(of: photo) {
                guard let photo else { return }
                self.photo = nil
                Task {
                    guard let data = try? await photo.loadTransferable(type: Data.self) else { return }
                    let ending = photo.supportedContentTypes.compactMap(\.preferredFilenameExtension).first { ["jpeg", "jpg", "png", "heic"].contains($0) } ?? "jpeg"
                    add(data, named: "Photo " + Self.stamp() + "." + ending)
                }
            }
            .fileImporter(isPresented: $picksFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let files) = result { add(files) }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $scanning) {
                DocumentCamera { pages in
                    scanning = false
                    if let data = Scans.pdf(of: pages) { add(data, named: "Scan " + Self.stamp() + ".pdf") }
                } cancel: { scanning = false }
                .ignoresSafeArea()
            }
            #endif
        }
        #if os(macOS)
        .frame(width: 460, height: 520)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    /// New: a photo, a scan or a file, added to the matter and connected to the item at once — a
    /// photo taken for a task after the fact. It is kept as files added by hand are, not read: Read
    /// on the file reads it.
    private var newMenu: some View {
        Menu {
            Button("Photo", systemImage: "photo") { picksPhoto = true }
            #if os(iOS)
            if VNDocumentCameraViewController.isSupported {
                Button("Scan", systemImage: "doc.viewfinder") { scanning = true }
            }
            #endif
            Button("File", systemImage: "doc") { picksFile = true }
        } label: {
            Label("New", systemImage: "plus")
        }
        .accessibilityIdentifier("connect.new")
    }

    /// "2026-11-04 at 16.05.12", as the devices name their own pictures.
    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }

    private func add(_ data: Data, named name: String) {
        said = ItemFiles.add(data, named: name, to: item, in: matter, context: context, store: store)
    }

    private func add(_ files: [URL]) {
        said = ItemFiles.add(files, to: item, in: matter, context: context, store: store)
    }

    private var store: URL? {
        #if os(macOS)
        navigation.store
        #else
        nil
        #endif
    }
}

/// Files brought to one item — from "New" in "Connect to …", or dropped on it: each a file of the
/// matter, kept where this device keeps the owner's own files and in the matter's folder, not read,
/// and connected to the item at once.
@MainActor
enum ItemFiles {
    /// What came from the camera, the photos or another app as data, through a file of its own.
    /// What is to be said after, or nil.
    @discardableResult
    static func add(_ data: Data, named name: String, to item: JournalItem, in matter: Matter, context: ModelContext, store: URL?) -> String? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(name)
        guard (try? data.write(to: file)) != nil else { return "It could not be added." }
        return add([file], to: item, in: matter, context: context, store: store)
    }

    @discardableResult
    static func add(_ files: [URL], to item: JournalItem, in matter: Matter, context: ModelContext, store: URL?) -> String? {
        let before = Set((matter.documents ?? []).map(\.persistentModelID))
        #if os(iOS)
        let folder = PhoneShots.folder
        let result = FolderImport.add(files, to: matter, context: context) { file, name in
            FolderImport.data(of: file).flatMap { PhoneShots.keep($0, named: name, in: folder) }
        }
        #else
        let folder = ScreenshotDoor.attachments(besides: store ?? CausabeeApp.storeLocation())
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let result = FolderImport.add(files, to: matter, context: context) { file, name in
            let target = folder.appendingPathComponent(UUID().uuidString.prefix(8) + "-" + name)
            var done = false
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: nil) { done = (try? FileManager.default.copyItem(at: $0, to: target)) != nil }
            return done ? target : nil
        }
        #endif
        let added = (matter.documents ?? []).filter { !before.contains($0.persistentModelID) }
        withAnimation { for document in added { matter.connect(item, .file(document), in: context) } }
        try? context.save()
        #if os(iOS)
        PhoneFolderSaver.save([matter])
        #else
        FolderSaver.shared.save([matter])
        #endif
        return added.isEmpty ? (result.said ?? "It is in the matter already.") : result.said
    }

    /// A page dragged from the browser: a link of the matter, connected to the item.
    static func add(link address: String, to item: JournalItem, in matter: Matter, context: ModelContext) {
        let link = (matter.links ?? []).shown.first { $0.address == address } ?? {
            let link = WebLink(address: address, title: "")
            context.insert(link)
            link.matter = matter
            return link
        }()
        withAnimation { matter.connect(item, .link(link), in: context) }
        try? context.save()
    }
}

/// What can be dropped on an item: a file from the Finder or Files, a page from the browser, a
/// picture or a PDF from another app.
enum DroppedThing: Transferable {
    case url(URL)
    case file(BroughtFile)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(importing: { (url: URL) in DroppedThing.url(url) })
        ProxyRepresentation(importing: { (file: BroughtFile) in DroppedThing.file(file) })
    }
}

extension View {
    /// Files or a page dropped on an item become the matter's and are connected to it; the item is
    /// outlined while something is held over it. On the Mac and the iPad, where things are dragged.
    func dropsOn(_ item: JournalItem?, in matter: Matter?) -> some View {
        modifier(DropsOnItem(item: item, matter: matter))
    }
}

private struct DropsOnItem: ViewModifier {
    let item: JournalItem?
    let matter: Matter?
    @Environment(\.modelContext) private var context
    #if os(macOS)
    @Environment(Navigation.self) private var navigation
    #endif
    @State private var over = false

    func body(content: Content) -> some View {
        if let item, let matter = matter ?? item.matter {
            content
                .dropDestination(for: DroppedThing.self) { things, _ in
                    take(things, to: item, in: matter)
                    return !things.isEmpty
                } isTargeted: { over = $0 }
                .overlay {
                    if over {
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2).allowsHitTesting(false)
                    }
                }
        } else {
            content
        }
    }

    private func take(_ things: [DroppedThing], to item: JournalItem, in matter: Matter) {
        #if os(macOS)
        let store: URL? = navigation.store
        #else
        let store: URL? = nil
        #endif
        var files: [URL] = []
        for thing in things {
            switch thing {
            case .url(let url) where url.isFileURL: files.append(url)
            case .url(let url):
                if let address = WebLink.address(in: url.absoluteString) { ItemFiles.add(link: address, to: item, in: matter, context: context) }
            case .file(let file): ItemFiles.add(file.data, named: file.name, to: item, in: matter, context: context, store: store)
            }
        }
        if !files.isEmpty { ItemFiles.add(files, to: item, in: matter, context: context, store: store) }
    }
}
