import MatterCore
import SwiftData
import SwiftUI

/// The overview, with each matter pushed on it, and the assistant as a sheet over both.
struct RootView: View {
    @State private var navigation = Navigation()
    @Environment(\.modelContext) private var context
    @Query private var matters: [Matter]
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            OverviewScreen(matters: matters)
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    if let matter = matters.first(where: { $0.persistentModelID == id }) {
                        MatterScreen(matter: matter)
                    } else {
                        ContentUnavailableView("This matter is gone", systemImage: "folder.badge.questionmark",
                                               description: Text("It was merged or removed on another device."))
                    }
                }
        }
        .tint(Theme.gold)
        // `--demo --shot listening`: the care matter open, the assistant over it.
        .task {
            guard PhoneShot.isListening, let care = matters.first(where: { $0.name.hasPrefix("Care for Mum") }) else { return }
            navigation.path = [care.persistentModelID]
            try? await Task.sleep(for: .seconds(1.2))
            navigation.showsAssistant = true
        }
        .sheet(isPresented: $navigation.showsAssistant) {
            AssistantSheet(matter: navigation.path.last.flatMap { id in matters.first { $0.persistentModelID == id } })
                .presentationDragIndicator(.visible)
        }
        .modifier(MatterQuestions())
        // The share sheet's matters, and what was shared to Causabee meanwhile.
        .modifier(SharedIn(matters: matters))
        // What is connected to Calendar and Reminders is kept in step both ways, as on the Mac.
        .onAppear { MirrorRunner.shared.start(context) }
        // This iPhone's list of names into the store when it goes to the background, as the Mac's.
        .onChange(of: phase) { _, now in if now == .background { PhoneNames.publish(in: context) } }
        .environment(\.reading, navigation.reading)
        .environment(navigation)
    }
}

/// The week across all matters, the pinned matters as cards, and every other matter going on as
/// one line — each a door into its page (Figma "Overview with many matters", 3 + 4). Worked out on
/// the iPhone; nothing is sent.
struct OverviewScreen: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(PhoneStore.self) private var store
    @State private var search = ""
    @Environment(\.modelContext) private var context
    @State private var editsAccount = false
    @AppStorage(WelcomeSheet.seenKey) private var introSeen = false
    @State private var showsWelcome = false

    private var ordered: [Matter] { activeMatters(matters) }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = PhoneCloudStatus.shared.lastImport
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Overview").font(Theme.phoneTitleFont)
                    Text(OverviewSummary.text(ordered)).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                // In the demo, three made-up mails come in: the whole round, nothing read or sent.
                PhoneMailCheckView()
                searchField
                if matters.isEmpty {
                    empty
                } else {
                    PhoneWeek(matters: matters)
                }
                let pinned = Pins.pinned(matters)
                if !pinned.isEmpty {
                    SectionHeader(title: "Pinned", detail: "stays on top").padding(.top, 4)
                    ForEach(pinned) { matter in
                        PhoneMatterCard(matter: matter) { todo in navigation.open(matter, showing: todo) }
                            // Held: unpinned, renamed or merged, as a row of the Mac's sidebar.
                            .contextMenu { MatterMenuItems(matter: matter, all: sidebarOrder(matters)) }
                    }
                }
                let rest = ordered.filter { !$0.isPinned }
                if !rest.isEmpty {
                    SectionHeader(title: pinned.isEmpty ? "Matters" : "Everything else",
                                  detail: pinned.isEmpty ? "hold one to pin it" : rest.count == 1 ? "1 matter" : "\(rest.count) matters")
                        .padding(.top, 4)
                    PhoneMatterRows(matters: rest, all: sidebarOrder(matters))
                }
                ForEach(matters.filter { $0.isClosed && !MatterStatus($0).mailsSinceClosed.isEmpty }) { matter in
                    let new = MatterStatus(matter).mailsSinceClosed.count
                    Button { navigation.open(matter) } label: {
                        HStack {
                            Image(systemName: "archivebox").foregroundStyle(.secondary)
                            Text("\(new) new \(new == 1 ? "mail" : "mails") in the closed matter “\(matter.name)”").multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .font(.subheadline).padding(14).phoneBox()
                    }
                    .buttonStyle(.plain)
                }
                // The quiet and the closed ones, folded away: the ones going on are the cards.
                OtherMattersList(matters: matters)
                if store.isDemo {
                    Button("Leave the demo") { store.switchDemo(false) }
                        .font(.footnote).foregroundStyle(Theme.gold).padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .containerRelativeFrame(.horizontal)
        }
        .dismissesKeyboard()
        // Pulled down: new mail is read — free — and waits for "Sort in"; in the demo, its three.
        .refreshable { PhoneMailCheck.shared.look(context: context) }
        .background(Theme.canvas)
        // The assistant about every matter, as on a matter's page.
        .overlay(alignment: .bottomTrailing) {
            if search.isEmpty { AssistantButton { navigation.showsAssistant = true } }
        }
        // No assistant here, as on the Mac: it opens from a matter, about that matter.
        // The ⋯ in the bar, drawn by the system as in a matter: a glass of our own on it, and the
        // bar hidden here and shown there, broke the swipe back from a matter (iOS 27).
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Settings", systemImage: "gearshape") { editsAccount = true }
                    Button("Introduction", systemImage: "info.circle") { showsWelcome = true }
                    Button(store.isDemo ? "Leave the demo" : "Try the demo", systemImage: store.isDemo ? "arrow.uturn.backward" : "sparkles") { store.switchDemo(!store.isDemo) }
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editsAccount) { SettingsSheet() }
        // Once, at the first start: what Causabee is and what it needs.
        .sheet(isPresented: $showsWelcome) { WelcomeSheet() }
        .onAppear { if !introSeen, !store.isDemo { showsWelcome = true } }
    }

    /// On top of the cards: a matter found by its name, a task or a mail.
    @ViewBuilder
    private var searchField: some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find or start a matter", text: $search)
                    .font(.body)
                    .submitLabel(.go)
                    .onSubmit {
                        let hits = MatterSearch.find(query, in: matters)
                        if let first = hits.first { search = ""; navigation.open(first.matter) } else if !query.isEmpty { start(query) }
                    }
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
            if !query.isEmpty {
                let hits = MatterSearch.find(query, in: matters)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                        if index > 0 { Divider().padding(.leading, 14) }
                        Button { search = ""; navigation.open(hit.matter) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.matter.name + (hit.matter.isClosed ? " · closed" : "")).foregroundStyle(.primary)
                                if let because = hit.because { Text(because).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if !hits.isEmpty { Divider().padding(.leading, 14) }
                    // Made here, nothing sent: the Mac sorts mail into it from the next "Get new mail".
                    Button { start(query) } label: {
                        Label("Start new matter: “\(query)”", systemImage: "plus.circle")
                            .fontWeight(.medium).foregroundStyle(.primary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .phoneCard()
            }
        }
    }

    private func start(_ name: String) {
        guard let matter = try? Matter.make(named: name, in: context) else { return }
        search = ""
        navigation.open(matter)
    }

    /// Nothing here yet: iCloud may still be bringing the matters, or they are made on the Mac.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No matters yet").font(.headline)
            Text(PhoneCloud.container == nil
                 ? "This store stays on the iPhone."
                 : "Get new mail above, and Causabee makes the matters from it. From your Mac, they come here through your iCloud — the first time can take a few minutes.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !store.isDemo {
                Button("Try the demo") { store.switchDemo(true) }.buttonStyle(.phoneFilled)
            }
        }
        .phoneBox()
    }
}

/// Started as `--demo --shot listening`, the app shows the assistant while it listens: for the
/// website's picture, taken in the simulator, which has no microphone.
enum PhoneShot {
    static let isListening: Bool = {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot"), at + 1 < arguments.count else { return false }
        return arguments[at + 1] == "listening"
    }()
}
