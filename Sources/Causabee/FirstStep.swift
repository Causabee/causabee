import MatterCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import VisionKit
#else
import AppKit
#endif

/// F008: the overview while there are no matters — one first step, the same on every device.
/// What is typed comes in as the owner's own note; what is added as any file does. With no matters
/// there is nothing to choose, so either goes into a new matter at once, and that matter opens.
/// The demo is a quiet link under it, never the first way.
struct FirstStep: View {
    @Environment(\.modelContext) private var context
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]
    @State private var text = ""
    /// What was sent or added, until its matter is made.
    @State private var waiting: UUID?
    @State private var problem: String?
    /// Since when this page is shown: iCloud is given thirty seconds to bring another device's matters.
    @State private var shownSince = Date()
    @State private var now = Date()
    #if os(iOS)
    @Environment(PhoneStore.self) private var store
    @State private var request: AttachKind?
    #endif
    @FocusState private var typing: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var reading: Bool { waiting != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if Welcome.waitsForCloud(signedIn: Self.signedIn, imported: Self.imported, since: shownSince, now: now) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(Welcome.cloudLine)
                }
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
            BeeMark(size: 28).foregroundStyle(Theme.beeMark)
            Text(Welcome.firstTitle).font(Theme.titleFont).fixedSize(horizontal: false, vertical: true)
            Text(Welcome.firstLine).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            field
            if reading {
                HStack(spacing: 8) {
                    BeeLoader(size: 18)
                    Text(Welcome.reading).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                adds
            }
            if let problem {
                Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
            }
            if !reading {
                HStack(spacing: 4) {
                    Text(Welcome.demoAsk).foregroundStyle(.secondary)
                    Button(Welcome.demo) { lookAround() }.buttonStyle(.gold)
                        .accessibilityLabel("Look around in an example")
                        #if os(iOS)
                        .frame(minHeight: 44).contentShape(Rectangle())
                        #endif
                }
                .font(.subheadline)
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity)
        .onAppear { shownSince = Date(); now = Date() }
        // The iCloud line goes after its thirty seconds, without anything else changing.
        .task {
            while !Task.isCancelled, now.timeIntervalSince(shownSince) < Welcome.cloudWait {
                try? await Task.sleep(for: .seconds(1))
                now = Date()
            }
        }
        .onChange(of: failedWords) { _, words in
            guard let words else { return }
            waiting = nil
            problem = words
        }
        #if os(iOS)
        // The pickers of the chat's plus, opened from the buttons here; nothing of its own to see.
        .background {
            AttachButton(matter: nil, request: $request, opensAssistant: false, brought: { waiting = $0 })
                .frame(width: 1, height: 1).opacity(0).accessibilityHidden(true)
        }
        #endif
    }

    /// The chat's field, on glass, with the microphone and the send button at its end.
    private var field: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(Welcome.placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .focused($typing)
                .disabled(reading)
                .accessibilityLabel(Welcome.firstTitle)
                .onSubmit(send)
            Button(action: send) {
                SendGlyph(stops: false)
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty || reading)
            .opacity(trimmed.isEmpty || reading ? 0.4 : 1)
            .accessibilityLabel("Send")
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 10)
        .glassBehind(RoundedRectangle(cornerRadius: 24))
        .opacity(reading ? 0.55 : 1)
    }

    /// Photo, Scan, File on the iPhone and the iPad; one button and the window's drop on the Mac.
    @ViewBuilder private var adds: some View {
        #if os(iOS)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { addButtons }
            VStack(alignment: .leading, spacing: 8) { addButtons }
        }
        #else
        HStack(spacing: 10) {
            Button("Add a file …") { chooseFile() }.quietButton()
            Text("or drop it here").font(.subheadline).foregroundStyle(.secondary)
        }
        #endif
    }

    #if os(iOS)
    @ViewBuilder private var addButtons: some View {
        Button { problem = nil; request = .photo } label: { Label("Photo", systemImage: "photo") }
            .quietButton().accessibilityLabel("Add a photo")
        if VNDocumentCameraViewController.isSupported {
            Button { problem = nil; request = .scan } label: { Label("Scan", systemImage: "doc.viewfinder") }
                .quietButton().accessibilityLabel("Scan a document")
        }
        Button { problem = nil; request = .files } label: { Label("File", systemImage: "folder") }
            .quietButton().accessibilityLabel("Add a file")
    }
    #endif

    // MARK: What happens

    private func send() {
        guard !trimmed.isEmpty, !reading else { return }
        problem = nil
        let folder: URL
        #if os(iOS)
        folder = PhoneShots.folder
        #else
        folder = ScreenshotDoor.attachments(besides: navigation.store)
        #endif
        guard let file = try? Welcome.typedFile(trimmed, in: folder) else {
            problem = Welcome.notRead
            return
        }
        typing = false
        bring(file)
    }

    private func bring(_ file: URL) {
        #if os(iOS)
        waiting = PhoneShots.shared.bring(file, matter: nil, context: context, owner: profiles.first?.names.first)
        #else
        waiting = Conversation(context: context, navigation: navigation, owner: profiles.first?.names.first).bring(file)
        #endif
    }

    #if os(macOS)
    private func chooseFile() {
        problem = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ScreenshotDoor.readable.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        bring(url)
    }
    #endif

    private func lookAround() {
        #if os(iOS)
        store.switchDemo(true)
        #else
        DemoData.restart(demo: true)
        #endif
    }

    private var failedWords: String? {
        guard let waiting else { return nil }
        #if os(iOS)
        guard let shot = PhoneShots.shared.shots.first(where: { $0.id == waiting }) else { return nil }
        if case .failed(let why) = shot.stage { return why.isEmpty ? Welcome.unreadable : why }
        #else
        guard let turn = navigation.turns.first(where: { $0.id == waiting }) else { return nil }
        if case .failed(let why) = turn.shot?.stage { return why.isEmpty ? Welcome.unreadable : why }
        #endif
        return nil
    }

    // MARK: iCloud

    private static var signedIn: Bool {
        #if os(iOS)
        PhoneCloud.container != nil && PhoneCloudStatus.shared.account == "signed in to iCloud"
        #else
        CloudSync.mode == .on && CloudSync.shared.account == "signed in to iCloud"
        #endif
    }

    private static var imported: Bool {
        #if os(iOS)
        PhoneCloudStatus.shared.lastImport != nil
        #else
        CloudSync.shared.lastImport != nil
        #endif
    }
}

extension Notification.Name {
    /// A first matter was made at once from what came in (F008): the window opens it. The first
    /// step cannot — it is gone the moment there is a matter.
    static let firstMatter = Notification.Name("causabee.firstMatter")
}

/// Opens the first matter once it is made (F008), wherever the window is.
struct FirstMatterOpens: ViewModifier {
    let navigation: Navigation
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .firstMatter)) { note in
            guard let id = note.object as? PersistentIdentifier, let matter = context.model(for: id) as? Matter else { return }
            navigation.open(matter)
        }
    }
}

/// F008 AC-8: once a matter exists and no mailbox is set up, mail is offered — once, quietly, under
/// the matters. Visible, never an obligation: no yellow, no badge, no count.
struct MailOffer: View {
    let matters: Int
    let setUp: () -> Void
    @AppStorage(Welcome.mailLaterKey) private var later = false

    var body: some View {
        if Welcome.offersMail(matters: matters, hasMailbox: !Keychain.accounts().isEmpty, later: later) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Welcome.mailTitle).fontWeight(.semibold)
                Text(Welcome.mailLine).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("Set up", action: setUp).quietButton()
                    Button("Not now") { later = true }.buttonStyle(.gold)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(iOS)
            .padding(16)
            .phoneCard()
            #else
            .journalCard()
            #endif
        }
    }
}
