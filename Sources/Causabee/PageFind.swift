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
            Button(action: start) {
                Image(systemName: "magnifyingglass").foregroundStyle(open ? .secondary : .primary)
                    .frame(width: 30, height: 30).contentShape(Circle())
            }
                .buttonStyle(.plain)
                .help("Find in this matter (⌘F)")
            TextField("Find in matter", text: $find.query)
                .textFieldStyle(.plain)
                .focused($focused)
                .frame(width: open ? 170 : 0)
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
        .padding(.trailing, open ? 10 : 0)
        .frame(height: 30)
        .clipShape(Capsule())
        // A disc of glass that opens into a field of it, with the ring a field has while it is typed in.
        .onGlass(Capsule())
        .overlay { if open, focused { Capsule().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 3) } }
        .onChange(of: focused) { if !focused, !find.isActive, open { close() } }
        .onAppear { if find.isActive { open = true; shown = true } }
        // Edit → Find: ⌘F, ⌘G and ⇧⌘G.
        .onReceive(NotificationCenter.default.publisher(for: .find)) { _ in start() }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in find.next() }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in find.previous() }
        .focusedSceneValue(\.findHasMatches, find.isActive && !find.matches.isEmpty)
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
    @Environment(\.undoManager) private var undoManager
    @State private var draft = ""
    @State private var editing: PersistentIdentifier?
    @State private var editingEarlier = false
    @State private var edited = ""
    @FocusState private var focused: Bool
    @State private var voice = VoiceInput()
    @State private var cursor: TextSelection?

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
                TextField(voice.phase == .writing ? voice.writingWords : "A thought, what was agreed, what to remember …", text: $draft, selection: $cursor, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .frame(minHeight: 34)
                    .focused($focused)
                    .accessibilityIdentifier("note.field")
                    #if os(macOS)
                    .onSubmit(add)
                    #endif
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Add", action: add).filledButton().padding(.bottom, 4).accessibilityIdentifier("note.add")
                }
                MicButton(voice: voice, text: $draft, selection: $cursor) { focused = false }
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
                      delete: { context.deleteByHand([note], undo: undoManager, named: "Delete Note") })
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
                        ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }
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
                    Button("Cancel") { editing = nil; editingEarlier = false }.quietButton()
                    Button("Save") {
                        withAnimation { save(edited.trimmingCharacters(in: .whitespacesAndNewlines)); try? context.save() }
                        editing = nil; editingEarlier = false
                    }
                    .filledButton()
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
            ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }
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

    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: The vault — contacts and details put in by hand

/// "New contact": a person or a company the owner adds — an insurer, a doctor, an office — with a
/// role and how to reach them.
struct ContactEditor: View {
    let matter: Matter
    var added: (Party) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = ""
    @State private var address = ""
    @State private var phone = ""

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).accessibilityIdentifier("contact.name")
                    TextField("Role — insurer, doctor, office", text: $role)
                }
                Section {
                    TextField("Mail", text: $address).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("contact.mail")
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                } footer: {
                    Text("A contact you add stays in this matter. If mail from the same address comes in later, it is the same contact.")
                }
            }
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: add).disabled(!canAdd) }
            }
        }
        #else
        VStack(alignment: .leading, spacing: 10) {
            Text("New contact").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("contact.name")
            TextField("Role — insurer, doctor, office", text: $role).textFieldStyle(.roundedBorder)
            TextField("Mail", text: $address).textFieldStyle(.roundedBorder).accessibilityIdentifier("contact.mail")
            TextField("Phone", text: $phone).textFieldStyle(.roundedBorder)
            Text("A contact you add stays in this matter. If mail from the same address comes in later, it is the same contact.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.quietButton().keyboardShortcut(.cancelAction)
                Button("Add", action: add).filledButton().keyboardShortcut(.defaultAction).disabled(!canAdd)
            }
        }
        .padding(18)
        .frame(width: 340)
        #endif
    }

    private func add() {
        guard let party = matter.addContact(name: name, role: role, address: address, phone: phone, in: context) else { return }
        try? context.save()
        added(party)
        dismiss()
    }
}

/// "New detail", or one put right: what it is, its value, and whose it is.
struct DetailEditor: View {
    let matter: Matter
    var detail: MatterDetail? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var value = ""
    @State private var party: PersistentIdentifier?

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var whose: some View {
        Picker("Of", selection: $party) {
            Text("no one").tag(PersistentIdentifier?.none)
            ForEach(matter.parties.sorted { $0.name < $1.name }) { Text($0.name).tag(Optional($0.persistentModelID)) }
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
            NavigationStack {
                Form {
                    Section {
                        TextField("What — Versichertennummer, file number", text: $label).accessibilityIdentifier("detail.label")
                        TextField("Value", text: $value).autocorrectionDisabled().accessibilityIdentifier("detail.value")
                        if !matter.parties.isEmpty { whose }
                    } footer: {
                        Text("Kept on your devices. The assistant learns that it is here, never the value.")
                    }
                    if detail != nil {
                        Section { Button("Delete", role: .destructive, action: delete) }
                    }
                }
                .navigationTitle(detail == nil ? "New detail" : "Detail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(detail == nil ? "Add" : "Save", action: save).disabled(!canSave) }
                }
            }
            #else
            VStack(alignment: .leading, spacing: 10) {
                Text(detail == nil ? "New detail" : "Detail").font(.headline)
                TextField("What — Versichertennummer, file number", text: $label).textFieldStyle(.roundedBorder).accessibilityIdentifier("detail.label")
                TextField("Value", text: $value).textFieldStyle(.roundedBorder).accessibilityIdentifier("detail.value")
                if !matter.parties.isEmpty { whose }
                Text("Kept on your devices. The assistant learns that it is here, never the value.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    if detail != nil { Button("Delete", role: .destructive, action: delete) }
                    Spacer()
                    Button("Cancel") { dismiss() }.quietButton().keyboardShortcut(.cancelAction)
                    Button(detail == nil ? "Add" : "Save", action: save).filledButton().keyboardShortcut(.defaultAction).disabled(!canSave)
                }
            }
            .padding(18)
            .frame(width: 340)
            #endif
        }
        .onAppear {
            guard let detail else { return }
            label = detail.label; value = detail.value; party = detail.party?.persistentModelID
        }
    }

    private func save() {
        let whose = party.flatMap { id in matter.parties.first { $0.persistentModelID == id } }
        if let detail {
            detail.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
            detail.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            detail.party = whose
        } else {
            matter.addDetail(label: label, value: value, of: whose, in: context)
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let detail { context.deleteByHand([detail], undo: undoManager, named: "Delete Detail") }
        dismiss()
    }
}

/// "Details", on top of a matter's record: what to have at hand on the phone with them. A tap
/// copies one; it is put right or deleted from its menu.
struct DetailsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    let matter: Matter
    /// Shown even while there is none yet — when the record shows only the details.
    var showsEmpty = false
    @State private var adding = false
    @State private var editing: MatterDetail?
    @State private var copied: PersistentIdentifier?

    #if os(iOS)
    private let radius: CGFloat = 12
    #else
    private let radius: CGFloat = 10
    #endif

    var body: some View {
        let details = matter.sortedDetails
        if !details.isEmpty || showsEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Details", detail: details.isEmpty ? nil : "\(details.count)")
                    // On the iPhone the round plus adds a detail; the Mac has its own here.
                    #if os(macOS)
                    Button("Detail", systemImage: "plus") { adding = true }
                        .buttonStyle(.plain).font(.footnote.weight(.medium)).foregroundStyle(Theme.gold)
                        .accessibilityIdentifier("detail.add")
                    #endif
                }
                if details.isEmpty {
                    Text("A membership number, a file number, a ward and room: what you need on the phone with them.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.box, in: RoundedRectangle(cornerRadius: radius))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(details.enumerated()), id: \.element.persistentModelID) { index, detail in
                            if index > 0 { Divider().padding(.leading, 14) }
                            row(detail)
                        }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: radius))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line))
                }
            }
            .sheet(isPresented: $adding) { DetailEditor(matter: matter) }
            .sheet(item: $editing) { DetailEditor(matter: matter, detail: $0) }
        }
    }

    private func row(_ detail: MatterDetail) -> some View {
        Button { copy(detail) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.label + (detail.party.map { " · \($0.name)" } ?? "")).font(.caption).foregroundStyle(.secondary)
                    Text(detail.value).fontWeight(.medium).foregroundStyle(.primary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: copied == detail.persistentModelID ? "checkmark" : "doc.on.doc").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .findable(.model(detail.persistentModelID), detail.label, detail.value)
        .accessibilityLabel("\(detail.label): \(detail.value)").accessibilityHint("Copies it")
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { copy(detail) }
            Button("Copy with its label", systemImage: "doc.on.doc") { NotesPart.copy("\(detail.label): \(detail.value)") }
            ShareLink(item: "\(detail.label): \(detail.value)") { Label("Share", systemImage: "square.and.arrow.up") }
            // What one does with a number: say it to whom it belongs to.
            if let party = detail.party { ContactItems(party: party) }
            Button("Edit", systemImage: "pencil") { editing = detail }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { context.deleteByHand([detail], undo: undoManager, named: "Delete Detail") } }
        }
    }

    private func copy(_ detail: MatterDetail) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(detail.value, forType: .string)
        #else
        UIPasteboard.general.string = detail.value
        #endif
        copied = detail.persistentModelID
        Task { try? await Task.sleep(for: .seconds(1.5)); if copied == detail.persistentModelID { copied = nil } }
    }
}

/// Under a contact's name: the phone number, and "Write mail" and "Call" right on it.
struct ContactActions: View {
    let party: Party
    @Environment(\.openURL) private var openURL

    var body: some View {
        let address = party.address ?? CardActions.addresses(of: party).first?.address
        if let phone = party.phone, !phone.isEmpty {
            Text(phone).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
        if party.addedAt != nil || party.phone != nil {
            HStack(spacing: 8) {
                if let address, let url = URL(string: "mailto:" + address) {
                    Button { openURL(url) } label: { Label("Write mail", systemImage: "envelope") }
                }
                if let phone = party.phone, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                    Button { openURL(url) } label: { Label("Call", systemImage: "phone") }
                }
            }
            .buttonStyle(.bordered).controlSize(.small).tint(.primary)
            .padding(.top, 4)
        }
    }
}

/// In a contact's menu, after its mail addresses: what a phone number is for.
struct ContactItems: View {
    let party: Party
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let phone = party.phone, !phone.isEmpty {
            if let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                Button("Call \(party.name)", systemImage: "phone") { openURL(url) }
            }
            Button("Copy phone number", systemImage: "doc.on.doc") { NotesPart.copy(phone) }
        }
    }
}

/// In a link's menu: open it, copy its address, pass it on.
struct LinkItems: View {
    let link: WebLink
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = link.url {
            Button("Open", systemImage: "safari") { openURL(url) }
            Button("Copy address", systemImage: "doc.on.doc") { NotesPart.copy(link.address) }
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}
