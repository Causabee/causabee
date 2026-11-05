import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// What can be added to a matter over the assistant's field, as on the iPhone and the iPad: a click
/// puts its card where the field was — "Task", "Note", "Link", "Detail", "Contact" — and what is typed
/// in it is that. Folded, only the chevron is left; it stays as it was left.
struct MacAddChips: View {
    let pick: (AssistantAdd) -> Void
    @AppStorage("addChipsOpen") private var open = true

    private static let chips: [(title: String, symbol: String, add: AssistantAdd)] = [
        ("Task", "checklist", .task), ("Note", "note.text", .note), ("Link", "link", .link),
        ("Detail", "info.circle", .detail), ("Contact", "person.badge.plus", .contact),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Over the chips, so that they go in under it.
                toggle.zIndex(1)
                if open {
                    // Fanned out from the chevron one after another, and folded back the last first.
                    ForEach(Array(Self.chips.enumerated()), id: \.offset) { index, item in
                        chip(item.title, item.symbol, item.add).transition(fan(index))
                    }
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    /// Each chip comes from the left, small and faint, a moment after the one before it; going, it
    /// only shrinks where it stands.
    private func fan(_ index: Int) -> AnyTransition {
        let step = 0.035, last = Self.chips.count - 1
        let shrink = AnyTransition.scale(scale: 0.6, anchor: .leading).combined(with: .opacity)
        return .asymmetric(
            insertion: AnyTransition.offset(x: -18).combined(with: shrink)
                .animation(.spring(response: 0.32, dampingFraction: 0.78).delay(Double(index) * step)),
            removal: shrink.animation(.easeIn(duration: 0.16).delay(Double(last - index) * step * 0.6)))
    }

    /// A chevron, as a drawer has: › while the chips are in, ‹ while they are out.
    private var toggle: some View {
        Button { withAnimation(.snappy) { open.toggle() } } label: {
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .rotationEffect(.degrees(open ? 180 : 0))
                .frame(width: 26, height: 26)
                .background(Theme.box, in: Circle())
                .overlay(Circle().stroke(Theme.line, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(open ? "Fold away what can be added" : "Add a task, a note, a link, a detail or a contact")
        .accessibilityLabel(open ? "Hide Add" : "Add")
        .accessibilityIdentifier("add.toggle")
    }

    private func chip(_ title: String, _ symbol: String, _ add: AssistantAdd) -> some View {
        Button { pick(add) } label: {
            Label(title, systemImage: symbol).font(.callout)
                .padding(.vertical, 4).padding(.leading, 8).padding(.trailing, 10)
                .background(Theme.box, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(add.hint)
        .accessibilityIdentifier("add." + title.lowercased())
    }
}

/// A new task, note, link, detail or contact, typed in its own card where the field was: what it
/// is, small, its fields, what becomes of what is typed, and Add. × puts it away. Nothing in it goes
/// to an AI but a task's or a note's words with Pro — as on the iPhone.
struct MacAddCard: View {
    let add: AssistantAdd
    @Binding var text: String
    @Binding var second: String
    let take: () -> Void
    let close: () -> Void
    @FocusState private var onFirst: Bool
    @FocusState private var onSecond: Bool

    private var empty: Bool { !add.isComplete(text, second) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(add.title).font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Put it away (esc)")
                .accessibilityLabel("Put it away")
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField(add.fields.first, text: $text, axis: add.fields.second == nil ? .vertical : .horizontal)
                    .textFieldStyle(.plain)
                    .font(add == .note ? .body : .headline)
                    .lineLimit(1...6)
                    .focused($onFirst)
                    // Return goes on to the second field where there is one, else adds; ⇧↩ is a new line.
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                            if add.fields.second == nil { text += "\n" }
                        } else if add.fields.second != nil {
                            onSecond = true
                        } else if !empty {
                            take()
                        }
                        return .handled
                    }
                    .accessibilityIdentifier("add.text")
                    .padding(.horizontal, 12).padding(.vertical, 10)
                if let label = add.fields.second {
                    Divider().padding(.leading, 12)
                    TextField(label, text: $second)
                        .textFieldStyle(.plain)
                        .focused($onSecond)
                        .onSubmit { if !empty { take() } }
                        .accessibilityIdentifier("add.second")
                        .padding(.horizontal, 12).padding(.vertical, 10)
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 8)
            Text(add.hint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8).padding(.leading, 4)
            HStack {
                Spacer(minLength: 0)
                Button("Add", action: take).inkButton().disabled(empty)
                    .accessibilityIdentifier("add.take")
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
        .onAppear { DispatchQueue.main.async { onFirst = true } }
    }
}

/// "Attach …" under a draft: the matter's files, newest first, a tick on each one going along — as
/// on the iPhone. What the draft names is ticked already; a click takes it away too.
struct AttachList: View {
    let matter: Matter
    /// The files the draft takes along by itself: named in it, or chosen by the assistant.
    let named: Set<PersistentIdentifier>
    @Binding var chosen: [PersistentIdentifier]
    @Binding var leftOut: Set<PersistentIdentifier>
    @State private var query = ""

    private var files: [MatterCore.Document] {
        let words = query.trimmingCharacters(in: .whitespaces).lowercased()
        return (matter.documents ?? [])
            .filter { !$0.isHidden && (words.isEmpty || $0.shownName.lowercased().contains(words)) }
            .sorted { ($0.source.date ?? .distantPast) > ($1.source.date ?? .distantPast) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attach to the mail").font(.headline)
            TextField("Search this matter's files", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if files.isEmpty {
                        Text(query.isEmpty ? "This matter has no files yet." : "No file is called that.")
                            .foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(files) { row($0) }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(14)
        .frame(width: 360)
    }

    private func row(_ document: MatterCore.Document) -> some View {
        let id = document.persistentModelID
        let isNamed = named.contains(id)
        let on = isNamed ? !leftOut.contains(id) : chosen.contains(id)
        return Button {
            withAnimation {
                if isNamed {
                    if leftOut.contains(id) { leftOut.remove(id) } else { leftOut.insert(id) }
                } else if let at = chosen.firstIndex(of: id) { chosen.remove(at: at) } else { chosen.append(id) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.primary : Color.secondary).frame(width: 18)
                Image(systemName: document.contentType.contains("pdf") || document.name.lowercased().hasSuffix(".pdf") ? "doc.richtext" : "doc")
                    .foregroundStyle(.secondary).frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(document.shownName).lineLimit(2)
                    if isNamed {
                        Text(on ? "Named in the draft" : "Named in the draft · left out").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let date = document.source.date { Text(Dates.short(date)).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.vertical, 5).padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("attach." + document.shownName)
    }
}

/// While Pro is off, on top of the chat: Causabee Pro in one line with Start Pro — the plans first
/// when it is not bought, else asked once and turned on. As on the iPhone and the iPad.
struct MacProOffer: View {
    @AppStorage(AutoMode.key) private var auto = false
    @State private var asks = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Causabee Pro").font(.callout.weight(.semibold))
                Text("Reads your mail, fills the cards from it, answers.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("Start Pro") { start() }.inkButton().fixedSize()
                .accessibilityIdentifier("pro.start")
        }
        .padding(.vertical, 10).padding(.leading, 12).padding(.trailing, 10)
        .background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 12))
        .asksBeforeAuto($asks) { withAnimation(.easeInOut(duration: 0.2)) { auto = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.line")
    }

    private func start() {
        // Without Pro bought: the plans first.
        guard Store.shared.mayTurnOnPro() else { return }
        if AutoMode.asksFirst { asks = true } else { withAnimation(.easeInOut(duration: 0.2)) { auto = true } }
    }
}
