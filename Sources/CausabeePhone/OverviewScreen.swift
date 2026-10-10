import MatterCore
import SwiftData
import SwiftUI

/// The overview, with each matter pushed on it, and the assistant as a sheet over both.
struct RootView: View {
    @State private var navigation = Navigation()
    @Environment(\.modelContext) private var context
    @Query private var matters: [Matter]
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var width

    /// The matter the assistant is about: the one that is open.
    private var about: Matter? { navigation.path.last.flatMap { id in matters.first { $0.persistentModelID == id } } }

    var body: some View {
        @Bindable var navigation = navigation
        // The window itself is measured, by a ground that is as large as it is and no larger: the
        // row of columns, measured, kept the width its columns had on the iPad's side, and stood
        // too wide once the iPad was turned upright again.
        Color.clear.overlay(alignment: .leading) { columns }
        // For a picture of the iPad on its side, taken in a simulator held upright: there the
        // status bar is drawn over the page, which keeps no room for it.
        .padding(.top, PhoneShot.topRoom)
        // The sidebar put away: its capsule stays where it was, over the page — the way back to the
        // sidebar, and reading and Auto still at hand. Not in the page's bar: a bar whose things
        // change with the sidebar is formed anew by the system, with a transition of its own.
        .overlay(alignment: .topLeading) {
            if navigation.isPad, !navigation.showsSidebar {
                // In a window of its own the iPad sets its three buttons in this corner: the capsule
                // stands clear of them, right of them, and where it was when there are none.
                PadControls().padding(.leading, 16).containerCornerOffset(.leading, sizeToFit: true).frame(height: PadMetrics.bar)
                    .transition(.identity)
            }
        }
        .background(Theme.canvas)
        // A shake, or ⌘Z on an iPad's keyboard, finds what was deleted by hand.
        .background { KeepsUndoAtHand().frame(width: 0, height: 0).accessibilityHidden(true) }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { wide in
            navigation.whole = wide
            let narrow = wide < PadMetrics.wide
            guard narrow != navigation.isNarrow || !navigation.measured else { return }
            navigation.measured = true
            navigation.isNarrow = narrow
            // Turned upright, the sidebar steps aside; turned on its side, it is back.
            withAnimation(.snappy(duration: 0.25)) { navigation.showsSidebar = !narrow }
        }
        .onChange(of: width, initial: true) { navigation.isPad = width == .regular }
        .tint(Theme.gold)
        .environment(\.reading, navigation.reading)
        .environment(navigation)
    }

    /// One row on every device, so the page stays the same view when an iPad's window is made
    /// narrow or wide: on the iPhone it is the page alone.
    private var columns: some View {
        @Bindable var navigation = navigation
        return HStack(spacing: 0) {
            if navigation.isPad, navigation.showsSidebar {
                PadSidebar(matters: matters).frame(width: PadMetrics.sidebar).transition(.move(edge: .leading))
                Divider().ignoresSafeArea()
            }
            // The page has what the columns beside it leave, said in points: left to take what it
            // likes, it kept the width it had before the assistant came, and slid under the sidebar.
            page.frame(width: navigation.isPad && navigation.whole > 0 ? navigation.pageWidth : nil)
            if navigation.isPad, navigation.showsAssistant {
                Divider().ignoresSafeArea()
                // In a stack of its own: what in it is as wide or as tall "as its container" — the
                // thread's newest turn — then measures by this column, not by the whole window.
                NavigationStack {
                    AssistantSheet(matter: about)
                        .toolbar(.hidden, for: .navigationBar)
                }
                    .id(about?.persistentModelID)
                    .frame(width: PadMetrics.assistant)
                    .background(Theme.canvas)
                    .sheet(item: $navigation.choosingInAssistant) { plus in MatterChooser(plus: plus) }
                    .transition(.move(edge: .trailing))
            }
        }
    }

    private var page: some View {
        @Bindable var navigation = navigation
        return NavigationStack(path: $navigation.path) {
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
        // Auto, the whole circle, as on the Mac: a matter whose record has changed and come to rest
        // gets its next step and its summary written again — while Causabee is open.
        .task {
            let context = context
            await AutoUpdate.shared.run(context: context) {
                let names = try PhoneNames.current(in: context)
                return .list(names.mapping, names.others)
            }
        }
        // `--demo --shot listening`: the care matter open, the assistant over it.
        .task {
            // `--shot matter`: the care matter alone, for the website's picture of a matter.
            guard PhoneShot.isListening || PhoneShot.isMatter, let care = matters.first(where: { $0.name.hasPrefix("Care for Mum") }) else { return }
            navigation.path = [care.persistentModelID]
            guard PhoneShot.isListening else { return }
            try? await Task.sleep(for: .seconds(1.2))
            navigation.showsAssistant = true
        }
        .sheet(isPresented: Binding(get: { navigation.showsAssistant && !navigation.isPad }, set: { navigation.showsAssistant = $0 })) {
            AssistantSheet(matter: about)
                // About another matter — one chosen from its plus — it is that matter's thread, anew.
                .id(about?.persistentModelID)
                .presentationDragIndicator(.visible)
                // Every matter, to choose from, over the assistant: the assistant stays.
                .sheet(item: $navigation.choosingInAssistant) { plus in MatterChooser(plus: plus) }
        }
        // Picked from the plus with no matter open: which one it is for.
        .sheet(item: $navigation.choosing) { plus in MatterChooser(plus: plus) }
        .modifier(MatterQuestions())
        // The share sheet's matters, and what was shared to Causabee meanwhile.
        .modifier(SharedIn(matters: matters))
        // What is connected to Calendar and Reminders is kept in step both ways, as on the Mac.
        .onAppear { MirrorRunner.shared.start(context) }
        // This iPhone's list of names into the store when it goes to the background, as the Mac's.
        .onChange(of: phase) { _, now in if now == .background { PhoneNames.publish(in: context) } }
        // The menu bar's commands, and their keys.
        .onReceive(NotificationCenter.default.publisher(for: .phoneSidebar)) { _ in
            if navigation.isPad { withAnimation(.snappy(duration: 0.25)) { navigation.showsSidebar.toggle() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phoneAssistant)) { _ in
            if navigation.showsAssistant { navigation.closeAssistant() } else { navigation.openAssistant() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phoneReading)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phoneNewMatter)) { _ in
            if navigation.isPad { navigation.go([]) } else { navigation.path = [] }
        }
        .focusedSceneValue(\.phoneWindow, PhoneWindowState(isPad: navigation.isPad, showsSidebar: navigation.showsSidebar,
                                                          showsAssistant: navigation.showsAssistant, reading: navigation.reading))
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
    /// The cursor is in "Find or start a matter".
    @FocusState private var searching: Bool
    @Environment(\.modelContext) private var context
    @State private var editsAccount = false
    @AppStorage(WelcomeSheet.seenKey) private var introSeen = false
    @State private var showsWelcome = false
    /// How many cards fit side by side: one on the iPhone, two on a wide iPad.
    private var columns: Int { navigation.isPad && navigation.pageWidth >= PadMetrics.twoColumns ? 2 : 1 }

    private var ordered: [Matter] { activeMatters(matters) }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Overview").font(Theme.phoneTitleFont)
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
                    SectionHeader(title: "Pinned", detail: nil).padding(.top, 4)
                    // Side by side where there is room for two, as on the Mac.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), alignment: .leading, spacing: 12) {
                        ForEach(pinned) { matter in
                            PhoneMatterCard(matter: matter) { todo in navigation.open(matter, showing: todo) }
                                // Held: unpinned, renamed or merged, as a row of the Mac's sidebar.
                                .contextMenu { MatterMenuItems(matter: matter, all: sidebarOrder(matters)).menuSigns() }
                        }
                    }
                }
                let rest = ordered.filter { !$0.isPinned }
                if !rest.isEmpty {
                    SectionHeader(title: pinned.isEmpty ? "Matters" : "Everything else",
                                  detail: nil)
                        .padding(.top, 4)
                    if columns == 1 {
                        PhoneMatterRows(matters: rest, all: sidebarOrder(matters))
                    } else {
                        // Two lists side by side, read down the first and then the second.
                        let half = (rest.count + 1) / 2
                        HStack(alignment: .top, spacing: 12) {
                            PhoneMatterRows(matters: Array(rest.prefix(half)), all: sidebarOrder(matters))
                            if rest.count > half { PhoneMatterRows(matters: Array(rest.dropFirst(half)), all: sidebarOrder(matters)) }
                        }
                    }
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
            .padding(.top, navigation.isPad ? 14 : 0)
            .padding(.bottom, 24)
            .pageWide(columns == 1 ? PadMetrics.page : PadMetrics.widePage)
        }
        .dismissesKeyboard()
        // Pulled down: new mail is read — free — and waits for "Sort in"; in the demo, its three.
        .modifier(PullsForMail())
        .background(Theme.canvas)
        // The assistant about every matter, as on a matter's page; held, its plus for any matter.
        .overlay(alignment: .bottomTrailing) {
            if search.isEmpty, !(navigation.isPad && navigation.showsAssistant) { AssistantButton { navigation.openAssistant() } }
        }
        // No assistant here, as on the Mac: it opens from a matter, about that matter.
        // The ⋯ in the bar, drawn by the system as in a matter: a glass of our own on it, and the
        // bar hidden here and shown there, broke the swipe back from a matter (iOS 27).
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Group {
                        Button("Settings", systemImage: "gearshape") { editsAccount = true }
                        Button("Introduction", systemImage: "info.circle") { showsWelcome = true }
                        Button(store.isDemo ? "Leave the demo" : "Try the demo", systemImage: store.isDemo ? "arrow.uturn.backward" : "sparkles") { store.switchDemo(!store.isDemo) }
                    }
                    .menuSigns()
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editsAccount) { SettingsSheet() }
        // The menu bar's commands: Settings, new mail, and the field a matter is found or started in.
        .onReceive(NotificationCenter.default.publisher(for: .phoneSettings)) { _ in editsAccount = true }
        .onReceive(NotificationCenter.default.publisher(for: .phoneGetMail)) { _ in PhoneMailCheck.shared.look(context: context) }
        .onReceive(NotificationCenter.default.publisher(for: .phoneFind)) { _ in if navigation.path.isEmpty { searching = true } }
        .onReceive(NotificationCenter.default.publisher(for: .phoneNewMatter)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { searching = true }
        }
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
                    .focused($searching)
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
            // Tapped and nothing typed yet: the matters opened last, to go straight back to. The first
            // letter typed puts what is found in their place.
            let recent = searching && query.isEmpty ? RecentMatters.list(in: matters, fillingFrom: activeMatters(matters)) : []
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("RECENT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
                    ForEach(Array(recent.enumerated()), id: \.element.persistentModelID) { index, matter in
                        if index > 0 { Divider().padding(.leading, 14) }
                        Button { searching = false; navigation.open(matter) } label: {
                            Label {
                                Text(matter.name + (matter.isClosed ? " · closed" : "")).foregroundStyle(.primary).lineLimit(1)
                            } icon: {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recent.matter")
                    }
                }
                .phoneCard()
            }
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
                 ? "This store stays on the \(ThisDevice.name)."
                 : "Pull down to get new mail, and Causabee makes the matters from it. From your Mac, they come here through your iCloud — the first time can take a few minutes.")
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
    /// `--shot-top 24`: room kept on top, in a picture only.
    static let topRoom: CGFloat = {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot-top"), at + 1 < arguments.count, let room = Double(arguments[at + 1]) else { return 0 }
        return room
    }()

    static let isMatter: Bool = {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot"), at + 1 < arguments.count else { return false }
        return arguments[at + 1] == "matter"
    }()
    static let isListening: Bool = {
        let arguments = CommandLine.arguments
        guard DemoData.isRequested, let at = arguments.firstIndex(of: "--shot"), at + 1 < arguments.count else { return false }
        return arguments[at + 1] == "listening"
    }()
}

/// A page pulled down looks for new mail. In the room the pull opens the bee comes with the pull,
/// alive — hovering, its wings beating — and whole when it is far enough. Then it is handed on, in
/// the moment the hand feels the looking begin: the bee above grows small and fades while the one
/// beside "Fetching mail …" grows and comes. The page goes back up meanwhile; the
/// system's own wheel is not shown (PhoneApp). What changes with every point of the pull is kept
/// here, so the page under it is not made anew while it is pulled.
private struct PullsForMail: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var pulled = CGFloat.zero
    /// Where the bee stood when the looking began, while it is handed on to the mail's place.
    @State private var handedFrom: CGFloat?
    @State private var going = false

    func body(content: Content) -> some View {
        content
            .refreshable {
                let check = PhoneMailCheck.shared
                handedFrom = max(10, pulled / 2 - 15)
                check.beeIsAbove = true
                check.look(context: context)
                // The mail's place is there, its bee small and unseen. Now, in one moment — the one
                // the hand feels — the bee above grows small and fades, and the one there grows and comes.
                await Task.yield()
                withAnimation(.easeInOut(duration: 0.28)) { going = true; check.beeIsAbove = false }
                try? await Task.sleep(for: .milliseconds(300))
                handedFrom = nil
                going = false
            }
            // How far it is pulled down past its top, in points.
            .onScrollGeometryChange(for: CGFloat.self) { max(0, -($0.contentOffset.y + $0.contentInsets.top)).rounded() } action: { _, far in pulled = far }
            .overlay(alignment: .top) {
                if let handedFrom {
                    BeePulled(pull: 1)
                        .scaleEffect(going ? 0.5 : 1)
                        .offset(y: handedFrom + (going ? 20 : 0))
                        .opacity(going ? 0 : 1)
                        .allowsHitTesting(false)
                } else if pulled > 6 {
                    BeePulled(pull: min(1, Double(pulled) / 90))
                        .offset(y: max(10, pulled / 2 - 15))
                        .opacity(min(1, Double(pulled) / 40))
                        .allowsHitTesting(false)
                }
            }
    }
}
