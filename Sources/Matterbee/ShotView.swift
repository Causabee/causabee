import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// C5–C7 · a screenshot in the thread: what was read on the Mac, what was left out and why, and
/// only on "Einordnen" what it means — as a card to take into a matter, or not.
struct ShotView: View {
    let turn: Navigation.Turn
    let shot: Navigation.Shot
    let matters: [Matter]
    let classify: () -> Void
    /// The matter, a new matter's name, and which found things to take: by their place in the
    /// answer, as "t0", "a1", "d0".
    let take: (Matter?, String, Set<String>) -> Void
    let dismiss: () -> Void
    let open: (PersistentIdentifier) -> Void
    /// Reads the file again, after a dismissal: what was answered is in the record, and free.
    var bringBack: (() -> Void)? = nil
    @State private var showsChat = true
    @State private var showsSent = false
    @State private var choice: PersistentIdentifier?
    @State private var newName = ""
    @State private var chose = false
    /// What is left out: unchecked by the owner, or already in the matter when it was chosen.
    @State private var skipped: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if ScreenshotDoor.chatTypes.contains(shot.file.pathExtension.lowercased()), let image = NSImage(contentsOf: shot.file) {
                    Image(nsImage: image).resizable().scaledToFit().frame(width: 64, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
                        .onTapGesture { NSWorkspace.shared.open(shot.file) }
                        .help("Open the image")
                }
                if !ScreenshotDoor.chatTypes.contains(shot.file.pathExtension.lowercased()) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: shot.file.path)).resizable().frame(width: 48, height: 48)
                        .onTapGesture { NSWorkspace.shared.open(shot.file) }
                        .help("Open the file")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(kindLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(shot.file.lastPathComponent).lineLimit(1)
                    Text(shot.document != nil ? "Taken from the mail it is attached to. It stays there; here it is only a cached copy."
                         : shot.copied ? "Copied into Matterbee: it had no place of its own."
                                     : "Stays where it is: \(shot.file.deletingLastPathComponent().lastPathComponent). Matterbee only remembers the path.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            switch shot.stage {
            case .reading:
                progress("Reading on the Mac …")
            case .read(let look):
                read(look)
                buttons(primary: look.earlier == nil ? String(format: "Sort in · ≈ %.0f cents", (look.estimate * 100).rounded(.up)) : "Sort in · already read, costs nothing",
                        action: classify)
            case .sending(let look):
                read(look)
                progress("Sending, pseudonymised …")
            case .answered(let look, let judgement):
                read(look)
                answered(judgement)
            case .taken(let name, let id):
                HStack {
                    Label("Taken into “\(name)”", systemImage: "checkmark").foregroundStyle(Theme.done)
                    if let id { Button("open ›") { open(id) }.buttonStyle(.plain).foregroundStyle(.secondary) }
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warning).textSelection(.enabled)
            case .dismissed:
                HStack {
                    Text("Dismissed — nothing was taken into a matter.").font(.caption).foregroundStyle(.secondary)
                    if let bringBack, FileManager.default.fileExists(atPath: shot.file.path) {
                        Button("Bring back", action: bringBack).buttonStyle(.gold).font(.caption)
                            .help("Read it again. If it was sorted in before, that answer is used again and costs nothing.")
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        .padding(.top, 8)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) { BeeLoader(size: 13); Text(text).foregroundStyle(.secondary) }
    }

    private func buttons(primary: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button("Dismiss", action: dismiss)
            Button(primary, action: action).inkButton()
        }
    }

    // MARK: What was read

    private var kindLabel: String {
        switch shot.file.pathExtension.lowercased() {
        case "eml", "emlx": "Mail"
        case "pdf": "Document"
        default: "Screenshot"
        }
    }

    @ViewBuilder
    private func read(_ look: ScreenshotDoor.Look) -> some View {
        if look.kind == .chat { readChat(look) } else { readFile(look) }
    }

    /// A mail or a PDF: what it is, from whom or how many pages, what could not be read as text,
    /// and how it starts.
    @ViewBuilder
    private func readFile(_ look: ScreenshotDoor.Look) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(look.heading).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(look.byline).font(.caption).foregroundStyle(.secondary)
            ForEach(look.notes, id: \.self) { note in
                Label(note, systemImage: note.contains("nothing readable") ? "exclamationmark.triangle" : "text.viewfinder")
                    .font(.caption).foregroundStyle(note.contains("nothing readable") ? Theme.warning : .secondary)
            }
            DisclosureGroup(isExpanded: $showsChat) {
                Text(look.preview).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            } label: {
                Text("Start of the text").font(.caption.weight(.semibold))
            }
            sentDisclosure(look)
        }
    }

    private func sentDisclosure(_ look: ScreenshotDoor.Look) -> some View {
        DisclosureGroup(isExpanded: $showsSent) {
            ScrollView {
                Text(look.sent).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        } label: {
            Text("what would be sent, pseudonymised").font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func readChat(_ look: ScreenshotDoor.Look) -> some View {
        let chat = look.transcript
        VStack(alignment: .leading, spacing: 6) {
            Text(look.heading).font(.headline)
            if let subtitle = chat.subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            ForEach(chat.notes, id: \.self) { note in
                Label(note, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Theme.warning)
            }
            DisclosureGroup(isExpanded: $showsChat) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(chat.messages.enumerated()), id: \.offset) { index, message in
                        // A day marker where the day changes, as the chat itself shows it.
                        if let day = message.day, index == 0 || chat.messages[index - 1].day != day {
                            Text(day).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                        bubble(message)
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("\(chat.messages.count) messages read").font(.caption.weight(.semibold))
            }
            if !chat.leftOut.isEmpty {
                Text("Left out: " + chat.leftOut.map { "“\($0.text)” (\($0.why))" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            sentDisclosure(look)
        }
    }

    private func bubble(_ message: ChatTranscript.Message) -> some View {
        let mine = message.side == .mine
        return VStack(alignment: mine ? .trailing : .leading, spacing: 1) {
            if let speaker = message.speaker { Text(speaker).font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
            Text(message.text).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let time = message.time { Text(time).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(mine ? Theme.done.opacity(0.12) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .padding(mine ? .leading : .trailing, 40)
    }

    // MARK: What it means

    @ViewBuilder
    private func answered(_ judgement: Judgement) -> some View {
        // Taken in before: the matter it is in. Dropped while a matter was open: that one — the
        // owner put it there. Otherwise the one the model named, if it exists.
        let known = matters.first { ($0.entries ?? []).contains { $0.messageID == judgement.emailID } }
            ?? turn.matter.flatMap { id in matters.first { $0.persistentModelID == id } }
            ?? judgement.matter.flatMap { key in matters.first { $0.answers(to: key) } }
        VStack(alignment: .leading, spacing: 8) {
            Text(known == nil ? "New matter?" : "Belongs to a matter").font(.caption.weight(.semibold))
            Picker("Matter", selection: $choice) {
                Text("New matter").tag(PersistentIdentifier?.none)
                ForEach(matters) { matter in Text(matter.name).tag(Optional(matter.persistentModelID)) }
            }
            .labelsHidden()
            if choice == nil {
                TextField("Name of the new matter", text: $newName).textFieldStyle(.roundedBorder)
            }
            if !judgement.matterReason.isEmpty {
                Text(judgement.matterReason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            let target = choice.flatMap { id in matters.first { $0.persistentModelID == id } }
            if !judgement.todos.isEmpty {
                Text("Tasks · \(judgement.todos.count)").font(.caption.weight(.semibold))
                ForEach(Array(judgement.todos.enumerated()), id: \.offset) { index, todo in
                    pick("t\(index)", todo.text + (todo.due.map { " · by \(Dates.short($0))" } ?? "") + " · "
                         + (["me": "mine", "we": "ours", "other": "waiting for"][todo.owner.rawValue] ?? "unclear"),
                         already: target.flatMap { Duplicates.todo(todo.text, in: $0) }.map(\.text))
                }
            }
            if !judgement.appointments.isEmpty || !judgement.deadlines.isEmpty {
                Text("Appointments and deadlines · \(judgement.appointments.count + judgement.deadlines.count)").font(.caption.weight(.semibold))
                ForEach(Array(judgement.appointments.indices), id: \.self) { index in
                    let item = judgement.appointments[index]
                    pick("a\(index)", "\(Dates.short(item.date))\(item.time.map { " \($0)" } ?? "") \(item.what)",
                         already: target.flatMap { Duplicates.appointment(on: item.date, at: item.time, item.what, in: $0) }.map(\.what))
                }
                ForEach(Array(judgement.deadlines.indices).map { $0 + 10_000 }, id: \.self) { shifted in
                    let index = shifted - 10_000
                    let item = judgement.deadlines[index]
                    pick("d\(index)", "by \(Dates.short(item.date)) \(item.what)",
                         already: target.flatMap { Duplicates.deadline(on: item.date, item.what, in: $0) }.map(\.what))
                }
            }
            if let digest = judgement.digest, !digest.isEmpty {
                Text("What it says").font(.caption.weight(.semibold))
                Text(digest).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            let files = judgement.attachments.filter { !($0.contentType.hasPrefix("image/") && $0.byteCount < 30_000) }
            if !files.isEmpty {
                Text("Files · \(files.count) — kept with the matter").font(.caption.weight(.semibold))
                ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                    Label("\(file.filename) · \(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))", systemImage: "paperclip")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !judgement.parties.isEmpty {
                Text("People: " + judgement.parties.map { $0.name + ($0.role.isEmpty ? "" : " (\($0.role))") }.joined(separator: ", "))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            buttons(primary: "Take in") {
                let all = Set(judgement.todos.indices.map { "t\($0)" } + judgement.appointments.indices.map { "a\($0)" }
                              + judgement.deadlines.indices.map { "d\($0)" })
                take(target, newName, all.subtracting(skipped))
            }
        }
        .padding(12)
        .box()
        .onAppear {
            guard !chose else { return }
            chose = true
            choice = known?.persistentModelID
            newName = judgement.matterTitle ?? known?.name ?? (shotTitle ?? "")
            skipped = doubles(judgement, in: known)
        }
        // Another matter chosen: what is already in that one starts unchecked.
        .onChange(of: choice) { skipped = doubles(judgement, in: choice.flatMap { id in matters.first { $0.persistentModelID == id } }) }
    }

    private func doubles(_ judgement: Judgement, in matter: Matter?) -> Set<String> {
        guard let matter else { return [] }
        var out: Set<String> = []
        for (index, todo) in judgement.todos.enumerated() where Duplicates.todo(todo.text, in: matter) != nil { out.insert("t\(index)") }
        for (index, item) in judgement.appointments.enumerated() where Duplicates.appointment(on: item.date, at: item.time, item.what, in: matter) != nil {
            out.insert("a\(index)")
        }
        for (index, item) in judgement.deadlines.enumerated() where Duplicates.deadline(on: item.date, item.what, in: matter) != nil { out.insert("d\(index)") }
        return out
    }

    /// One found thing, with a box to leave it out, and what it doubles when the matter has it.
    private func pick(_ id: String, _ text: String, already: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(isOn: Binding(get: { !skipped.contains(id) }, set: { if $0 { skipped.remove(id) } else { skipped.insert(id) } })) {
                Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(skipped.contains(id) ? .secondary : .primary)
            }
            .toggleStyle(.checkbox)
            if let already {
                Text("already in the matter: \(already)").font(.caption).foregroundStyle(Theme.warning).padding(.leading, 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shotTitle: String? {
        if case .answered(let look, _) = shot.stage { return look.kind == .chat ? look.transcript.title : look.heading }
        return nil
    }
}
