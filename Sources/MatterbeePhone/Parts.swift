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

/// The filled button and the grey one beside it: "Write message", "Done", "Show".
struct PhoneButtonStyle: ButtonStyle {
    var filled = false
    var wide = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: wide ? .infinity : nil)
            .foregroundStyle(filled ? Theme.onInk : isEnabled ? Color.primary : Color.secondary)
            .background(filled ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Color.secondary.opacity(0.12)), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : isEnabled ? 1 : 0.6)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PhoneButtonStyle {
    static var phone: PhoneButtonStyle { PhoneButtonStyle() }
    static var phoneFilled: PhoneButtonStyle { PhoneButtonStyle(filled: true) }
    static func phone(filled: Bool = false, wide: Bool) -> PhoneButtonStyle { PhoneButtonStyle(filled: filled, wide: wide) }
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
struct AssistantButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Matterbee's own bee, black on its yellow as the app icon has it — not a speech bubble.
            BeeMark(size: 24, livesNowAndThen: true)
                .foregroundStyle(.black)
                .frame(width: 60, height: 60)
                .background(Theme.bee, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Assistant")
        .padding(.trailing, 16).padding(.bottom, 8)
    }
}

/// One matter on the overview: what is open and whose, what comes next, and what is overdue —
/// each overdue line a door to that very task.
struct PhoneMatterCard: View {
    let matter: Matter
    let open: (PersistentIdentifier?) -> Void

    var body: some View {
        let status = MatterStatus(matter)
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: Self.line(mine: status.open(.me).count, ours: status.open(.we).count, waiting: status.open(.other).count))
            Text(matter.name).font(Theme.phoneCardTitleFont).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
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
