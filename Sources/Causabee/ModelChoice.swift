import CoreData
import MatterCore
import SwiftData
import SwiftUI

/// Which model does which job, as the owner chose in the settings (⌘,, or Settings on the iPhone).
/// Opus unless changed. Shared by both apps, and the choice is too: it travels with the owner's
/// profile through iCloud, so a newly installed app starts with the model chosen elsewhere.
enum ModelChoice {
    static let mailKey = "model.mail", assistantKey = "model.assistant", strictKey = "model.strict"

    private static func model(_ key: String) -> Claude.Model {
        UserDefaults.standard.string(forKey: key).flatMap { id in Claude.Model.choices.first { $0.id == id } } ?? .opus
    }

    /// Sorting new mail, screenshots and files into matters.
    static var mail: Claude.Model { model(mailKey) }
    /// Answers, summaries, the next step.
    static var assistant: Claude.Model { model(assistantKey) }
    /// Fewer, real to-dos — on by default, and only ever given to Mistral or OpenAI: Opus's
    /// instructions stay as its answers were made with.
    static var strict: Bool { (mail.isMistral || mail.isOpenAI) && (UserDefaults.standard.object(forKey: strictKey) as? Bool ?? true) }

    /// The API client for the model, with the key its API takes; nil when that key is missing.
    static func client(for model: Claude.Model) -> Claude? { Claude.key(for: model).map(Claude.init) }

    static func missingKey(_ model: Claude.Model) -> String {
        #if os(iOS)
        let settings = "Settings (⋯ on the overview) — or on your Mac: a key saved there comes through iCloud Keychain"
        #else
        let settings = "Settings (⌘,)"
        #endif
        return model.isMistral ? "No Mistral key: paste it in \(settings)."
            : model.isOpenAI ? "No OpenAI key: paste it in \(settings)." : "No Claude key: paste it in \(settings)."
    }
}

#if os(macOS)
/// ⌘, — which model sorts the mail and which answers. Both see only pseudonymised text.
struct ModelSettingsView: View {
    @AppStorage(ModelChoice.mailKey) private var mail = Claude.Model.opus.id
    @AppStorage(ModelChoice.assistantKey) private var assistant = Claude.Model.opus.id
    @AppStorage(ModelChoice.strictKey) private var strict = true

    var body: some View {
        Form {
            Section {
                picker("Sort mail", selection: $mail)
                if mail.hasPrefix("mistral") || mail.hasPrefix("gpt-") {
                    Toggle("Fewer, real tasks", isOn: $strict)
                        .help("The rule from the test: no task for saying yes or getting ready, unless the mail asks for it.")
                }
                Text(estimate(mail) + " A mail is sorted only once: what a model sorted in stays that way.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: { Text("New mail, screenshots, files") }
            Section {
                picker("Assistant", selection: $assistant)
                Text("Answers, summaries and the next step. Under each answer you see which model wrote it.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: { Text("Questions") }
            Section { CloudSettings() } header: { Text("iCloud") }
            Section { CalendarSettings() } header: { Text("Calendar and Reminders") }
            Section { FolderSettings() } header: { Text("Matter folders in iCloud Drive") }
            Section {
                KeyField(title: "Claude (Anthropic)", name: "ANTHROPIC_API_KEY")
                KeyField(title: "Mistral", name: "MISTRAL_API_KEY")
                KeyField(title: "OpenAI", name: "OPENAI_API_KEY")
            } header: { Text("API keys") } footer: {
                Text("Pasted here, kept in the Keychain like the mail password. Never in a file.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("All of them get only pseudonymised text: Claude (Anthropic, USA), Mistral (Paris) or OpenAI (USA). In the test, Mistral Large 3 sorted almost as well as Opus; for tasks, Opus was better in about one mail out of three.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding(.vertical, 8)
    }

    private func picker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Claude.Model.choices, id: \.id) { model in
                Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
            }
        }
    }

    private func estimate(_ id: String) -> String {
        let model = Claude.Model.choices.first { $0.id == id } ?? .opus
        return String(format: "About %.2f cents per mail.", model.perMail * 100)
    }
}
#endif

/// One key: whether it is there and where from, a field to paste a new one, and a way to remove it.
struct KeyField: View {
    let title: String
    let name: String
    @State private var pasted = ""
    @State private var stored = false
    @State private var error: String?

    var body: some View {
        let found = stored || Claude.key(named: name) != nil
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(stored ? "in the Keychain" : found ? "from .env" : "missing")
                    .font(.caption).foregroundStyle(found ? Theme.done : Theme.warning)
            }
            HStack {
                SecureField("Paste a new key", text: $pasted).textFieldStyle(.roundedBorder)
                Button("Save") {
                    do { try APIKeys.save(pasted, as: name); pasted = ""; error = nil } catch { self.error = plainWords(error) }
                    stored = APIKeys.get(name) != nil
                }
                .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
                if stored { Button("Remove") { APIKeys.delete(name); stored = false } }
            }
            #if os(iOS)
            // In a form's row on the iPhone a tap anywhere presses every plain button in it:
            // Save, and then Remove. Borderless, each is pressed only where it stands.
            .buttonStyle(.borderless)
            #endif
            if let error { Text(error).font(.caption).foregroundStyle(Theme.warning) }
        }
        .onAppear { stored = APIKeys.get(name) != nil }
    }
}

/// Keeps the model choice the same on every device. What is chosen here goes into the synced
/// profile; what was chosen on another device comes from it. A device that never chose — a new
/// install — takes the profile's and does not overwrite it with Opus.
struct ModelChoiceSync: ViewModifier {
    @Query private var profiles: [Profile]
    @Environment(\.modelContext) private var context
    @AppStorage(ModelChoice.mailKey) private var mail = ""
    @AppStorage(ModelChoice.assistantKey) private var assistant = ""

    func body(content: Content) -> some View {
        content
            .onAppear(perform: takeOver)
            .onChange(of: profiles.first?.mailModel) { takeOver() }
            .onChange(of: profiles.first?.assistantModel) { takeOver() }
            .onChange(of: profiles.count) { takeOver() }
            .onChange(of: mail) { pass(on: mail, to: \.mailModel) }
            .onChange(of: assistant) { pass(on: assistant, to: \.assistantModel) }
    }

    /// The profile's choice becomes this device's; where the profile has none yet, this device's
    /// own choice — if it ever made one — becomes the profile's.
    private func takeOver() {
        guard !DemoData.isRequested, let profile = profiles.first else { return }
        if let chosen = profile.mailModel { if mail != chosen { mail = chosen } } else { pass(on: mail, to: \.mailModel) }
        if let chosen = profile.assistantModel { if assistant != chosen { assistant = chosen } } else { pass(on: assistant, to: \.assistantModel) }
    }

    private func pass(on id: String, to field: ReferenceWritableKeyPath<Profile, String?>) {
        guard !DemoData.isRequested, !id.isEmpty, let profile = profiles.first, profile[keyPath: field] != id else { return }
        profile[keyPath: field] = id
        try? context.save()
    }
}

/// Counts up whenever the store was written to — here, or by iCloud bringing in what another device
/// changed. The pages read it, so they are drawn again with what is true now. iCloud says "imported"
/// before the app's own context has taken the change in, so the count goes up when the store itself
/// reports a write, and again a moment later.
@MainActor
@Observable
final class StoredChanges {
    static let shared = StoredChanges()
    private(set) var count = 0
    /// The app's context, for the debug build's report of what it sees.
    @ObservationIgnored var context: ModelContext?
    @ObservationIgnored private var watching = false
    @ObservationIgnored private var pending = false

    func watch(_ context: ModelContext) {
        self.context = context
        guard !watching else { return }
        watching = true
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { StoredChanges.shared.changed() }
        }
    }

    /// One write is many notices: they are gathered, and the pages redrawn a few times after — tested
    /// with two Causabees on the test container, the context had another device's tick about four
    /// seconds after the store reported the write, not at once.
    private func changed() {
        guard !pending else { return }
        pending = true
        for delay in [0.5, 2, 4, 8, 15] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if delay == 2 { self.pending = false }
                self.count += 1
                #if DEBUG
                if CommandLine.arguments.contains("--report-changes"), let context = self.context {
                    let todos = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
                    fputs("StoredChanges \(self.count): \(todos.filter(\.isDone).count) of \(todos.count) tasks done\n", stderr)
                }
                #endif
            }
        }
    }
}

/// Under a matter's next step and its summary while Auto is on, in the place of the link that
/// asks for them: Auto does the asking. "Auto mode", or that the record has changed and they are
/// written in a moment.
struct AutoLine: View {
    let matter: Matter
    var size: CGFloat = 10

    var body: some View {
        let soon = AutoUpdate.shared.pending.contains(matter.key)
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill").font(.system(size: size))
            Text(soon ? "Changed · Auto updates this in a moment" : "Auto mode")
        }
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("auto.line")
    }
}

/// Auto, the whole circle: when a matter's record has changed, its next step and its summary are
/// written again by themselves — what "ask again" and "Update" do on a tap.
///
/// - What counts as a change: `Matter.recordStamp` is another — a mail, a file, a task, a date, a note.
/// - Bundled: a matter is written again only once its record has stood still from one look to the
///   next, so a round of mail that brings three things is one update, not three.
/// - Never for the first sight of a matter: turning Auto on writes nothing; only what changes after.
/// - What it spent is kept by the day, and which step and summary it wrote, to say so beside them.
/// - Written on another device meanwhile: taken as it is, not paid for twice.
@MainActor
@Observable
final class AutoUpdate {
    static let shared = AutoUpdate()

    /// The names to disguise with: the Mac's file of them, or the iPhone's list.
    enum Names {
        case file(URL)
        case list(Pseudonymizer.Mapping, [Pseudonymizer.Entry])
    }

    /// The matters being written right now: their boxes say so.
    private(set) var working: Set<String> = []
    /// Counts up with every update done, so that what is shown of it is drawn again.
    private(set) var done = 0
    /// The matters whose record has changed and is coming to rest: written in a moment, and said so.
    private(set) var pending: Set<String> = []
    /// How often it looks. A matter is written once it has stood still from one look to the next.
    private static let pace: Duration = .seconds(3)

    private struct Known: Codable {
        var stamp: String
        /// When Auto wrote the step and the summary, as the matter says it: beside them, "Auto".
        var stepAt: Date?
        var summaryAt: Date?
    }

    @ObservationIgnored private var lastSeen: [String: String] = [:]
    private static let knownKey = "auto.known", spentKey = "auto.spent"

    private static var known: [String: Known] {
        get { (UserDefaults.standard.data(forKey: knownKey)).flatMap { try? JSONDecoder().decode([String: Known].self, from: $0) } ?? [:] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: knownKey) }
    }

    /// What Auto spent on a day, in dollars.
    static func spent(on day: String = MatterStatus.day(Date())) -> Double {
        (UserDefaults.standard.dictionary(forKey: spentKey) as? [String: Double])?[day] ?? 0
    }

    /// "Auto · $0.12 today", or nil when it spent nothing today.
    static var spentWords: String? {
        let spent = spent()
        return spent > 0 ? String(format: "Auto has spent $%.2f today on next steps and summaries", spent) : nil
    }

    private static func add(_ cost: Double) {
        var all = (UserDefaults.standard.dictionary(forKey: spentKey) as? [String: Double]) ?? [:]
        let today = MatterStatus.day(Date())
        all[today, default: 0] += cost
        // A month of days is enough to look back on.
        for day in all.keys.sorted().dropLast(31) { all[day] = nil }
        UserDefaults.standard.set(all, forKey: spentKey)
    }

    /// The step, or the summary, as it stands was written by Auto.
    static func wroteStep(of matter: Matter) -> Bool {
        guard let at = matter.nextStepAt, let mine = known[matter.key]?.stepAt else { return false }
        return abs(at.timeIntervalSince(mine)) < 1
    }
    static func wroteSummary(of matter: Matter) -> Bool {
        guard let at = matter.summaryAt, let mine = known[matter.key]?.summaryAt else { return false }
        return abs(at.timeIntervalSince(mine)) < 1
    }

    /// For as long as the app's first view is there: a look every quarter of a minute. The matters
    /// are read from the store each time — not from the view that started this, whose copy of them
    /// is the one it had then.
    func run(context: ModelContext, names: @escaping () throws -> Names) async {
        // A test starts from nothing known.
        if CommandLine.arguments.contains("--auto-anew") { Self.known = [:] }
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pace)
            guard AutoMode.isOn else { lastSeen = [:]; if !pending.isEmpty { pending = [] }; continue }
            let matters = (try? context.fetch(FetchDescriptor<Matter>())) ?? []
            look(matters, context: context, owner: AutoMode.owner(in: context).first, names: names)
        }
    }

    /// Looks at every matter going on, every few seconds while Auto is on; cheap, and sends nothing
    /// unless one has changed and come to rest.
    func look(_ matters: [Matter], context: ModelContext, owner: String?, names: () throws -> Names) {
        guard AutoMode.isOn else { lastSeen = [:]; return }
        var known = Self.known
        defer { Self.known = known }
        for matter in matters where !matter.isClosed && !working.contains(matter.key) {
            let key = matter.key, stamp = matter.recordStamp
            guard let before = known[key] else { known[key] = Known(stamp: stamp); continue }
            guard before.stamp != stamp else { lastSeen[key] = nil; if pending.contains(key) { pending.remove(key) }; continue }
            // Both written elsewhere in the last minutes — the other device's Auto: taken as they are.
            if let step = matter.nextStepAt, let summary = matter.summaryAt, step != before.stepAt, summary != before.summaryAt,
               min(step, summary) > Date().addingTimeInterval(-600) {
                known[key] = Known(stamp: stamp)
                pending.remove(key)
                continue
            }
            // Still changing: once more round — and said meanwhile, that it will be written.
            guard lastSeen[key] == stamp else { lastSeen[key] = stamp; if !pending.contains(key) { pending.insert(key) }; continue }
            lastSeen[key] = nil
            pending.remove(key)
            // The demo sends nothing and costs nothing: after a moment, the step worked out on the
            // device and the summary as it stands, marked as Auto's — to see how it goes.
            if DemoData.isRequested {
                known[key] = Known(stamp: stamp, stepAt: before.stepAt, summaryAt: before.summaryAt)
                working.insert(key)
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    defer { working.remove(key); done += 1 }
                    guard AutoMode.isOn else { return }
                    let now = Date()
                    if let rule = MatterStatus(matter).nextStep {
                        matter.nextStep = rule.text
                        matter.nextStepWhy = rule.why
                        matter.nextStepTodo = rule.todo.flatMap { id in (matter.todos ?? []).first { $0.persistentModelID == id }?.origin }
                        matter.nextStepAt = now
                    }
                    if matter.summary != nil { matter.summaryAt = now }
                    try? context.save()
                    var all = Self.known
                    all[key] = Known(stamp: matter.recordStamp, stepAt: matter.nextStepAt == now ? now : nil, summaryAt: matter.summaryAt == now ? now : nil)
                    Self.known = all
                }
                continue
            }
            guard let names = try? names() else { continue }
            let model = ModelChoice.assistant
            guard let claude = ModelChoice.client(for: model) else { continue }
            // Its stamp is kept before anything is sent: an update that fails is not tried again
            // and again, each time for money — the next change tries the next.
            known[key] = Known(stamp: stamp, stepAt: before.stepAt, summaryAt: before.summaryAt)
            working.insert(key)
            let facts = FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), mails: 40)
            let today = MatterStatus.day(Date())
            Task {
                defer { working.remove(key); done += 1 }
                do {
                    let step: (step: String, why: String, todo: FactRef?, cost: Double)
                    let summary: (lines: [String], cost: Double)
                    switch names {
                    case .file(let url):
                        step = try await AssistantAsk.nextStep(facts: facts, owner: owner, today: today, mapping: url, claude: claude, model: model)
                        summary = try await AssistantAsk.summarize(facts: facts, owner: owner, today: today, mapping: url, claude: claude, model: model)
                    case .list(let mapping, let others):
                        step = try await AssistantAsk.nextStep(facts: facts, owner: owner, today: today, mapping: mapping, others: others, claude: claude, model: model)
                        summary = try await AssistantAsk.summarize(facts: facts, owner: owner, today: today, mapping: mapping, others: others, claude: claude, model: model)
                    }
                    // Turned off while it was on its way: what came back is not put in.
                    guard AutoMode.isOn else { return }
                    let now = Date()
                    matter.nextStep = step.step
                    matter.nextStepWhy = step.why
                    if case .todo(let id) = step.todo { matter.nextStepTodo = (matter.todos ?? []).first { $0.persistentModelID == id }?.origin }
                    else { matter.nextStepTodo = nil }
                    matter.nextStepAt = now
                    matter.summary = summary.lines.joined(separator: "\n")
                    matter.summaryAt = now
                    try? context.save()
                    Self.add(step.cost + summary.cost)
                    var all = Self.known
                    all[key] = Known(stamp: matter.recordStamp, stepAt: now, summaryAt: now)
                    Self.known = all
                } catch {}
            }
        }
    }
}
