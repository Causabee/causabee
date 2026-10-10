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
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
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

/// The yellow round button in the corner, with the bee on it: the assistant, over whatever is open.
/// Held, it offers what the assistant's plus does — straight to a task, a note, a scan — without
/// going through the assistant first.
struct AssistantButton: View {
    var matter: Matter? = nil
    let action: () -> Void
    @Environment(Navigation.self) private var navigation
    @State private var picksPhoto = false
    @State private var picksFile = false

    var body: some View {
        // Over the bee, Auto: how the assistant works is turned on and off where the assistant is.
        VStack(spacing: 10) {
            // On the iPad Auto is in the sidebar's capsule, top left.
            if !navigation.isPad { PhoneAutoButton() }
            bee
        }
        .padding(.trailing, 16).padding(.bottom, 8)
    }

    private var bee: some View {
        Menu {
            // The button is yellow; what its menu lists is not: yellow signs on the menu's white
            // could hardly be read.
            PlusItems(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
                .menuSigns()
        } label: {
            // Causabee's own bee, black on its yellow as the app icon has it — not a speech bubble.
            BeeMark(size: 24, livesNowAndThen: true)
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
        } primaryAction: {
            action()
        }
        .menuIndicator(.hidden)
        // The system's own glass button, in the bee's yellow and round: alive under the finger, and
        // the held menu grows out of it and goes back into it. Glass of our own on the menu or on
        // its label stood bare, or black, for a moment as the menu closed.
        .menuStyle(.button)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(Theme.bee)
        // Held: a small knock in the hand as its menu comes, as the system's own held things give.
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in Haptics.held() })
        .accessibilityLabel("Ask Causabee")
        .accessibilityHint("Hold to add to a matter")
        .bringsIn(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
    }
}

/// Auto on and off, small, over the bee — the same switch as in Settings › New mail and the bolt
/// on the Mac. On: the black bolt on the bee's yellow. What Auto does is asked once, before it is
/// first turned on (AutoQuestion).
struct PhoneAutoButton: View {
    @AppStorage(AutoMode.key) private var auto = false
    @Environment(\.modelContext) private var context
    @State private var asks = false

    var body: some View {
        Button {
            // The first time it is turned on, what it does is said and asked — before anything is
            // read, not beside the bolt once it already is.
            if AutoMode.asksFirst { asks = true; return }
            auto.toggle()
            Haptics.tap()
            if auto { PhoneMailCheck.shared.autoTurnedOn(context: context) }
        } label: {
            Image(systemName: auto ? "bolt.fill" : "bolt").font(.system(size: 15, weight: .medium))
                .foregroundStyle(auto ? Color.black : Color.secondary)
                .frame(width: 36, height: 36)
                // Glass, as the bee under it: clear while Auto is off, the bee's yellow while it is on.
                .onGlass(Circle(), tint: auto ? Theme.bee.opacity(0.82) : nil)
                // A finger's room around the small disc.
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Auto")
        .accessibilityValue(auto ? "On" : "Off")
        .accessibilityHint("New mail and files are read at once, or only when you say so")
        .accessibilityIdentifier("auto.toggle")
        .asksBeforeAuto($asks) {
            auto = true
            Haptics.tap()
            PhoneMailCheck.shared.autoTurnedOn(context: context)
        }
    }
}

/// "Ask Causabee" in a row's menu, with the bee — the same mark as the yellow button. A menu only
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
        Button(action: action) { Label { Text("Ask Causabee") } icon: { Self.bee } }
    }
}

/// One matter on the overview: what is open and whose, what comes next, and what is overdue —
/// each overdue line a door to that very task.
struct PhoneMatterCard: View {
    let matter: Matter
    let open: (PersistentIdentifier?) -> Void

    var body: some View {
        // What came from another device shows at once: an arriving change redraws this.
        let _ = StoredChanges.shared.count
        let status = MatterStatus(matter)
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: Self.line(mine: status.open(.me).count, ours: status.open(.we).count, waiting: status.open(.other).count))
            HStack(spacing: 10) {
                MatterIconTile(matter: matter, size: 38)
                Text(matter.name).font(Theme.phoneCardTitleFont).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            if let next = status.next {
                Text("Next, on \(Dates.short(next.day)): \(next.what)").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            let overdue = status.overdue.sorted { ($0.due ?? "") < ($1.due ?? "") }
            ForEach(overdue.prefix(3)) { todo in
                Button { open(todo.persistentModelID) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.circle").font(.footnote)
                        Text("Overdue since \(todo.due.map(Dates.short) ?? ""): \(todo.text)").lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.warning)
                }
                .buttonStyle(.plain)
            }
            if overdue.count > 3 {
                Text("… and \(overdue.count - 3) more overdue").font(.caption).foregroundStyle(Theme.warning)
            }
        }
        .padding(16)
        .phoneCard()
        .contentShape(RoundedRectangle(cornerRadius: 12))
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
    Once.worked("active", for: matters) { workOutActiveMatters(matters) }
}

private func workOutActiveMatters(_ matters: [Matter]) -> [Matter] {
    return matters.compactMap { matter -> (matter: Matter, late: Bool, next: String)? in
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
