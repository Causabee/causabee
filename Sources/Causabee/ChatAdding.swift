import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// Over the assistant's field in a matter, on glass, as on the iPhone and the iPad: what is brought
/// in — read by Causabee, or only kept — as cards, and under them what can be added, a row of pills.
/// It comes out of the plus and goes back into it.
struct MacAddPanel: View {
    /// A screenshot, a mail or a PDF, for Causabee to read.
    let read: () -> Void
    /// Files or a folder, kept with the matter unread.
    let keep: () -> Void
    let pick: (AssistantAdd) -> Void

    private static let pills: [(title: String, symbol: String, add: AssistantAdd)] = [
        ("Task", "checklist", .task), ("Note", "note.text", .note), ("Link", "link", .link),
        ("Detail", "info.circle", .detail), ("Contact", "person.badge.plus", .contact),
    ]
    @State private var position = ScrollPosition(edge: .leading)
    @State private var offset: CGFloat = 0
    @State private var dragFrom: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                card("Screenshot, Mail or PDF", "doc.viewfinder", id: "read", help: "Causabee reads it, and offers its tasks and dates", action: read)
                card("Files or a Folder", "folder", id: "files", help: "Kept with the matter, unread", action: keep)
            }
            .padding(.horizontal, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.pills, id: \.title) { pill($0.title, $0.symbol, $0.add) }
                }
                .padding(.horizontal, 12)
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in offset = x }
            // Dragged with the mouse, as with a finger: a scroll view on the Mac moves only with the
            // trackpad or the wheel. A click still picks its pill.
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { drag in
                if dragFrom == nil { dragFrom = offset }
                position.scrollTo(x: max(0, (dragFrom ?? 0) - drag.translation.width))
            }.onEnded { _ in dragFrom = nil })
        }
        .padding(.vertical, 12)
        .glassBehind(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add.panel")
    }

    /// The icon over its name, in a card of its own.
    private func card(_ title: String, _ symbol: String, id: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.callout.weight(.medium)).multilineTextAlignment(.center)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityIdentifier("plus." + id)
    }

    private func pill(_ title: String, _ symbol: String, _ add: AssistantAdd) -> some View {
        Button { pick(add) } label: {
            Label(title, systemImage: symbol).font(.callout)
                .padding(.vertical, 5).padding(.leading, 9).padding(.trailing, 11)
                .background(Color.primary.opacity(0.06), in: Capsule())
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
                    // A task's words stand out; a note, an address, a label or a name are plain.
                    .font(add == .task ? .headline : .body)
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
