import MatterCore
import SwiftData
import SwiftUI

/// The Mac's Settings (⌘,), as far as the iPhone does the same: which model answers, iCloud, the
/// API keys — the same three, the same field — and what the iPhone needs of its own: the mail
/// account the files come out of, and the list of names from a Mac. Calendar and Reminders and
/// the matter folders are the Mac's alone for now.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneStore.self) private var store
    @AppStorage(ModelChoice.assistantKey) private var assistant = Claude.Model.opus.id
    @Query(sort: \NameList.updatedAt, order: .reverse) private var lists: [NameList]
    @State private var sync = PhoneCloudStatus.shared
    @State private var accounts = Keychain.accounts().filter { !$0.usesGoogle }
    @State private var addsAccount = false
    /// Counts up when a key may have arrived, so the pickers say "— no key" again or not.
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if accounts.isEmpty { Text("Not set up yet").foregroundStyle(.secondary) }
                    ForEach(accounts, id: \.user) { account in LabeledContent(account.user, value: account.host) }
                    Button(accounts.isEmpty ? "Add mail account …" : "Change …") { addsAccount = true }
                } header: { Text("Mail") } footer: {
                    Text("To open a matter's files from your mail, and to put a scanned document into it. The password comes from your Mac through iCloud Keychain, or is typed here once.")
                }

                Section {
                    Text("Your Mac sorts new mail, screenshots and files into matters, with the model chosen there.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("New mail, screenshots, files") }

                Section {
                    Picker("Assistant", selection: $assistant) {
                        ForEach(Claude.Model.choices, id: \.id) { model in
                            Text(model.label + (Claude.key(for: model) == nil ? " — no key" : "")).tag(model.id)
                        }
                    }
                    .id(tick)
                    Text("Answers, summaries and the next step. Under each answer you see which model wrote it.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Questions") }

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
                    Text("Only the store syncs: matters, tasks, dates, people, digests and the assistant's history. Full mail texts and files stay in your mail and on your Mac.")
                }

                Section { CalendarSettings() } header: { Text("Calendar and Reminders") }

                Section {
                    if lists.isEmpty { Label("Not here yet", systemImage: "hourglass").foregroundStyle(Theme.warning) }
                    ForEach(lists) { list in
                        LabeledContent(list.deviceName.isEmpty ? "A Mac" : list.deviceName,
                                       value: list.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: { Text("List of names") } footer: {
                    Text("Names are disguised with your Mac's list before anything is sent. Each Mac puts its list into iCloud when Matterbee starts there, and when you switch away from it. Without a list, the assistant sends nothing.")
                }

                Section {
                    KeyField(title: "Claude (Anthropic)", name: "ANTHROPIC_API_KEY")
                    KeyField(title: "Mistral", name: "MISTRAL_API_KEY")
                    KeyField(title: "OpenAI", name: "OPENAI_API_KEY")
                } header: { Text("API keys") } footer: {
                    Text("Pasted here or on your Mac, kept in iCloud Keychain like the mail password, and shared by Matterbee on all your devices. Never in a file.")
                }

                Section {
                    Text("All of them get only pseudonymised text: Claude (Anthropic, USA), Mistral (Paris) or OpenAI (USA). In the test, Mistral Large 3 sorted almost as well as Opus; for tasks, Opus was better in about one mail out of three.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { accounts = Keychain.accounts().filter { !$0.usesGoogle } }) { MailAccountSheet() }
            // A key or a password saved on a Mac may have arrived meanwhile.
            .onAppear {
                accounts = Keychain.accounts().filter { !$0.usesGoogle }
                tick += 1
            }
        }
    }
}
