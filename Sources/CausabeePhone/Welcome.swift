import MatterCore
import SwiftData
import SwiftUI

/// The first start on the iPhone (Figma "Welcome 1"): a promise in the website's voice, care first;
/// one matter as it looks; what this iPhone has as ticks — a button only where something is
/// missing, since most of it comes from the Mac by itself; privacy in one line; and the demo as
/// the first thing to try. Again from ⋯ on the overview, where everything there puts the owner's
/// own matters first.
struct WelcomeSheet: View {
    static let seenKey = "intro.seen"

    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneStore.self) private var store
    @State private var sync = PhoneCloudStatus.shared
    @State private var addsAccount = false
    @State private var opensSettings = false
    /// Counts up when something may have come in meanwhile — a password, a key.
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    promise
                    sample
                    checks.id(tick)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "eyeglasses").font(.footnote)
                        Text("Names are disguised before anything is sent — and only when you tap.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
                .containerRelativeFrame(.horizontal)
            }
            // The buttons stay at the foot, whatever the length of the page.
            .safeAreaInset(edge: .bottom) { buttons }
            .background(Theme.canvas)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { tick += 1 }) { MailAccountSheet() }
            .sheet(isPresented: $opensSettings, onDismiss: { tick += 1 }) { SettingsSheet() }
            .onAppear { tick += 1 }
        }
    }

    private var promise: some View {
        VStack(alignment: .leading, spacing: 12) {
            BeeMark(size: 44, livesNowAndThen: true).foregroundStyle(Theme.beeMark)
            Text("Every matter.\nIn its place.").font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
            Text("Mum’s care, a claim, a move: each in its own place — with what comes next, and who does what by when.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One matter as the overview shows it — a picture of what is to come, not a real one.
    private var sample: some View {
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: "1 for you · waiting for 1")
            Text("Care for Mum (Helga) after her fall").font(Theme.phoneCardTitleFont).fixedSize(horizontal: false, vertical: true)
            Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .phoneCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("An example: Care for Mum after her fall. Next, on October 6, the medical service visits.")
    }

    private var signedIn: Bool { sync.account == "signed in to iCloud" }
    private var hasAccount: Bool { !Keychain.accounts().filter { !$0.usesGoogle }.isEmpty }
    private var hasKey: Bool { Claude.Model.choices.contains { Claude.key(for: $0) != nil } }
    private var allThere: Bool { signedIn && hasAccount && hasKey }

    /// What this iPhone has: a tick and two words where it is there, a button where it is not.
    /// The list of names is no row: it comes from the Mac, and until it is there nothing is sent.
    private var checks: some View {
        let there = [signedIn, hasKey, hasAccount].filter { $0 }.count
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "On this iPhone", detail: there == 3 ? "All there" : "\(there) of 3 there")
            VStack(spacing: 0) {
                check("iCloud", done: signedIn, detail: signedIn ? "from your Mac" : "sign in, in Settings")
                Divider().padding(.leading, 48)
                check("AI key", done: hasKey, detail: hasKey ? ModelChoice.assistant.label : "for the assistant") {
                    Button("Add …") { opensSettings = true }.buttonStyle(.phone)
                }
                Divider().padding(.leading, 48)
                check("Mail", done: hasAccount, detail: hasAccount ? "ready" : "for new mail") {
                    Button("Add …") { addsAccount = true }.buttonStyle(.phone)
                }
            }
            .phoneCard()
        }
    }

    private func check<Action: View>(_ title: String, done: Bool, detail: String, @ViewBuilder action: () -> Action = { EmptyView() }) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(done ? Theme.done : .secondary)
                .frame(width: 20)
            Text(title).fontWeight(.medium)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            if !done { action() }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// First start: the demo first. Everything there — the usual case on a second device — and
    /// the owner's own matters come first.
    private var buttons: some View {
        VStack(spacing: 8) {
            if store.isDemo {
                Button("Start") { finish() }.buttonStyle(.phone(filled: true, wide: true))
            } else if allThere {
                Button("Open my matters") { finish() }.buttonStyle(.phone(filled: true, wide: true))
                Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(wide: true))
            } else {
                Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(filled: true, wide: true))
                Button("Start with my matters") { finish() }.buttonStyle(.phone(wide: true))
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .background(Theme.canvas)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        dismiss()
    }
}
