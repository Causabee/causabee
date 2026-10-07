import MatterCore
import SwiftData
import SwiftUI
import UIKit

/// This iPhone's own list of names, once it sorts mail: kept beside the store as the Mac keeps
/// its `mapping.json`, put into the store for the other devices, and the only list that hands
/// out this iPhone's stand-ins. Until then, it asks with the newest list from a Mac.
@MainActor
enum PhoneNames {
    private static let deviceKey = "names.device"

    /// A random id this iPhone keeps, as each Mac keeps its own.
    static var device: String {
        if let id = UserDefaults.standard.string(forKey: deviceKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceKey)
        return id
    }

    static var mapping: URL { PhoneCloud.storeLocation().deletingLastPathComponent().appendingPathComponent("mapping.json") }
    static var hasOwn: Bool { FileManager.default.fileExists(atPath: mapping.path) }

    /// The names to ask with: this iPhone's list when it keeps one, the other lists' names beside it.
    static func current(in context: ModelContext) throws -> (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry]) {
        try NameLists.current(in: context, own: hasOwn ? mapping : nil, device: device)
    }

    /// The other devices' new names in, and this iPhone's list out — when it keeps one.
    static func publish(in context: ModelContext) {
        guard hasOwn, !DemoData.isRequested else { return }
        _ = try? NameLists.adopt(into: mapping, device: device, in: context)
        _ = try? NameLists.publish(mapping, device: device, deviceName: UIDevice.current.name, in: context)
    }
}

/// "Get new mail", as on the Mac: reading is free and happens first; what is new is listed with
/// what sending it would cost, and only "Sort in" sends it. What any device sorted before is known
/// from the store, so no mail is sent twice.
@MainActor
@Observable
final class PhoneMailCheck {
    static let shared = PhoneMailCheck()

    enum State {
        case idle
        case reading(String)
        case nothingNew(known: Int)
        case ready(DailyDoor.Look, DailyDoor)
        /// New mail found by the check that runs by itself, waiting quietly to be looked at.
        case newMail(DailyDoor.Look, DailyDoor)
        /// The demo's three made-up mails, found: the same panel, nothing read or sent.
        case demoReady
        /// The demo's three, found by the check that runs by itself.
        case demoNew
        case sending(String)
        /// Read by the AI, and offered: what of it is taken in, and where, is the owner's to say.
        case answered(Answered)
        case done(String, [IntakeSummary.Item] = [], [IntakeSummary.Mail] = [])
        case failed(String)
    }

    /// A round as it came back from the AI, with what it cost — not in any matter yet.
    struct Answered {
        var judgements: [Judgement]
        var cost: Double
        var failed: Int
        let look: DailyDoor.Look
        let door: DailyDoor
    }

    var state: State = .idle
    /// Which step it is at, for the panel's transitions: one view each, faded into the next.
    var phase: String {
        switch state {
        case .idle: "idle"
        case .reading: "reading"
        case .nothingNew: "nothing"
        case .ready, .demoReady: "ready"
        case .newMail, .demoNew: "new"
        case .sending: "sending"
        case .answered: "answered"
        case .done: "done"
        case .failed: "failed"
        }
    }
    /// Changes when a run ends, so the list of mail without a matter is read again.
    var stateKey: String {
        switch state {
        case .done(let text, _, _): "done " + text
        case .idle: "idle"
        default: "busy"
        }
    }
    var isBusy: Bool {
        switch state {
        case .reading, .sending: true
        default: false
        }
    }

    static var log: URL { PhoneCloud.storeLocation().deletingLastPathComponent().appendingPathComponent("decisions-fetch.jsonl") }

    /// When the last check, by hand or by itself, came back.
    var lastChecked: Date?
    private var checking = false

    /// New mail unticked once: not offered again on this iPhone.
    static let setAsideKey = "mail.setAside"
    static var setAside: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: Data((UserDefaults.standard.string(forKey: setAsideKey) ?? "[]").utf8))) ?? []) }
        set { UserDefaults.standard.set(String(decoding: (try? JSONEncoder().encode(newValue.sorted())) ?? Data("[]".utf8), as: UTF8.self), forKey: setAsideKey) }
    }

    /// The door to the label, or why there is none — the same for a check by hand or by itself.
    private func door(context: ModelContext) -> (door: DailyDoor?, why: String?) {
        guard let account = Keychain.accounts().first(where: { !$0.usesGoogle }) else {
            return (nil, "No mail account yet: add it in Settings (⋯ above).")
        }
        var door = DailyDoor(account: account, besides: PhoneCloud.storeLocation())
        door.model = ModelChoice.mail
        door.strict = ModelChoice.strict
        // This iPhone's own list, started from the Mac's, with the other devices' names in it.
        do { try NameLists.adopt(into: door.mapping, device: PhoneNames.device, in: context) } catch {
            return (nil, "The list of names cannot be written: \(error.localizedDescription)")
        }
        door.earlier = SortedMails.answered(in: context)
        // Mail in a matter was sorted somewhere: not read again, whatever the record says.
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        door.alsoKnown = Set(entries.map(\.messageID))
        door.setAside = Self.setAside
        // A Mac that sorted mail before shares what it sorted when the new Causabee starts there.
        // Until it has, every mail it answered would look new here — read again, and offered to
        // be sent again.
        if door.earlier.isEmpty, entries.contains(where: { $0.source.kind == .mail }) {
            return (nil, "Your Mac has not shared what it sorted yet. Open Causabee on your Mac once and wait a minute for iCloud — otherwise every mail would be read and sorted again.")
        }
        return (door, nil)
    }

    private var isQuiet: Bool {
        switch state {
        case .idle, .nothingNew, .done, .failed, .newMail, .demoNew: true
        default: false
        }
    }

    /// Checks by itself when Causabee opens or comes back to the front — not more than every two
    /// minutes — and only says something when there is new mail. Reading is free; nothing is sent.
    func checkQuietly(context: ModelContext) {
        guard isQuiet, !checking, lastChecked.map({ Date().timeIntervalSince($0) > 120 }) ?? true else { return }
        if DemoData.isRequested {
            // The demo's three are always new: the quiet line, ready to be looked at.
            lastChecked = Date()
            if AutoMode.isOn { sortInDemo(context: context) } else { state = .demoNew }
            return
        }
        // Auto turned on while new mail waited: it is read now.
        if AutoMode.isOn, case .newMail(let look, let door) = state {
            classify(look, with: door, context: context, owner: AutoMode.owner(in: context))
            return
        }
        guard let door = door(context: context).door else { return }
        checking = true
        Task {
            defer { checking = false }
            guard let password = try? Keychain.password(for: door.account.user),
                  let look = try? await door.look(password: password) else { return }
            lastChecked = Date()
            guard isQuiet else { return }
            // Auto: read at once, and offered to be taken in.
            if look.pending > 0, AutoMode.isOn { classify(look, with: door, context: context, owner: AutoMode.owner(in: context)) }
            else if look.pending > 0 { state = .newMail(look, door) } else if case .newMail = state { state = .idle }
        }
    }

    /// What another device sorted meanwhile is no longer asked about here: the mails it took in or
    /// put aside go from the line that says "new mails", from the list to tick, and from what was
    /// read and waits to be taken in. With none left, the prompt is gone.
    func settleElsewhere(context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let known = Set(SortedMails.answered(in: context).keys).union(entries.map(\.messageID))
        switch state {
        case .newMail(let look, let door):
            let left = Set(look.newIDs.filter { !known.contains($0) })
            if left.isEmpty { state = .idle } else if left.count < look.newIDs.count { state = .newMail(look.only(left), door) }
        case .ready(let look, let door):
            let left = Set(look.newIDs.filter { !known.contains($0) })
            if left.isEmpty { state = .idle } else if left.count < look.newIDs.count { state = .ready(look.only(left), door) }
        case .answered(var answered):
            let left = answered.judgements.filter { !known.contains($0.emailID) }
            if left.allSatisfy(\.isBulk) { state = .idle } else if left.count < answered.judgements.count {
                answered.judgements = left
                state = .answered(answered)
            }
        default: break
        }
    }

    /// A mail of the round moved by the owner: its line says where it is now.
    func moved(_ messageID: String, to name: String) {
        guard case .done(let text, let items, var mails) = state, let at = mails.firstIndex(where: { $0.messageID == messageID }) else { return }
        mails[at].matter = name
        state = .done(text, items, mails)
    }

    /// Sort in the ticked ones; the others are set aside, so they are not offered again. With none
    /// ticked, all are left out, and nothing is sent.
    func sortIn(_ chosen: Set<String>, of look: DailyDoor.Look, with door: DailyDoor, context: ModelContext, owner: [String]) {
        Self.setAside.formUnion(Set(look.newIDs).subtracting(chosen))
        guard !chosen.isEmpty else { state = .nothingNew(known: look.intake.alreadyKnown); return }
        classify(look.only(chosen), with: door, context: context, owner: owner)
    }

    func look(context: ModelContext) {
        guard !isBusy else { return }
        // A round that was read waits for its answer first.
        if case .answered = state { return }
        if DemoData.isRequested { lookInDemo(context: context); return }
        let (found, why) = door(context: context)
        guard let door = found else { state = .failed(why ?? "Mail cannot be read."); return }
        let account = door.account
        // Only that it is at it: how many mails the label holds is nothing to worry about.
        state = .reading("Fetching mail …")
        running = Task {
            do {
                guard let password = try Keychain.password(for: account.user) else {
                    state = .failed("No password for \(account.user) on this iPhone: add it in Settings (⋯ above).")
                    return
                }
                let look = try await door.look(password: password)
                guard !Task.isCancelled else { return }
                lastChecked = Date()
                if look.pending == 0 { state = .nothingNew(known: look.intake.alreadyKnown) }
                else if AutoMode.isOn { classify(look, with: door, context: context, owner: AutoMode.owner(in: context)) }
                else { state = .ready(look, door) }
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(plainWords(error))
            }
        }
    }

    @ObservationIgnored private var running: Task<Void, Never>?

    /// Stops reading: nothing was sent, and nothing is kept.
    /// The demo's round, at the pace of a real one: fetching, three new mails, sorting, and what
    /// came of it — the mails, a task and two dates in three matters. Nothing is read or sent.
    private func lookInDemo(context: ModelContext) {
        state = .reading("Fetching mail …")
        running = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            // Every time the whole round: the last one's three mails are taken out on Sort in.
            if AutoMode.isOn { sortInDemo(context: context) } else { state = .demoReady }
        }
    }

    func sortInDemo(context: ModelContext, only chosen: Set<Int> = Set(DemoData.newMail.indices)) {
        state = .sending("Sorting \(chosen.count) \(chosen.count == 1 ? "mail" : "mails") …")
        running = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            let taken = DemoData.takeInNewMail(context, only: chosen)
            // As a real run: a line in each matter's history, what came in.
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            for (index, matter) in taken {
                let mail = DemoData.newMail[index]
                let brought = index == 0 ? " · 1 new task" : " · 1 date"
                var turn = Navigation.Turn(question: "", scope: "Mail", inHand: nil, seen: "", refs: [:], matter: matter.persistentModelID)
                turn.note = "1 mail taken in" + brought + " · \(DemoData.demoIntakeMark)\n• " + mail.subject
                guard let payload = try? encoder.encode(turn) else { continue }
                let record = ThreadTurn(id: turn.id, date: turn.date, payload: payload)
                context.insert(record)
                record.matter = matter
            }
            try? context.save()
            let tasks = chosen.contains(0) ? 1 : 0
            state = .done(IntakeSummary.line(mails: taken.count, matters: taken.map(\.matter.name), tasks: tasks, dates: taken.count - tasks),
                          DemoData.newMailItems(chosen),
                          taken.map { IntakeSummary.Mail(messageID: "demo-new-\($0.index)@mail.example", subject: DemoData.newMail[$0.index].subject, matter: $0.matter.name) })
        }
    }

    func cancel() {
        running?.cancel()
        running = nil
        state = .idle
    }

    /// Sends what is new, pseudonymised, and keeps what came back as an offer: nothing is in a
    /// matter until the owner takes it in.
    func classify(_ look: DailyDoor.Look, with door: DailyDoor, context: ModelContext, owner: [String]) {
        guard let claude = ModelChoice.client(for: door.model) else {
            state = .failed(ModelChoice.missingKey(door.model))
            return
        }
        state = .sending("Reading \(look.pending) \(look.pending == 1 ? "mail" : "mails") …")
        // Paid for once: switching away from Causabee meanwhile does not stop it halfway.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Reading mail")
        Task {
            defer { UIApplication.shared.endBackgroundTask(background) }
            do {
                let (judgements, summary) = try await door.classify(look, claude: claude, owner: owner, matters: Unplaced.matters(in: context), placed: Unplaced.placed(in: context))
                let answered = Answered(judgements: judgements, cost: summary.cost, failed: summary.failed.count, look: look, door: door)
                // Only newsletters: nothing to decide on.
                if judgements.allSatisfy(\.isBulk) { take(answered, chosen: [], moved: [:], context: context, owner: owner) }
                else { Haptics.success(); state = .answered(answered) }
            } catch {
                Haptics.failure()
                state = .failed(plainWords(error))
            }
        }
    }

    /// Takes in what the owner left ticked, each into the matter suggested or the one chosen for it;
    /// with the tasks and dates left ticked in it; a mail that was unticked is put aside. All of it
    /// is recorded as read, so none is sent again.
    func take(_ answered: Answered, chosen: Set<String>, moved: [String: PersistentIdentifier], skipped: [String: Set<String>] = [:], context: ModelContext, owner: [String]) {
        let look = answered.look, door = answered.door
        do {
            let all = try context.fetch(FetchDescriptor<Matter>())
            let judgements = answered.judgements.filter { $0.isBulk || chosen.contains($0.emailID) }.map { judgement -> Judgement in
                // Only the tasks and dates the owner left ticked.
                var judgement = IntakeSummary.leaving(out: skipped[judgement.emailID] ?? [], of: judgement)
                guard let id = moved[judgement.emailID], let matter = all.first(where: { $0.persistentModelID == id }) else { return judgement }
                judgement.matter = matter.key
                judgement.matterTitle = nil
                return judgement
            }
            UnplacedAside.add(answered.judgements.filter { !$0.isBulk && !chosen.contains($0.emailID) }.map(\.emailID))
            let imported = try MatterImport.apply(judgements, to: context, owner: owner)
            // Into the record the other devices read, and the names it learned into the store.
            try SortedMails.record(answered.judgements, device: PhoneNames.device, in: context)
            PhoneNames.publish(in: context)
            let matters = try context.fetch(FetchDescriptor<Matter>())
            Self.logIntake(judgements, matters: matters, model: door.model.label, in: context)
            // Their important links, offered in their matters.
            let takenIDs = Set(judgements.map(\.emailID))
            for outcome in look.report.outcomes where takenIDs.contains(outcome.judgement.emailID) { _ = MailLinks.suggest(outcome.email, in: context) }
            try? context.save()
            let keys = Set(judgements.compactMap(\.matter))
            let names = matters.filter { matter in keys.contains { matter.answers(to: $0) } }.map(\.name)
            // Short: what came of it, and what it cost; what it brought, line by line, under it.
            let unplaced = judgements.filter { $0.matter == nil && !$0.isBulk }.count
            var text = IntakeSummary.line(mails: imported.mails, matters: names, tasks: imported.todosNew,
                                          dates: imported.appointments + imported.deadlines, unplaced: unplaced, cost: answered.cost)
            if answered.failed > 0 { text += " · \(answered.failed) failed" }
            // Each mail with the matter it went into: a wrong one is moved from here.
            let mails = IntakeSummary.mails(judgements) { key in matters.first { $0.answers(to: key) }?.name }
            Haptics.success()
            state = .done(text, IntakeSummary.items(judgements), mails)
        } catch {
            Haptics.failure()
            state = .failed(plainWords(error))
        }
    }

    /// What came in, as a line of each matter's history — as the Mac writes it.
    static func logIntake(_ judgements: [Judgement], matters: [Matter], model: String, in context: ModelContext) {
        var byMatter: [PersistentIdentifier: (matter: Matter, mails: [Judgement])] = [:]
        for judgement in judgements where !judgement.isBulk {
            guard let key = judgement.matter, let matter = matters.first(where: { $0.answers(to: key) }) else { continue }
            byMatter[matter.persistentModelID, default: (matter, [])].mails.append(judgement)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for (matter, mails) in byMatter.values {
            let tasks = mails.reduce(0) { $0 + $1.todos.filter { $0.sameAs == nil }.count }
            let dates = mails.reduce(0) { $0 + $1.appointments.count + $1.deadlines.count }
            let done = mails.reduce(0) { $0 + $1.done.count }
            var head = "\(mails.count) \(mails.count == 1 ? "mail" : "mails") taken in"
            if tasks > 0 { head += " · \(tasks) new \(tasks == 1 ? "task" : "tasks")" }
            if dates > 0 { head += " · \(dates) \(dates == 1 ? "date" : "dates")" }
            if done > 0 { head += " · \(done) shown done" }
            head += " · sorted by \(model)"
            let lines = mails.prefix(5).map { "• " + ($0.subject.isEmpty ? "(no subject)" : $0.subject) }
                + (mails.count > 5 ? ["• … and \(mails.count - 5) more"] : [])
            var turn = Navigation.Turn(question: "", scope: "Mail", inHand: nil, seen: "", refs: [:], matter: matter.persistentModelID)
            turn.note = ([head] + lines).joined(separator: "\n")
            guard let payload = try? encoder.encode(turn) else { continue }
            let record = ThreadTurn(id: turn.id, date: turn.date, payload: payload)
            context.insert(record)
            record.matter = matter
        }
    }
}

/// On the overview, under its line: "Get new mail", and what came of it — the Mac's sidebar
/// bottom, on the iPhone.
struct PhoneMailCheckView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var matters: [Matter]
    @State private var check = PhoneMailCheck.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var unplaced: [Judgement] = []
    @State private var showsUnplaced = true
    /// Mail set aside with "Not needed" — on this device, as on the Mac.
    @AppStorage("unplaced.setAside") private var setAsideJSON = "[]"

    private var setAside: Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(setAsideJSON.utf8))) ?? []) }

    private func refresh() {
        unplaced = Unplaced.find(log: PhoneMailCheck.log, context: context, setAside: setAside)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // One step at a time: the button opens into the panel, the panel turns into the
            // result — each faded into the next while the box takes its new height.
            stage
                .id(check.phase)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
            unplacedList
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35), value: check.phase)
        .onAppear { refresh(); check.checkQuietly(context: context) }
        .onChange(of: check.stateKey) { refresh() }
        // Mail the Mac sorted meanwhile is not asked about here any more.
        .onChange(of: StoredChanges.shared.count) { check.settleElsewhere(context: context) }
        // Back to the front: a look whether new mail came, by itself — iOS lets no app check
        // reliably while it is away.
        .onChange(of: phase) { _, now in if now == .active { check.checkQuietly(context: context) } }
    }

    /// Found by itself: a small capsule in the middle, opened when the owner wants.
    private func quiet(_ count: Int, open: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 8) {
                    Circle().fill(Theme.bee).frame(width: 8, height: 8)
                    Text("\(count) new \(count == 1 ? "mail" : "mails")").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text("Review").font(.subheadline).foregroundStyle(Theme.gold)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.box, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // The same words in the demo: its list says it is the demo, once opened.
            Text("Checked when you opened Causabee")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var stage: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch check.state {
            case .idle:
                button
            case .reading(let text):
                // Centred, as the button it came from: the bee at work, and Cancel under it.
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        BeeLoader(size: 15)
                        Text(text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Cancel") { check.cancel() }.buttonStyle(.phone)
                }
                .frame(maxWidth: .infinity)
                .phoneBox()
            case .sending(let text):
                HStack(spacing: 10) {
                    BeeLoader(size: 15)
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .phoneBox()
            case .nothingNew:
                Text("No new mail.").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    // Apart from the overview's sentence above: its own line, not part of it.
                    .padding(.top, 14)
                button
            case .newMail(let look, let door):
                quiet(look.pending) { check.state = .ready(look, door) }
            case .demoNew:
                quiet(DemoData.newMail.count) { check.state = .demoReady }
            case .ready(let look, let door):
                PhoneMailReview(look: look, door: door) {
                    check.state = .newMail(look, door)
                } sortIn: { chosen in
                    check.sortIn(chosen, of: look, with: door, context: context, owner: profiles.first?.names ?? [])
                }
            case .answered(let answered):
                PhoneMailVerdict(answered: answered) { chosen, moved, skipped in
                    check.take(answered, chosen: chosen, moved: moved, skipped: skipped, context: context, owner: profiles.first?.names ?? [])
                }
            case .demoReady:
                PhoneDemoMailReview(later: { check.state = .demoNew }) { chosen in check.sortInDemo(context: context, only: chosen) }
            case .done(let text, let items, let mails):
                Label(text, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Theme.done)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.top, 14)
                if !items.isEmpty || !mails.isEmpty {
                    // Where each mail went — a wrong one moved from here — and what it brought.
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(mails, id: \.messageID) { mail in
                            PhoneIntakeMailRow(mail: mail) { name in check.moved(mail.messageID, to: name) }
                        }
                        ForEach(items, id: \.self) { item in
                            Label(item.text, systemImage: item.symbol).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .phoneBox()
                }
                button
            case .failed(let text):
                Label(text, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(Theme.warning).textSelection(.enabled)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.top, 14)
                button
            }
        }
    }

    /// In the middle, with room above and below: the overview's one thing to do.
    private var button: some View {
        Button { check.look(context: context) } label: {
            Label("Get new mail", systemImage: "arrow.down.circle")
        }
        .buttonStyle(.phone)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .accessibilityHint(AutoMode.isOn ? "Auto is on: new mail with the label is read by the AI at once. You decide what is taken in."
                                         : "Reads only new mail with the label. Nothing is sent until you tap Sort in.")
    }

    /// Mail that was read but found no matter: to put into one, or to set aside.
    @ViewBuilder
    private var unplacedList: some View {
        if !unplaced.isEmpty {
            DisclosureGroup(isExpanded: $showsUnplaced) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(unplaced, id: \.emailID) { mail in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mail.subject.isEmpty ? "(no subject)" : mail.subject).font(.subheadline.weight(.medium)).lineLimit(2)
                            if let digest = mail.digest, !digest.isEmpty {
                                Text(digest).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                            }
                            HStack(spacing: 16) {
                                Menu("Add to …") {
                                    ForEach(matters.filter { !$0.isClosed }.sorted { $0.name < $1.name }) { matter in
                                        Button(matter.name) {
                                            try? Unplaced.place(mail, in: matter, context: context, owner: profiles.first?.names ?? [])
                                            refresh()
                                        }
                                    }
                                }
                                .tint(Theme.gold)
                                Button("Not needed") {
                                    var ids = setAside
                                    ids.insert(mail.emailID)
                                    setAsideJSON = String(decoding: (try? JSONEncoder().encode(Array(ids))) ?? Data("[]".utf8), as: UTF8.self)
                                    refresh()
                                }
                                .buttonStyle(.gold)
                            }
                            .font(.footnote)
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("No matter found · \(unplaced.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
            .tint(.secondary)
            .phoneBox()
        }
    }
}

/// The new mails, each with a tick: Sort in sends only the ticked ones, at the cost shown; the
/// unticked ones are set aside. Later puts the list away; the capsule stays.
struct PhoneMailReview: View {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("\(look.pending) new \(look.pending == 1 ? "mail" : "mails")").font(.headline)
            ForEach(look.newMails, id: \.judgement.emailID) { outcome in
                let id = outcome.judgement.emailID, on = chosen.contains(id)
                Button {
                    if on { chosen.remove(id) } else { chosen.insert(id) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3)
                            .foregroundStyle(on ? Theme.gold : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(outcome.email.subject.isEmpty ? "(no subject)" : outcome.email.subject).font(.subheadline)
                                .strikethrough(!on).foregroundStyle(on ? .primary : .secondary)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Text(Self.from(outcome.email)).font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Text(chosen.isEmpty ? "None ticked: “Leave out” puts \(look.pending == 1 ? "it" : "them") aside, and \(look.pending == 1 ? "it is" : "they are") not offered again. “Later” keeps \(look.pending == 1 ? "it" : "them") for the next time."
                 : String(format: "Sorting in %d %@ costs about $%.2f. Sent pseudonymised to %@.", chosen.count, chosen.count == 1 ? "mail" : "mails",
                          look.only(chosen).estimate, door.model.label))
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Later", action: later).buttonStyle(.phone)
                // With none ticked the button leaves them out — "Later" alone would only bring them back.
                Button(chosen.isEmpty ? "Leave out" : chosen.count == look.pending ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
                    .buttonStyle(.phoneFilled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneBox()
    }

    static func from(_ email: Email) -> String {
        let who = Email.displayName(in: email.from) ?? Email.address(in: email.from)
        guard let date = email.date else { return who }
        let time = Calendar.current.isDateInToday(date) ? date.formatted(.dateTime.hour().minute()) : Dates.short(date)
        return who + " · " + time
    }
}

/// The round as the AI read it, before any of it is in a matter: each mail with a tick, the matter
/// it would go into, and what it brings. "Take in" does what is ticked; the rest is put aside.
struct PhoneMailVerdict: View {
    let answered: PhoneMailCheck.Answered
    let take: (Set<String>, [String: PersistentIdentifier], [String: Set<String>]) -> Void
    @Query private var matters: [Matter]
    @State private var chosen: Set<String>
    @State private var moved: [String: PersistentIdentifier] = [:]
    @State private var skipped: [String: Set<String>] = [:]

    init(answered: PhoneMailCheck.Answered, take: @escaping (Set<String>, [String: PersistentIdentifier], [String: Set<String>]) -> Void) {
        self.answered = answered
        self.take = take
        // A mail no matter was found for starts unticked: put aside with one tap, ticked only to place it.
        _chosen = State(initialValue: Set(answered.judgements.filter { !$0.isBulk && $0.matter != nil }.map(\.emailID)))
    }

    var body: some View {
        let offers = IntakeSummary.offers(answered.judgements) { key in matters.first { $0.answers(to: key) }?.name }
        let bulk = answered.judgements.count - offers.count
        VStack(alignment: .leading, spacing: 10) {
            Text("\(offers.count) \(offers.count == 1 ? "mail" : "mails") read").font(.headline)
            MailOffers(offers: offers, chosen: $chosen, moved: $moved, skipped: $skipped)
            Text(String(format: "Read for $%.3f. Nothing is in a matter yet: tick what you want of it — the mails, and each task and date. The rest is put aside.", answered.cost)
                 + (bulk > 0 ? " \(bulk) left out as \(bulk == 1 ? "a newsletter" : "newsletters")." : ""))
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(chosen.isEmpty ? "Leave out" : chosen.count == offers.count ? "Take in" : "Take in \(chosen.count)") { take(chosen, moved, skipped) }
                .buttonStyle(.phoneFilled)
                .accessibilityIdentifier("mail.takeIn")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneBox()
    }
}

/// The demo's three, each with a tick, as a real round has them: nothing is read, sent or paid.
struct PhoneDemoMailReview: View {
    let later: () -> Void
    let sortIn: (Set<Int>) -> Void
    @State private var chosen = Set(DemoData.newMail.indices)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(DemoData.newMail.count) new mails").font(.headline)
            ForEach(Array(DemoData.newMail.enumerated()), id: \.offset) { index, mail in
                let on = chosen.contains(index)
                Button { if on { chosen.remove(index) } else { chosen.insert(index) } } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(on ? Theme.gold : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mail.subject).font(.subheadline).strikethrough(!on).foregroundStyle(on ? .primary : .secondary)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Text(Email.displayName(in: mail.from) ?? mail.from).font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("In the demo, sorting in sends nothing and costs nothing.").font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Later", action: later).buttonStyle(.phone)
                Button(chosen.count == DemoData.newMail.count ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
                    .buttonStyle(.phoneFilled).disabled(chosen.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneBox()
    }
}

/// One mail of the round: its subject, the matter it went into, and Move — to another matter.
struct PhoneIntakeMailRow: View {
    let mail: IntakeSummary.Mail
    let moved: (String) -> Void
    @Query private var matters: [Matter]
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(mail.subject, systemImage: "envelope").font(.subheadline.weight(.medium)).lineLimit(2)
            HStack(spacing: 6) {
                Text("→ " + mail.matter).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Menu("Move") {
                    ForEach(PhoneMoveMail.order(matters, current: nil).filter { $0.name != mail.matter }) { matter in
                        Button(matter.name) {
                            let id = mail.messageID
                            guard let entry = try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.messageID == id })).first else { return }
                            PhoneMoveMail.move(entry, to: matter, in: context)
                            moved(matter.name)
                        }
                    }
                }
                .font(.footnote).tint(Theme.gold)
            }
            .padding(.leading, 28)
        }
    }
}
