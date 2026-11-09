import EventKit
import MatterCore
import QuickLook
import SwiftData
import SwiftUI

/// One matter on the iPhone and the iPad, as one journal: what is new and what comes next on top,
/// then what happened, a day at a time; the filters show the plan, the mail, the files, the people
/// and the notes alone — read from the store the Mac fills. Ticking a task, writing the notes and
/// closing the matter sync back.
struct MatterScreen: View {
    let matter: Matter
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @State private var showsDone = false
    @State private var showsPast = false
    @State private var writingNote = false
    /// A task the owner is writing with "Add Task": in the matter while its sheet is open, taken
    /// out again if it is left without words.
    @State private var newTodo: Todo?
    @State private var asksToClose = false
    @State private var splitting = false
    @State private var find = PageFind()
    @State private var finding = false
    @FocusState private var findFocused: Bool
    @State private var newMatterName = ""
    @State private var marked: PersistentIdentifier?
    /// The filter that is open: a matter with much to do opens on its plan.
    @State private var part: Journal.Part
    /// What is open in the one card for what has no date.
    @State private var atHand: Set<AtHandRow> = []
    /// The old months opened, and the conversations opened.
    @State private var openMonths: Set<String> = []
    @State private var openThreads: Set<String> = []
    /// Which of them, and in which order: the two menus over Mail and Files.
    @State private var show: RecordBrowse.Show = .all
    @State private var sort: RecordBrowse.Sort = .newest
    /// How much of the page is seen under the bar.
    @State private var pageHeight = CGFloat.zero
    @State private var choosingIcon = false
    @State private var addingContact = false
    @State private var addingDetail = false
    @State private var addingLink = false
    @State private var addingScan = false
    @State private var addingFiles = false
    /// Files or a folder being brought in: how far it is, and what it came to.
    @State private var coming = FilesComing.State()
    @State private var bringing: Task<Void, Never>?
    /// Where the page stands while it scrolls: whether the parts are under the bar. Kept apart
    /// from the page's own state — the parts passing under the bar redraw the tabs, not the page.
    @State private var scroll = PageScroll()
    /// The matter written out as a document, and why it could not be.
    @State private var exported: URL?
    @State private var exportFailure: String?
    /// One person's part of the record: chosen in "People".
    @State private var person: PersistentIdentifier?
    /// Every conversation shown, not only the newest: a source pointed at an older mail.
    @State private var showsAllHistory = false
    @Query private var profiles: [Profile]
    @Environment(PhoneStore.self) private var store
    @State private var askingStep = false
    @AppStorage(AutoMode.key) private var auto = false
    @State private var stepError: String?
    @State private var writingSummary = false
    @State private var summaryError: String?
    /// The owner's reminders, read when the matter opens and again when Reminders changes.
    @State private var reminders: [Calendars.Reminder] = []
    @State private var calendarTick = 0

    init(matter: Matter) {
        self.matter = matter
        _part = State(initialValue: Journal.opening(matter, today: MatterStatus.day(Date())))
    }

    /// What Mail and Files show of the record.
    private var filter: RecordBrowse.Kind { part == .mail ? .mail : .files }
    /// A wide iPad has room for what is ahead in a column of its own.
    /// With the chat closed there is none: the page is one column, read from top to bottom.
    private var hasColumn: Bool { navigation.isPad && navigation.pageWidth >= 860 && navigation.showsAssistant }
    /// What that column takes of the page's room. While finding it is away, and the page has it all.
    private var beside: CGFloat { hasColumn && !find.isActive ? PadMetrics.column : 0 }

    var body: some View {
        // Drawn again when this matter changes — here or from another device: the page reads it.
        // Not after every change to the store: one to another matter changes nothing here.
        let _ = ScreenMeter.printsChanges ? Self._printChanges() : ()
        let status = MatterStatus(matter)
        let plan = Journal.plan(status)
        ScrollViewReader { scroller in
            HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardGap) {
                    header(status)
                    if find.isActive {
                        // Searching looks into every part, so everything is on the page.
                        top(status, plan, scroller)
                        planList(status, plan)
                        FilesSection(matter: matter)
                        LinksSection(matter: matter)
                        PeopleSection(matter: matter)
                        notesPart
                        history(status)
                    } else {
                        // Under the bar the pinned ones stand for them: these do not show through it.
                        UnderBar(scroll: scroll) { parts() }
                            .id("parts")
                            // Gone up to where the pinned ones stand, 6 points under the bar: then those
                            // take their place at once, on the same spot, so nothing jumps.
                            .onGeometryChange(for: Bool.self) { [scroll] in $0.frame(in: .global).minY < scroll.topInset + 6 } action: { scroll.partsUnder = $0 }
                        // At least as tall as the page shows: a short part does not pull the page
                        // down, and the filters stay where they were tapped.
                        VStack(alignment: .leading, spacing: Theme.cardGap) {
                            switch part {
                            case .all:
                                if personParty == nil {
                                    // Wide, the column has what comes next: the journal begins with what is new.
                                    if hasColumn {
                                        if matter.isClosed { closedBanner(status) }
                                        NewsCard(matter: matter, editor: Self.newEditor)
                                    } else {
                                        top(status, plan, scroller)
                                    }
                                }
                                journal(status)
                            case .plan:
                                // The next step lives in the digest only: here, over the plan it is
                                // one of, it read as a second plan.
                                if !hasColumn {
                                    if matter.isClosed { closedBanner(status) } else { ForYouCard(matter: matter, folds: true) }
                                }
                                planList(status, plan)
                                CalendarAccessBanner { loadCalendars() }
                            case .mail, .files:
                                record(status)
                            case .people:
                                PeopleSection(matter: matter) { party in person = party.persistentModelID; part = .all }
                            case .notes:
                                notesPart
                            }
                            HiddenItemsLine(matter: matter)
                        }
                        .frame(maxWidth: .infinity, minHeight: max(0, pageHeight - 120), alignment: .topLeading)
                        // Where a part begins: a part chosen from the pinned tabs is shown from here.
                        .id("part")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                // On an iPad no wider than is good to read.
                // Exactly the page's width, and on an iPad no wider than is good to read: nothing on
                // the page — a long address, a word without a break — can make it wider and let it
                // slide sideways.
                .pageWide(PadMetrics.page, beside: beside)
                // A tap on the page puts the keyboard away. Behind the page, not over it: a tap
                // gesture over the scroll view takes the taps from the system's segmented control.
                .background {
                    Color.clear.contentShape(Rectangle()).onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // Pulled down: the next step and the summary are written again — with Auto on, too.
            .refreshable { writeAnew() }
            .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { pageHeight = $1 }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.top } action: { scroll.topInset = $1 }
            // Another part chosen from the pinned tabs: it is shown from its start, not from where the last one was read.
            .onChange(of: part) {
                // Right under the pinned tabs, which stay: the part's start at their lower edge.
                if scroll.partsUnder { scroller.scrollTo("part", anchor: UnitPoint(x: 0.5, y: 44 / max(pageHeight, 200))) }
            }
            .onAppear {
                // `--part record`: starts in that part — for the scroll tour.
                if let at = CommandLine.arguments.firstIndex(of: "--part"), at + 1 < CommandLine.arguments.count,
                   let chosen = Journal.Part(asked: CommandLine.arguments[at + 1]) { part = chosen }
                show(navigation.showing, with: scroller); showNews(with: scroller); loadCalendars()
                // `--timing`: from the tap to the page drawn — said after the frame it came in.
                if let asked = Navigation.askedAt {
                    DispatchQueue.main.async { NSLog("[timing] matter page %d ms", Int(Date().timeIntervalSince(asked) * 1000)); Navigation.askedAt = nil }
                }
            }
            // Asked to show a task while the page is open already — from a card in the assistant.
            .onChange(of: navigation.showing) { if navigation.showing != nil { show(navigation.showing, with: scroller) } }
            .onChange(of: navigation.showsNews) { showNews(with: scroller) }
            .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in loadCalendars() }
            .onPreferenceChange(PageFindMatches.self) { found in
                MainActor.assumeIsolated {
                    find.matches = found
                    if find.index >= found.count { find.index = 0 }
                }
            }
            .onChange(of: find.query) {
                find.index = 0
                // What is folded away is looked into too.
                if find.isActive { showsDone = true; showsPast = true }
            }
            .onChange(of: find.current) { if let at = find.current { withAnimation { scroller.scrollTo(at, anchor: .center) } } }
                // What is ahead keeps its own column while the journal scrolls beside it.
                if hasColumn, !find.isActive {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.cardGap) {
                            if !matter.isClosed {
                                // The next step with the digest only, as on the iPhone.
                                if part == .all { nextStep(status, scroller) }
                                ForYouCard(matter: matter, folds: part != .all)
                            }
                            // The summary over what is ahead: what the matter is, then its dates.
                            atHandCard
                            if !matter.isClosed, part != .plan, plan.openCount > 0 { AheadCard(plan: plan, tick: tick, open: { part = .plan }, days: 4, editor: Self.newEditor) }
                            BallCard(matter: matter)
                        }
                        .padding(.top, 10).padding(.trailing, 16).padding(.bottom, 90)
                    }
                    .frame(width: PadMetrics.column)
                }
            }
            // Over the page, not in it: the page keeps its place when they come and go.
            .overlay(alignment: .top) {
                PinnedParts(scroll: scroll, hidden: find.isActive) {
                    // The tabs change places without a fade: there is one set of them at a time.
                    // As wide as they are in the page, on a bar across the whole width: on an
                    // iPad the page is narrower than its column, and the bar goes on over what is ahead.
                    parts()
                        .padding(.horizontal, 16)
                        .frame(maxWidth: PadMetrics.page, alignment: .leading).frame(maxWidth: .infinity)
                        .padding(.trailing, beside)
                        .padding(.top, 6).padding(.bottom, 10)
                        .background(.bar, ignoresSafeAreaEdges: .top)
                        .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
        .environment(find)
        .shownToAuto(matter)
        // Edit → Find, ⌘F: in the matter that is open.
        .onReceive(NotificationCenter.default.publisher(for: .phoneFind)) { _ in
            if navigation.path.last == matter.persistentModelID { startFinding() }
        }
        .safeAreaBar(edge: .top) { if finding { findBar } }
        // While finding, the hard edge: the page under the field is held back enough for the words
        // typed to be read on the glass; the soft one let the text under it show through.
        .scrollEdgeEffectStyle(finding ? .hard : .automatic, for: .top)
        .background(Theme.page)
        .overlay(alignment: .bottomTrailing) {
            // Not over the keyboard while finding. The bee asks, and adds: the plus is beside its field.
            if !finding {
                VStack(alignment: .trailing, spacing: 12) {
                    LetterShotBringer(matter: matter)
                    if !(navigation.isPad && navigation.showsAssistant) { AssistantButton(matter: matter) { navigation.openAssistant() } }
                }
            }
        }
        // As on the Mac: a link dragged from the browser onto the matter is kept in it, and files
        // dragged from Files become its files — kept, not read. What is to be read goes to the assistant.
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            if !files.isEmpty { bring(files) }
            let web = urls.filter { !$0.isFileURL }.compactMap { WebLink.address(in: $0.absoluteString) }
            for address in web where !(matter.links ?? []).shown.contains(where: { $0.address == address && $0.todo == nil }) {
                let link = WebLink(address: address, title: "")
                context.insert(link)
                link.matter = matter
            }
            if !web.isEmpty { try? context.save() }
            return !web.isEmpty || !files.isEmpty
        }
        // The keyboard's Matter menu, on the iPad.
        .onReceive(NotificationCenter.default.publisher(for: .phoneMatterAction)) { note in
            guard let name = note.object as? String else { return }
            if name == "writeAgain" { writeAnew() } else if let action = MatterAction(rawValue: name) { run(action) }
        }
        // Picked from the assistant's plus: once its sheet has gone, the editor comes.
        .onChange(of: navigation.adding) {
            guard let adding = navigation.adding else { return }
            navigation.adding = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                switch adding {
                case .task: part = .plan; addTodo()
                case .note: part = .notes; writingNote = true
                case .contact: addingContact = true
                case .detail: addingDetail = true
                case .link: addingLink = true
                case .scan: addingScan = true
                case .files: addingFiles = true
                }
            }
        }
        .sheetWhenAsked(isPresented: $addingScan, onDismiss: { part = .files }) { ScanSheet(matter: matter) }
        // Files, or a folder with all that is in it: each a file of the matter, as on the Mac.
        .fileImporter(isPresented: $addingFiles, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            if case .success(let picked) = result { bring(picked) }
        }
        .sheetWhenAsked(isPresented: $coming.shows) {
            FilesComing(state: coming) { bringing?.cancel() }
                .presentationDetents([.height(210)])
                .interactiveDismissDisabled(coming.said == nil)
        }
        .sheetWhenAsked(isPresented: $addingContact, onDismiss: { part = .people }) { ContactEditor(matter: matter) }
        .sheetWhenAsked(isPresented: $addingDetail, onDismiss: { part = .all; atHand.insert(.details) }) { DetailEditor(matter: matter) }
        .sheetWhenAsked(isPresented: $addingLink, onDismiss: { part = .files }) {
            PhoneLinkEditor(link: nil, todos: matter.openTodos) { address, title, todo in
                guard !(matter.links ?? []).shown.contains(where: { $0.address == address && $0.todo === todo }) else { return }
                let link = WebLink(address: address, title: title)
                context.insert(link)
                link.matter = matter
                link.todo = todo
                try? context.save()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // On the iPad the sidebar leads to the overview and to every matter: no way back is needed
        // beside it.
        .navigationBarBackButtonHidden(navigation.isPad)
        .toolbar {
            // The bar has the same things in it whether the sidebar is open or put away: one that
            // came and went with the sidebar made the system form find and ⋯ anew — they shrank
            // into one, blurred and came back as two. The sidebar's own capsule lies over the page
            // while the sidebar is away (RootView), and the name stands clear of it.
            // The matter's icon and name in the bar, as on the Mac: on the line of find and ⋯, and
            // there however far the page is scrolled. On the bar's own ground, no glass around them.
            if navigation.isPad {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 10) {
                        Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 32) }
                            // A bar draws its symbols a size up: here the icon keeps the share of
                            // its tile it has everywhere else.
                            .imageScale(.medium)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Icon").accessibilityHint("Chooses another icon")
                        // At its own size always, as large beside the page's text as on the Mac and the
                        // iPhone: a name too long for the bar ends in "…", it is not made small to fit.
                        Text(matter.name).font(Theme.padTitleFont).lineLimit(1).truncationMode(.tail)
                            .accessibilityIdentifier("matter.title")
                    }
                    // Its room said in points — what find and ⋯, and the sidebar's button, leave of
                    // the page's width: left to the bar, the name got the width of a letter.
                    // On the page's own left edge, over its first line — and clear of the sidebar's
                    // capsule where that lies over the page.
                    // Where the page's words begin, 16 in from its edge; less the 10 the bar puts
                    // before its first item by itself — counted twice, the icon and the name stood
                    // a little right of the page's words, and 22 points off the capsule (6 November).
                    .padding(.leading, max((navigation.pageWidth - beside - min(navigation.pageWidth - beside, PadMetrics.page)) / 2 + 16,
                                           navigation.showsSidebar ? 0 : PadMetrics.controls) - PadMetrics.barInset)
                    .frame(width: max(120, navigation.pageWidth - 172), alignment: .leading)
                    // Moved with the page, not by a transition of the bar's own.
                    .animation(nil, value: navigation.showsSidebar)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { startFinding() } label: { Image(systemName: "magnifyingglass") }
                    .tint(.primary)
                    .accessibilityLabel("Find in this matter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Group {
                        // What can be added, and the next step and summary written again — as the Mac's ⋯ has them.
                        MatterAddItems(writeAgain: writeAnew)
                        // The other matters are fetched when the menu needs them: not with every page.
                        MatterMenuItems(matter: matter, all: nil)
                        // Everything the matter holds, as one document: what is gathered here can leave at any time.
                        Button(Say.exportRTF, systemImage: "square.and.arrow.up", action: export)
                        // Reading mode: no button of its own in the bar any more, the owner seldom used it;
                        // here, as in the Mac's View menu, and kept for what is shared later.
                        Button(navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode", systemImage: "eyeglasses") {
                            withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
                        }
                        Divider()
                        if matter.isClosed {
                            Button(Say.openAgain, systemImage: "arrow.uturn.backward") { matter.reopen(); try? context.save() }
                        } else {
                            Button(Say.closeMatter, systemImage: "archivebox") { asksToClose = true }
                        }
                    }
                    .menuSigns()
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        // The exported document, shown: its share button sends it on.
        .quickLookPreview($exported)
        .alert("The matter could not be exported", isPresented: Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })) {
            Button("OK") { exportFailure = nil }
        } message: { Text(exportFailure ?? "") }
        .sheet(item: $newTodo, onDismiss: dropEmptyTodos) { todo in PhoneTodoEditor(todo: todo, isNew: true) }
        .confirmationDialogWhenAsked(closeQuestion, isPresented: $asksToClose, titleVisibility: .visible) {
            if matter.openTodos.isEmpty {
                Button("Close") { close(markingOpenDone: false) }
            } else {
                Button("Mark all done and close") { close(markingOpenDone: true) }
                Button("Leave them open and close") { close(markingOpenDone: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The matter goes away from the list and from the assistant. Nothing is deleted, and “Open again” brings it back.")
        }
    }

    private var closeQuestion: String {
        let open = matter.openTodos.count
        return open == 0 ? "Close “\(matter.name)”?"
            : "Close “\(matter.name)”? \(open) \(open == 1 ? "task is" : "tasks are") still open."
    }

    /// Copied in the background — a file in iCloud Drive is brought down first, and a folder of
    /// them takes its time — while a sheet says how far it is; then they are the matter's files.
    private func bring(_ picked: [URL]) {
        coming = FilesComing.State(shows: true)
        let taken = FolderImport.taken(by: matter.documents ?? [])
        let folder = PhoneShots.folder
        let state = coming
        let work = Task.detached(priority: .userInitiated) {
            FolderImport.bring(picked, taken: taken) { file, name in
                FolderImport.data(of: file).flatMap { PhoneShots.keep($0, named: name, in: folder) }
            } progress: { done, total, name in
                Task { @MainActor in state.done = done; state.total = total; state.name = name }
            }
        }
        bringing = Task {
            let outcome = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            let result = FolderImport.take(outcome, into: matter, context: context)
            try? context.save()
            PhoneFolderSaver.save([matter])
            part = .files
            bringing = nil
            // One file, added: nothing to say, as before.
            if let said = result.said { coming.said = said } else { coming.shows = false }
        }
    }

    private func close(markingOpenDone: Bool) {
        matter.close(markingOpenDone: markingOpenDone)
        try? context.save()
    }

    /// From a notification of news: what is new, whole, under the bar at the top — with room above
    /// it for the tabs that pin there once the page has moved.
    private func showNews(with scroller: ScrollViewProxy) {
        guard navigation.showsNews else { return }
        navigation.showsNews = false
        // The news stands in the Digest: a matter that opened on its plan, or on one person, goes
        // there first — else the tap landed on the plan's top and the news was nowhere.
        part = .all
        person = nil
        // The news, or what is new without news: both stand in the card at "news".
        guard matter.shownBrief?.news?.seen == false || !matter.newItems().isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.snappy) { scroller.scrollTo("news", anchor: UnitPoint(x: 0.5, y: 72 / max(pageHeight, 200))) }
            Haptics.landed()
        }
    }

    /// The task an overdue line pointed at: scrolled to and marked for a moment.
    private func show(_ id: PersistentIdentifier?, with scroller: ScrollViewProxy) {
        guard let id else { return }
        navigation.showing = nil
        defer { navigation.showsInItsPart = false }
        if status(of: id)?.isDone == true { showsDone = true }
        // The part of the page it is in, with nothing filtered away.
        let (threads, _) = StoredChanges.shared.record(matter)
        let picked = RecordBrowse.pick(threads: threads, documents: shownDocuments, links: keptLinks, kind: .everything, show: .all, made: StoredChanges.shared.record(matter).made)
        var line: String?
        if matter.infos.contains(where: { $0.persistentModelID == id }) {
            part = .all; person = nil; atHand.insert(.info)
        } else if (matter.todos ?? []).shown.contains(where: { $0.persistentModelID == id })
            || (matter.appointments ?? []).shown.contains(where: { $0.persistentModelID == id })
            || (matter.deadlines ?? []).shown.contains(where: { $0.persistentModelID == id }) {
            part = .plan
        } else if matter.shownParties.contains(where: { $0.persistentModelID == id }) {
            part = .people
        } else if navigation.showsInItsPart, let own = Self.ownPart(of: id, in: matter) {
            // A connection's chip: the item in its own part, as the owner would look it up.
            part = own; person = nil
        } else {
            part = .all; person = nil
            // What is folded away is unfolded for it: its month, and its conversation.
            if let month = Journal.fold(of: id, items: picked.items) { openMonths.insert(month) }
            let lines = journalLines(picked.items, status: MatterStatus(matter), party: nil)
            if let found = Journal.line(of: id, in: lines, attached: picked.attached) {
                line = found.id
                if case .item(.thread(let thread)) = found { openThreads.insert(thread.id) }
            }
        }
        // A source of an answer can be anything on the page: what is folded away is unfolded for it.
        let today = MatterStatus(matter).today
        if (matter.appointments ?? []).shown.contains(where: { $0.persistentModelID == id && $0.day < today })
            || (matter.deadlines ?? []).shown.contains(where: { $0.persistentModelID == id && $0.day < today }) { showsPast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // The journal draws what is near the screen: to its line first, so that it is there to go to.
            if let line { scroller.scrollTo(line, anchor: .center) }
            DispatchQueue.main.asyncAfter(deadline: .now() + (line == nil ? 0 : 0.1)) { withAnimation { scroller.scrollTo(id, anchor: .center) } }
            marked = id
            find.shown = id
            Haptics.landed()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { marked = nil; if find.shown == id { find.shown = nil } } }
        }
    }

    /// The part of the page an item has of its own: a file's is Files, a mail's Mail, a note's Notes.
    static func ownPart(of id: PersistentIdentifier, in matter: Matter) -> Journal.Part? {
        if (matter.documents ?? []).contains(where: { $0.persistentModelID == id }) { return .files }
        if (matter.entries ?? []).contains(where: { $0.persistentModelID == id }) { return .mail }
        if (matter.noteBlocks ?? []).contains(where: { $0.persistentModelID == id }) { return .notes }
        return nil
    }

    /// What is new, corrected in place: the task's or the date's own editor, as in Plan.
    static func newEditor(_ item: NewItem, close: @escaping () -> Void) -> AnyView {
        switch item {
        case .task(let todo), .fact(let todo): AnyView(PhoneTodoEditor(todo: todo))
        case .appointment(let date): AnyView(PhoneDateEditor(item: PhoneDateRow.Item(date)))
        case .deadline(let date): AnyView(PhoneDateEditor(item: PhoneDateRow.Item(date)))
        }
    }

    private func status(of id: PersistentIdentifier) -> Todo? { (matter.todos ?? []).shown.first { $0.persistentModelID == id } }

    // MARK: Header

    /// "12 mails · since Sep 8": as the Mac's title bar says it — a view of its own, so that only
    /// it is drawn again when the store changes.
    private func countLine(_ status: MatterStatus) -> some View { PhoneCountLine(matter: matter) }

    private func header(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // On the iPad the icon and the name stand in the bar, beside find and ⋯, and stay there;
            // under it, as under the name on the iPhone and in the Mac's title bar: how many came, since when.
            if navigation.isPad {
                countLine(status)
            } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // The matter's icon in front of its name, level with the first line: a tap chooses another.
                Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 36) }
                    .buttonStyle(.plain)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 7 }
                    .accessibilityLabel("Icon").accessibilityHint("Chooses another icon")
                // The count under the name, on the name's left edge — not under the icon.
                VStack(alignment: .leading, spacing: 4) {
                    Text(matter.name).font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
                    countLine(status)
                }
            }
            }
        }
        // Under the iPad's bar a little air: the name is up there, and the page began too close to it.
        .padding(.top, navigation.isPad ? 10 : 4)
        .sheetWhenAsked(isPresented: $choosingIcon) {
            MatterIconPicker(matter: matter).presentationDetents([.height(470)]).presentationDragIndicator(.visible)
        }
    }

    // MARK: Find

    /// Under the bar while finding: the words, how many rows have them, and the way between them —
    /// on glass, as Safari's find is: the page goes on under it, softened by the bar.
    private var findBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Find in this matter", text: $find.query)
                        .focused($findFocused)
                        .submitLabel(.next)
                        .onSubmit { find.next(); findFocused = true }
                        .autocorrectionDisabled()
                    if find.isActive {
                        Text(find.matches.isEmpty ? "none" : "\(find.index + 1) of \(find.matches.count)")
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
                    }
                }
                .padding(.horizontal, 14).frame(height: 44)
                .glassEffect(.regular.interactive(), in: .capsule)
                // The way between what was found: one glass piece, as the system groups its arrows.
                HStack(spacing: 0) {
                    Button(action: find.previous) { Image(systemName: "chevron.up").frame(width: 40, height: 44).contentShape(Rectangle()) }
                        .disabled(find.matches.isEmpty).accessibilityLabel("Previous")
                    Button(action: find.next) { Image(systemName: "chevron.down").frame(width: 40, height: 44).contentShape(Rectangle()) }
                        .disabled(find.matches.isEmpty).accessibilityLabel("Next")
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                Button(role: .confirm) { stopFinding() }
                    .buttonStyle(.glassProminent).buttonBorderShape(.circle).controlSize(.large)
                    .accessibilityLabel("Done")
            }
            .tint(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    private func startFinding() {
        withAnimation(.easeOut(duration: 0.2)) { finding = true }
        findFocused = true
    }

    private func stopFinding() {
        find.query = ""
        findFocused = false
        withAnimation(.easeOut(duration: 0.2)) { finding = false }
    }

    private func closedBanner(_ status: MatterStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Closed on \(matter.closedAt.map(Dates.short) ?? "")").font(Theme.rowTitleFont)
            let new = StoredChanges.shared.summary(matter).newMailsSinceClosed
            Text(new == 0 ? "Nothing new since." : "\(new) new \(new == 1 ? "mail" : "mails") came after it was closed.")
                .foregroundStyle(new == 0 ? Color.secondary : Theme.warning)
            HStack(spacing: 10) {
                if new > 0 {
                    // What came in, with what it brought, becomes a matter of its own; this one stays closed.
                    Button("Start a new matter") {
                        newMatterName = Matter.suggestedName(for: status.mailsSinceClosed)
                        splitting = true
                    }
                    .buttonStyle(.phoneFilled)
                }
                Button(Say.openAgain) { matter.reopen(); try? context.save() }.buttonStyle(.phone)
            }
            .padding(.top, 4)
        }
        .journalCard()
        .alertWhenAsked(splitting ? Self.splitTitle(StoredChanges.shared.summary(matter).newMailsSinceClosed) : "", isPresented: $splitting) {
            TextField("Name", text: $newMatterName)
            Button("Cancel", role: .cancel) {}
            Button("Start", action: startNewMatter)
                .disabled(newMatterName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Their tasks, dates, files and links go with them. “\(matter.name)” stays closed.")
        }
    }

    private func startNewMatter() {
        let mails = MatterStatus(matter).mailsSinceClosed
        let name = newMatterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mails.isEmpty, !name.isEmpty, Store.shared.mayStartMatter(in: context),
              let new = try? matter.split(mails, intoNewMatterNamed: name, turnsSince: matter.closedAt, in: context) else { return }
        try? context.save()
        // The new matter in place of the closed one: back goes to the overview.
        if navigation.path.last == matter.persistentModelID { navigation.path.removeLast() }
        navigation.open(new)
    }

    // MARK: Next step

    /// The one thing to do now, and why: Causabee's suggestion while nothing has changed since,
    /// else the one worked out on the device.
    @ViewBuilder
    private func nextStep(_ status: MatterStatus, _ scroller: ScrollViewProxy) -> some View {
        let rule = status.nextStep
        let fresh = matter.nextStep != nil && matter.nextStepAt.map { at in (matter.lastChange ?? .distantPast) <= at } == true
        // Changed, and Auto will write it again: at once it says so, grey, and it is not offered
        // to act on until it has.
        let coming = AutoUpdate.shared.updating(matter)
        let outOfDate = coming && matter.nextStep != nil
        // Without Pro the rule chooses, also over a step written earlier.
        let own = fresh && !coming && !ModelChoice.reach.isFree
        // Yellow only when something waits for the owner: while it waits for someone else there is
        // nothing to do, and the page says so without a colour.
        let forYou = own ? matter.nextStep != nil : rule.map { $0.kind != .wait } ?? false
        NextCard(forYou: forYou, outOfDate: outOfDate) {
            if outOfDate {
                OutOfDateStep(matter: matter)
            } else if own, let step = matter.nextStep {
                BeeChip(text: "NEXT · FROM CAUSABEE")
                Text(step).font(Theme.rowTitleFont).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), step, matter.nextStepWhy)
                if let why = matter.nextStepWhy { Text(why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() }
                // What the owner said to the step; more is said from the card's menu, and Causabee writes it again.
                TileComments(matter: matter, about: step)
            } else if let rule {
                BeeChip(text: rule.heading.uppercased(), tone: rule.kind == .overdue || rule.kind == .followUp ? .warning : .bee)
                Text(rule.text).font(Theme.rowTitleFont).fixedSize(horizontal: false, vertical: true)
                    .findable(.section("next"), rule.text, rule.why)
                Text(rule.why).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation()
            } else {
                Text("Nothing for you right now").font(Theme.rowTitleFont)
            }
        } foot: {
            if outOfDate {
                EmptyView()
            } else if own, let step = matter.nextStep {
                let todo = matter.nextStepTodo.flatMap { origin in matter.openTodos.first { $0.origin == origin } }
                stepButtons(text: step, todo: todo, waiting: todo?.owner == .other, scroller).tool()
            } else if let rule, let todo = rule.todo.flatMap({ id in matter.openTodos.first { $0.persistentModelID == id } }) {
                // As on the Mac: a step worked out on the device has buttons when it is a task.
                stepButtons(text: todo.text, todo: todo, waiting: rule.kind == .followUp || rule.kind == .wait, scroller).tool()
            }
            // Asking Claude, below the buttons: apart from what the step itself offers — as on the Mac.
            HStack(spacing: 4) {
                if askingStep {
                    BeeLoader(size: 12)
                    Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary)
                } else if coming {
                    AutoWaitLine(matter: matter, writing: "Causabee is on it …")
                } else if auto {
                    // Auto asks: no link to ask with.
                    AutoLine(matter: matter, size: 11)
                } else if ModelChoice.reach != .pro {
                    ProLine(reach: ModelChoice.reach, mails: matter.entries?.count ?? 0)
                } else {
                    // An older suggestion says only its day.
                    if let at = matter.nextStepAt, matter.nextStep != nil, !fresh {
                        Text("From \(Dates.short(at)) ·").font(.caption).foregroundStyle(.secondary)
                    }
                    UpdateNowButton(action: askStep)
                }
            }
            .tool()
            if let stepError { Text(stepError).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
        }
        // "Comment" is the card's long press: only to a step Causabee wrote.
        .commentsOnHold(matter, about: own && !outOfDate ? matter.nextStep : nil)
    }

    /// The facts the step and the summary are asked from: this matter's, the last 40 mails.
    private var summaryFacts: Facts { FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), mails: 40) }

    /// The names the iPhone asks with: its own list, or a Mac's until it keeps one — or, in the
    /// demo, none: its people are made up.
    private func names() throws -> (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry]) {
        store.isDemo ? (Pseudonymizer.Mapping(), []) : try PhoneNames.current(in: context)
    }

    private func askStep() {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { stepError = ModelChoice.missingKey(model); return }
        let list: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        do { list = try names() } catch { stepError = error.localizedDescription; return }
        askingStep = true
        stepError = nil
        let facts = summaryFacts
        let owner = profiles.first?.names.first
        Task {
            do {
                let (step, why, ref, _) = try await AssistantAsk.nextStep(facts: facts, owner: owner, today: MatterStatus.day(Date()),
                                                                          mapping: list.mapping, others: list.others, claude: claude, model: model)
                matter.nextStep = step
                matter.nextStepWhy = why
                if case .todo(let id) = ref { matter.nextStepTodo = (matter.todos ?? []).shown.first { $0.persistentModelID == id }?.origin }
                else { matter.nextStepTodo = nil }
                matter.nextStepAt = Date()
                try? context.save()
            } catch {
                stepError = plainWords(error)
            }
            askingStep = false
        }
    }

    /// The page pulled down: both asked for at once, each saying in its own box that it is on its
    /// way. A closed matter has no next step; one being written already is not asked for twice.
    /// An action of the ⋯ — or of the iPad's keyboard: the part it belongs to, then its editor.
    private func run(_ action: MatterAction) {
        switch action {
        case .newTask: part = .plan; addTodo()
        case .writeNote: part = .notes; writingNote = true
        case .addFile: addingFiles = true
        case .addContact: addingContact = true
        case .addDetail: addingDetail = true
        case .addLink: addingLink = true
        }
    }

    private func writeAnew() {
        guard !AutoUpdate.shared.working.contains(matter.key) else { return }
        Haptics.tap()
        // The demo sends nothing and costs nothing: after a moment, the step worked out on the
        // device and the summary as it stands, both of now — to see how it goes.
        if store.isDemo {
            guard !askingStep, !writingSummary else { return }
            askingStep = !matter.isClosed
            writingSummary = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                let now = Date()
                if !matter.isClosed, let rule = MatterStatus(matter).nextStep {
                    matter.nextStep = rule.text
                    matter.nextStepWhy = rule.why
                    matter.nextStepTodo = rule.todo.flatMap { id in (matter.todos ?? []).shown.first { $0.persistentModelID == id }?.origin }
                    matter.nextStepAt = now
                }
                if matter.summary != nil { matter.summaryAt = now }
                try? context.save()
                askingStep = false
                writingSummary = false
            }
            return
        }
        // The adviser writes the step with the brief: one request.
        if !writingSummary { writeSummary() }
    }

    /// The adviser: the brief, the summary and the step, and its proposals for the list — one request, as on the Mac.
    private func writeSummary() {
        let model = ModelChoice.assistant
        guard ModelChoice.client(for: model) != nil else { summaryError = ModelChoice.missingKey(model); return }
        // Auto is writing it already: a second request would only cost twice, and count against the limit.
        guard !AutoUpdate.shared.working.contains(matter.key) else { return }
        let list: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        do { list = try names() } catch { summaryError = error.localizedDescription; return }
        writingSummary = true
        summaryError = nil
        let owner = profiles.first?.names.first
        Task {
            do {
                try await Adviser.write(matter, names: .list(list.mapping, list.others), owner: owner, in: context)
            } catch {
                summaryError = plainWords(error)
            }
            writingSummary = false
        }
    }

    /// What can be done with the step right here, as on the Mac: write the message it is, tick it
    /// off, see it — or talk it over.
    @ViewBuilder
    private func stepButtons(text: String, todo: Todo?, waiting: Bool, _ scroller: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            if waiting {
                Button("Write follow-up") {
                    navigation.talk(todo?.text ?? text, kind: todo == nil ? "Step" : "Task", in: matter,
                                    prefill: "Write a short, friendly follow-up about this.")
                }
                .buttonStyle(.phoneFilled)
            } else if Todo.isMessage(text) || todo?.isMessage == true {
                Button("Write message") {
                    navigation.talk(todo?.text ?? text, kind: todo == nil ? "Step" : "Task", in: matter,
                                    prefill: "Write a short message about this.")
                }
                .buttonStyle(.phoneFilled)
            }
            if let todo {
                if !waiting {
                    Button("Done") {
                        withAnimation { toggle(todo) }
                        if todo.isDone { BeeJoy.shared.celebrate(big: (todo.matter?.todos ?? []).shown.allSatisfy(\.isDone), still: BeeJoy.reducesMotion) }
                    }
                    .buttonStyle(.phone)
                }
                Button("Show") { show(todo.persistentModelID, with: scroller) }.buttonStyle(.phone)
            } else if !waiting, !Todo.isMessage(text) {
                Button("Talk it over") { navigation.talk(text, kind: "Step", in: matter) }.buttonStyle(.phone)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Summary and notes

    /// What has no date, in one card: the summary with its brief, the details, what is good to know.
    private var atHandCard: some View {
        AtHandCard(matter: matter, opened: $atHand, talk: { navigation.talk($0.text, kind: "Info", in: matter) }) {
            // Update below on the left, as under the next step; with no summary yet, the button.
            HStack(spacing: 8) {
                if writingSummary {
                    BeeLoader(size: 12)
                    Text("Writing the brief …").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if AutoUpdate.shared.updating(matter) {
                    AutoWaitLine(matter: matter, writing: "Writing the brief …")
                } else if matter.summaryAt != nil, auto {
                    AutoLine(matter: matter, size: 11)
                    Spacer()
                } else if matter.summaryAt != nil {
                    if ModelChoice.reach == .pro { UpdateNowButton(action: writeSummary) }
                    Spacer()
                    if let at = matter.summaryAt { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) }
                } else if ModelChoice.reach == .pro {
                    Button("Write the brief", action: writeSummary).buttonStyle(.phone)
                    Spacer()
                }
            }
            .tool()
            if let summaryError { Text(summaryError).font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
        }
    }

    /// What stands on top of the journal: the closed matter's line, what is new, what comes next
    /// and what waits for an answer; then the summary with what has no date, and under it what is
    /// ahead — what the matter is first, then its dates.
    @ViewBuilder
    private func top(_ status: MatterStatus, _ plan: Journal.Plan, _ scroller: ScrollViewProxy) -> some View {
        if matter.isClosed { closedBanner(status) }
        NewsCard(matter: matter, editor: Self.newEditor)
        if !matter.isClosed {
            nextStep(status, scroller)
            ForYouCard(matter: matter)
        }
        atHandCard
        // On an iPad the page has the room the column had: as many days as it showed.
        if !matter.isClosed, plan.openCount > 0 { AheadCard(plan: plan, tick: tick, open: { part = .plan }, days: navigation.isPad ? 4 : 2, editor: Self.newEditor) }
    }

    /// The owner's own words on the matter: small dated blocks, read by the assistant too.
    private var notesPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotesPart(matter: matter, writing: $writingNote)
            ForEach((matter.decisions ?? []).sorted { $0.decidedAt > $1.decidedAt }) { JournalDecisionCard(decision: $0) }
        }
    }

    // MARK: Plan

    /// "Add Task": an empty task of the owner's, opened in the editor.
    private func addTodo() {
        let todo = Todo(text: "", owner: .me, due: nil, source: Source(kind: .conversation, pointer: "you", date: Date()),
                        origin: "you#" + UUID().uuidString)
        context.insert(todo)
        todo.matter = matter
        // Saved before its sheet opens: a model's identity changes with its first save, and a sheet
        // whose item changes identity is closed and opened again — which dropped the empty task
        // under the editor, so what was typed into it was lost.
        try? context.save()
        newTodo = todo
    }

    /// A task closed without words was never there.
    private func dropEmptyTodos() {
        // Only once the sheet is really gone: never under an editor that is open.
        guard newTodo == nil else { return }
        for todo in matter.todos ?? [] where todo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(todo)
        }
        try? context.save()
    }

    /// The matter as one RTF document in its folder — iCloud Drive › Causabee › the matter — and shown.
    /// The demo's goes to a temporary folder, never among the owner's files.
    private func export() {
        do {
            try? context.save()
            exported = try MatterExport.write(matter, into: DemoData.isRequested ? nil : MatterFolders.folder(for: matter))
        } catch {
            exportFailure = error.localizedDescription
        }
    }

    /// What is left, by when: dates and tasks together, with each row's own way to change it.
    private func planList(_ status: MatterStatus, _ plan: Journal.Plan) -> some View {
        PlanList(plan: plan, showsDone: $showsDone, showsPast: $showsPast) { todo, showsOwner in
            PhoneTodoRow(todo: todo, today: status.today, showsOwner: showsOwner, showsDue: todo.isDone,
                         reminders: todo.isDone ? nil : reminders, calendarTick: calendarTick) { withAnimation { toggle(todo) } }
                .background(marked == todo.persistentModelID ? Theme.mark : .clear)
                // Also its place to scroll to, from an overdue line or the page search.
                .findable(.model(todo.persistentModelID), todo.text, todo.note)
        } date: { item, past in
            if let row = dateItem(item) {
                PhoneDateRow(item: row, isPast: past, matter: matter, tick: calendarTick)
                    .findable(row.findID, row.what, row.place)
            }
        } empty: {
            PhoneEmptyBox(text: "What is to do, and whose, and what is coming. Tasks and dates in mail are found when it is sorted in.",
                          action: "Add Task", symbol: "checklist", run: addTodo)
        }
    }

    private func dateItem(_ item: Journal.Plan.Item) -> PhoneDateRow.Item? {
        switch item {
        case .appointment(let appointment): PhoneDateRow.Item(appointment)
        case .deadline(let deadline): PhoneDateRow.Item(deadline)
        case .task: nil
        }
    }

    private func tick(_ todo: Todo) { withAnimation { toggle(todo) } }

    private func toggle(_ todo: Todo) {
        todo.isDone.toggle()
        if todo.isDone { Haptics.success() } else { Haptics.tap() }
        todo.doneAt = todo.isDone ? Date() : nil
        // Done by the owner's tap, not by a mail: there is no mail to point at.
        if !todo.isDone { todo.doneSource = nil }
        try? context.save()
    }

    /// The owner's reminders, read when the matter opens and again when Reminders changes.
    private func loadCalendars() {
        Task {
            reminders = await Calendars.shared.allReminders()
            calendarTick += 1
        }
    }

    // MARK: People

    // MARK: Parts

    private var shownDocuments: [MatterCore.Document] { (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage } }
    private var keptLinks: [WebLink] { (matter.links ?? []).shown.filter(\.isKept) }
    private var personParty: Party? { person.flatMap { id in matter.shownParties.first { $0.persistentModelID == id } } }

    /// The filters over the journal, as on the Mac.
    private func parts() -> some View {
        JournalPills(parts: Journal.parts(of: matter, open: part), selection: $part)
    }

    /// Whether this person wrote it: by any way their name is written.
    private func wrote(_ party: Party, _ from: String?) -> Bool {
        guard let from else { return false }
        return matter.writer(from) === party
    }

    /// The journal itself: what happened, a day at a time, the newest first, old months folded.
    /// With one person chosen in People, what they wrote or are named in.
    @ViewBuilder
    private func journal(_ status: MatterStatus) -> some View {
        let (threads, made) = StoredChanges.shared.record(matter)
        readsTheMailbox
        let party = personParty
        let picked = MatterKept.shared.value(matter, "pick everything all") {
            RecordBrowse.pick(threads: threads, documents: shownDocuments, links: keptLinks, kind: .everything, show: .all, made: made)
        }
        let items = party.map { party in
            picked.items.filter { item in NamedPeople.of(item, in: matter).contains { $0.id == party.persistentModelID } }
        } ?? picked.items
        let lines = MatterKept.shared.value(matter, "journal \(openMonths.sorted()) \(person?.hashValue ?? 0)") {
            journalLines(items, status: status, party: party)
        }
        if let party {
            Button { person = nil } label: { Label(party.name, systemImage: "xmark.circle.fill").lineLimit(1) }
                .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small).tint(.primary)
        }
        if lines.isEmpty {
            PhoneEmptyBox(text: party != nil ? "Nothing here was written by \(party?.name ?? "them") or names them."
                              : "Mail sorted into this matter, its files, links and notes show here, a day at a time.")
        }
        // Only what is near the screen is drawn.
        LazyVStack(alignment: .leading, spacing: Theme.cardGap) {
            ForEach(lines) { line in
                switch line {
                case .day(_, let title):
                    JournalHeading(title: title)
                case .fold(let fold):
                    JournalFoldCard(fold: fold) {
                        withAnimation(.snappy(duration: 0.2)) { if openMonths.remove(fold.id) == nil { openMonths.insert(fold.id) } }
                    }
                case .note(let note):
                    JournalNoteCard(note: note) { part = .notes }
                case .decision(let decision):
                    JournalDecisionCard(decision: decision)
                case .done(let todo):
                    JournalDoneLine(todo: todo)
                case .item(let item):
                    recordItem(item, picked: picked, made: made)
                }
            }
        }
    }

    private func journalLines(_ items: [RecordBrowse.Item], status: MatterStatus, party: Party?) -> [Journal.Line] {
        Journal.lines(items: items, notes: party == nil ? matter.sortedNotes : [], decisions: party == nil ? matter.decisions ?? [] : [],
                      done: party == nil ? status.done : [], opened: openMonths)
    }

    /// Which mail answers which, read once from the mailbox — as on the Mac — and which is still
    /// unread in the inbox, read-only: the dots as the mailbox has them now.
    private var readsTheMailbox: some View {
        Color.clear.frame(width: 0, height: 0).task(id: matter.persistentModelID) {
            if !store.isDemo { await UnreadMail.refresh(matter, in: context) }
            await ReplyLinks.fill(in: matter, context: context)
            // A file added before still kept only in the app: into the matter's folder, once.
            if MatterFolders.hasOwnCopies(matter) { PhoneFolderSaver.save([matter]) }
        }
    }

    /// One conversation, one file of its own, or one link, as a card.
    @ViewBuilder
    private func recordItem(_ item: RecordBrowse.Item, picked: RecordBrowse.Picked, made: RecordLinks) -> some View {
        switch item {
        case .thread(let thread):
            let files = picked.attached[thread.id] ?? []
            JournalThreadCard(thread: thread, links: made, files: files.map(\.shownName), isOpen: openThreads.contains(thread.id) || find.isActive,
                              toggle: { withAnimation(.snappy(duration: 0.2)) { if openThreads.remove(thread.id) == nil { openThreads.insert(thread.id) } } },
                              talk: { navigation.talk($0.title, kind: "Mail", in: matter) }) {
                // Its files right under it, close: one thing.
                if !files.isEmpty { FilesSection(matter: matter, attachments: files).padding(.top, 8) }
            }
        case .document(let document):
            FilesSection(matter: matter, only: document, made: made.made(from: document))
        case .link(let link):
            PhoneLinkRow(link: link, todos: matter.openTodos) {
                withAnimation { context.deleteByHand([link], undo: undoManager, named: "Remove Link") }
            }
            .findable(.model(link.persistentModelID), link.shownName, link.address)
            .journalRows()
        }
    }

    /// Mail or files alone, as the two menus have them. Files are followed by the links.
    @ViewBuilder
    private func record(_ status: MatterStatus) -> some View {
        // Built once for this drawing, for the menus' counts and the list alike.
        let (threads, made) = StoredChanges.shared.record(matter)
        readsTheMailbox
        HStack(spacing: 10) {
            RecordBar(kind: filter, show: $show, sort: $sort, counts: counts(threads: threads, made: made)) {
                // The matter's folder, on the record's own line — as on the Mac. Files are added by the plus.
                if filter == .files {
                    // Not in the demo: its made-up matters have no folder among the owner's own.
                    if MatterFolders.root != nil, !store.isDemo, let folder = MatterFolders.folder(for: matter),
                       let files = URL(string: "shareddocuments://" + folder.path) {
                        Button { UIApplication.shared.open(files) } label: { Label("Show in Files", systemImage: "folder") }
                            .labelStyle(.iconOnly).buttonStyle(.gold).font(.callout)
                            .accessibilityHint("Opens this matter's folder in iCloud Drive → Causabee, in Files")
                            .tool()
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        if show == .kept, filter != .mail {
            // The files kept only, to read one or several at once.
            FilesSection(matter: matter, keptOnly: true)
        } else if filter == .files, show == .all, sort == .newest {
            FilesSection(matter: matter)
            LinksSection(matter: matter)
        } else {
            recordList(threads: threads, made: made)
        }
    }

    /// How many there are for each "Show", of the kind chosen.
    private func counts(threads: [MailThreads.Thread], made: RecordLinks) -> [RecordBrowse.Show: Int] {
        MatterKept.shared.value(matter, "counts \(filter)") {
            Dictionary(uniqueKeysWithValues: RecordBrowse.Show.allCases.map { item in
                (item, RecordBrowse.pick(threads: threads, documents: shownDocuments, links: keptLinks, kind: filter, show: item, made: made).items.count)
            })
        }
    }

    /// Mail or files as the two menus have them: which of them, in which order.
    @ViewBuilder
    private func recordList(threads: [MailThreads.Thread], made: RecordLinks) -> some View {
        let picked = MatterKept.shared.value(matter, "pick \(filter) \(show)") {
            RecordBrowse.pick(threads: threads, documents: shownDocuments, links: keptLinks, kind: filter, show: show, made: made)
        }
        let all = picked.items
        let ordered = all.sorted { sort == .oldest ? $0.date < $1.date : $0.date > $1.date }
        let visible = showsAllHistory || sort == .byPerson || sort == .byKind ? ordered : Array(ordered.prefix(60))
        let groups = RecordBrowse.groups(visible, sort: sort) { item in NamedPeople.of(item, in: matter).map(\.name) }
        if all.isEmpty {
            PhoneEmptyBox(text: show != .all ? "Nothing here is \(show.label.lowercased())."
                              : "Mail sorted into this matter shows here, newest first.")
        }
        ForEach(groups) { group in
            VStack(alignment: .leading, spacing: Theme.cardGap) {
                JournalHeading(title: group.title.uppercased(), detail: group.items.count == 1 ? "1 entry" : "\(group.items.count) entries")
                ForEach(group.items) { item in
                    AlsoUnder(names: group.also[item.id] ?? [])
                    recordItem(item, picked: picked, made: made)
                }
            }
        }
        if all.count > visible.count {
            Button("… and \(all.count - visible.count) older — show them") { showsAllHistory = true }
                .font(.caption).foregroundStyle(Theme.gold).padding(.horizontal, 4)
        }
    }

    // MARK: History

    /// The mail, as the Mac shows it: conversation by conversation, the newest first, each reply
    /// under the mail it answers — until about 60 mails are shown.
    private func history(_ status: MatterStatus) -> some View {
        let threads = StoredChanges.shared.record(matter).threads
        var shown = 0
        // Searching looks into all of it, as on the Mac.
        let visible = threads.prefix { thread in defer { shown += thread.count }; return shown < 60 || showsAllHistory || find.isActive }
        let hidden = threads.count - visible.count
        let made = StoredChanges.shared.record(matter).made
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History", detail: Self.count(status.mailEntries)
                          + (threads.count == status.mailEntries.count ? "" : " in \(threads.count) \(threads.count == 1 ? "conversation" : "conversations")"))
            if status.mailEntries.isEmpty {
                PhoneEmptyBox(text: "Mail sorted into this matter shows here, newest first. It comes from your mailbox, not by hand.")
            }
            ForEach(visible) { thread in
                ThreadCard(thread: thread, links: made) { navigation.talk($0.title, kind: "Mail", in: matter) }
            }
            if hidden > 0 {
                Text("… and \(hidden) older \(hidden == 1 ? "conversation" : "conversations")").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
    }

    /// "32 mails · 3 screenshots · 1 document": each kind counted as what it is.
    static func count(_ entries: [Entry]) -> String {
        var counts: [Source.Kind: Int] = [:]
        for entry in entries { counts[entry.source.kind, default: 0] += 1 }
        return count(kinds: counts)
    }

    /// Worked out only while it is asked: read every time the page drew, it made the page draw
    /// again after every change to the store.
    static func splitTitle(_ new: Int) -> String { "A new matter with the \(new) new \(new == 1 ? "mail" : "mails")" }

    static func count(kinds counts: [Source.Kind: Int]) -> String {
        let names: [(Source.Kind, String, String)] = [
            (.mail, "mail", "mails"), (.screenshot, "screenshot", "screenshots"), (.document, "document", "documents"),
            (.photo, "photo", "photos"), (.spokenNote, "spoken note", "spoken notes"), (.phoneCall, "call", "calls"),
            (.conversation, "from the assistant", "from the assistant"),
        ]
        let parts = names.compactMap { kind, one, many -> String? in
            let n = counts[kind] ?? 0
            return n == 0 ? nil : "\(n) \(n == 1 ? one : many)"
        }
        return parts.isEmpty ? "No mails yet" : parts.joined(separator: " · ")
    }
}

/// A task with its box to tick: whose it is, by when, and where it came from.
struct PhoneTodoRow: View {
    let todo: Todo
    let today: String
    var showsOwner = false
    /// Off where its day stands beside it, on a tile.
    var showsDue = true
    /// The owner's reminders, for the Reminders chip; nil where none is shown.
    var reminders: [Calendars.Reminder]? = nil
    var calendarTick = 0
    let toggle: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(Navigation.self) private var navigation
    @State private var editing = false
    @State private var connecting = false
    @State private var deleting = false
    @State private var choosingWait = false
    @State private var addingReminder = 0

    /// A task the owner can be reminded of: its offer is in the ⋯, its connection on the row.
    private var remindable: Bool { !todo.isDone && !todo.isInfo && (todo.owner == .me || todo.owner == .we || todo.reminderID != nil) }

    var body: some View {
        // Taken back with Undo in the assistant, the task is gone while this row is drawn once more:
        // a deleted model must not be read — SwiftData stops the app.
        if todo.isDeleted || todo.modelContext == nil { EmptyView() } else { row.connectSheet(.task(todo), in: todo.matter, isPresented: $connecting).dropsOn(.task(todo), in: todo.matter) }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            PlanTick(todo: todo, toggle: toggle)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.text)
                    .foregroundStyle(todo.isDone || todo.isBlocked ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.planTop)
                ConnectionChips(item: .task(todo))
                if let reminders, remindable {
                    CalendarChip(kind: .reminder, linkedID: todo.reminderID, title: todo.text, day: todo.due, time: todo.dueTime,
                                 note: todo.note, matterName: todo.matter?.name ?? "", reminders: reminders, tick: calendarTick, asked: addingReminder) { id in
                        todo.reminderID = id
                        todo.reminderStamp = nil
                        try? context.save()
                    }
                }
                if !todo.isDone, let other = todo.waitsFor {
                    Label(other.isDone ? "its turn now — done: \(other.text)" : "only after: \(other.text)",
                          systemImage: other.isDone ? "arrow.right.circle.fill" : "hourglass")
                        .font(.footnote).foregroundStyle(other.isDone ? Theme.done : .secondary)
                }
                if let note = todo.note, !note.isEmpty {
                    // The owner's note under the task, as words alone: an icon would only add clutter.
                    Text(Linked.text(note)).fixedSize(horizontal: false, vertical: true)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let note = todo.note, !note.isEmpty {
                    let loose = WebLink.split(note: note).links.filter { found in !(todo.links ?? []).shown.contains { $0.address == found.address } }
                    if !loose.isEmpty {
                        Button(loose.count == 1 ? "Save as link" : "Save \(loose.count) links") { keepLinks(from: note) }
                            .font(.caption).foregroundStyle(Theme.gold)
                    }
                }
                ForEach((todo.links ?? []).shown.sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                    if let url = link.url {
                        Link(destination: url) { Label(link.shownName, systemImage: "link").font(.footnote).lineLimit(1) }
                    }
                }
                // Whose, when that is not the owner; where it came from is in the ⋯. Done, what showed it done.
                if todo.isDone {
                    SourceJump(sources: todo.doneSource.map { [$0] } ?? [],
                               label: todo.doneSource == nil ? "done by you" : "done, says the mail of \(todo.doneSource?.date.map(Dates.short) ?? "?")",
                               matter: todo.matter, color: Theme.done, before: line, beforeColor: lineColor)
                } else if !line.isEmpty {
                    Text(line).font(.caption).foregroundStyle(lineColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The Mac's ⋯: change it by hand, say it is only worth knowing, what it waits for.
            PlanMore { moreItems }
        }
        .planRow()
        .contentShape(Rectangle())
        .contextMenu { Group { moreItems }.menuSigns() }
        .sheetWhenAsked(isPresented: $editing) { PhoneTodoEditor(todo: todo) }
        .sheetWhenAsked(isPresented: $choosingWait) { WaitsForChooser(todo: todo) }
        .confirmationDialogWhenAsked("Delete “\(todo.text)”?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // The reminder it is connected with goes too: a task that is gone reminds of nothing.
                Calendars.shared.removeReminder(todo.reminderID)
                withAnimation { context.deleteByHand([todo], undo: undoManager, named: "Delete Task") }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(todo.reminderID == nil ? "It goes from this matter; Undo brings it back."
                 : "It goes from this matter, and its reminder from Reminders. Undo brings the task back, not the reminder.")
        }
    }

    @ViewBuilder
    private var moreItems: some View {
        // Short, one line each, with an icon; one line only, above Delete.
        // Every item's menu begins alike: Use in Chat, Connect, Move to Matter, Hide — then its own.
        if let matter = todo.matter {
            AskCausabeeButton { navigation.talk(todo.text, kind: todo.isInfo ? "Info" : "Task", in: matter) }
            Button(Say.connect, systemImage: "link") { connecting = true }
            MoveAndHide(item: .task(todo), matter: matter)
            Divider()
        }
        Button(Say.edit, systemImage: "pencil") { editing = true }
        if !todo.isDone { SourceItems(sources: todo.sources, matter: todo.matter) }
        if reminders != nil, remindable, todo.reminderID == nil, Calendars.shared.canReadReminders {
            Button(Say.addToReminders, systemImage: "bell") { addingReminder += 1 }
        }
        if !todo.isDone {
            Button(Say.waitsForChoose, systemImage: "hourglass") { choosingWait = true }
                .disabled((todo.matter?.openTodos.count ?? 0) < 2)
            if todo.waitsFor != nil {
                Button(Say.stopWaiting, systemImage: "xmark.circle") {
                    withAnimation { todo.waitsFor = nil }
                    try? context.save()
                }
            }
        }
        Divider()
        if !todo.isDone { NotNeeded.button(todo, in: context, undo: undoManager) }
        Button(Say.delete, systemImage: "trash", role: .destructive) { deleting = true }
    }

    /// The addresses in the note become the task's links, and their lines leave the note.
    private func keepLinks(from note: String) {
        guard let matter = todo.matter else { return }
        let (found, rest) = WebLink.split(note: note)
        for item in found where !(todo.links ?? []).shown.contains(where: { $0.address == item.address }) {
            let link = WebLink(address: item.address, title: item.title)
            context.insert(link)
            link.matter = matter
            link.todo = todo
        }
        withAnimation { todo.note = rest }
        try? context.save()
    }

    private var line: String {
        var parts: [String] = []
        // The owner's own need no saying: most of a list is.
        if todo.owner == .other, let whom = Journal.whom(todo) {
            // Whom it waits for, by name; under its heading, the name is enough.
            parts.append(showsOwner ? "Waiting for \(whom)" : whom)
        } else if showsOwner, todo.owner != .me { parts.append(["we": "Ours", "other": "Waiting for"][todo.owner.rawValue] ?? "Unclear whose") }
        if showsDue, let due = todo.due {
            parts.append("by " + Dates.short(due) + (todo.dueTime.map { " at \($0)" } ?? ""))
        } else if let time = todo.dueTime, todo.due != nil {
            parts.append("at \(time)")
        }
        return parts.joined(separator: " · ")
    }

    private var lineColor: Color {
        todo.isDone ? Theme.done : .secondary
    }
}

/// A task put right by hand, as the Mac's editor: its words, a note, whose it is, what it waits
/// for, its links, and by when — a day, and a time if wanted.
struct PhoneTodoEditor: View {
    let todo: Todo
    /// A task just started with "Add Task": "New task", and nothing to add until it has words.
    var isNew = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var note = ""
    @State private var owner = Todo.Owner.me
    @State private var hasDay = false
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var after: PersistentIdentifier?
    @State private var circle = false
    @State private var newLink = ""

    private var others: [Todo] { (todo.matter?.openTodos ?? []).filter { $0 !== todo }.sorted { $0.text < $1.text } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What to do", text: $text, axis: .vertical).lineLimit(2...5)
                        .accessibilityIdentifier("task.text")
                    TextField("Note — a list, a detail, what was agreed", text: $note, axis: .vertical).lineLimit(2...8)
                }
                Section {
                    Picker("Whose", selection: $owner) {
                        Text("Mine").tag(Todo.Owner.me)
                        Text("Ours").tag(Todo.Owner.we)
                        Text("Waiting for").tag(Todo.Owner.other)
                        Text("Unclear whose").tag(Todo.Owner.unknown)
                    }
                    // A menu, not the Mac's segments: four of them do not fit a phone's width in full.
                    .pickerStyle(.menu)
                    if !others.isEmpty {
                        Picker("Only after", selection: $after) {
                            Text("nothing — can go any time").tag(PersistentIdentifier?.none)
                            ForEach(others, id: \.persistentModelID) { other in Text(other.text).lineLimit(1).tag(Optional(other.persistentModelID)) }
                        }
                        if circle {
                            Text("The other one already waits for this one — neither could ever be done.").font(.footnote).foregroundStyle(Theme.warning)
                        }
                    }
                }
                Section {
                    ForEach((todo.links ?? []).shown.sorted { $0.createdAt < $1.createdAt }, id: \.persistentModelID) { link in
                        HStack {
                            Label(link.shownName, systemImage: "link").lineLimit(1)
                            Spacer()
                            // Off the task; the link stays in the matter.
                            Button { link.todo = nil } label: { Image(systemName: "xmark.circle") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Paste a link — https://docs.google.com/…", text: $newLink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    if !newLink.isEmpty, WebLink.address(in: newLink) == nil {
                        Text("This is not a web address.").font(.footnote).foregroundStyle(Theme.warning)
                    }
                } header: { Text("Links") }
                Section {
                    Toggle("By a day", isOn: $hasDay)
                    if hasDay {
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                        Toggle("Time", isOn: $hasTime)
                        if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "en_US"))
            .navigationTitle(isNew ? "New task" : "Change task")
            .navigationBarTitleDisplayMode(.inline)
            .keepsWhatWasTyped([text, note, owner, hasDay, day, hasTime, time, after, circle, newLink])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancel { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirm(isNew ? "Add" : "Save", action: save)
                        .disabled(isNew && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        text = todo.text
        note = todo.note ?? ""
        owner = todo.owner
        after = todo.waitsFor?.persistentModelID
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm"
        if let due = todo.due, let date = parser.date(from: due + " " + (todo.dueTime ?? "09:00")) {
            hasDay = true
            day = date
            time = date
            hasTime = todo.dueTime != nil
        }
    }

    /// As the Mac saves it: a wait in a circle stops the save before anything is changed.
    private func save() {
        let other = after.flatMap { id in others.first { $0.persistentModelID == id } }
        if other !== todo.waitsFor, !todo.wait(for: other) {
            circle = true
            return
        }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { todo.text = words }
        let written = note.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.note = written.isEmpty ? nil : written
        if let address = WebLink.address(in: newLink), let matter = todo.matter,
           !(todo.links ?? []).shown.contains(where: { $0.address == address }) {
            let link = WebLink(address: address)
            context.insert(link)
            link.matter = matter
            link.todo = todo
        }
        todo.owner = owner
        if hasDay {
            todo.due = MatterStatus.day(day)
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "HH:mm"
            todo.dueTime = hasTime ? format.string(from: time) : nil
        } else {
            todo.due = nil
            todo.dueTime = nil
        }
        try? context.save()
        dismiss()
    }
}

/// An appointment or a deadline, as the Mac's date row: the day on the left, what it is, its kind
/// and place, whether it is in Calendar — and its ⋯: talk about it, change it, delete it.
struct PhoneDateRow: View {
    struct Item {
        var day: String
        var time: String?
        var what: String
        var place: String?
        var kind: String
        var appointment: Appointment?
        var deadline: Deadline?
        /// The appointment or deadline it shows, as a journal item.
        var journalItem: JournalItem? { appointment.map(JournalItem.meeting) ?? deadline.map(JournalItem.deadline) }
        var endDay: String? { appointment?.endDay }
        var endTime: String? { appointment?.endTime }
        /// "10:00–11:30", or the start alone.
        var hours: String? { time.map { start in endTime.map { "\(start)–\($0)" } ?? start } }

        var findID: PageFind.ID {
            if let id = appointment?.persistentModelID ?? deadline?.persistentModelID { return .model(id) }
            return .section("date \(day) \(what)")
        }

        init(_ appointment: Appointment) {
            (day, time, what, place, kind) = (appointment.day, appointment.time, appointment.what, appointment.place, "Appointment")
            self.appointment = appointment
        }

        init(_ deadline: Deadline) {
            (day, time, what, place, kind) = (deadline.day, nil, deadline.what, nil, "Deadline")
            self.deadline = deadline
        }

        var calendarID: String? { appointment?.calendarID ?? deadline?.calendarID }
        func connect(_ id: String?) {
            appointment?.calendarID = id
            deadline?.calendarID = id
            // Connected anew: in step from here on, as each side is now.
            appointment?.calendarStamp = nil
            deadline?.calendarStamp = nil
        }
    }

    let item: Item
    let isPast: Bool
    let matter: Matter
    var tick = 0
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(Navigation.self) private var navigation
    @State private var editing = false
    @State private var connecting = false
    @State private var deleting = false
    @State private var addingToCalendar = 0

    private var sources: [Source] { item.appointment?.sources ?? item.deadline?.sources ?? [] }

    var body: some View {
        rowBody
        .connectSheet(item.journalItem, in: matter, isPresented: $connecting)
        .dropsOn(item.journalItem, in: matter)
    }

    @ViewBuilder
    private var rowBody: some View {
        HStack(alignment: .top, spacing: 10) {
            PlanDateMark(isDeadline: item.deadline != nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.what).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .padding(.top, Theme.planTop)
                PlanDateLine(isDeadline: item.deadline != nil, hours: item.hours, last: item.endDay, place: item.place)
                if !isPast || item.calendarID != nil {
                    CalendarChip(kind: .event, linkedID: item.calendarID, title: item.what, day: item.day, time: item.time, endDay: item.endDay, endTime: item.endTime,
                                 place: item.place, matterName: matter.name, tick: tick, asked: addingToCalendar) { id in item.connect(id); try? context.save() }
                }
                // Under its words, in its box, as a task's are: outside it they began a little left
                // of the words and ran out of the card.
                if let journalItem = item.journalItem { ConnectionChips(item: journalItem, matter: matter) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PlanMore { moreItems }
        }
        .planRow()
        .planDate()
        .contentShape(Rectangle())
        .contextMenu { Group { moreItems }.menuSigns() }
        .sheetWhenAsked(isPresented: $editing) { PhoneDateEditor(item: item) }
        .confirmationDialogWhenAsked("Delete “\(item.what)”?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // The entry in Calendar it is connected with goes too.
                Calendars.shared.removeEvent(item.calendarID)
                context.deleteByHand(([item.appointment, item.deadline] as [(any PersistentModel)?]).compactMap { $0 }, undo: undoManager, named: "Delete Date")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.calendarID == nil ? "It goes from this matter; Undo brings it back."
                 : "It goes from this matter, and its entry from Calendar. Undo brings the date back, not the entry.")
        }
    }

    @ViewBuilder
    private var moreItems: some View {
        AskCausabeeButton { navigation.talk(item.what, kind: item.kind, in: matter) }
        Button(Say.connect, systemImage: "link") { connecting = true }
        MoveAndHide(item: item.journalItem, matter: matter)
        Divider()
        Button(Say.edit, systemImage: "pencil") { editing = true }
        SourceItems(sources: sources, matter: matter)
        if !isPast, item.calendarID == nil, Calendars.shared.canReadEvents {
            Button(Say.addToCalendar, systemImage: "calendar.badge.plus") { addingToCalendar += 1 }
        }
        Divider()
        Button(Say.delete, systemImage: "trash", role: .destructive) { deleting = true }
    }
}

/// An appointment or a deadline put right by hand, as the Mac's editor: what, which day, and for
/// an appointment the time and the place. A connected Calendar entry follows on the next sync.
struct PhoneDateEditor: View {
    let item: PhoneDateRow.Item
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var what = ""
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var place = ""

    private var isAppointment: Bool { item.appointment != nil }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What", text: $what, axis: .vertical).lineLimit(1...4)
                    .accessibilityIdentifier("date.what")
                DatePicker("Day", selection: $day, displayedComponents: .date)
                if isAppointment {
                    Toggle("Time", isOn: $hasTime)
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    TextField("Place", text: $place)
                }
            }
            .environment(\.locale, Locale(identifier: "en_US"))
            .navigationTitle(isAppointment ? "Change appointment" : "Change deadline")
            .navigationBarTitleDisplayMode(.inline)
            .keepsWhatWasTyped([what, day, hasTime, time, place])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancel { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirm("Save", action: saveChanges).disabled(what.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private func load() {
        what = item.what
        place = item.place ?? ""
        day = MatterStatus.date(of: item.day) ?? Date()
        if let at = item.time, let parsed = Self.formatter("HH:mm").date(from: at) {
            hasTime = true
            time = parsed
        }
    }

    private func saveChanges() {
        let text = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayText = Self.formatter("yyyy-MM-dd").string(from: day)
        if let appointment = item.appointment {
            appointment.what = text
            appointment.day = dayText
            appointment.time = hasTime ? Self.formatter("HH:mm").string(from: time) : nil
            let spot = place.trimmingCharacters(in: .whitespacesAndNewlines)
            appointment.place = spot.isEmpty ? nil : spot
        }
        if let deadline = item.deadline {
            deadline.what = text
            deadline.day = dayText
        }
        try? context.save()
        dismiss()
    }
}

/// Where a matter's page stands while it scrolls. Read only by the small views below: a part
/// passing under the bar used to work out the whole page again — every task, the brief, the next
/// step — in the middle of the scroll, and a frame was lost.
@MainActor
@Observable
final class PageScroll {
    var partsUnder = false
    var topInset: CGFloat = 0
}

/// The parts in the page, unseen while the bar shows them.
private struct UnderBar<Content: View>: View {
    let scroll: PageScroll
    let content: Content
    init(scroll: PageScroll, @ViewBuilder content: () -> Content) { self.scroll = scroll; self.content = content() }
    var body: some View { content.opacity(scroll.partsUnder ? 0 : 1) }
}

/// The parts pinned under the bar, once the page's have gone under it.
private struct PinnedParts<Content: View>: View {
    let scroll: PageScroll
    let hidden: Bool
    let content: Content
    init(scroll: PageScroll, hidden: Bool, @ViewBuilder content: () -> Content) { self.scroll = scroll; self.hidden = hidden; self.content = content() }
    var body: some View { if scroll.partsUnder, !hidden { content } }
}

/// "12 mails · since Sep 8", under a matter's name: the kinds counted away from the screen, once
/// per change of the store; meanwhile how many there are.
private struct PhoneCountLine: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @State private var counted: (version: Int, line: String)?

    var body: some View {
        if !(matter.entries ?? []).isEmpty {
            let total = (matter.entries ?? []).count
            // The day of its first mail, as the overview's summary has it: not every mail read again.
            let since = StoredChanges.shared.summary(matter).firstDate.map { " · since \(Dates.short($0))" } ?? ""
            Text((counted?.line ?? (total == 1 ? "1 mail" : "\(total) mails")) + since)
                .task(id: StoredChanges.shared.count) {
                    let id = matter.persistentModelID
                    guard counted?.version != StoredChanges.shared.count else { return }
                    let container = context.container
                    let version = StoredChanges.shared.count
                    let kinds = await Task.detached { RecordKinds.count(of: id, in: container) }.value
                    counted = (version, MatterScreen.count(kinds: kinds))
                }
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

/// The same page as long as it is the same matter: what it shows of the matter it reads itself,
/// and draws again when that changes. Compared by its fields, a page seemed new each time the
/// screen around it was drawn — its own state is made anew with each — and was worked out whole.
extension MatterScreen: Equatable {
    nonisolated static func == (a: Self, b: Self) -> Bool { a.matter === b.matter }
}
