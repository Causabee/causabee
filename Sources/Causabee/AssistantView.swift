import AppKit
import MatterCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Which matters "über alle Sachen" means: those with something open or a date, overdue first,
/// then the soonest.
@MainActor
func activeMatters(_ matters: [Matter]) -> [Matter] {
    // Each matter's status read once, not again in every comparison.
    matters.compactMap { matter -> (matter: Matter, late: Bool, next: String)? in
        guard !matter.isClosed else { return nil }
        let status = MatterStatus(matter), next = status.next
        guard !matter.openTodos.isEmpty || next != nil else { return nil }
        return (matter, !status.overdue.isEmpty, next?.day ?? "9999")
    }
    .sorted { a, b in
        if a.late != b.late { return a.late }
        if a.next != b.next { return a.next < b.next }
        return a.matter.name.localizedStandardCompare(b.matter.name) == .orderedAscending
    }
    .map(\.matter)
}

/// C1 · the assistant, always there on the left: one thread over every matter, cards rather than
/// paragraphs. The field is about what is open on the right — a matter, or all of them — and what
/// a "reden" brings is pinned above it (C3). A question goes out pseudonymised, like the mail:
/// the field says what the assistant can see, and under each answer is exactly what was sent.
struct AssistantColumn: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    #if DEBUG
    /// For looking at the field with words in it, in a screenshot: `CAUSABEE_DRAFT`.
    @State private var draft = ProcessInfo.processInfo.environment["CAUSABEE_DRAFT"] ?? ""
    #else
    @State private var draft = ""
    #endif
    /// Scrolled up from the newest: a round button above the composer brings the thread down again.
    @State private var scrolledUp = false
    /// An answer that arrived while the thread was scrolled up: the thread stays where it is being
    /// read, and the button says so — "New answer" — and goes to where the answer begins.
    @State private var newAnswer: UUID?
    @FocusState private var focused: Bool

    private var conversation: Conversation {
        Conversation(context: context, navigation: navigation, owner: profiles.first?.names.first)
    }

    private var openMatter: Matter? {
        guard case .matter(let id) = navigation.place else { return nil }
        return matters.first { $0.persistentModelID == id }
    }

    /// What a question is about: the matter of what is in hand, else the one open on the right,
    /// else — on the overview — every matter with something going on.
    private var scopeMatter: Matter? {
        if let pinned = navigation.pinned { return matters.first { $0.persistentModelID == pinned.matter } }
        return openMatter
    }

    /// The question of this thread whose answer is on its way: one at a time, and the send button stops it.
    private var asking: Navigation.Turn? { shown.last(where: \.isAsking) }

    /// The newest question here: the one that can be asked again.
    private var newestQuestion: UUID? { shown.last { $0.note == nil && $0.shot == nil }?.id }

    private var answeredCount: Int {
        navigation.turns.filter { if case .asking = $0.state { false } else { true } }.count
    }

    /// With a matter open, its own conversation; on the overview, everything.
    private var shown: [Navigation.Turn] {
        guard let open = openMatter else { return navigation.turns }
        return navigation.turns.filter { $0.matter == open.persistentModelID }
    }

    /// How many of the newest turns are laid out: a long thread, all of it at once, kept the column
    /// from coming up for seconds. The older ones are a click away, on top.
    @State private var showsNewest = AssistantColumn.page
    private static let page = 30
    private var laidOut: [Navigation.Turn] { Array(shown.suffix(showsNewest)) }

    /// The bar on top of the thread: frosted glass that stays put; the thread scrolls under it
    /// and shows through only blurred.
    /// No title and no bar: only the room the window's buttons need on top.
    private var header: some View {
        Color.clear.frame(height: WindowMetrics.topLine)
    }

    private static let bottom = "thread-bottom"
    /// How the thread moves when it moves by itself: slowly enough to follow, not a jump.
    private static let glide = Animation.easeInOut(duration: 0.3)

    /// Down to the newest, so that its last line is readable — after the thread is laid out with
    /// what is new: asked for in the same moment, its lower edge is still the old one.
    private func toBottom(_ scroller: ScrollViewProxy) {
        DispatchQueue.main.async { withAnimation(Self.glide) { scroller.scrollTo(Self.bottom, anchor: .bottom) } }
    }

    /// How far a file brought in is, as a number: its card grows with it.
    private static func step(_ shot: Navigation.Shot) -> Int {
        switch shot.stage {
        case .reading: 0
        case .read: 1
        case .sending: 2
        case .answered: 3
        case .taken: 4
        case .failed: 5
        case .dismissed: 6
        }
    }

    var body: some View {
        column
            // Put away with a click: the page beside it gets the whole window.
            .overlay(alignment: .topTrailing) {
                Button { withAnimation(.snappy(duration: 0.25)) { navigation.closeAssistant() } } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 26, height: 26).background(.regularMaterial, in: Circle()).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 14).padding(.trailing, 14)
                .help("Close the assistant")
                .accessibilityLabel("Close the assistant")
            }
    }

    private var column: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if shown.isEmpty {
                            Text(openMatter != nil
                                 ? "No talk about this matter yet. Ask something — or click “talk” on a line on the right."
                                 : "Find a matter below, or start a new one — then ask about it. Screenshots, mails and PDFs can be dropped here too.")
                                .font(.callout).foregroundStyle(.secondary)
                                .padding(.top, 20)
                        }
                        let turns = laidOut
                        if turns.count < shown.count {
                            Button("Show earlier · \(shown.count - turns.count) more") { showsNewest += Self.page }
                                .buttonStyle(.gold).font(.caption)
                                .frame(maxWidth: .infinity).padding(.top, 16)
                        }
                        ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                            // The day, where it changes: one thread since the first question.
                            if index == 0 || !Calendar.current.isDate(turns[index - 1].date, inSameDayAs: turn.date) {
                                Text(turn.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))))
                                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, index == 0 ? 16 : 24)
                            }
                            if let note = turn.note {
                                IntakeNote(text: note).id(turn.id).transition(.opacity)
                            } else if let shot = turn.shot {
                                ShotView(turn: turn, shot: shot, matters: matters,
                                         classify: { conversation.classify(shot: turn.id, owner: profiles.first?.names ?? []) },
                                         take: { conversation.take(shot: turn.id, into: $0, newName: $1, owner: profiles.first?.names ?? [], keep: $2) },
                                         dismiss: { Conversation.set(shot: turn.id, .dismissed, in: navigation) },
                                         open: { id in if let matter = matters.first(where: { $0.persistentModelID == id }) { navigation.open(matter) } },
                                         bringBack: { conversation.bring(shot.file) })
                                    .id(turn.id).transition(.opacity)
                            } else {
                                TurnView(turn: turn, open: conversation.open, label: conversation.label,
                                         apply: { conversation.apply($0, text: $1, subject: $2, in: turn) },
                                         undo: { conversation.undo($0, in: turn) },
                                         dismiss: { index, dismissed in
                                             guard let at = navigation.turns.firstIndex(where: { $0.id == turn.id }) else { return }
                                             if dismissed { navigation.turns[at].dismissedCards.insert(index) } else { navigation.turns[at].dismissedCards.remove(index) }
                                         },
                                         recipient: { conversation.recipient($0, in: turn) },
                                         again: turn.id == newestQuestion && asking == nil ? { conversation.again(turn, all: matters) } : nil)
                                    .id(turn.id).transition(.opacity)
                            }
                        }
                        Color.clear.frame(height: 1).id(Self.bottom)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .safeAreaInset(edge: .top, spacing: 0) { header }
                // With the sidebar folded away, the window's buttons sit over the thread: it fades
                // out under them — the page's own colour on top, thinning to nothing below their line.
                .softTopEdge()
                .overlay(alignment: .top) {
                    if navigation.sidebarHidden {
                    LinearGradient(stops: [.init(color: Theme.canvas, location: 0), .init(color: Theme.canvas, location: 0.55),
                                           .init(color: Theme.canvas.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: WindowMetrics.topLine + 20)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
                // What is seen, not where the view starts: the glass bar on top shifts the offset.
                // Read together, so that what was true before a change decides: the field growing by a
                // line, a chip coming over it, the window made lower — a thread that was at its newest
                // stays there, and one being read further up stays where it is read.
                .onScrollGeometryChange(for: ThreadPlace.self) { geometry in
                    ThreadPlace(up: geometry.visibleRect.maxY < geometry.contentSize.height - 60, height: geometry.containerSize.height)
                } action: { old, new in
                    if new.height != old.height, !old.up {
                        scroller.scrollTo(Self.bottom, anchor: .bottom)
                        return
                    }
                    withAnimation(.easeOut(duration: 0.15)) { scrolledUp = new.up }
                    // Down at the newest again: the answer has been reached.
                    if !new.up { newAnswer = nil }
                }
                // What comes into the thread fades in, and what is under it moves, not jumps.
                .animation(Self.glide, value: shown.map(\.id))
                .overlay(alignment: .bottom) {
                    if scrolledUp {
                        Button {
                            withAnimation(Self.glide) {
                                if let newAnswer { scroller.scrollTo(newAnswer, anchor: .top) } else { scroller.scrollTo(Self.bottom, anchor: .bottom) }
                                newAnswer = nil
                            }
                        } label: {
                            ToNewestLabel(newAnswer: newAnswer != nil)
                        }
                        .buttonStyle(.plain)
                        .help(newAnswer != nil ? "To the new answer" : "To the newest")
                        .padding(.bottom, 10)
                        .transition(.opacity)
                    }
                }
                .onAppear { if let last = shown.last { scroller.scrollTo(last.id, anchor: .top) } }
                .onChange(of: navigation.place) { newAnswer = nil; showsNewest = Self.page; if let last = shown.last { scroller.scrollTo(last.id, anchor: .top) } }
                .onChange(of: shown.count) { old, new in
                    guard new > old, let last = shown.last else { return }
                    // A question just asked is followed down, wherever the thread was; anything
                    // else that comes in — new mail, a file — leaves a reader where they are.
                    if case .asking = last.state, last.note == nil, last.shot == nil {
                        newAnswer = nil
                        toBottom(scroller)
                    } else if !scrolledUp {
                        // A file brought in is followed down, as its card grows while it is read.
                        if last.shot != nil { toBottom(scroller) } else { withAnimation(Self.glide) { scroller.scrollTo(last.id, anchor: .top) } }
                    }
                }
                // A file's card that grew — read, sent, answered: followed, if the thread is at it.
                .onChange(of: shown.last?.shot.map(Self.step)) { if !scrolledUp, shown.last?.shot != nil { toBottom(scroller) } }
                .onChange(of: answeredCount) { old, new in
                    guard new > old, let last = shown.last(where: { if case .asking = $0.state { false } else { $0.note == nil && $0.shot == nil } }) else { return }
                    // The answer from where it begins — unless the thread is being read further up.
                    // All of it when it fits — the thread ends at its last line — and from its beginning
                    // when it is longer than the window shows.
                    if scrolledUp { newAnswer = last.id } else { DispatchQueue.main.async { withAnimation(Self.glide) { scroller.scrollTo(last.id, anchor: .top) } } }
                }
            }
            let scope = scopeMatter
            if scope == nil {
                // Only a dropped file brings the assistant to the overview: it is sorted into a
                // matter from its card, and questions are asked inside a matter.
                Text("Take the file into a matter above — or open a matter on the left to ask about it.")
                    .font(.caption).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            } else {
            Composer(draft: $draft, focused: $focused, pinned: navigation.pinned,
                     seen: { FactSheet.facts(for: scope.map { [$0] } ?? activeMatters(matters), today: MatterStatus.day(Date()),
                                             focus: navigation.pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : $0.text }).seen },
                     placeholder: scope.map { "Ask about \($0.name)" } ?? "Say anything",
                     unpin: { navigation.pinned = nil },
                     attach: chooseScreenshot,
                     // Said before it is typed: the chip over the field, and the cursor in the field.
                     add: scope.map { matter in { add in
                         navigation.pinned = Navigation.Pinned(matter: matter.persistentModelID, matterName: matter.name, kind: add.rawValue, text: add.hint)
                         focused = true
                     } },
                     stop: asking.map { turn in { conversation.stop(turn.id) } },
                     send: send)
            }
        }
        .background(Theme.canvas)
        // A screenshot dragged here is read on the Mac, like one chosen with the paper clip.
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter { ScreenshotDoor.readable.contains($0.pathExtension.lowercased()) }
            for url in files { conversation.bring(url) }
            return !files.isEmpty
        }
        .onPasteCommand(of: [.png, .tiff, .fileURL]) { providers in paste(providers) }
        .onChange(of: navigation.focusRequest) {
            if let words = navigation.prefill {
                draft = words
                navigation.prefill = nil
            }
            focused = true
        }
        .onAppear {
            // `--ask "<question>"` asks once at launch, to see an answer without typing.
            let arguments = CommandLine.arguments
            if navigation.turns.isEmpty, let flag = arguments.firstIndex(of: "--ask"), flag + 1 < arguments.count {
                draft = arguments[flag + 1]
                send()
            }
        }
    }

    private func chooseScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .pdf, UTType(filenameExtension: "eml") ?? .emailMessage]
        panel.allowsMultipleSelection = true
        panel.message = "Choose a screenshot, a mail (.eml) or a PDF — it is scanned on the Mac, and sent only after “Sort in”."
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { conversation.bring(url) }
    }

    /// ⌘V with an image: it has no home, so it is written beside the store and read from there.
    private func paste(_ providers: [NSItemProvider]) {
        let conversation = self.conversation
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in conversation.bring(url) }
                }
            } else if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
                      let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) {
                conversation.bringPasted(png)
                return
            }
        }
    }

    private func send() {
        // One question at a time: what is typed meanwhile waits in the field.
        guard asking == nil, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let question = draft
        draft = ""
        let scope = scopeMatter
        conversation.ask(question, about: scope.map { [$0] } ?? activeMatters(matters), pinnedMatter: scope)
    }
}

/// The button over the thread's lower edge: an arrow down to the newest, and "New answer" beside
/// it when one arrived while the thread was scrolled up.
struct ToNewestLabel: View {
    let newAnswer: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: newAnswer ? "arrow.down" : "chevron.down").font(.body.weight(.semibold))
            if newAnswer { Text("New answer").font(.callout.weight(.medium)) }
        }
        .foregroundStyle(newAnswer ? .primary : .secondary)
        .padding(.horizontal, newAnswer ? 14 : 0)
        .frame(minWidth: 32, minHeight: 32)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
    }
}

/// What came in with "Get new mail", in the thread of the matter it went to.
struct IntakeNote: View {
    let text: String

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Notes written before the symbol took its place begin with the tray emoji.
        let head = (lines.first ?? "").replacingOccurrences(of: "📥", with: "").trimmingCharacters(in: .whitespaces)
        VStack(alignment: .leading, spacing: 3) {
            Label(head, systemImage: "tray.and.arrow.down").font(.caption.weight(.semibold))
            ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Nothing to decide here, only to read: white, as a card taken in — grey is what waits.
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        .padding(.top, 6)
    }
}

/// The overview: the week across all matters, the pinned matters as cards, and every other matter
/// going on as one line, each a door into its status (Figma "Overview with many matters", 3 + 4).
/// Worked out on the device; nothing is sent.
struct OverviewView: View {
    let matters: [Matter]
    @Binding var search: String
    let start: (String) -> Void
    @Environment(Navigation.self) private var navigation
    @FocusState private var searching: Bool
    /// The matters opened last are shown under the field: after a click on it or ↓, with nothing typed.
    @State private var showsRecent = false
    /// The row the arrow keys or the mouse are on; Return opens it. The last row is "Start new".
    @State private var picked = 0
    /// How wide the page is: how many pinned matters fit side by side.
    @State private var width: CGFloat = 0

    private var ordered: [Matter] { activeMatters(matters) }

    /// On top of the cards: a matter found by its name, a task or a mail — or started.
    @ViewBuilder
    private var searchField: some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        // Nothing typed, and the field clicked or ↓ pressed: the matters opened last, to go straight
        // back to. The first letter typed puts what is found in their place.
        let hits = query.isEmpty ? (showsRecent && searching ? RecentMatters.list(in: matters, fillingFrom: ordered).map { MatterSearch.Hit(matter: $0) } : [])
                                 : MatterSearch.find(query, in: matters)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find or start a matter", text: $search)
                    .textFieldStyle(.plain).font(.title3)
                    .focused($searching)
                    .accessibilityIdentifier("overview.search")
                    .onSubmit {
                        if hits.indices.contains(picked) { search = ""; showsRecent = false; navigation.open(hits[picked].matter) } else if !query.isEmpty { start(query) }
                    }
                    .onKeyPress(.downArrow) {
                        // With nothing typed, ↓ brings the last ones; then it walks them.
                        guard !query.isEmpty else {
                            if showsRecent { picked = min(picked + 1, max(hits.count - 1, 0)) } else { showsRecent = true; picked = 0 }
                            return .handled
                        }
                        picked = min(picked + 1, hits.count); return .handled
                    }
                    .onKeyPress(.upArrow) {
                        guard !query.isEmpty || showsRecent else { return .ignored }
                        picked = max(picked - 1, 0); return .handled
                    }
                    .onChange(of: search) { picked = 0 }
                    .onChange(of: searching) { if !searching { showsRecent = false } }
                    .onExitCommand { search = ""; showsRecent = false }
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(searching ? Theme.strongLine : Theme.line, lineWidth: searching ? 1.5 : 1))
            // Anywhere on the field puts the cursor in it, not only on its words.
            .contentShape(Capsule())
            .onTapGesture { searching = true; showsRecent = true }
            // A click on the words themselves is the field's own, and says nothing of it: until the
            // last ones are shown, the click is taken here, over the field — it puts the cursor in and
            // brings them. After that the field has its clicks again.
            .overlay {
                if !showsRecent, query.isEmpty {
                    Color.clear.contentShape(Capsule()).onTapGesture { searching = true; showsRecent = true }
                }
            }
            if !query.isEmpty || !hits.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if query.isEmpty {
                        Text("RECENT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.top, 2)
                    }
                    ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                        Button { search = ""; showsRecent = false; navigation.open(hit.matter) } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: index == picked ? "return" : "folder").font(.caption).foregroundStyle(.secondary).frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(hit.matter.name + (hit.matter.isClosed ? " · closed" : ""))
                                    if let because = hit.because { Text(because).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4).padding(.horizontal, 6).contentShape(Rectangle())
                            .background(index == picked ? Theme.mark : .clear, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .onHover { if $0 { picked = index } }
                    }
                    if !query.isEmpty {
                    Button { start(query) } label: {
                        HStack {
                            Image(systemName: picked == hits.count ? "return" : "plus.circle").font(.caption).frame(width: 18)
                            Text("Start new matter: “\(query)”").fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6).contentShape(Rectangle())
                        .background(picked == hits.count ? Theme.mark : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .onHover { if $0 { picked = hits.count } }
                    .help("Made on the Mac, nothing is sent.")
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
            }
        }
        .padding(.bottom, 14)
        // The overview opens ready to type: the cursor in the field.
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { searching = true } }
        .background {
            Button("") { searching = true }.keyboardShortcut("f", modifiers: .command).hidden()
        }
    }

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // The day, where things stand and the search: one block in the middle, as wide as a
                // search needs — not the page — with room around it.
                VStack(spacing: 10) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(OverviewSummary.text(ordered)).font(.title3).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    searchField.padding(.top, 4)
                    // The assistant about every matter, beside the overview.
                    if !navigation.assistantOnOverview {
                        Button { withAnimation(.snappy(duration: 0.25)) { navigation.openAssistant() } } label: {
                            HStack(spacing: 7) {
                                BeeMark(size: 15)
                                Text("Ask Causabee").font(.callout.weight(.medium))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Theme.bee, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Ask about all your matters")
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 18)
                if !matters.isEmpty { OverviewWeek(matters: matters) }
                let pinned = Pins.pinned(matters)
                if !pinned.isEmpty { pinnedCards(pinned).padding(.top, 6) }
                let rest = ordered.filter { !$0.isPinned }
                if !rest.isEmpty {
                    SectionHeader(title: pinned.isEmpty ? "Matters" : "Everything else",
                                  detail: pinned.isEmpty ? "right-click one to pin it" : rest.count == 1 ? "1 matter" : "\(rest.count) matters")
                        .padding(.top, 6)
                    OverviewRows(matters: rest, all: matters)
                }
                // A closed matter is out of the overview, unless mail came for it after it was closed.
                ForEach(matters.filter { $0.isClosed && !MatterStatus($0).mailsSinceClosed.isEmpty }) { matter in
                    let new = MatterStatus(matter).mailsSinceClosed.count
                    HStack {
                        Image(systemName: "archivebox").foregroundStyle(.secondary)
                        Text("\(new) new \(new == 1 ? "mail" : "mails") in the closed matter “\(matter.name)”")
                        Spacer()
                    }
                    .font(.callout)
                    .padding(12)
                    .box()
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { navigation.open(matter) }
                    .help("Open the matter")
                }
                let quiet = matters.filter { !$0.isClosed && !$0.isPinned }.count - rest.count
                if quiet > 0 {
                    Text("\(quiet) \(quiet == 1 ? "matter is" : "matters are") quiet: nothing open, no date.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(24)
            // The whole width, up to where lines would get too long to follow.
            .frame(maxWidth: 1400, alignment: .leading)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .navigationTitle("Overview")
    }

    /// The pinned matters under the day, side by side — as many in a row as are pinned, up to
    /// three, and fewer where the page is too narrow for them.
    private func pinnedCards(_ pinned: [Matter]) -> some View {
        let fit = width >= 1100 ? 3 : width >= 720 ? 2 : 1
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: max(1, min(pinned.count, fit)))
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Pinned", detail: "stays on top")
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(pinned) { matter in
                    MatterCard(matter: matter, open: { navigation.open(matter) }, openTodo: { navigation.open(matter, showing: $0) })
                        .contextMenu { PinMenuItem(matter: matter, all: matters) }
                }
            }
        }
    }
}

/// One question and what came back: lines that cite their facts, cards to tick, and what was sent.
struct TurnView: View {
    let turn: Navigation.Turn
    let open: (FactRef) -> Void
    let label: (FactRef) -> String
    let apply: (Int, String, String?) -> Void
    let undo: (Int) -> Void
    var dismiss: (Int, Bool) -> Void = { _, _ in }
    var recipient: (String?) -> (name: String, address: String?)? = { _ in nil }
    /// Asks the same question once more — for the newest question, while nothing else is on its way.
    var again: (() -> Void)? = nil
    @State private var showsSent = false
    /// The answer's sources, unfolded: one list for the whole answer.
    @State private var showsSources = false
    /// Just copied: the button says so for a moment.
    @State private var copied = false
    /// Kept as a note of its matter: the button says so, and does not keep it twice.
    @State private var savedNote = false
    @Environment(\.modelContext) private var context
    @Environment(\.reading) private var reading

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(turn.question)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Theme.honey, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.black)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 80)
            ForEach(turn.readAs, id: \.self) { note in
                Label(note, systemImage: "character.cursor.ibeam").font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            switch turn.state {
            case .asking:
                AskSteps(step: turn.step ?? .disguising, sentAt: turn.sentAt)
            case .failed(let message):
                // Stopped by the owner is no failure: said quietly.
                if AssistantAsk.wasStopped(message) {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                } else {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warning).textSelection(.enabled)
                }
                if let again {
                    Button(action: again) { Label("Try again", systemImage: "arrow.clockwise") }
                        .buttonStyle(.gold).font(.callout)
                        .help("Asks the same question once more")
                }
            case .answered(let answer):
                answered(answer)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func answered(_ answer: AssistantAsk.Answer) -> some View {
        // What the answer and its cards rest on, each once, in the order it is cited.
        let cites = (answer.reply.lines.flatMap(\.cites) + answer.reply.cards.flatMap(\.cites))
            .reduce(into: [String]()) { if turn.refs[$1] != nil, !$0.contains($1) { $0.append($1) } }
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(answer.reply.lines.enumerated()), id: \.offset) { _, line in
                Text(line.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            // What the facts do not say is part of the answer, said like the rest of it — not a notice.
            if let missing = answer.reply.notInFacts {
                Text(missing).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(answer.reply.cards.enumerated()), id: \.offset) { index, card in
                // While reading, a draft asked for stays; the other suggestions are put away.
                if !reading || card.kind == .draftMessage {
                    ActionCard(card: card, done: turn.applied.contains(index), refs: turn.refs, open: open, label: label,
                               apply: { apply(index, $0, $1) }, undo: turn.undos[index] == nil ? nil : { undo(index) },
                               recipient: recipient(card.party),
                               dismissed: turn.dismissedCards.contains(index), setDismissed: { dismiss(index, $0) })
                }
            }
            // One line under the answer: copy it, ask again, what it rests on — and what it cost.
            HStack(spacing: 14) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(answer.plainText, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .help(copied ? "Copied" : "Copy the answer")
                .accessibilityLabel("Copy the answer")
                // An answer about one matter can be kept with it, as a note.
                if let kept = turn.matter.flatMap({ context.model(for: $0) as? Matter }) {
                    Button {
                        NotesPart.keep(answer.plainText, in: kept, context: context)
                        savedNote = true
                    } label: {
                        Image(systemName: savedNote ? "checkmark" : "note.text.badge.plus").frame(width: 16, height: 16).contentShape(Rectangle())
                    }
                    .disabled(savedNote)
                    .help(savedNote ? "Saved in the notes of \(kept.name)" : "Save as a note in \(kept.name)")
                    .accessibilityLabel("Save as note")
                }
                // Another answer would take the place of this one: not once a card of it is taken in.
                if let again, turn.applied.isEmpty {
                    Button(action: again) {
                        Image(systemName: "arrow.clockwise").frame(width: 16, height: 16).contentShape(Rectangle())
                    }
                    .help("Try again: asks the same question once more, for another answer")
                    .accessibilityLabel("Try again")
                }
                if !cites.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showsSources.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Sources (\(cites.count))")
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                .rotationEffect(.degrees(showsSources ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .help(showsSources ? "Hide the sources" : "What this rests on: mails, tasks, dates")
                }
                Spacer(minLength: 8)
                // Only what it cost; who answered and what was sent are behind it.
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showsSent.toggle() }
                } label: {
                    // What the disguise found in the question — so it is seen that it looked — and what it cost.
                    Text((answer.disguiseLine.map { $0 + " · " } ?? "") + String(format: "$%.3f", answer.cost)).font(.caption2).contentShape(Rectangle())
                }
                .help(showsSent ? "Hide what was sent" : (answer.disguiseSentence.map { $0 + " " } ?? "") + "\(answer.modelLabel) — shows what was sent, pseudonymised")
            }
            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            .tool()
            if showsSources, !cites.isEmpty {
                SourceList(cites: cites, refs: turn.refs, open: open).padding(.top, 4).explanation()
            }
            if showsSent {
                VStack(alignment: .leading, spacing: 6) {
                    Text(answer.modelLabel).font(.caption2).foregroundStyle(.secondary)
                    if let sentence = answer.disguiseSentence {
                        Text(sentence).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    ScrollView {
                        Text(answer.sent).font(.caption.monospaced()).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 260)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .explanation()
            }
        }
    }
}

/// Something to do, record or correct, with its reason. Nothing changes until its button is
/// clicked — a button that says what it does, not a checkbox that looks like "done" — and a name
/// or a to-do can be put right on the card first.
struct ActionCard: View {
    let card: AssistantPrompt.Reply.Card
    let done: Bool
    let refs: [String: FactRef]
    let open: (FactRef) -> Void
    let label: (FactRef) -> String
    let apply: (String, String?) -> Void
    let undo: (() -> Void)?
    var recipient: (name: String, address: String?)? = nil
    @State private var text: String
    @State private var subject: String
    /// Dismissed, as the thread keeps it.
    var dismissed = false
    var setDismissed: (Bool) -> Void = { _ in }
    /// A draft opened in Mail folds to a few lines; "Edit" unfolds it again.
    @State private var editingDraft = false
    /// Taken in, the card turns into its small quiet box in three steps, as on the iPhone: its
    /// content fades out, the empty grey box closes to its new size, the new content fades in.
    @Namespace private var morph
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quiet = false
    @State private var showsContent = true

    /// Out, change, in. With Reduce Motion: a short cross-fade.
    private func step(_ change: @escaping () -> Void) {
        if reduceMotion { withAnimation(.easeInOut(duration: 0.2)) { change() }; return }
        withAnimation(.easeOut(duration: 0.14)) { showsContent = false } completion: {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { change() } completion: {
                withAnimation(.easeIn(duration: 0.16)) { showsContent = true }
            }
        }
    }

    init(card: AssistantPrompt.Reply.Card, done: Bool, refs: [String: FactRef], open: @escaping (FactRef) -> Void,
         label: @escaping (FactRef) -> String, apply: @escaping (String, String?) -> Void, undo: (() -> Void)?,
         recipient: (name: String, address: String?)? = nil,
         dismissed: Bool = false, setDismissed: @escaping (Bool) -> Void = { _ in }) {
        (self.card, self.done, self.refs, self.open, self.label, self.apply, self.undo) = (card, done, refs, open, label, apply, undo)
        self.recipient = recipient
        (self.dismissed, self.setDismissed) = (dismissed, setDismissed)
        _text = State(initialValue: card.text)
        _subject = State(initialValue: card.subject ?? "")
        // In its own state from the first frame, so a card scrolled into view does not shrink.
        _quiet = State(initialValue: done)
    }

    private var editable: Bool { [.newTodo, .renameParty, .changeRole, .correctText, .addNote, .newMatter, .addLink, .addContact, .newAppointment, .newDeadline, .addDetail].contains(card.kind) }

    var body: some View {
        Group {
            if card.kind == .draftMessage, quiet, !editingDraft {
                sentDraft
            } else if quiet {
                taken
            } else if dismissed, !done {
            // Put aside, not gone: a small white card — nothing waits in it — that says what was
            // suggested, and brings it back.
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You dismissed this suggestion").font(.caption2)
                    Text(card.text.isEmpty ? title : card.text).font(.caption)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Show again") { setDismissed(false) }.buttonStyle(.gold).font(.caption).fixedSize()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                if let what = what { Text(what).fixedSize(horizontal: false, vertical: true) }
                if card.kind == .draftMessage {
                    TextField("Subject", text: $subject).cardField()
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140, maxHeight: 320)
                        .padding(6)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                } else if editable {
                    TextField("", text: $text, axis: .vertical)
                        .cardField()
                        .disabled(done)
                        .help("Change it before taking it in, if it is not quite right")
                }
                Text(card.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if card.kind == .sameParty, !done {
                    Text("Later you can only turn merging off for new mail; you cannot split it again.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Spacer()
                    if quiet, card.kind == .draftMessage {
                        Button("Cancel") { step { editingDraft = false } }
                        Button("Open in Mail") {
                            apply(text, subject)
                            step { editingDraft = false }
                        }
                        .inkButton()
                    } else if quiet {
                        Label("Taken in", systemImage: "checkmark")
                            .font(.callout).foregroundStyle(Theme.done)
                        if let undo {
                            Button("Undo", action: undo)
                                .help(card.kind == .sameParty ? "Turns the rule off: the next mail is not merged any more"
                                                              : "Puts it back the way it was")
                        }
                    } else {
                        Button("Dismiss") { withAnimation { setDismissed(true) } }
                        Button(verb) { apply(text, card.kind == .draftMessage ? subject : nil) }
                            .inkButton()
                    }
                }
                .padding(.top, 10)
            }
            .opacity(showsContent ? 1 : 0)
            .padding(12)
            .background { RoundedRectangle(cornerRadius: 10).fill(Theme.box).matchedGeometryEffect(id: "box", in: morph, isSource: !quiet || editingDraft) }
            .transition(.opacity)
            }
        }
        // Undo plays it backwards; with Reduce Motion it is a short cross-fade.
        .onChange(of: done) { if quiet != done { step { quiet = done; editingDraft = false } } }
    }

    /// A card taken in, small and quiet: what was done, what kind, and Undo while the app is open.
    /// The reason and the sources stay with what it made; a click opens its matter.
    private var taken: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(Theme.done)
            VStack(alignment: .leading, spacing: 1) {
                Text(takenWhat).fontWeight(.medium).lineLimit(2)
                Text(takenKind).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let undo {
                Button("Undo") { undo() }
                    .buttonStyle(.gold).font(.caption)
                    .help(card.kind == .sameParty ? "Turns the rule off: the next mail is not merged any more" : "Puts it back the way it was")
            }
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background { RoundedRectangle(cornerRadius: 10).fill(Theme.card).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: openTaken)
        .help("Opens it in its matter")
        .transition(.opacity)
    }

    private var takenWhat: String {
        switch card.kind {
        case .sameParty: return "\(name(card.party))  →  \(name(card.into))"
        case .waitsFor, .changeOwner: return name(card.todo)
        default: return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? card.text : text
        }
    }

    private var takenKind: String {
        switch card.kind {
        case .newTodo: return "Task added · " + whose + (card.due.map { " · by \(Dates.short($0))" + (card.time.map { " at \($0)" } ?? "") } ?? "")
        case .markDone: return "Marked done"
        case .sameParty: return "Merged into one person"
        case .renameParty: return "Name changed"
        case .changeRole: return "Role changed · " + name(card.party)
        case .addNote: return card.todo == nil ? "Note added" : "Note added · " + name(card.todo)
        case .changeDate: return "Date changed"
        case .newMatter: return "Matter started"
        case .waitsFor: return "Now waits for " + name(card.into)
        case .addLink: return "Link saved"
        case .addContact: return "Contact saved"
        case .newAppointment: return "Appointment added"
        case .newDeadline: return "Deadline added"
        case .addDetail: return "Detail saved"
        case .correctText: return "Text corrected"
        case .changeOwner: return "Now " + whose.lowercased()
        case .draftMessage: return "Opened in Mail"
        }
    }

    /// The matter it is about: the task it names, else what it rests on.
    private func openTaken() {
        if let ref = ([card.todo, card.party] + card.cites).compactMap({ $0.flatMap { refs[$0] } }).first { open(ref) }
    }

    /// What was opened in Mail, as small and quiet as a card taken in: its subject, where it went
    /// and to whom. A click opens it in Mail again; Edit unfolds it. Opened is not sent: the
    /// envelope, not a tick.
    private var sentDraft: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "envelope").font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(subject.isEmpty ? text : subject).fontWeight(.medium).lineLimit(2)
                Text("Draft opened in Mail · To: \(recipient?.name ?? "—")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit") { step { editingDraft = true } }.buttonStyle(.gold).font(.caption)
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background { RoundedRectangle(cornerRadius: 10).fill(Theme.card).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { apply(text, subject) }
        .help("Opens it in Mail again")
        .transition(.opacity)
    }

    private func name(_ id: String?) -> String { id.flatMap { refs[$0] }.map(label) ?? "?" }

    private var whose: String { ["me": "Mine", "we": "Ours", "other": "Waiting for"][card.owner] ?? "Unclear whose" }

    /// What the button does, in a word or two.
    private var verb: String {
        switch card.kind {
        case .markDone: "Done"
        case .newTodo: "Add"
        case .sameParty: "Merge"
        case .addNote: "Save note"
        case .draftMessage: "Open in Mail"
        case .changeDate: "Change date"
        case .newMatter: "Create"
        case .waitsFor: "Link"
        case .addLink: "Save link"
        case .addContact: "Save contact"
        case .newAppointment, .newDeadline: "Add"
        case .addDetail: "Save detail"
        case .renameParty, .changeRole, .correctText, .changeOwner: "Change"
        }
    }

    private var title: String {
        switch card.kind {
        case .markDone: return "Done?"
        case .newTodo: return "New task? · " + whose + (card.due.map { " · by \(Dates.short($0))" + (card.time.map { " at \($0)" } ?? "") } ?? "")
        case .sameParty: return "Same person?"
        case .renameParty: return "Change name?"
        case .changeRole: return "Change role?"
        case .addNote: return card.todo == nil ? "Note for the matter?" : "Note for the task?"
        case .draftMessage: return "Draft"
        case .changeDate: return "Change date?"
        case .newMatter: return "New matter?"
        case .waitsFor: return "Waits for another task?"
        case .addLink: return "Save link? · Name:"
        case .addContact: return "Contact? · Name:"
        case .newAppointment: return "New appointment? · " + (card.due.map(Dates.short) ?? "?") + (card.time.map { " at \($0)" } ?? "")
        case .newDeadline: return "New deadline? · by " + (card.due.map(Dates.short) ?? "?")
        case .addDetail: return "Detail? · " + (card.subject ?? "")
        case .correctText: return "Replace in the text?"
        case .changeOwner: return "Whose task? → " + whose
        }
    }

    /// The line above the field: what the card is about.
    private var what: String? {
        switch card.kind {
        case .markDone: return card.text
        case .newTodo: return nil
        case .sameParty: return "\(name(card.party))  →  \(name(card.into))"
        case .renameParty: return "\(name(card.party))  is called:"
        case .changeRole: return "\(name(card.party))  is here:"
        case .addNote: return card.todo == nil ? nil : name(card.todo)
        case .draftMessage:
            guard let recipient else { return "To: (fill in in Mail)" }
            return "To: \(recipient.name)" + (recipient.address.map { " <\($0)>" } ?? " — address not known, fill it in in Mail")
        case .correctText: return "“\(card.from ?? "")”  becomes:"
        case .newMatter: return nil
        case .waitsFor: return "\(name(card.todo))  →  only after: \(name(card.into))"
        case .addLink: return card.todo == nil ? "to the matter" : "to: \(name(card.todo))"
        case .newAppointment, .newDeadline: return nil
        case .addDetail: return card.party == nil ? "its value is never among the facts sent" : "of \(name(card.party)) · its value is never among the facts sent"
        case .addContact: return [card.subject, card.from, card.time].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        case .changeDate:
            let when = (card.due.map(Dates.short) ?? "?") + (card.time.map { " at \($0)" } ?? "")
            return "\(name(card.todo))  →  \(when)"
        case .changeOwner: return name(card.todo)
        }
    }
}

/// One matter in the assistant: what is open and whose, what comes next, and what is overdue —
/// by name, each a door to that very to-do. "öffnen" is the door into its status.
struct MatterCard: View {
    let matter: Matter
    let open: () -> Void
    let openTodo: (PersistentIdentifier) -> Void
    @State private var hovering = false

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let status = MatterStatus(matter)
        VStack(alignment: .leading, spacing: 8) {
            let mine = status.open(.me).count, ours = status.open(.we).count, waiting = status.open(.other).count
            BeeChip(text: line(mine: mine, ours: ours, waiting: waiting))
            HStack(spacing: 10) {
                MatterIconTile(matter: matter, size: 34)
                Text(matter.name).font(Theme.cardTitleFont).foregroundStyle(.primary)
            }
            if let next = status.next {
                Text("Next, on \(Dates.short(next.day)): \(next.what)").foregroundStyle(.secondary).lineLimit(2)
            }
            let overdue = status.overdue.sorted { ($0.due ?? "") < ($1.due ?? "") }
            ForEach(overdue.prefix(3)) { todo in
                Button { openTodo(todo.persistentModelID) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                        Text("Overdue since \(todo.due.map(Dates.short) ?? ""): \(todo.text)").lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .font(.callout)
                    .foregroundStyle(Theme.warning)
                }
                .buttonStyle(.plain)
                .help("Open the matter, at this task")
            }
            if overdue.count > 3 {
                Button("… and \(overdue.count - 3) more overdue", action: open).buttonStyle(.plain).font(.caption).foregroundStyle(Theme.warning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(hovering ? Theme.strongLine : Theme.line))
        // The whole card is the door into the matter; an overdue line inside opens it at that task.
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: open)
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .help("Open the matter")
    }

    private func line(mine: Int, ours: Int, waiting: Int) -> String {
        var parts: [String] = []
        if mine > 0 { parts.append("\(mine) for you") }
        if ours > 0 { parts.append("\(ours) together") }
        if waiting > 0 { parts.append("waiting for \(waiting)") }
        return parts.isEmpty ? "Nothing open." : parts.joined(separator: " · ")
    }
}

/// Chips side by side, wrapping onto the next line when there is no room.
struct FlowRow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] = []
        var items: [Int] = [], x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append((items, y, x - spacing, height))
                y += height + spacing
                items = []; x = 0; height = 0
            }
            items.append(index)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !items.isEmpty { rows.append((items, y, x - spacing, height)) }
        return rows
    }
}

