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
        case sending(String)
        case done(String)
        case failed(String)
    }

    var state: State = .idle
    /// Told what was taken in, to write it into the matters' threads.
    var taken: (([Judgement], String) -> Void)?
    /// Changes when a run ends, so the list of mail without a matter is read again.
    var stateKey: String {
        switch state {
        case .done(let text): "done " + text
        case .idle: "idle"
        default: "busy"
        }
    }

    func look(store: URL, context: ModelContext) {
        guard let account = Keychain.accounts().first else {
            state = .failed("No mail account yet. Choose Matterbee → Set Up Matterbee … to log in.")
            return
        }
        var door = DailyDoor(account: account, besides: store)
        door.model = ModelChoice.mail
        door.strict = ModelChoice.strict
        // What the iPhone or the other Mac sorted is known here too, and their names disguised.
        NameListPublisher.adopt()
        door.earlier = SortedMails.answered(in: context)
        state = .reading("Reading “\(door.label)” at \(door.account.host) …")
        Task {
            do {
                guard let password = try await MailSecret.secret(for: account) else {
                    state = .failed("No password for \(account.user) in the Keychain. Choose Matterbee → Set Up Matterbee … to log in again.")
                    return
                }
                let look = try await door.look(password: password)
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
                var text = "\(imported.mails) \(imported.mails == 1 ? "mail" : "mails") sorted"
                if !names.isEmpty { text += " · in: " + names.joined(separator: ", ") }
                if imported.mattersNew > 0 { text += " · \(imported.mattersNew) new \(imported.mattersNew == 1 ? "matter" : "matters")" }
                if imported.todosNew > 0 { text += " · \(imported.todosNew) new \(imported.todosNew == 1 ? "task" : "tasks")" }
                let unplaced = judgements.filter { $0.matter == nil && !$0.isBulk }.count
                if unplaced > 0 { text += " · \(unplaced) without a matter, below" }
                if links > 0 { text += " · \(links) \(links == 1 ? "link" : "links") suggested" }
                text += String(format: " · %@ · $%.3f", door.model.label, summary.cost)
                if !summary.failed.isEmpty { text += " · \(summary.failed.count) failed" }
                state = .done(text)
            } catch {
                state = .failed("\(error)")
            }
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
            switch check.state {
            case .idle:
                button
            case .reading(let text), .sending(let text):
                HStack(spacing: 8) {
                    BeeLoader()
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
            case .nothingNew(let known):
                Text("Nothing new. Matterbee already knows \(known) mails.").font(.caption).foregroundStyle(.secondary)
                button
            case .ready(let look, let door):
                Text("\(look.pending) new \(look.pending == 1 ? "mail" : "mails")").font(.callout.weight(.semibold))
                ForEach(Array(look.report.outcomes.filter { $0.judgement.disguise != nil }.prefix(5).enumerated()), id: \.offset) { _, outcome in
                    Text("• " + (outcome.email.subject.isEmpty ? "(no subject)" : outcome.email.subject))
                        .font(.caption).lineLimit(2)
                }
                Text(String(format: "Sorting in costs about $%.2f. Sent pseudonymised to %@.", look.estimate, door.model.label))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { check.state = .idle }
                    Button("Sort in") {
                        check.classify(look, with: door, context: context, owner: profiles.first?.names ?? [])
                    }
                    
                    .inkButton()
                }
            case .done(let text):
                Label(text, systemImage: "checkmark.circle").font(.caption).foregroundStyle(Theme.done)
                button
            case .failed(let text):
                Label(text, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled)
                button
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The sidebar's own grey under it, a line above: part of the sidebar, not a bar on it.
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            refresh()
            check.taken = { judgements, model in navigation.logIntake(judgements, matters: matters, model: model) }
        }
        .onChange(of: check.stateKey) { refresh() }
    }

    @ViewBuilder
    private var button: some View {
        if DemoData.isRequested, !SetupState.isFresh, IntroShot.current == nil {
            // The demo's matters are made up: no real mail comes into them, and the way back is here.
            // The introduction's pictures show the button a real start has.
            Button { DemoData.restart(demo: false) } label: {
                Label("Leave the demo", systemImage: "arrow.uturn.backward.circle")
            }
            .help("Starts Matterbee again with your own matters. The demo stays apart, in its own store.")
        } else {
            Button { check.look(store: navigation.store, context: context) } label: {
                Label("Get new mail", systemImage: "arrow.down.circle")
            }
            .help("Reads only new mail with the label. Nothing is sent until you click “Sort in”.")
        }
    }
}
