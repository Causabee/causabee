import MatterCore
import SwiftData
import SwiftUI

/// The first start on the iPhone and the iPad, and again from ⋯ on the overview: the Mac's
/// introduction, page by page — the promise; four pictures of the demo's matters, each with what
/// it shows; and what this device has, as ticks, with the way in: the demo first on a first start,
/// the owner's own matters first once everything is there.
struct WelcomeSheet: View {
    static let seenKey = "intro.seen"

    struct Page {
        let image: String
        let title: String
        let text: String
        /// A line of its own under the text, with a lock: what stays private.
        var privacy: String? = nil
    }

    /// The Mac's pages, said for a touch screen; its files-and-people page goes into the third.
    static let pages = [
        Page(image: "phone-intro-1.jpg", title: "Mail, files, screenshots: sorted into matters",
             text: "Give Causabee whatever you have: a mail, a PDF, a screenshot. It sorts everything into matters — a trip, a move, care for a parent — and the overview shows what comes next and what is late.",
             privacy: "Your mail and files stay with you. Before anything goes to the AI, names, addresses and numbers are replaced."),
        Page(image: "phone-intro-2.jpg", title: "One page for each matter",
             text: "The next step, a short summary, your own notes and every task, all in one place. The bee opens the assistant for this matter."),
        Page(image: "phone-intro-3.jpg", title: "Who does what, and by when",
             text: "Tasks are yours, shared, or someone else’s you wait for. Dates and tasks go to Calendar and Reminders with a tap, and every fact leads back to the mail it came from."),
        Page(image: "phone-intro-4.jpg", title: "Ask about a matter",
             text: "Ask, or speak, and get an answer with its sources. A suggestion becomes a task with one tap. Your question goes out disguised, like everything else."),
    ]
    /// The promise, the pictures, and what this device has.
    private static let count = pages.count + 2

    @Environment(\.dismiss) private var dismiss
    @Environment(PhoneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sync = PhoneCloudStatus.shared
    @State private var addsAccount = false
    @State private var opensSettings = false
    @State private var index = 0
    /// Counts up when something may have come in meanwhile — a password, a key.
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                page { promise }.tag(0)
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { offset, item in
                    page { picturePage(item) }.tag(offset + 1)
                }
                page { ready }.tag(Self.count - 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // The dots and the buttons stay at the foot, whatever the page.
            .safeAreaInset(edge: .bottom) { foot }
            .background(Theme.canvas)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
            .sheet(isPresented: $addsAccount, onDismiss: { tick += 1 }) { MailAccountSheet() }
            .sheet(isPresented: $opensSettings, onDismiss: { tick += 1 }) { SettingsSheet() }
            .onAppear { tick += 1 }
        }
    }

    /// One page: as wide as the sheet, its words in a column a person reads comfortably — on an
    /// iPad's wide sheet too — and scrolling when a large type size needs more than the screen.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var promise: some View {
        VStack(alignment: .leading, spacing: 16) {
            BeeMark(size: 44, livesNowAndThen: true).foregroundStyle(Theme.beeMark)
            Text("Every matter.\nIn its place.").font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
            Text("Mum’s care, a claim, a move: each in its own place — with what comes next, and who does what by when.")
                .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            sample.padding(.top, 8)
        }
        .padding(.top, 24)
    }

    /// One matter as the overview shows it — a picture of what is to come, not a real one.
    private var sample: some View {
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: "1 for you · waiting for 1")
            Text("Care for Mum (Helga) after her fall").font(Theme.phoneCardTitleFont).fixedSize(horizontal: false, vertical: true)
            Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("An example: Care for Mum after her fall. Next, on October 6, the medical service visits.")
    }

    /// A picture of the demo on this device, its title and what it shows.
    private func picturePage(_ item: Page) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            picture(item.image)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            Text(item.title).font(Theme.phoneCardTitleFont).fixedSize(horizontal: false, vertical: true)
            Text(item.text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let privacy = item.privacy {
                Label(privacy, systemImage: "lock.fill")
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.box, in: RoundedRectangle(cornerRadius: 10))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The screenshot as a small phone screen: rounded, framed, about half the height it has.
    private func picture(_ name: String) -> some View {
        Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Theme.box.aspectRatio(0.46, contentMode: .fit)
            }
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .accessibilityHidden(true)
    }

    /// What this device has, and that names are disguised.
    private var ready: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ready when you are").font(Theme.phoneCardTitleFont)
            checks.id(tick)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "eyeglasses").font(.footnote)
                Text("Names are disguised before anything is sent — and only when you tap.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var signedIn: Bool { sync.account == "signed in to iCloud" }
    private var hasAccount: Bool { !Keychain.accounts().filter { !$0.usesGoogle }.isEmpty }
    private var allThere: Bool { signedIn && hasAccount }
    /// No key needed: without Pro, Apple's model on the device reads the mail.
    private var planWords: String {
        switch Store.shared.plan {
        case .free: "free — reads on this \(ThisDevice.name)"
        case .matters: "Causabee Plus"
        case .pro: "Causabee Pro"
        }
    }

    /// What this iPhone has: a tick and two words where it is there, a button where it is not.
    /// The list of names is no row: it comes from the Mac, and until it is there nothing is sent.
    private var checks: some View {
        let there = [signedIn, true, hasAccount].filter { $0 }.count
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "On this \(ThisDevice.name)", detail: there == 3 ? "All there" : "\(there) of 3 there")
            VStack(spacing: 0) {
                check("iCloud", done: signedIn, detail: signedIn ? "from your Mac" : "sign in, in Settings")
                Divider().padding(.leading, 48)
                check("Plan", done: true, detail: planWords)
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

    /// The dots, and the way on: Next through the pages — Skip goes to the last — and on the last,
    /// the demo first on a first start, the owner's own matters first once everything is there.
    private var foot: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<Self.count, id: \.self) { dot in
                    Circle().fill(dot == index ? Theme.ink : Theme.strongLine).frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Page \(index + 1) of \(Self.count)")
            VStack(spacing: 8) {
                if index < Self.count - 1 {
                    Button("Next") { go(index + 1) }.buttonStyle(.phone(filled: true, wide: true))
                    Button("Skip") { go(Self.count - 1) }.buttonStyle(.phone(wide: true))
                } else if store.isDemo {
                    Button("Start") { finish() }.buttonStyle(.phone(filled: true, wide: true))
                } else if allThere {
                    Button("Open my matters") { finish() }.buttonStyle(.phone(filled: true, wide: true))
                    Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(wide: true))
                } else {
                    Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(filled: true, wide: true))
                    Button("Start with my matters") { finish() }.buttonStyle(.phone(wide: true))
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas)
    }

    private func go(_ page: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index = page }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        dismiss()
    }
}
