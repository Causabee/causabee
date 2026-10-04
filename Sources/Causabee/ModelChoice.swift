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
                    do { try APIKeys.save(pasted, as: name); pasted = ""; error = nil } catch { self.error = "\(error)" }
                    stored = APIKeys.get(name) != nil
                }
                .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
                if stored { Button("Remove") { APIKeys.delete(name); stored = false } }
            }
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
