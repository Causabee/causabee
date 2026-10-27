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
    /// None in the demo with the owner's real matters: from there nothing is sent, whatever is asked.
    static func client(for model: Claude.Model) -> Claude? {
        DemoData.usesReal || deviceOnly ? nil : BeeServer.client(for: model) ?? Claude.key(for: model).map { Claude(key: $0) }
    }

    /// For testing Causabee as it is without a key or Pro: only Apple's model on this device.
    static let deviceOnlyKey = "reading.deviceOnly"
    static var deviceOnly: Bool { UserDefaults.standard.bool(forKey: deviceOnlyKey) }

    /// Who reads new mail: the chosen model with its key or Pro; without either, Apple's model on
    /// this device — nothing leaves it, nothing is paid.
    enum Reader {
        case cloud(Claude)
        case device
        case none(String)

        var client: Claude? { if case .cloud(let claude) = self { claude } else { nil } }
    }

    static func mailReader(for model: Claude.Model) -> Reader {
        if let claude = client(for: model) { return .cloud(claude) }
        if DemoData.isRequested || DemoData.usesReal { return .none(missingKey(model)) }
        return DeviceReader.isAvailable ? .device : .none(deviceOnly ? DeviceReader.Unavailable().errorDescription ?? "" : missingKey(model))
    }

    /// Under the mails ticked to be sorted in: who reads them, and — with your own keys — about what it costs.
    static func sortingWords(_ count: Int, estimate: Double, model: Claude.Model) -> String {
        let mails = count == 1 ? "mail" : "mails"
        if case .device = mailReader(for: model) { return "Sorting in \(count) \(mails) on this device, with Apple's model: nothing leaves it." }
        if Money.hidden { return "Sorting in \(count) \(mails) with Causabee Pro. Sent pseudonymised to \(model.label)." }
        return String(format: "Sorting in %d %@ costs about $%.2f. Sent pseudonymised to %@.", count, mails, estimate, model.label)
    }

    static func missingKey(_ model: Claude.Model) -> String {
        if DemoData.usesReal { return "This is the demo with your real matters: nothing is sent to an AI from it." }
        if DemoData.isRequested { return "This is the demo: your keys are not used in it, so nothing is sent to an AI from it." }
        if deviceOnly { return "Only Apple's model on this device is on (Settings → Causabee Pro). It reads new mail; this comes to it later." }
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
    @AppStorage(BeeJoy.key) private var celebrates = true

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
            Section {
                Toggle("The bee is glad when you tick a task", isOn: $celebrates)
            } header: { Text("Tasks") }
            Section { CloudSettings() } header: { Text("iCloud") }
            Section { CalendarSettings() } header: { Text("Calendar and Reminders") }
            Section { FolderSettings() } header: { Text("Matter folders in iCloud Drive") }
            Section { PublicNamesSettings() } header: { Text("Public names") } footer: {
                Text("Big companies and brands — Expedia, Lufthansa — are not disguised: the AI reads them as they are, and a question looked up on the web may name them. Mark one here, or in a person's menu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if BeeServerSettings.shows {
                Section { BeeServerSettings() } header: { Text("Causabee Pro") }
            }
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

/// Keeps the owner's choices the same on every device: the models, Auto, fewer real tasks, the
/// bee's gladness, and the calendar and list for new entries. What is chosen here goes into the
/// synced profile; what was chosen on another device comes from it. A device that never chose — a
/// new install — takes the profile's and does not overwrite it with its own defaults.
struct ModelChoiceSync: ViewModifier {
    @Query private var profiles: [Profile]
    @Environment(\.modelContext) private var context
    @AppStorage(ModelChoice.mailKey) private var mail = ""
    @AppStorage(ModelChoice.assistantKey) private var assistant = ""
    @AppStorage(AutoMode.key) private var auto = false
    @AppStorage(ModelChoice.strictKey) private var strict = true
    @AppStorage(BeeJoy.key) private var bee = true
    @AppStorage(Calendars.calendarKey) private var calendar = ""
    @AppStorage(Calendars.listKey) private var list = ""

    func body(content: Content) -> some View {
        let profile = profiles.first
        content
            .onAppear(perform: takeOver)
            .onChange(of: profiles.count) { takeOver() }
            .onChange(of: profile?.mailModel) { takeOver() }
            .onChange(of: profile?.assistantModel) { takeOver() }
            .onChange(of: profile?.autoOn) { takeOver() }
            .onChange(of: profile?.strictTasks) { takeOver() }
            .onChange(of: profile?.beeGlad) { takeOver() }
            .onChange(of: profile?.calendarTitle) { takeOver() }
            .onChange(of: profile?.reminderListTitle) { takeOver() }
            .onChange(of: profile?.autoSpent) { AutoUpdate.takeSpending(from: profile) }
            .onChange(of: mail) { pass(on: mail, to: \.mailModel) }
            .onChange(of: assistant) { pass(on: assistant, to: \.assistantModel) }
            .onChange(of: auto) { pass(auto, to: \.autoOn) }
            .onChange(of: strict) { pass(strict, to: \.strictTasks) }
            .onChange(of: bee) { pass(bee, to: \.beeGlad) }
            .onChange(of: calendar) { pass(Calendars.shared.title(of: calendar), to: \.calendarTitle) }
            .onChange(of: list) { pass(Calendars.shared.title(of: list), to: \.reminderListTitle) }
    }

    /// The profile's choices become this device's; where the profile has none yet, this device's
    /// own — if it ever made one — becomes the profile's.
    private func takeOver() {
        guard !DemoData.isRequested, let profile = profiles.first else { return }
        if let chosen = profile.mailModel { if mail != chosen { mail = chosen } } else { pass(on: mail, to: \.mailModel) }
        if let chosen = profile.assistantModel { if assistant != chosen { assistant = chosen } } else { pass(on: assistant, to: \.assistantModel) }
        take(\.autoOn, key: AutoMode.key, into: $auto)
        // Turned on on another device: it was agreed to there.
        if auto { UserDefaults.standard.set(true, forKey: AutoMode.agreedKey) }
        take(\.strictTasks, key: ModelChoice.strictKey, into: $strict)
        take(\.beeGlad, key: BeeJoy.key, into: $bee)
        if let title = profile.calendarTitle, Calendars.shared.title(of: calendar) != title,
           let id = Calendars.shared.identifier(titled: title, events: true) { calendar = id }
        else if profile.calendarTitle == nil, !calendar.isEmpty { pass(Calendars.shared.title(of: calendar), to: \.calendarTitle) }
        if let title = profile.reminderListTitle, Calendars.shared.title(of: list) != title,
           let id = Calendars.shared.identifier(titled: title, events: false) { list = id }
        else if profile.reminderListTitle == nil, !list.isEmpty { pass(Calendars.shared.title(of: list), to: \.reminderListTitle) }
        AutoUpdate.takeSpending(from: profile)
    }

    /// A yes or no of the profile, here — or, where the profile has none, this device's into it,
    /// if this device ever chose.
    private func take(_ field: ReferenceWritableKeyPath<Profile, Bool?>, key: String, into value: Binding<Bool>) {
        guard let profile = profiles.first else { return }
        if let chosen = profile[keyPath: field] { if value.wrappedValue != chosen { value.wrappedValue = chosen } }
        else if UserDefaults.standard.object(forKey: key) != nil { pass(value.wrappedValue, to: field) }
    }

    private func pass(_ value: Bool, to field: ReferenceWritableKeyPath<Profile, Bool?>) {
        guard !DemoData.isRequested, let profile = profiles.first, profile[keyPath: field] != value else { return }
        profile[keyPath: field] = value
        try? context.save()
    }

    private func pass(_ title: String?, to field: ReferenceWritableKeyPath<Profile, String?>) {
        guard !DemoData.isRequested, let title, !title.isEmpty, let profile = profiles.first, profile[keyPath: field] != title else { return }
        profile[keyPath: field] = title
        try? context.save()
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
    fileprivate(set) var count = 0

    /// The prepared overview for these matters, as the store is now: prepared once per change,
    /// however many views ask for it.
    func overview(_ matters: [Matter]) -> OverviewPage {
        OverviewPages.shared.page(for: matters, version: count)
    }

    /// One matter as its card or row shows it, prepared once per change.
    func summary(_ matter: Matter) -> MatterSummary {
        OverviewPages.shared.summary(of: matter, version: count)
    }

    // The week's questions, answered once per change and per day — the week asked them eight or
    // nine times each time it drew, and it draws every minute.
    @ObservationIgnored private var weekKept: [String: Any] = [:]
    @ObservationIgnored private var weekVersion = -1

    /// Anything worked out from the store, kept until the store changes or the day turns.
    func kept<Value>(_ name: String, _ work: () -> Value) -> Value {
        kept(name, for: [], work)
    }

    /// A matter's conversations and what came from each mail and file, prepared once per change —
    /// the record, its menus' counts and find all draw from it.
    func record(_ matter: Matter) -> (threads: [MailThreads.Thread], made: RecordLinks) {
        kept("record \(matter.persistentModelID.hashValue)") { (MailThreads.build(MatterStatus(matter).mailEntries), RecordLinks(matter)) }
    }

    /// Every rule the owner set, read once per change — not fetched by each drawing of People.
    func rules(in context: ModelContext) -> [Rule] {
        kept("rules") { (try? context.fetch(FetchDescriptor<Rule>())) ?? [] }
    }

    private func kept<Value>(_ name: String, for matters: [Matter], _ work: () -> Value) -> Value {
        if weekVersion != count { weekKept = [:]; weekVersion = count }
        var hasher = Hasher()
        for matter in matters { hasher.combine(matter.persistentModelID) }
        let key = "\(name) \(MatterStatus.day(Date())) \(hasher.finalize())"
        // Looked up, then cast: an answer that is nil is kept too, and not mistaken for none kept.
        if let stored = weekKept[key], let value = stored as? Value { return value }
        let value = work()
        weekKept[key] = value
        return value
    }

    func things(on day: String, in matters: [Matter]) -> [DayThing] {
        kept("things \(day)", for: matters) { Week.things(on: day, in: matters) }
    }

    func next(after day: String, in matters: [Matter]) -> (day: String, thing: DayThing)? {
        kept("next \(day)", for: matters) { Week.next(after: day, in: matters) }
    }

    /// Every open task past its day, the longest overdue first.
    func overdue(in matters: [Matter]) -> [Todo] {
        kept("overdue", for: matters) {
            matters.filter { !$0.isClosed }.flatMap { MatterStatus($0).overdue }.sorted { ($0.due ?? "") < ($1.due ?? "") }
        }
    }
    /// The app's context, for the debug build's report of what it sees.
    @ObservationIgnored var context: ModelContext?
    @ObservationIgnored private var watching = false
    @ObservationIgnored private var pending = false

    func watch(_ context: ModelContext) {
        self.context = context
        // The names the owner marked as public, read before anything is disguised.
        PublicNames.refresh(in: context)
        // From the start: what iCloud brings in, so the mail check can wait for it.
        CloudCatchUp.shared.watch()
        guard !watching else { return }
        watching = true
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { StoredChanges.shared.changed() }
        }
        // A change saved here is a change too, at once: the prepared overview is made anew from it.
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                StoredChanges.shared.count += 1
                if let context = StoredChanges.shared.context { PublicNames.refresh(in: context) }
                if CommandLine.arguments.contains("--timing-tour") { NSLog("[timing] saved, change %d", StoredChanges.shared.count) }
            }
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
                // A name marked public on another device counts here too.
                if let context = self.context { PublicNames.refresh(in: context) }
                // What another device kept of a mail or a file comes beside this store too.
                if delay == 15, let store = KeptTexts.store, let context = self.context { KeptTexts.share(besides: store, in: context) }
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
            Text(soon ? "Changed · Pro updates this in a moment" : "Pro")
        }
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("auto.line")
    }
}

/// What asking for a matter's next step or summary would cost, as the links beside them say it.
/// Worked out from the matter's last 40 mails — a hundredth of a second and more — so only where
/// it is shown, and kept until the matter's record or the model is another.
@MainActor
enum PriceEstimates {
    private static var kept: [PersistentIdentifier: (version: Int, key: String, step: Double, summary: Double)] = [:]

    static func of(_ matter: Matter) -> (step: Double, summary: Double) {
        // Unchanged store: as it was. Changed: worked out anew only when this matter's own record
        // changed — the facts are the heavy part — told by a cheap mark: its counts, and its notes'.
        let version = StoredChanges.shared.count
        if let known = kept[matter.persistentModelID], known.version == version { return (known.step, known.summary) }
        let key = [ModelChoice.assistant.id, "\(matter.entries?.count ?? 0)", "\(matter.todos?.count ?? 0)",
                   "\(matter.documents?.count ?? 0)", "\(matter.noteCount)",
                   "\((matter.noteBlocks ?? []).reduce(0) { $0 + $1.text.count } + (matter.notes?.count ?? 0))", MatterStatus.day(Date())].joined(separator: "|")
        if let known = kept[matter.persistentModelID], known.key == key {
            kept[matter.persistentModelID] = (version, key, known.step, known.summary)
            return (known.step, known.summary)
        }
        // What the facts would come to, told from what goes into them — the whole sheet was made
        // just to be measured, and was most of opening a matter with many people and mails.
        let length = Self.factsLength(matter)
        let model = ModelChoice.assistant
        let found = (version: version, key: key, step: AssistantAsk.nextStepEstimate(length: length, model: model),
                     summary: AssistantAsk.adviceEstimate(length: length, model: model))
        kept[matter.persistentModelID] = found
        return (found.step, found.summary)
    }

    /// About as many characters as the matter's facts have: its open tasks, the newest forty mails,
    /// the notes, the people, the dates and the files, each about as long as the sheet writes it.
    static func factsLength(_ matter: Matter) -> Int {
        let mails = (matter.entries ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.prefix(40)
        let mailText = mails.reduce(0) { $0 + $1.title.count + $1.from.count + ($1.digest?.count ?? 0) + 30 }
        let todos = (matter.todos ?? []).reduce(0) { $0 + $1.text.count + 60 }
        let notes = (matter.notesText?.count ?? 0) + (matter.shownBrief?.forFacts?.count ?? 0)
        let rest = matter.parties.count * 80 + ((matter.appointments ?? []).count + (matter.deadlines ?? []).count) * 60
            + (matter.documents ?? []).count * 50
        return 600 + mailText + todos + notes + rest
    }

    /// " · ≈ 2.4 cents" after a button's words — nothing with Pro, where the plan holds the AI.
    static func step(_ matter: Matter) -> String { Money.hidden ? "" : String(format: " · ≈ %.1f cents", of(matter).step * 100) }
    static func summary(_ matter: Matter) -> String { Money.hidden ? "" : String(format: " · ≈ %.1f cents", of(matter).summary * 100) }
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
    /// Auto's requests, one after another: all at once — every matter changed by a sync, on every
    /// device — they ran into the AI service's limit per minute ("Too many requests").
    @ObservationIgnored private var queue: Task<Void, Never>?
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
    /// Saves to the store — here or from another device — and how many there had been at the last
    /// look. A matter's record is read whole for its stamp: every few seconds, for every matter,
    /// that held the screen up a tenth of a second each time. Now it is read only after a save.
    @ObservationIgnored private var saves = 0
    @ObservationIgnored private var savesLooked = -1
    @ObservationIgnored private var watching = false

    private func watchSaves() {
        guard !watching else { return }
        watching = true
        for name in [ModelContext.didSave, .NSPersistentStoreRemoteChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AutoUpdate.shared.saves += 1 }
            }
        }
    }
    private static let knownKey = "auto.known", spentKey = "auto.spent"

    private static var known: [String: Known] {
        get { (UserDefaults.standard.data(forKey: knownKey)).flatMap { try? JSONDecoder().decode([String: Known].self, from: $0) } ?? [:] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: knownKey) }
    }

    /// What Auto spent on a day, in dollars.
    static func spent(on day: String = MatterStatus.day(Date())) -> Double {
        ((UserDefaults.standard.dictionary(forKey: spentKey) as? [String: Double])?[day] ?? 0)
            + ((UserDefaults.standard.dictionary(forKey: elsewhereKey) as? [String: Double])?[day] ?? 0)
    }

    /// What the other devices' Auto spent, by day, as the profile says it: kept here for `spent`.
    private static let elsewhereKey = "auto.spent.elsewhere"
    private static let deviceKey = "names.device"
    private static var device: String { UserDefaults.standard.string(forKey: deviceKey) ?? "" }

    static func takeSpending(from profile: Profile?) {
        guard let data = profile?.autoSpent, let all = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else { return }
        var elsewhere: [String: Double] = [:]
        for (id, days) in all where id != device { for (day, dollars) in days { elsewhere[day, default: 0] += dollars } }
        UserDefaults.standard.set(elsewhere, forKey: elsewhereKey)
    }

    /// This device's spending into the profile, for the others to say.
    static func shareSpending(in context: ModelContext) {
        guard !DemoData.isRequested, !device.isEmpty, let profile = ((try? context.fetch(FetchDescriptor<Profile>())) ?? []).first else { return }
        var all = profile.autoSpent.flatMap { try? JSONDecoder().decode([String: [String: Double]].self, from: $0) } ?? [:]
        all[device] = (UserDefaults.standard.dictionary(forKey: spentKey) as? [String: Double]) ?? [:]
        profile.autoSpent = try? JSONEncoder().encode(all)
        try? context.save()
    }

    /// "Auto · $0.12 today", or nil when it spent nothing today.
    static var spentWords: String? {
        let spent = spent()
        return spent > 0 ? String(format: "Pro has spent $%.2f today on next steps and summaries", spent) : nil
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
        watchSaves()
        NewsNotice.listen()
        BeeServer.listen()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pace)
            // News written here, or come from another device: told once, Auto or not.
            NewsNotice.tell { (try? context.fetch(FetchDescriptor<Matter>())) ?? [] }
            guard AutoMode.isOn else { lastSeen = [:]; if !pending.isEmpty { pending = [] }; continue }
            // Not even the matters fetched when nothing was saved since the last look.
            guard saves != savesLooked || !lastSeen.isEmpty || !pending.isEmpty else { continue }
            let matters = (try? context.fetch(FetchDescriptor<Matter>())) ?? []
            look(matters, context: context, owner: AutoMode.owner(in: context).first, names: names)
        }
    }

    /// Looks at every matter going on, every few seconds while Auto is on; cheap, and sends nothing
    /// unless one has changed and come to rest.
    func look(_ matters: [Matter], context: ModelContext, owner: String?, names: () throws -> Names) {
        guard AutoMode.isOn else { lastSeen = [:]; return }
        // Nothing saved since the last look, and nothing on its way to rest: nothing can have changed.
        guard saves != savesLooked || !lastSeen.isEmpty || !pending.isEmpty else { return }
        savesLooked = saves
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
            guard ModelChoice.client(for: ModelChoice.assistant) != nil else { continue }
            // Its stamp is kept before anything is sent: an update that fails is not tried again
            // and again, each time for money — the next change tries the next.
            known[key] = Known(stamp: stamp, stepAt: before.stepAt, summaryAt: before.summaryAt)
            working.insert(key)
            let ahead = queue
            queue = Task {
                await ahead?.value
                defer { working.remove(key); done += 1 }
                do {
                    // One request — the brief, the summary and the step, and what to change in the list.
                    guard AutoMode.isOn else { return }
                    let cost = try await Adviser.write(matter, names: names, owner: owner, in: context)
                    let now = matter.nextStepAt ?? Date()
                    Self.add(cost)
                    Self.shareSpending(in: context)
                    var all = Self.known
                    all[key] = Known(stamp: matter.recordStamp, stepAt: now, summaryAt: matter.summaryAt)
                    Self.known = all
                } catch {}
            }
        }
    }
}

/// Before Auto is on for the first time, at the bolt: what it does, said once and agreed to.
/// Everything else goes to an AI only at a click; Auto is the one switch after which it goes by
/// itself — so that is not left to a tooltip. Agreed once, the bolt is a bolt again.
struct AutoQuestion: ViewModifier {
    @Binding var asks: Bool
    let turnOn: () -> Void
    @AppStorage(AutoMode.agreedKey) private var agreed = false
    @AppStorage(ModelChoice.mailKey) private var mail = Claude.Model.opus.id

    func body(content: Content) -> some View {
        let model = Claude.Model.choices.first { $0.id == mail } ?? .opus
        content.confirmationDialog("Turn on Pro?", isPresented: $asks, titleVisibility: .visible) {
            Button("Turn Pro On") { agreed = true; turnOn() }
            Button("Cancel", role: .cancel) { }
        } message: {
            // Short, and by name: which model reads, that names are disguised, who decides, what it costs.
            Text("Pro reads new mail and files for you as they arrive, with \(model.label) — names disguised. " +
                 "You still decide what goes into a matter. " + String(format: "About %.1f cents a mail. ", model.perMail * 100) +
                 "Without Pro, nothing is read by the AI until you tap.")
        }
    }
}

extension View {
    /// The question before Auto is turned on for the first time.
    func asksBeforeAuto(_ asks: Binding<Bool>, turnOn: @escaping () -> Void) -> some View {
        modifier(AutoQuestion(asks: asks, turnOn: turnOn))
    }
}

/// Waits for iCloud before mail is looked at: opened after a while, Causabee checked the mailbox
/// within seconds, before iCloud had brought what the other devices sorted meanwhile — and mail
/// already taken in looked new, was read again, and its tasks came twice.
@MainActor
final class CloudCatchUp {
    static let shared = CloudCatchUp()
    private var activeSince = Date()
    private var lastImport: Date?
    private var watching = false

    /// Whether this store syncs at all: without iCloud there is nothing to wait for.
    private var syncs: Bool {
        guard !DemoData.isRequested else { return false }
        #if os(iOS)
        return PhoneCloud.container != nil
        #else
        return CloudSync.mode == .on
        #endif
    }

    func watch() {
        guard !watching else { return }
        watching = true
        NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  event.type == .import, let ended = event.endDate, event.succeeded else { return }
            MainActor.assumeIsolated { CloudCatchUp.shared.lastImport = ended }
        }
        #if os(iOS)
        let active = UIApplication.didBecomeActiveNotification
        #else
        let active = NSApplication.didBecomeActiveNotification
        #endif
        NotificationCenter.default.addObserver(forName: active, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CloudCatchUp.shared.activeSince = Date() }
        }
    }

    /// Until iCloud has brought in what came since Causabee came to the front — at most `limit`:
    /// with nothing new, iCloud may not say so at all.
    func caughtUp(limit: Duration = .seconds(25)) async {
        watch()
        guard syncs else { return }
        let start = ContinuousClock.now
        while (lastImport ?? .distantPast) < activeSince, ContinuousClock.now - start < limit {
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}
