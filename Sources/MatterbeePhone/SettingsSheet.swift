import MatterCore
import SwiftData
import SwiftUI

/// What the iPhone needs to ask and to open files, and whether it has it: the mail account, the
/// Claude key, and the list of names from a Mac. The first two come from the Mac through iCloud
/// Keychain, or are typed here once; the list only ever comes from a Mac.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NameList.updatedAt, order: .reverse) private var lists: [NameList]
    @State private var accounts = Keychain.accounts().filter { !$0.usesGoogle }
    @State private var hasKey = Claude.key(for: .opus) != nil
    @State private var pasted = ""
    @State private var addsAccount = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if accounts.isEmpty {
                        Text("Not set up yet").foregroundStyle(.secondary)
                    }
                    ForEach(accounts, id: \.user) { account in
                        LabeledContent(account.user, value: account.host)
                    }
                    Button(accounts.isEmpty ? "Add mail account …" : "Change …") { addsAccount = true }
                } header: {
                    Text("Mail")
                } footer: {
                    Text("To open a matter's files from your mail, and to put a scanned document into it.")
                }

                Section {
                    if hasKey {
                        Label("Saved — shared with your Macs through iCloud Keychain", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.done)
                        Button("Remove from all devices", role: .destructive) {
                            APIKeys.delete("ANTHROPIC_API_KEY")
                            hasKey = Claude.key(for: .opus) != nil
                        }
                    } else {
                        SecureField("Paste the key (sk-ant-…)", text: $pasted)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Save") {
                            do {
                                try APIKeys.save(pasted, as: "ANTHROPIC_API_KEY")
                                pasted = ""
                                hasKey = Claude.key(for: .opus) != nil
                                failure = nil
                            } catch { failure = "\(error)" }
                        }
                        .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let failure { Text(failure).foregroundStyle(Theme.warning) }
                } header: {
                    Text("Claude key")
                } footer: {
                    Text("The assistant asks Claude with it. A key saved on your Mac comes here by itself through iCloud Keychain, once the Mac has opened it — or paste it here, and your Macs get it.")
                }

                Section {
                    if lists.isEmpty {
                        Label("Not here yet", systemImage: "hourglass").foregroundStyle(Theme.warning)
                    }
                    ForEach(lists) { list in
                        LabeledContent(list.deviceName.isEmpty ? "A Mac" : list.deviceName,
                                       value: list.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: {
                    Text("List of names")
                } footer: {
                    Text("Names are disguised with your Mac's list before anything is sent. Each Mac puts its list into iCloud when Matterbee starts there, and when you switch away from it. Without a list, the assistant sends nothing.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { accounts = Keychain.accounts().filter { !$0.usesGoogle } }) { MailAccountSheet() }
            // A key or a password saved on a Mac may have arrived meanwhile.
            .onAppear {
                accounts = Keychain.accounts().filter { !$0.usesGoogle }
                hasKey = Claude.key(for: .opus) != nil
            }
        }
    }
}
