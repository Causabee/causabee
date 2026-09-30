import SwiftData
import SwiftUI

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
        content
            .background(hit ? Theme.mark.opacity(current ? 1 : 0.45) : .clear, in: RoundedRectangle(cornerRadius: 6))
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
