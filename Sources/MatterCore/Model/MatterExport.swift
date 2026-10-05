import Foundation

/// A matter written out as one document — what is to do, the dates, the people, the details, the
/// notes, the links, the files and the history — so what Causabee has gathered can leave it at any
/// time. Made on the device from the store, nothing sent anywhere: the real names, as the owner
/// sees them. RTF, which Pages, Word and TextEdit all open.
public enum MatterExport {
    /// A heading and its lines; a line may carry a second, lighter one under it.
    public struct Section: Equatable {
        public var title: String
        public var lines: [Line]
    }
    public struct Line: Equatable {
        public var text: String
        public var detail: String?
        public init(_ text: String, _ detail: String? = nil) { self.text = text; self.detail = detail }
    }

    /// The file's name: the matter's, without what a file name cannot hold.
    @MainActor
    public static func fileName(for matter: Matter) -> String {
        let name = matter.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name.isEmpty ? "Matter" : name) + ".rtf"
    }

    /// Everything the matter holds, in the order of its page; a part with nothing in it is left out.
    @MainActor
    public static func sections(of matter: Matter) -> [Section] {
        let status = MatterStatus(matter)
        var sections: [Section] = []
        func add(_ title: String, _ lines: [Line]) { if !lines.isEmpty { sections.append(Section(title: title, lines: lines)) } }
        func when(_ day: String?, _ time: String?) -> String? { day.map { MatterStatus.short($0) + (time.map { " at \($0)" } ?? "") } }
        func joined(_ parts: [String?]) -> String? {
            let kept = parts.compactMap { $0 }.filter { !$0.isEmpty }
            return kept.isEmpty ? nil : kept.joined(separator: " · ")
        }
        func whose(_ todo: Todo) -> String {
            switch todo.owner { case .me: "Mine"; case .we: "Ours"; case .other: "Waiting for"; case .unknown: "Unclear" }
        }

        var top: [Line] = []
        if let summary = matter.summary, !summary.isEmpty { top.append(Line(summary)) }
        if !matter.isClosed, let next = matter.nextStep, !next.isEmpty { top.append(Line("Next: " + next, matter.nextStepWhy)) }
        add("Summary", top)

        let open = matter.openTodos.sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
        add("Tasks", open.map { todo in
            Line(todo.text, joined([whose(todo), when(todo.due, todo.dueTime).map { "by " + $0 },
                                    todo.waitsFor.map { "only after: " + $0.text }, todo.note]))
        })
        add("Done", status.done.map { Line($0.text, joined([whose($0), $0.doneAt.map { "done " + MatterStatus.short($0) }, $0.note])) })
        add("Good to know", matter.infos.map { Line($0.text, $0.note) })

        let appointments = (matter.appointments ?? []).sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
        add("Appointments", appointments.map { Line($0.what, joined([when($0.day, $0.time), $0.place])) })
        add("Deadlines", (matter.deadlines ?? []).sorted { $0.day < $1.day }.map { (deadline: Deadline) in Line(deadline.what, "by " + MatterStatus.short(deadline.day)) })
        add("Decisions", (matter.decisions ?? []).sorted { $0.decidedAt < $1.decidedAt }.map {
            Line($0.what, joined([MatterStatus.short($0.decidedAt), $0.why]))
        })

        add("People", status.memberships.compactMap { membership in
            guard let party = membership.party else { return nil }
            return Line(party.name, joined([membership.role, party.address, party.phone]))
        })
        add("Details", matter.sortedDetails.reversed().map { Line("\($0.label): \($0.value)", $0.party?.name) })

        var notes: [Line] = []
        if let earlier = matter.earlierNote { notes.append(Line(earlier)) }
        notes += matter.sortedNotes.reversed().filter { !$0.text.isEmpty }.map { Line($0.text, MatterStatus.short($0.createdAt)) }
        add("Notes", notes)

        add("Links", (matter.links ?? []).filter(\.isKept).sorted { $0.createdAt < $1.createdAt }.map { Line($0.shownName, $0.address) })
        add("Files", (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage }.sorted { ($0.source.date ?? .distantPast) < ($1.source.date ?? .distantPast) }.map {
            Line($0.shownName, joined([$0.source.date.map { MatterStatus.short($0) }, $0.says]))
        })
        add("History", status.mailEntries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }.map { entry in
            Line(joined([entry.date.map { MatterStatus.short($0) }, entry.title]) ?? entry.title, joined([entry.from, entry.digest]))
        })
        return sections
    }

    /// Writes the document into the matter's folder — iCloud Drive › Causabee › the matter, where its
    /// files are — in place of an earlier one; or, with no folder (the demo, iCloud Drive off and none
    /// chosen), into a temporary one, to be shown or shared from there.
    @MainActor
    public static func write(_ matter: Matter, into folder: URL?) throws -> URL {
        let data = rtf(for: matter)
        let files = FileManager.default
        let place = folder ?? files.temporaryDirectory.appendingPathComponent("causabee-export-" + UUID().uuidString.prefix(8), isDirectory: true)
        try files.createDirectory(at: place, withIntermediateDirectories: true)
        let target = place.appendingPathComponent(fileName(for: matter))
        var failure: NSError?
        var thrown: Error?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &failure) { url in
            do { try data.write(to: url, options: .atomic) } catch { thrown = error }
        }
        if let error = failure ?? thrown { throw error }
        return target
    }

    /// The document itself.
    @MainActor
    public static func rtf(for matter: Matter, on date: Date = Date()) -> Data {
        let status = MatterStatus(matter)
        var body = #"{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0\fswiss Helvetica;}}{\colortbl;\red110\green110\blue110;}\paperw11906\paperh16838\margl1417\margr1417\margt1417\margb1417"# + "\n"
        body += #"\pard\sa120\f0\b\fs40 "# + escaped(matter.name) + #"\b0\par"# + "\n"
        var under = ["From Causabee, " + MatterStatus.short(date)]
        if matter.isClosed { under.append("closed") }
        if let first = status.firstDate { under.append("since " + MatterStatus.short(first)) }
        body += #"\pard\sa360\fs20\cf1 "# + escaped(under.joined(separator: " · ")) + #"\cf0\par"# + "\n"
        for section in sections(of: matter) {
            body += #"\pard\sb240\sa120\b\fs26 "# + escaped(section.title) + #"\b0\par"# + "\n"
            for line in section.lines {
                body += #"\pard\li240\sa\#(line.detail == nil ? 100 : 20)\fs22 "# + escaped(line.text) + #"\par"# + "\n"
                if let detail = line.detail, !detail.isEmpty {
                    body += #"\pard\li240\sa100\fs18\cf1 "# + escaped(detail) + #"\cf0\par"# + "\n"
                }
            }
        }
        body += "}"
        return Data(body.utf8)
    }

    /// RTF's own way of writing a text: its three marks escaped, a line break as `\line`, and
    /// everything beyond ASCII by its number, so an ä or a “ arrives whatever opens the file.
    static func escaped(_ text: String) -> String {
        var out = ""
        for unit in text.utf16 {
            switch unit {
            case 0x5C: out += #"\\"#
            case 0x7B: out += #"\{"#
            case 0x7D: out += #"\}"#
            case 0x0A: out += #"\line "#
            case 0x0D: break
            case 0x09: out += #"\tab "#
            case 0x20..<0x7F: out.unicodeScalars.append(UnicodeScalar(UInt8(unit)))
            default: out += #"\u\#(Int16(bitPattern: unit))?"#
            }
        }
        return out
    }
}
