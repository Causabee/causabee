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
    @AppStorage(BeeServerSettings.revealedKey) private var revealed = false
    @AppStorage(AutoMode.key) private var auto = false
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if accounts.isEmpty { Text("Not set up yet").foregroundStyle(.secondary) }
                    ForEach(accounts, id: \.user) { account in LabeledContent(account.user, value: account.host) }
                    Button(accounts.isEmpty ? "Add mail account …" : "Change …") { addsAccount = true }
                } header: { Text("Mail") } footer: {
                    Text("To get new mail, to open a matter's files from your mail, and to put a scanned document into it. The password comes from your Mac through iCloud Keychain, or is typed here once.")
                }

                Section {
                    if ModelChoice.proPicks {
                        LabeledContent("Sort mail", value: Claude.Model.gptSol.label)
                    } else {
                        Picker("Sort mail", selection: $mail) {
                            ForEach(Claude.Model.choices, id: \.id) { model in
                                Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
                            }
                        }
                        .id(tick)
                    }
                    if mail.hasPrefix("mistral") || mail.hasPrefix("gpt-") {
                        Toggle("Fewer, real tasks", isOn: $strict)
                    }
                    Toggle("Pro: the bigger AI reads mail and files at once", isOn: Binding(
                        get: { auto && Store.shared.plan == .pro },
                        set: { on in if !on { auto = false } else if Store.shared.mayTurnOnPro() { auto = true } }))
                    if BeeServer.isSetUp {
                        Text(auto ? "Pro is on: GPT-6.1 Sol reads new mail and files as they come and answers your questions — sent pseudonymised. What is taken in, and into which matter, you still decide."
                                  : "Pro is off: Apple's model on this device reads new mail when you tap “Sort in”. Nothing leaves it.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                    Text(auto ? "New mail and files are read by the AI as soon as they are there — sent pseudonymised, without asking first. What is taken in, and into which matter, you still decide. When a matter’s record changes, its next step and its summary are written again" + (Money.hidden ? "." : " — a few cents each time.")
                              : "New mail and files wait until you tap “Sort in”. What is taken in, and into which matter, you decide after. Next steps and summaries are written when you tap for them.")
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    if auto, !BeeServer.isSetUp { Text(AutoUpdate.spentWords ?? "Pro has spent nothing today on next steps and summaries").font(.footnote).foregroundStyle(.secondary) }
                    Text((ModelChoice.proPicks ? "Causabee Pro picks the model: GPT-6.1 Sol, for mail and answers. " : String(format: "About %.2f cents per mail. ",
                                (Claude.Model.choices.first { $0.id == mail } ?? .opus).perMail * 100))
                         + "A mail is sorted only once — here or on your Mac: what a model sorted in stays that way.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("New mail") }

                Section {
                    if ModelChoice.proPicks {
                        LabeledContent("Assistant", value: Claude.Model.gptSol.label)
                    } else {
                        Picker("Assistant", selection: $assistant) {
                            ForEach(Claude.Model.choices, id: \.id) { model in
                                Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
                            }
                        }
                        .id(tick)
                    }
                    Text("Answers, summaries and the next step. Under each answer you see which model wrote it.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Questions") }

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
                    Toggle("The bee is glad when you tick a task", isOn: $celebrates)
                } header: { Text("Tasks") }

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

                Section { FolderSetting() } header: { Text("Files") }

                Section { CalendarSettings() } header: { Text("Calendar and Reminders") }

                Section { PublicNamesSettings() } header: { Text("Public names") } footer: {
                    Text("Big companies and brands — Expedia, Lufthansa — are not disguised: the AI reads them as they are, and a question looked up on the web may name them. Mark one here, or in a person's menu.")
                }

                Section {
                    if lists.isEmpty { Label("Not here yet", systemImage: "hourglass").foregroundStyle(Theme.warning) }
                    ForEach(lists) { list in
                        LabeledContent(list.device == PhoneNames.device ? "This \(ThisDevice.name)" : list.deviceName.isEmpty ? "A Mac" : list.deviceName,
                                       value: list.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: { Text("List of names") } footer: {
                    Text("Names are disguised before anything is sent. Each device keeps its own list — this \(ThisDevice.name) once it gets new mail — and puts it into iCloud, end-to-end encrypted, when you switch away from Causabee; a name one device learned, the others disguise too. Without any list, the assistant sends nothing.")
                }

                if revealed || BeeServerSettings.shows {
                    Section { BeeServerSettings() } header: { Text("Causabee Pro") }
                }

                Section {
                    KeyField(title: "Claude (Anthropic)", name: "ANTHROPIC_API_KEY")
                    KeyField(title: "Mistral", name: "MISTRAL_API_KEY")
                    KeyField(title: "OpenAI", name: "OPENAI_API_KEY")
                } header: { Text("API keys") } footer: {
                    Text("Pasted here or on your Mac, kept in iCloud Keychain like the mail password, and shared by Causabee on all your devices. Never in a file.")
                }

                Section {
                    Text("All of them get only pseudonymised text: Claude (Anthropic, USA), Mistral (Paris) or OpenAI (USA). In the test, Mistral Large 3 sorted almost as well as Opus; for tasks, Opus was better in about one mail out of three.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                // Which Causabee this is, to say when something is reported.
                // Five taps show the beeserver's switch, for testing Pro.
                Section { LabeledContent("Causabee", value: AppRelease.label).onTapGesture(count: 5) { revealed = true } }
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
