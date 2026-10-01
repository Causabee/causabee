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
        case sending(String)
        case done(String)
        case failed(String)
    }

    var state: State = .idle
    /// Which step it is at, for the panel's transitions: one view each, faded into the next.
    var phase: String {
        switch state {
        case .idle: "idle"
        case .reading: "reading"
        case .nothingNew: "nothing"
        case .ready: "ready"
        case .sending: "sending"
        case .done: "done"
        case .failed: "failed"
        }
    }
    /// Changes when a run ends, so the list of mail without a matter is read again.
    var stateKey: String {
        switch state {
        case .done(let text): "done " + text
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

    func look(context: ModelContext) {
        guard !isBusy else { return }
        guard let account = Keychain.accounts().first(where: { !$0.usesGoogle }) else {
            state = .failed("No mail account yet: add it in Settings (⋯ above).")
            return
        }
        var door = DailyDoor(account: account, besides: PhoneCloud.storeLocation())
        door.model = ModelChoice.mail
        door.strict = ModelChoice.strict
        // This iPhone's own list, started from the Mac's, with the other devices' names in it.
        do { try NameLists.adopt(into: door.mapping, device: PhoneNames.device, in: context) } catch {
            state = .failed("The list of names cannot be written: \(error.localizedDescription)")
            return
        }
        door.earlier = SortedMails.answered(in: context)
        // Mail in a matter was sorted somewhere: not read again, whatever the record says.
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        door.alsoKnown = Set(entries.map(\.messageID))
        // A Mac that sorted mail before shares what it sorted when the new Matterbee starts there.
        // Until it has, every mail it answered would look new here — read again, and offered to
        // be sent again.
        if door.earlier.isEmpty, entries.contains(where: { $0.source.kind == .mail }) {
            state = .failed("Your Mac has not shared what it sorted yet. Open Matterbee on your Mac once and wait a minute for iCloud — otherwise every mail would be read and sorted again.")
            return
        }
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
                state = look.pending == 0 ? .nothingNew(known: look.intake.alreadyKnown) : .ready(look, door)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed("\(error)")
            }
        }
    }

    @ObservationIgnored private var running: Task<Void, Never>?

    /// Stops reading: nothing was sent, and nothing is kept.
    func cancel() {
        running?.cancel()
        running = nil
        state = .idle
    }

    func classify(_ look: DailyDoor.Look, with door: DailyDoor, context: ModelContext, owner: [String]) {
        guard let claude = ModelChoice.client(for: door.model) else {
            state = .failed(ModelChoice.missingKey(door.model))
            return
        }
        state = .sending("Sorting \(look.pending) \(look.pending == 1 ? "mail" : "mails") …")
        // Paid for once: switching away from Matterbee meanwhile does not stop it halfway.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Sorting mail")
        Task {
            defer { UIApplication.shared.endBackgroundTask(background) }
            do {
                let (judgements, summary) = try await door.classify(look, claude: claude, owner: owner, matters: Unplaced.matters(in: context))
                let imported = try MatterImport.apply(judgements, to: context, owner: owner)
                // Into the record the other devices read, and the names it learned into the store.
                try SortedMails.record(judgements, device: PhoneNames.device, in: context)
                PhoneNames.publish(in: context)
                let matters = try context.fetch(FetchDescriptor<Matter>())
                Self.logIntake(judgements, matters: matters, model: door.model.label, in: context)
                // Their important links, offered in their matters.
                let links = look.report.outcomes.reduce(0) { $0 + MailLinks.suggest($1.email, in: context) }
                try? context.save()
                let keys = Set(judgements.compactMap(\.matter))
                let names = matters.filter { matter in keys.contains { matter.answers(to: $0) } }.map(\.name)
                // Short: what came of it, and what it cost. The model is in each matter's history.
                var text = "\(imported.mails) \(imported.mails == 1 ? "mail" : "mails") sorted"
                if !names.isEmpty { text += " into " + names.joined(separator: ", ") }
                if imported.mattersNew > 0 { text += " · \(imported.mattersNew) new \(imported.mattersNew == 1 ? "matter" : "matters")" }
                if imported.todosNew > 0 { text += " · \(imported.todosNew) new \(imported.todosNew == 1 ? "task" : "tasks")" }
                let unplaced = judgements.filter { $0.matter == nil && !$0.isBulk }.count
                if unplaced > 0 { text += " · \(unplaced) without a matter, below" }
                if links > 0 { text += " · \(links) \(links == 1 ? "link" : "links") suggested" }
                text += String(format: " · $%.3f", summary.cost)
                if !summary.failed.isEmpty { text += " · \(summary.failed.count) failed" }
                state = .done(text)
            } catch {
                state = .failed("\(error)")
            }
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
        .onAppear(perform: refresh)
        .onChange(of: check.stateKey) { refresh() }
    }

    @ViewBuilder
    private var stage: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch check.state {
            case .idle:
                button
            case .reading(let text):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        BeeLoader(size: 15)
                        Text(text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Cancel") { check.cancel() }.buttonStyle(.phone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).phoneBox()
            case .sending(let text):
                HStack(spacing: 10) {
                    BeeLoader(size: 15)
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).phoneBox()
            case .nothingNew:
                Text("No new mail.").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                button
            case .ready(let look, let door):
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(look.pending) new \(look.pending == 1 ? "mail" : "mails")").font(.headline)
                    ForEach(Array(look.report.outcomes.filter { $0.judgement.disguise != nil }.prefix(5).enumerated()), id: \.offset) { _, outcome in
                        Text("• " + (outcome.email.subject.isEmpty ? "(no subject)" : outcome.email.subject))
                            .font(.subheadline).lineLimit(2)
                    }
                    Text(String(format: "Sorting in costs about $%.2f. Sent pseudonymised to %@.", look.estimate, door.model.label))
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button("Cancel") { check.state = .idle }.buttonStyle(.phone)
                        Button("Sort in") { check.classify(look, with: door, context: context, owner: profiles.first?.names ?? []) }
                            .buttonStyle(.phoneFilled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).phoneBox()
            case .done(let text):
                Label(text, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Theme.done)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                button
            case .failed(let text):
                Label(text, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(Theme.warning).textSelection(.enabled)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
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
        .accessibilityHint("Reads only new mail with the label. Nothing is sent until you tap Sort in.")
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
            .padding(14).phoneBox()
        }
    }
}
