import MatterCore
import SwiftData
import SwiftUI

/// The Mac's Settings (⌘,), as far as the iPhone does the same: which model sorts the mail and
/// which answers, iCloud, Calendar and Reminders, the API keys — the same three, the same field —
/// and what the iPhone needs of its own: the mail account, and the lists of names. The matter
/// folders are the Mac's alone.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneStore.self) private var store
    @AppStorage(ModelChoice.assistantKey) private var assistant = Claude.Model.opus.id
    @AppStorage(ModelChoice.mailKey) private var mail = Claude.Model.opus.id
    @AppStorage(ModelChoice.strictKey) private var strict = true
    @AppStorage(BeeJoy.key) private var celebrates = true
    @Query private var profiles: [Profile]
    @Environment(\.modelContext) private var context
    /// The owner's names, one per line: read from the synced profile when the sheet opens.
    @State private var ownNames = ""
    @Query(sort: \NameList.updatedAt, order: .reverse) private var lists: [NameList]
    @State private var sync = PhoneCloudStatus.shared
    @State private var accounts = Keychain.accounts().filter { !$0.usesGoogle }
    @State private var addsAccount = false
    /// Counts up when a key may have arrived, so the pickers say "— no key" again or not.
    @State private var tick = 0

    private func saveOwnNames() {
        guard !store.isDemo else { return }
        let names = ownNames.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let profile = profiles.first { guard profile.names != names else { return }; profile.names = names }
        else if !names.isEmpty { context.insert(Profile(names: names)) }
        try? context.save()
    }

    /// Your own models and keys, and Pro's token by hand: for testing, folded away.
    private var developer: some View {
        Form {
            Section {
                Picker("Sort mail", selection: $mail) {
                    ForEach(Claude.Model.choices, id: \.id) { model in
                        Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
                    }
                }
                .id(tick)
                Picker("Assistant", selection: $assistant) {
                    ForEach(Claude.Model.choices, id: \.id) { model in
                        Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
                    }
                }
                .id(tick)
            } header: { Text("Your own models") } footer: {
                Text(ModelChoice.proPicks ? "Pro picks GPT-6.1 Sol while it is on; these are used with your own keys."
                     : "Used with your own keys. All of them get only pseudonymised text: Claude (Anthropic, USA), Mistral (Paris) or OpenAI (USA).")
            }
            Section {
                KeyField(title: "Claude (Anthropic)", name: "ANTHROPIC_API_KEY")
                KeyField(title: "Mistral", name: "MISTRAL_API_KEY")
                KeyField(title: "OpenAI", name: "OPENAI_API_KEY")
            } header: { Text("API keys") } footer: {
                Text("Pasted here or on your Mac, kept in iCloud Keychain like the mail password, and shared by Causabee on all your devices. Never in a file.")
            }
            Section { BeeServerSettings() } header: { Text("Pro's server") }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { PlanSettings() } header: { Text("Your plan") }

                Section {
                    if accounts.isEmpty { Text("Not set up yet").foregroundStyle(.secondary) }
                    ForEach(accounts, id: \.user) { account in LabeledContent(account.user, value: account.host) }
                    Button(accounts.isEmpty ? "Add mail account …" : "Change …") { addsAccount = true }
                    if ModelChoice.mail.isMistral || ModelChoice.mail.isOpenAI {
                        Toggle("Fewer, real tasks", isOn: $strict)
                    }
                } header: { Text("Mail") } footer: {
                    Text(ModelChoice.readerWords + " A mail is sorted only once — here or on your Mac. The password comes from your Mac through iCloud Keychain, or is typed here once.")
                }

                Section {
                    // As in the Mac's setup: one per line, saved as typed, the same on every device.
                    TextField("Your name", text: $ownNames, axis: .vertical)
                        .lineLimit(2...6)
                        .textInputAutocapitalization(.never)
                        .onChange(of: ownNames) { saveOwnNames() }
                } header: { Text("You") } footer: {
                    Text("Your name and the email addresses you use, one per line, and a nickname if people write to you by it. Causabee needs them to tell you apart from everyone else: you are never listed as a person in your own matters, and tasks for you are marked “Mine”.")
                }

                Section {
                    SettingsPart("Calendar and Reminders")
                    CalendarSettings()
                    SettingsPart("Files")
                    FolderSetting()
                    Toggle("The bee is glad when you tick a task", isOn: $celebrates)
                } header: { Text("Matters") }

                Section {
                    SettingsPart("Public names")
                    PublicNamesSettings()
                    SettingsPart("Lists of names")
                    ForEach(lists) { list in
                        LabeledContent("Names · " + (list.device == PhoneNames.device ? "this \(ThisDevice.name)" : list.deviceName.isEmpty ? "a Mac" : list.deviceName),
                                       value: list.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if lists.isEmpty { Label("No list of names here yet", systemImage: "hourglass").foregroundStyle(Theme.warning) }
                } header: { Text("Privacy") } footer: {
                    Text("Names are disguised before anything leaves the device: each device keeps a list of them, end-to-end encrypted in iCloud, and without any list the assistant sends nothing. Big companies and brands — Expedia, Lufthansa — are not disguised; mark one here, or in a person's menu.")
                }

                Section {
                    if store.isDemo {
                        LabeledContent("iCloud", value: "Off in the demo")
                        Text("In the demo, iCloud stays off: the made-up matters never meet your iCloud.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Now: On — your matters, in your private iCloud · \(sync.account)").font(.footnote)
                            Text("Last sent: \(sync.lastExport.map { $0.formatted(date: .omitted, time: .shortened) } ?? "not yet") · last received: \(sync.lastImport.map { $0.formatted(date: .omitted, time: .shortened) } ?? "not yet")")
                                .font(.footnote).foregroundStyle(.secondary)
                            if let error = sync.lastError { Text(error).font(.footnote).foregroundStyle(Theme.warning) }
                        }
                    }
                } header: { Text("iCloud") } footer: {
                    Text("Your matters, tasks, dates, people, digests, what each mail was sorted as, the assistant's history, and the full texts of mails and scans — those end to end encrypted — sync through your private iCloud. Files go into the matters' folders.")
                }

                Section {
                    NavigationLink("Developer") { developer }
                    // Which Causabee this is, to say when something is reported.
                    LabeledContent("Causabee", value: AppRelease.label)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { accounts = Keychain.accounts().filter { !$0.usesGoogle } }) { MailAccountSheet() }
            // A key or a password saved on a Mac may have arrived meanwhile.
            .onAppear {
                ownNames = (profiles.first?.names ?? []).joined(separator: "\n")
                accounts = Keychain.accounts().filter { !$0.usesGoogle }
                tick += 1
            }
        }
    }
}
