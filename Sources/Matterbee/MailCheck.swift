import MatterCore
import SwiftData
import SwiftUI

/// "Neue Mails holen": the daily door from inside the app. Reading is free and happens first;
/// what is new is listed with what sending it would cost, and only "Einordnen" sends it.
@MainActor
@Observable
final class MailCheck {
    enum State {
        case idle
        case reading(String)
        case nothingNew(known: Int)
        case ready(DailyDoor.Look, DailyDoor)
        /// New mail found by the check that runs by itself, waiting quietly to be looked at.
        case newMail(DailyDoor.Look, DailyDoor)
        /// The demo's three made-up mails, found: the same panel, nothing read or sent.
        case demoReady
        case sending(String)
        case done(String, [IntakeSummary.Item] = [])
        case failed(String)
    }

    var state: State = .idle
    /// Which step it is at, for the panel's transitions: one view each, faded into the next.
    var phase: String {
        switch state {
        case .idle: "idle"
        case .reading: "reading"
        case .nothingNew: "nothing"
        case .ready, .demoReady: "ready"
        case .newMail: "new"
        case .sending: "sending"
        case .done: "done"
        case .failed: "failed"
        }
    }
    /// Told what was taken in, to write it into the matters' threads.
    var taken: (([Judgement], String) -> Void)?
    /// Changes when a run ends, so the list of mail without a matter is read again.
    var stateKey: String {
        switch state {
        case .done(let text, _): "done " + text
        case .idle: "idle"
        default: "busy"
        }
    }

    /// Told what the demo's round took in, to write its lines into the matters' threads.
    var demoTaken: (([(index: Int, matter: Matter)]) -> Void)?

    /// When the last check, by hand or by itself, came back.
    var lastChecked: Date?
    private var checking = false

    /// New mail unticked once: not offered again. On this Mac, as the iPhone keeps its own.
    static let setAsideKey = "mail.setAside"
    static var setAside: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: Data((UserDefaults.standard.string(forKey: setAsideKey) ?? "[]").utf8))) ?? []) }
        set { UserDefaults.standard.set(String(decoding: (try? JSONEncoder().encode(newValue.sorted())) ?? Data("[]".utf8), as: UTF8.self), forKey: setAsideKey) }
    }

    /// Checks by itself — on start, every ten minutes, after sleep — and only says something when
    /// there is new mail: "3 new mails · Review". Reading is free; nothing is sent.
    func checkQuietly(store: URL, context: ModelContext) {
        guard !DemoData.isRequested, IntroShot.current == nil, !checking else { return }
        switch state {
        case .idle, .nothingNew, .done, .failed, .newMail: break
        default: return
        }
        guard let account = Keychain.accounts().first else { return }
        let door = door(for: account, store: store, context: context)
        checking = true
        Task {
            defer { checking = false }
            guard let password = try? await MailSecret.secret(for: account),
                  let look = try? await door.look(password: password) else { return }
            lastChecked = Date()
            // Something else began meanwhile — a check by hand, a Sort in: that one decides.
            switch state {
            case .idle, .nothingNew, .done, .failed, .newMail:
                if look.pending > 0 { state = .newMail(look, door) } else if case .newMail = state { state = .idle }
            default: break
            }
        }
    }

    private func door(for account: MailAccount, store: URL, context: ModelContext) -> DailyDoor {
        var door = DailyDoor(account: account, besides: store)
        door.model = ModelChoice.mail
        door.strict = ModelChoice.strict
        // What the iPhone or the other Mac sorted is known here too, and their names disguised.
        NameListPublisher.adopt()
        door.earlier = SortedMails.answered(in: context)
        door.setAside = Self.setAside
        return door
    }

    /// Sort in the ticked ones; the others are set aside, so they are not offered again.
    func sortIn(_ chosen: Set<String>, of look: DailyDoor.Look, with door: DailyDoor, context: ModelContext, owner: [String]) {
        Self.setAside.formUnion(Set(look.newIDs).subtracting(chosen))
        classify(look.only(chosen), with: door, context: context, owner: owner)
    }

    func look(store: URL, context: ModelContext) {
        if DemoData.isRequested { lookInDemo(); return }
        guard let account = Keychain.accounts().first else {
            state = .failed("No mail account yet. Choose Matterbee → Set Up Matterbee … to log in.")
            return
        }
        let door = door(for: account, store: store, context: context)
        // Only that it is at it: how many mails the label holds is nothing to worry about.
        state = .reading("Fetching mail …")
        Task {
            do {
                guard let password = try await MailSecret.secret(for: account) else {
                    state = .failed("No password for \(account.user) in the Keychain. Choose Matterbee → Set Up Matterbee … to log in again.")
                    return
                }
                let look = try await door.look(password: password)
                lastChecked = Date()
                state = look.pending == 0 ? .nothingNew(known: look.intake.alreadyKnown) : .ready(look, door)
            } catch {
                state = .failed("\(error)")
            }
        }
    }

    func classify(_ look: DailyDoor.Look, with door: DailyDoor, context: ModelContext, owner: [String]) {
        guard let claude = ModelChoice.client(for: door.model) else {
            state = .failed(ModelChoice.missingKey(door.model))
            return
        }
        state = .sending("Sorting \(look.pending) \(look.pending == 1 ? "mail" : "mails") …")
        Task {
            do {
                let (judgements, summary) = try await door.classify(look, claude: claude, owner: owner, matters: Unplaced.matters(in: context))
                let imported = try MatterImport.apply(judgements, to: context, owner: owner)
                // Into the record the other devices read, and the names it learned into the store.
                try SortedMails.record(judgements, device: NameListPublisher.device, in: context)
                NameListPublisher.publish()
                taken?(judgements, door.model.label)
                // Their attachments into the matters' folders, by themselves.
                let withFiles = Set(judgements.filter { !$0.attachments.isEmpty }.compactMap(\.matter))
                FolderSaver.shared.save(try context.fetch(FetchDescriptor<Matter>()).filter { matter in withFiles.contains { matter.answers(to: $0) } })
                // Their important links, found on the Mac, offered in their matters.
                let links = look.report.outcomes.reduce(0) { $0 + MailLinks.suggest($1.email, in: context) }
                // Their words, kept on this Mac only, so they need not be read from the server again.
                for outcome in look.report.outcomes where outcome.judgement.disguise != nil { MailText.save(outcome.email, besides: door.log) }
                try? context.save()
                let matters = Set(judgements.compactMap(\.matter))
                let names = try context.fetch(FetchDescriptor<Matter>()).filter { matter in matters.contains { matter.answers(to: $0) } }.map(\.name)
                // Short: what came of it, and what it cost; what it brought, line by line, under it.
                let unplaced = judgements.filter { $0.matter == nil && !$0.isBulk }.count
                var text = IntakeSummary.line(mails: imported.mails, matters: names, tasks: imported.todosNew,
                                              dates: imported.appointments + imported.deadlines, unplaced: unplaced, cost: summary.cost)
                if !summary.failed.isEmpty { text += " · \(summary.failed.count) failed" }
                _ = links
                state = .done(text, IntakeSummary.items(judgements))
            } catch {
                state = .failed("\(error)")
            }
        }
    }
}

extension MailCheck {
    /// The demo's round, at the pace of a real one: fetching, three new mails, sorting, and what
    /// came of it — the mails, a task and two dates in three matters. Nothing is read or sent.
    private func lookInDemo() {
        state = .reading("Fetching mail …")
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard case .reading = state else { return }
            // Every time the whole round: the last one's three mails are taken out on Sort in.
            state = .demoReady
        }
    }

    func sortInDemo(context: ModelContext, only chosen: Set<Int> = Set(DemoData.newMail.indices)) {
        state = .sending("Sorting \(chosen.count) \(chosen.count == 1 ? "mail" : "mails") …")
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard case .sending = state else { return }
            let taken = DemoData.takeInNewMail(context, only: chosen)
            demoTaken?(taken)
            let tasks = chosen.contains(0) ? 1 : 0
            state = .done(IntakeSummary.line(mails: taken.count, matters: taken.map(\.matter.name), tasks: tasks, dates: taken.count - tasks),
                          DemoData.newMailItems(chosen))
        }
    }
}

/// The bottom of the sidebar.
struct MailCheckView: View {
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var matters: [Matter]
    /// Owned above the sidebar: the sidebar comes and goes, a run of "Get new mail" must not —
    /// shown again, a fresh idle check would hide the one still running, and invite a second paid run.
    let check: MailCheck
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Mail that was read but found no matter: to put into one, or to set aside.
    @State private var unplaced: [Judgement] = []
    @State private var showsUnplaced = true
    @AppStorage("unplaced.setAside") private var setAsideJSON = "[]"

    private var setAside: Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(setAsideJSON.utf8))) ?? []) }

    private func refresh() {
        let log = navigation.store.deletingLastPathComponent().appendingPathComponent("decisions-fetch.jsonl")
        unplaced = Unplaced.find(log: log, context: context, setAside: setAside)
    }

    @ViewBuilder
    private var unplacedList: some View {
        if !unplaced.isEmpty {
            DisclosureGroup(isExpanded: $showsUnplaced) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(unplaced, id: \.emailID) { mail in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mail.subject.isEmpty ? "(no subject)" : mail.subject).font(.caption.weight(.medium)).lineLimit(2)
                            if let digest = mail.digest, !digest.isEmpty {
                                Text(digest).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                            HStack(spacing: 10) {
                                Menu("Add to …") {
                                    ForEach(matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }) { matter in
                                        Button(matter.name) {
                                            try? Unplaced.place(mail, in: matter, context: context, owner: profiles.first?.names ?? [])
                                            refresh()
                                        }
                                    }
                                }
                                .menuStyle(.borderlessButton).fixedSize().font(.caption)
                                .help("Into that matter, with its tasks and dates. Nothing is sent: it was read already.")
                                Button("Not needed") {
                                    var ids = setAside
                                    ids.insert(mail.emailID)
                                    setAsideJSON = String(decoding: (try? JSONEncoder().encode(Array(ids))) ?? Data("[]".utf8), as: UTF8.self)
                                    refresh()
                                }
                                .buttonStyle(.gold).font(.caption)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("No matter found · \(unplaced.count)").font(.caption.weight(.semibold))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            unplacedList
            // One step at a time: the button gives way to the bee at work, that to the result —
            // each faded into the next while the bottom of the sidebar takes its new height.
            stage
                .id(check.phase)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35), value: check.phase)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The sidebar's own grey under it, a line above: part of the sidebar, not a bar on it.
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            refresh()
            check.taken = { judgements, model in navigation.logIntake(judgements, matters: matters, model: model) }
            check.demoTaken = { taken in navigation.logDemoIntake(taken) }
        }
        .onChange(of: check.stateKey) { refresh() }
    }

    @ViewBuilder
    private var stage: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch check.state {
            case .idle:
                button
                checkedLine
            case .newMail(let look, let door):
                // Found by itself: one quiet line, opened when the owner wants.
                Button { check.state = .ready(look, door) } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.bee).frame(width: 7, height: 7)
                        Text("\(look.pending) new \(look.pending == 1 ? "mail" : "mails")").font(.callout.weight(.semibold))
                        Spacer(minLength: 4)
                        Text("Review ›").font(.caption).foregroundStyle(Theme.gold)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                checkedLine
            case .reading(let text), .sending(let text):
                HStack(spacing: 8) {
                    BeeLoader(size: 10)
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
            case .nothingNew:
                Text("No new mail.").font(.caption).foregroundStyle(.secondary)
                button
            case .ready(let look, let door):
                MailReview(look: look, door: door) {
                    check.state = .newMail(look, door)
                } sortIn: { chosen in
                    check.sortIn(chosen, of: look, with: door, context: context, owner: profiles.first?.names ?? [])
                }
            case .demoReady:
                DemoMailReview(later: { check.state = .idle }) { chosen in check.sortInDemo(context: context, only: chosen) }
            case .done(let text, let items):
                Label(text, systemImage: "checkmark.circle").font(.caption).foregroundStyle(Theme.done)
                // What it brought, to see without opening every matter.
                ForEach(items, id: \.self) { item in
                    Label(item.text, systemImage: item.symbol).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                button
            case .failed(let text):
                Label(text, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled)
                button
            }
        }
    }

    /// When the last check came back, small: so a quiet sidebar says it is not asleep.
    @ViewBuilder
    private var checkedLine: some View {
        if let at = check.lastChecked {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text("Checked \(MailReview.ago(at)) · nothing is sent until Sort in").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var button: some View {
        Button { check.look(store: navigation.store, context: context) } label: {
            Label("Get new mail", systemImage: "arrow.down.circle")
        }
        // In the demo too: its round is made up, and the way back is Matterbee → Leave the Demo.
        .help(DemoData.isRequested ? "Fetches the demo's three made-up mails. Nothing is read or sent."
                                   : "Reads only new mail with the label. Nothing is sent until you click “Sort in”.")
    }
}

/// The new mails, each with a tick: Sort in sends only the ticked ones, at the cost shown; the
/// unticked ones are set aside. Later puts the list away; the quiet line stays.
struct MailReview: View {
    let look: DailyDoor.Look
    let door: DailyDoor
    let later: () -> Void
    let sortIn: (Set<String>) -> Void
    @State private var chosen: Set<String>

    init(look: DailyDoor.Look, door: DailyDoor, later: @escaping () -> Void, sortIn: @escaping (Set<String>) -> Void) {
        self.look = look
        self.door = door
        self.later = later
        self.sortIn = sortIn
        _chosen = State(initialValue: Set(look.newIDs))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(look.pending) new \(look.pending == 1 ? "mail" : "mails")").font(.callout.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(look.newMails, id: \.judgement.emailID) { outcome in
                        let id = outcome.judgement.emailID, on = chosen.contains(id)
                        Button {
                            if on { chosen.remove(id) } else { chosen.insert(id) }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.gold : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(outcome.email.subject.isEmpty ? "(no subject)" : outcome.email.subject)
                                        .strikethrough(!on).foregroundStyle(on ? .primary : .secondary).lineLimit(2)
                                    Text(Self.from(outcome.email)).foregroundStyle(.tertiary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .font(.caption)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .frame(maxHeight: 260)
            .fixedSize(horizontal: false, vertical: true)
            Text(chosen.isEmpty ? "Tick the mails to sort in."
                 : String(format: "Sorting in %d %@ costs about $%.2f. Sent pseudonymised to %@.", chosen.count, chosen.count == 1 ? "mail" : "mails",
                          look.only(chosen).estimate, door.model.label))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Later", action: later)
                Button(chosen.count == look.pending ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
                    .inkButton().disabled(chosen.isEmpty)
            }
        }
    }

    static func from(_ email: Email) -> String {
        let who = Email.displayName(in: email.from) ?? Email.address(in: email.from)
        guard let date = email.date else { return who }
        let time = Calendar.current.isDateInToday(date) ? date.formatted(.dateTime.hour().minute()) : Dates.short(date)
        return who + " · " + time
    }

    static func ago(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        return minutes < 1 ? "just now" : minutes == 1 ? "a minute ago" : minutes < 60 ? "\(minutes) min ago" : "at " + date.formatted(.dateTime.hour().minute())
    }
}

/// The demo's three, each with a tick, as a real round has them: nothing is read, sent or paid.
struct DemoMailReview: View {
    let later: () -> Void
    let sortIn: (Set<Int>) -> Void
    @State private var chosen = Set(DemoData.newMail.indices)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(DemoData.newMail.count) new mails").font(.callout.weight(.semibold))
            ForEach(Array(DemoData.newMail.enumerated()), id: \.offset) { index, mail in
                let on = chosen.contains(index)
                Button { if on { chosen.remove(index) } else { chosen.insert(index) } } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.gold : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mail.subject).strikethrough(!on).foregroundStyle(on ? .primary : .secondary).lineLimit(2)
                            Text(Email.displayName(in: mail.from) ?? mail.from).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.caption).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("In the demo, sorting in sends nothing and costs nothing.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Later", action: later)
                Button(chosen.count == DemoData.newMail.count ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
                    .inkButton().disabled(chosen.isEmpty)
            }
        }
    }
}
