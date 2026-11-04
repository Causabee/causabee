import MatterCore
import SwiftData
import SwiftUI

// The iPhone's parts, as Figma's "iPhone parts" draws them (`iOS/…`).

extension Theme {
    /// The overview's and a matter's name on top of the page (Figma "iOS/Large Title Serif").
    static let phoneTitleFont = Font.custom("Source Serif 4", size: 34, relativeTo: .largeTitle)
    /// A matter's name in the iPad's bar: the same face, the size of the bar.
    static let padTitleFont = Font.custom("Source Serif 4", size: 30, relativeTo: .title)
    /// A matter's name on its overview card.
    static let phoneCardTitleFont = Font.custom("Source Serif 4", size: 22, relativeTo: .title2)
}

extension View {
    /// A tap on the page, or scrolling it, puts the keyboard away — to see all of the page; what
    /// was typed stays in its field. Buttons on the page still work as before.
    func dismissesKeyboard() -> some View {
        scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
    }
}

extension View {
    /// Inside a scroll view: exactly as wide as that scroll view, by a width we measured ourselves
    /// (`tellsItsWidth`). `containerRelativeFrame` did this until an iPad's window was resized: then
    /// it kept the old width, and what was in the sheet stood cut off on both sides.
    func asWide(as width: CGFloat) -> some View { frame(width: width > 0 ? width : nil) }

    /// On a scroll view: says how wide it is, now and whenever its window changes.
    func tellsItsWidth(_ width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width.wrappedValue = $0 }
    }

    /// The signs in a menu — every menu, held or tapped: one grey, a step quieter than the words
    /// beside them, whatever colour the button has that opens it. A menu takes its signs' colour
    /// from its button otherwise: yellow under the bee, black under ⋯, gold when held.
    func menuSigns() -> some View { tint(Color.secondary) }

}

/// A section with nothing in it yet, as on the Mac: a grey box, what goes in it in the middle,
/// and — where the owner can add it by hand — the button that does.
struct PhoneEmptyBox: View {
    let text: String
    var action: String? = nil
    var symbol = "plus"
    var run: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: run) { Label(action, systemImage: symbol) }.buttonStyle(.phoneFilled)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, action == nil ? 18 : 22)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

extension View {
    /// The grey box of "Next" and "Summary".
    func phoneBox() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Rows or a card on white, with a thin line round it.
    func phoneCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
    }
}

/// The round button in the corner, with the bee on it: one button for the assistant and for Pro.
/// Yellow, Pro is on: a tap opens the chat. Grey, Pro is off — Light: a tap says what Pro adds and
/// offers what can be added here without it. Held, either way: Pro on or off first, then what the
/// assistant's plus offers — a task, a note, a scan — without going through the assistant. The
/// bolt that stood over it for Pro is gone: the bee's colour says it.
struct AssistantButton: View {
    var matter: Matter? = nil
    let action: () -> Void
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @AppStorage(AutoMode.key) private var auto = false
    @State private var picksPhoto = false
    @State private var picksFile = false
    @State private var asks = false
    @State private var light = false

    /// On, and Pro bought.
    private var pro: Bool { auto && Store.shared.plan == .pro }

    /// Light as a grey bee on light glass, or the yellow bee's form in grey — a white bee on a solid
    /// grey disc: which one reads better is to be chosen — `-bee.light inverse` shows the second.
    private var inverse: Bool { UserDefaults.standard.string(forKey: "bee.light") == "inverse" }

    var body: some View {
        bee
            .padding(.trailing, 16).padding(.bottom, 8)
            .sheetWhenAsked(isPresented: $light) {
                LightBeeSheet(matter: matter) { light = false; turnOn() }
            }
            .asksBeforeAuto($asks) { switchOn() }
    }

    /// Yellow: the chat on a tap, and held, Pro off and what can be added. Grey: one tap, the
    /// sheet — there is no menu to hold, since what it lists to be read and sorted in is Pro's.
    @ViewBuilder
    private var bee: some View {
        if pro {
            Menu {
                // The button is yellow; what its menu lists is not: yellow signs on the menu's
                // white could hardly be read.
                Group {
                    Button("Turn off Pro", systemImage: "bolt.slash") { auto = false; Haptics.tap() }
                    Divider()
                    PlusItems(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
                }
                .menuSigns()
            } label: {
                face
            } primaryAction: {
                action()
            }
            .menuIndicator(.hidden)
            // The system's own glass button, round: alive under the finger, and the held menu grows
            // out of it and goes back into it.
            .menuStyle(.button)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(Theme.bee)
            // Held: a small knock in the hand as its menu comes, as the system's own held things give.
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in Haptics.held() })
            .accessibilityLabel("Causabee")
            .accessibilityValue("Pro on")
            .accessibilityHint("Opens the chat. Hold to turn off Pro or to add to a matter")
            .accessibilityIdentifier("bee")
            .bringsIn(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
        } else {
            Button { light = true } label: { face }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(inverse ? Color(white: 0.36) : Color(white: 0.86))
                .accessibilityLabel("Causabee")
                .accessibilityValue("Pro off")
                .accessibilityHint("Says what Pro adds, and what can be added without it")
                .accessibilityIdentifier("bee")
        }
    }

    /// Causabee's own bee, black on its yellow as the app icon has it — not a speech bubble.
    private var face: some View {
        BeeAtHome(size: 24, livesNowAndThen: pro, ink: pro ? .black : inverse ? .white : Color(white: 0.45))
            .frame(width: 46, height: 46)
    }

    /// As the bolt did: without Pro bought, the plans first; the first time, what Pro does is
    /// said and asked before anything is read.
    private func turnOn() {
        guard Store.shared.mayTurnOnPro() else { return }
        if AutoMode.asksFirst { asks = true; return }
        switchOn()
    }

    private func switchOn() {
        auto = true
        Haptics.tap()
        PhoneMailCheck.shared.autoTurnedOn(context: context)
    }
}

/// A tap on the grey bee: what Pro adds, in two lines, the way to turn it on, and what can be added
/// to a matter here without it — the same as the bee's hold menu. No price: only the plans cost.
struct LightBeeSheet: View {
    let matter: Matter?
    let turnOn: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(Navigation.self) private var navigation
    @AppStorage("bee.lightSeen") private var seen = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pro reads new mail as it comes, writes the next step and the summary, and answers in the chat.")
                        if !seen {
                            Text("Without Pro, Causabee sorts mail on this device and chooses the next step from your own tasks and dates. Nothing is written about a matter by an AI.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                    .padding(.vertical, 4)
                    Button {
                        dismiss()
                        turnOn()
                    } label: {
                        Label("Turn on Pro", systemImage: "bolt")
                    }
                }
                // What can be added without Pro, as rows.
                Section("Add") {
                    add("Task", "checklist", .task)
                    add("Note", "note.text", .note)
                    add("Link", "link", .link)
                    add("Detail", "info.circle", .detail)
                    add("Contact", "person.badge.plus", .contact)
                    // Kept only, not read: what is read and sorted in — a photo, a scan, a file —
                    // is Pro's, and is not offered here.
                    add("Files or a folder", "folder", .files)
                }
            }
            .navigationTitle("Light")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetCancel { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        // A task, a note, a contact picked: its editor comes on the page, which this sheet would cover.
        .onChange(of: navigation.adding) { if navigation.adding != nil { dismiss() } }
        .onDisappear { seen = true }
    }

    /// In a matter, for that matter; on the overview, which one is asked.
    private func add(_ title: String, _ symbol: String, _ plus: Navigation.Plus) -> some View {
        Button(title, systemImage: symbol) {
            if let matter { navigation.add(plus, to: matter) } else { dismiss(); navigation.choose(for: plus) }
        }
    }
}

/// Auto on and off, small, over the bee — the same switch as in Settings › New mail and the bolt
/// on the Mac. On: the black bolt on the bee's yellow. What Auto does is asked once, before it is
/// first turned on (AutoQuestion).
struct PhoneAutoButton: View {
    @AppStorage(AutoMode.key) private var auto = false
    @Environment(\.modelContext) private var context
    @State private var asks = false
    /// On, and Pro bought.
    private var pro: Bool { auto && Store.shared.plan == .pro }

    var body: some View {
        Button {
            // The first time it is turned on, what it does is said and asked — before anything is
            // read, not beside the bolt once it already is.
            if pro { auto = false; Haptics.tap(); return }
            // Without Pro bought: the plans first.
            guard Store.shared.mayTurnOnPro() else { return }
            if AutoMode.asksFirst { asks = true; return }
            auto = true
            Haptics.tap()
            PhoneMailCheck.shared.autoTurnedOn(context: context)
        } label: {
            Image(systemName: pro ? "bolt.fill" : "bolt").font(.system(size: 15, weight: .medium))
                .foregroundStyle(pro ? Color.black : Color.secondary)
                .frame(width: 36, height: 36)
                // Glass, as the bee under it: clear while Auto is off, the bee's yellow while it is on.
                .onGlass(Circle(), tint: pro ? Theme.bee.opacity(0.82) : nil)
                // A finger's room around the small disc.
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pro")
        .accessibilityValue(pro ? "On" : "Off")
        .accessibilityHint("Pro: the bigger AI reads new mail and files at once. Without Pro: only when you say so")
        .accessibilityIdentifier("auto.toggle")
        .asksBeforeAuto($asks) {
            auto = true
            Haptics.tap()
            PhoneMailCheck.shared.autoTurnedOn(context: context)
        }
    }
}

/// "Use in Chat" in a row's menu, with the bee — the same mark as the yellow button. A menu only
/// takes pictures, so the bee is drawn once into one, as a template: grey like the other icons.
struct AskCausabeeButton: View {
    let action: () -> Void

    @MainActor private static let bee: Image = { @MainActor in
        let renderer = ImageRenderer(content: BeeMark(size: 15).tight().foregroundStyle(.black))
        renderer.scale = 3
        guard let picture = renderer.uiImage else { return Image(systemName: "bubble.left.and.bubble.right") }
        return Image(uiImage: picture.withRenderingMode(.alwaysTemplate))
    }()

    var body: some View {
        Button(action: action) { Label { Text(Say.useInChat) } icon: { Self.bee } }
    }
}

/// One matter on the overview: what is open and whose, what comes next, and what is overdue —
/// each overdue line a door to that very task.
struct PhoneMatterCard: View {
    let matter: Matter
    let open: (PersistentIdentifier?) -> Void

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        // Prepared once per change, not worked out by every card each time it draws.
        let summary = StoredChanges.shared.summary(matter)
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: Self.line(mine: summary.mine, ours: summary.ours, waiting: summary.waiting))
            HStack(spacing: 10) {
                MatterIconTile(matter: matter, size: 38)
                Text(matter.name).font(Theme.phoneCardTitleFont).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            // What new mail changes, first: the brief's news, until it is seen.
            if let news = summary.news { NewsLine(text: news).font(.subheadline) }
            if let next = summary.next {
                Text("Next, on \(Dates.short(next.day)): \(next.what)").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            let overdue = summary.overdue
            ForEach(overdue.prefix(3), id: \.todo) { todo in
                Button { open(todo.todo) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.circle").font(.footnote)
                        Text("Overdue since \(Dates.short(todo.due)): \(todo.text)").lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.warning)
                }
                .buttonStyle(.plain)
            }
            // A way to the rest, as on the Mac: the matter opens at the first of them.
            if overdue.count > 3 {
                Button { open(overdue[3].todo) } label: {
                    Text("… and \(overdue.count - 3) more overdue").font(.caption).foregroundStyle(Theme.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .journalRows()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onTapGesture { open(nil) }
        .accessibilityAddTraits(.isButton)
    }

    static func line(mine: Int, ours: Int, waiting: Int) -> String {
        var parts: [String] = []
        if mine > 0 { parts.append("\(mine) for you") }
        if ours > 0 { parts.append("\(ours) together") }
        if waiting > 0 { parts.append("waiting for \(waiting)") }
        return parts.isEmpty ? "Nothing open." : parts.joined(separator: " · ")
    }
}

/// The matters that have something going on, late ones first, then by their next day — as on the Mac.
@MainActor func activeMatters(_ matters: [Matter]) -> [Matter] {
    // From the prepared overview: worked out once per change to the store, however often asked.
    OverviewPages.matters(StoredChanges.shared.overview(matters).active, among: matters)
}

/// What is worked out from all the matters — which are going on, their order — is worked out once
/// for each drawing of the screen, however many views ask: on the iPad the sidebar, the overview and
/// a matter's menus each asked, and each for itself; opening one matter worked out the order of all
/// of them thirty times. Kept only until the main queue is next free, so nothing shown is ever older
/// than the drawing it was worked out in.
@MainActor
enum Once {
    private static var kept: [String: Any] = [:]
    private static var clears = false

    static func worked<Value>(_ name: String, for matters: [Matter], _ work: () -> Value) -> Value {
        var hasher = Hasher()
        hasher.combine(name)
        for matter in matters { hasher.combine(matter.persistentModelID) }
        let key = "\(name) \(hasher.finalize())"
        if let value = kept[key] as? Value { return value }
        let value = work()
        kept[key] = value
        if !clears {
            clears = true
            DispatchQueue.main.async { kept.removeAll(); clears = false }
        }
        return value
    }
}

/// A shake, the three-finger swipe and ⌘Z ask "whoever has the keys" what there is to undo — and
/// in Causabee nobody had them unless a field was being typed in, so a deleted task could not be
/// shaken back although its Undo was written down. This takes the keys whenever no field has
/// them: nothing is seen of it, and a field that is tapped takes them over as before.
struct KeepsUndoAtHand: UIViewRepresentable {
    func makeUIView(context: Context) -> Holder { Holder() }
    func updateUIView(_ view: Holder, context: Context) {}

    final class Holder: UIView {
        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            let center = NotificationCenter.default
            for name in [UIApplication.didBecomeActiveNotification, UIResponder.keyboardDidHideNotification,
                         UITextField.textDidEndEditingNotification, UITextView.textDidEndEditingNotification] {
                center.addObserver(self, selector: #selector(take), name: name, object: nil)
            }
            take()
        }

        /// A moment later: what gave the keys up has finished doing so, and a field that takes them
        /// next has them already.
        @objc private func take() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.window != nil, !self.isFirstResponder, !Self.someoneTypes else { return }
                self.becomeFirstResponder()
            }
        }

        /// A field or a text view has the keys: they are not taken from it.
        private static var someoneTypes: Bool {
            Finder.found = nil
            UIApplication.shared.sendAction(#selector(UIResponder.causabeeSaysItHasTheKeys), to: nil, from: nil, for: nil)
            return Finder.found is UITextInput
        }
    }

    fileprivate enum Finder { nonisolated(unsafe) static weak var found: UIResponder? }
}

private extension UIResponder {
    /// Sent to nobody in particular, it arrives at whoever has the keys.
    @objc func causabeeSaysItHasTheKeys() { KeepsUndoAtHand.Finder.found = self }
}

/// Files or a folder being brought into a matter: the bee, how far it is and which file, and a
/// way to stop — then what it came to. Small, over the page: the page behind it is still the matter.
struct FilesComing: View {
    @MainActor
    @Observable
    final class State {
        var shows = false
        var done = 0
        var total = 0
        var name = ""
        /// What it came to, once it is done: "12 files added · 3 already here".
        var said: String?
        init(shows: Bool = false) { self.shows = shows }
    }

    let state: State
    let stop: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            if let said = state.said {
                Image(systemName: "checkmark.circle").font(.title2).foregroundStyle(Theme.done)
                Text(said).font(.headline).multilineTextAlignment(.center)
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.ink)
            } else {
                BeeLoader(size: 22)
                Text(state.total == 0 ? "Looking at what was picked …" : "Bringing in \(state.done) of \(state.total) …").font(.headline)
                // One line, whatever the name: the sheet does not change its height from file to file.
                Text(state.total == 0 ? "A file in iCloud Drive is brought down first." : state.name)
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Button("Stop", role: .cancel, action: stop).buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("files.coming")
    }
}
