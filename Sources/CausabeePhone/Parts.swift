import MatterCore
import SwiftData
import SwiftUI

// The iPhone's parts, as Figma's "iPhone parts" draws them (`iOS/…`).

extension Theme {
    /// The overview's and a matter's name on top of the page (Figma "iOS/Large Title Serif").
    static let phoneTitleFont = Font.custom("Source Serif 4", size: 34, relativeTo: .largeTitle)
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
    @State private var picksPhoto = false
    @State private var picksFile = false

    var body: some View {
        // Over the bee, Auto: how the assistant works is turned on and off where the assistant is.
        VStack(spacing: 10) {
            PhoneAutoButton()
            bee
        }
        .padding(.trailing, 16).padding(.bottom, 8)
    }

    private var bee: some View {
        Menu {
            PlusItems(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
        } label: {
            // Causabee's own bee, black on its yellow as the app icon has it — not a speech bubble.
            BeeMark(size: 24, livesNowAndThen: true)
                .foregroundStyle(.black)
                .frame(width: 60, height: 60)
                .background(Theme.bee, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        } primaryAction: {
            action()
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        // Held: a small knock in the hand as its menu comes, as the system's own held things give.
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in Haptics.held() })
        .accessibilityLabel("Ask Causabee")
        .accessibilityHint("Hold to add to a matter")
        .bringsIn(matter: matter, picksPhoto: $picksPhoto, picksFile: $picksFile)
    }
}

/// Auto on and off, small, over the bee — the same switch as in Settings › New mail and the bolt
/// on the Mac. On: the black bolt on the bee's yellow. The first few times it says what changed,
/// beside it, since a bolt alone does not.
struct PhoneAutoButton: View {
    @AppStorage(AutoMode.key) private var auto = false
    @AppStorage("auto.explained") private var explained = 0
    @Environment(\.modelContext) private var context
    @State private var says: String?

    var body: some View {
        Button {
            auto.toggle()
            Haptics.tap()
            if auto { PhoneMailCheck.shared.autoTurnedOn(context: context) }
            guard explained < 4 else { return }
            explained += 1
            let words = auto ? "Auto on: mail and files are read at once, next steps and summaries kept up to date" : "Auto off: mail and files wait for “Sort in”"
            withAnimation(.easeOut(duration: 0.2)) { says = words }
            Task {
                try? await Task.sleep(for: .seconds(2.8))
                if says == words { withAnimation(.easeIn(duration: 0.25)) { says = nil } }
            }
        } label: {
            Image(systemName: auto ? "bolt.fill" : "bolt").font(.system(size: 15, weight: .medium))
                .foregroundStyle(auto ? Color.black : Color.secondary)
                .frame(width: 36, height: 36)
                .background(auto ? AnyShapeStyle(Theme.bee) : AnyShapeStyle(.regularMaterial), in: Circle())
                .overlay(Circle().stroke(Theme.line).opacity(auto ? 0 : 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                // A finger's room around the small disc.
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Auto")
        .accessibilityValue(auto ? "On" : "Off")
        .accessibilityHint("New mail and files are read at once, or only when you say so")
        .accessibilityIdentifier("auto.toggle")
        .overlay(alignment: .trailing) {
            if let says {
                Text(says).font(.footnote.weight(.medium)).foregroundStyle(Theme.onInk)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.ink, in: Capsule())
                    .fixedSize()
                    .offset(x: -50)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
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
func activeMatters(_ matters: [Matter]) -> [Matter] {
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
