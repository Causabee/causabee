import MatterCore
import SwiftData
import SwiftUI

/// The first start on the iPhone: what Matterbee is, in a few lines, and what it needs — each
/// with whether it is there already, since most of it comes from the Mac by itself. Not the Mac's
/// five pages: on the iPhone, the matters themselves are the introduction. Again from ⋯ on the
/// overview.
struct WelcomeSheet: View {
    static let seenKey = "intro.seen"

    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneStore.self) private var store
    @Query private var lists: [NameList]
    @State private var sync = PhoneCloudStatus.shared
    @State private var addsAccount = false
    @State private var opensSettings = false
    /// Counts up when something may have come in meanwhile — a password, a key.
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        BeeMark(size: 44, livesNowAndThen: true).foregroundStyle(Theme.beeMark)
                        Text("Matterbee").font(Theme.titleFont)
                        Text("Mail, files and screenshots, sorted into matters — a trip, a move, care for a parent. The overview shows what comes next; each matter has its next step, its tasks and dates, and an assistant that answers about it with its sources. What goes to an AI goes disguised.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "What it needs").padding(.bottom, 8)
                        VStack(alignment: .leading, spacing: 0) {
                            step(done: sync.account == "signed in to iCloud", title: "iCloud",
                                 text: sync.account == "signed in to iCloud"
                                    ? "Your matters from your Mac come here, and what you do here goes back."
                                    : "Sign in to iCloud in the iPhone's Settings, with the account your Mac uses, to see its matters here.")
                            Divider().padding(.leading, 44)
                            step(done: hasAccount, title: "Mail",
                                 text: hasAccount
                                    ? "For new mail, the files of a matter and scanned letters. The password came through iCloud Keychain or was typed here."
                                    : "For new mail, the files of a matter and scanned letters. Added on your Mac, it comes here through iCloud Keychain — or add it here once.") {
                                if !hasAccount { Button("Add mail account …") { addsAccount = true }.buttonStyle(.phone) }
                            }
                            Divider().padding(.leading, 44)
                            step(done: hasKey, title: "An AI key",
                                 text: hasKey
                                    ? "For the assistant and for sorting new mail — \(ModelChoice.assistant.label)."
                                    : "For the assistant and for sorting new mail: Claude, Mistral or OpenAI. Pasted on your Mac, it comes here too — or paste it in Settings.") {
                                if !hasKey { Button("Settings …") { opensSettings = true }.buttonStyle(.phone) }
                            }
                            Divider().padding(.leading, 44)
                            step(done: hasNames, title: "A list of names",
                                 text: hasNames
                                    ? "People, companies and places are disguised with it before anything is sent."
                                    : "Comes from your Mac — or starts with the first “Get new mail” here. Until then, nothing is sent.")
                        }
                        .phoneCard()
                    }
                    .id(tick)
                    HStack(spacing: 10) {
                        if !store.isDemo {
                            Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(wide: true))
                        }
                        Button("Start") { finish() }.buttonStyle(.phone(filled: true, wide: true))
                    }
                }
                .padding(20)
                .containerRelativeFrame(.horizontal)
            }
            .background(Theme.canvas)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { tick += 1 }) { MailAccountSheet() }
            .sheet(isPresented: $opensSettings, onDismiss: { tick += 1 }) { SettingsSheet() }
            .onAppear { tick += 1 }
        }
    }

    private var hasAccount: Bool { !Keychain.accounts().filter { !$0.usesGoogle }.isEmpty }
    private var hasKey: Bool { Claude.Model.choices.contains { Claude.key(for: $0) != nil } }
    private var hasNames: Bool { !lists.isEmpty || PhoneNames.hasOwn }

    private func step<Action: View>(done: Bool, title: String, text: String, @ViewBuilder action: () -> Action = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(done ? Theme.done : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).fontWeight(.medium)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                action()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        dismiss()
    }
}
