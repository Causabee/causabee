import MatterCore
import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Find on a matter's page, as ⌘F finds in a browser: every row that has the words is marked,
/// the current one strongly, and ↩ / ⇧↩ go from one to the next. The Mac and the iPhone alike,
/// each with a field of its own.
@MainActor
@Observable
final class PageFind {
    var query = ""
    /// The rows that have the words, top to bottom, as the page reports them.
    var matches: [PageFind.ID] = []
    var index = 0
    /// A row jumped to — from an answer's sources, from an overdue line: marked for a moment.
    var shown: PersistentIdentifier?

    enum ID: Hashable, Sendable {
        case model(PersistentIdentifier)
        case section(String)
    }

    var isActive: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var current: ID? { matches.indices.contains(index) ? matches[index] : nil }

    func has(_ texts: [String?]) -> Bool {
        let words = query.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return false }
        return texts.contains { $0?.range(of: words, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    func next() { if !matches.isEmpty { index = (index + 1) % matches.count } }
    func previous() { if !matches.isEmpty { index = (index - 1 + matches.count) % matches.count } }
}

/// Which rows have the words, in the order they are drawn.
struct PageFindMatches: PreferenceKey {
    static let defaultValue: [PageFind.ID] = []
    static func reduce(value: inout [PageFind.ID], nextValue: () -> [PageFind.ID]) { value += nextValue() }
}

extension View {
    /// A row the page search looks into: marked when it has the words, and a place to scroll to.
    func findable(_ id: PageFind.ID, _ texts: String?...) -> some View { modifier(Findable(id: id, texts: texts)) }
}

private struct Findable: ViewModifier {
    let id: PageFind.ID
    let texts: [String?]
    @Environment(PageFind.self) private var find

    func body(content: Content) -> some View {
        let hit = find.has(texts)
        let current = hit && find.current == id
        let shown = find.shown.map { id == .model($0) } ?? false
        content
            .background(shown ? Theme.mark : hit ? Theme.mark.opacity(current ? 1 : 0.45) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay { if current { RoundedRectangle(cornerRadius: 6).stroke(Theme.gold, lineWidth: 1.5) } }
            .preference(key: PageFindMatches.self, value: hit ? [id] : [])
            .modifier(ScrollTarget(id: id))
    }
}

private struct ScrollTarget: ViewModifier {
    let id: PageFind.ID
    func body(content: Content) -> some View {
        switch id {
        case .model(let model): content.id(model)
        case .section(let name): content.id(name)
        }
    }
}

extension ScrollViewProxy {
    func scrollTo(_ id: PageFind.ID, anchor: UnitPoint) {
        switch id {
        case .model(let model): scrollTo(model, anchor: anchor)
        case .section(let name): scrollTo(name, anchor: anchor)
        }
    }
}

#if os(macOS)
/// The search of a page: a magnifier that opens into a field — the words, how many rows have
/// them, and the way between them — and closes again once it is empty and left. It is one
/// view throughout, never swapped: opening, its grey widens out of the magnifier, and the words
/// and the cursor fade in once it has landed; closing, the words go first and the grey narrows
/// back into the magnifier.
struct PageFindField: View {
    @Bindable var find: PageFind
    @FocusState private var focused: Bool
    /// The grey is out: the field's width.
    @State private var open = false
    /// The words, the cursor and ✕: in once the grey has landed.
    @State private var shown = false

    private static let move = Animation.easeOut(duration: 0.18)

    var body: some View {
        HStack(spacing: open ? 6 : 0) {
            Button(action: start) { Image(systemName: "magnifyingglass") }
                .buttonStyle(.rowIcon)
                .help("Find in this matter (⌘F)")
            TextField("Find in matter", text: $find.query)
                .textFieldStyle(.plain)
                .focused($focused)
                .frame(width: open ? 150 : 0)
                .opacity(shown ? 1 : 0)
                .disabled(!open)
                .onKeyPress(.return, phases: .down) { press in
                    press.modifiers.contains(.shift) ? find.previous() : find.next()
                    return .handled
                }
                .onExitCommand { close() }
            if shown, find.isActive {
                Text(find.matches.isEmpty ? "none" : "\(find.index + 1) of \(find.matches.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
                Button(action: find.previous) { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless).help("Previous (⇧↩)").disabled(find.matches.isEmpty)
                Button(action: find.next) { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless).help("Next (↩)").disabled(find.matches.isEmpty)
            }
            Button(action: close) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless).foregroundStyle(.secondary).help("Close (esc)")
                .frame(width: open ? 16 : 0)
                .opacity(shown ? 1 : 0)
                .disabled(!open)
        }
        .padding(.trailing, open ? 6 : 0)
        .frame(height: 24)
        .background(Color.secondary.opacity(open ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onChange(of: focused) { if !focused, !find.isActive, open { close() } }
        .onAppear { if find.isActive { open = true; shown = true } }
        .background {
            Button("", action: start).keyboardShortcut("f", modifiers: .command).hidden()
        }
    }

    private func start() {
        guard !open else { focused = true; return }
        withAnimation(Self.move) { open = true } completion: {
            withAnimation(.easeIn(duration: 0.1)) { shown = true }
            focused = true
        }
    }

    private func close() {
        find.query = ""
        focused = false
        guard open else { return }
        shown = false
        withAnimation(Self.move) { open = false }
    }
}
#endif

/// "Notes", a part of a matter's page: thoughts written down as they come, each a small block with
/// its day, the newest on top. The field on top takes the next one.
struct NotesPart: View {
    let matter: Matter
    /// Set from outside — "Write Note" in the menu — to put the cursor into the field.
    @Binding var writing: Bool
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @State private var editing: PersistentIdentifier?
    @State private var editingEarlier = false
    @State private var edited = ""
    @FocusState private var focused: Bool
    @State private var voice = VoiceInput()

    #if os(iOS)
    private let radius: CGFloat = 12, inset: CGFloat = 16
    #else
    private let radius: CGFloat = 10, inset: CGFloat = 14
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
              if voice.phase == .listening {
                ListeningBar(voice: voice)
              } else {
                TextField(voice.phase == .writing ? "Writing it down …" : "A thought, what was agreed, what to remember …", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .frame(minHeight: 34)
                    .focused($focused)
                    #if os(macOS)
                    .onSubmit(add)
                    #endif
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Add", action: add).buttonStyle(.borderedProminent).controlSize(.small).padding(.bottom, 6)
                }
                MicButton(voice: voice, text: $draft)
              }
            }
            .padding(.leading, inset).padding(.trailing, 6).padding(.vertical, 5)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
            if voice.asksModel { SpeechModelCard(voice: voice) }
            if let problem = voice.problem { Text(problem).font(.caption).foregroundStyle(Theme.warning).padding(.horizontal, 4) }
            Text("The assistant reads your notes too — names in them are pseudonymised first.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.bottom, 4)

            ForEach(matter.sortedNotes) { note in
                block(Self.label(note.createdAt) + (note.fromAssistant ? " · from the assistant" : ""), note.text, isEditing: editing == note.persistentModelID,
                      edit: { edited = note.text; editing = note.persistentModelID; editingEarlier = false },
                      save: { text in if text.isEmpty { context.delete(note) } else { note.text = text } },
                      delete: { context.delete(note) })
                    .findable(.model(note.persistentModelID), note.text)
            }
            if let earlier = matter.earlierNote {
                block("Earlier", earlier, isEditing: editingEarlier,
                      edit: { edited = earlier; editingEarlier = true; editing = nil },
                      save: { text in matter.notes = text.isEmpty ? nil : text },
                      delete: { matter.notes = nil })
                    .findable(.section("notes"), earlier)
            }
        }
        .onChange(of: writing) { if writing { focused = true; writing = false } }
        .onAppear { if writing { focused = true; writing = false } }
    }

    /// One note: its day, its words, and what can be done with it. Being put right, it is a field.
    @ViewBuilder
    private func block(_ day: String, _ text: String, isEditing: Bool, edit: @escaping () -> Void,
                       save: @escaping (String) -> Void, delete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !isEditing {
                    Menu {
                        Button("Edit", systemImage: "pencil", action: edit)
                        Button("Copy", systemImage: "doc.on.doc") { Self.copy(text) }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 28, height: 18).contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .tint(Color.secondary)
                    .accessibilityLabel("More")
                }
            }
            if isEditing {
                TextField("Note", text: $edited, axis: .vertical).textFieldStyle(.plain).lineLimit(1...20)
                HStack {
                    Spacer()
                    Button("Cancel") { editing = nil; editingEarlier = false }.controlSize(.small)
                    Button("Save") {
                        withAnimation { save(edited.trimmingCharacters(in: .whitespacesAndNewlines)); try? context.save() }
                        editing = nil; editingEarlier = false
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
            } else {
                Text(Self.linked(text)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, inset).padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line))
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: edit)
            Button("Copy", systemImage: "doc.on.doc") { Self.copy(text) }
            Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = MatterNote(text: text)
        context.insert(note)
        note.matter = matter
        try? context.save()
        withAnimation { draft = "" }
    }

    /// An answer of the assistant's, kept as a note of the matter it was about.
    static func keep(_ answer: String, in matter: Matter, context: ModelContext) {
        let note = MatterNote(text: answer, fromAssistant: true)
        context.insert(note)
        note.matter = matter
        try? context.save()
    }

    /// "Today, 14:05", "Yesterday", or the day.
    static func label(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today, " + date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Dates.short(date)
    }

    /// Web addresses in a note can be clicked.
    private static func linked(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return result }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url, let range = Range(match.range, in: text),
                  let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].link = url
        }
        return result
    }

    private static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
