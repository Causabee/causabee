import Foundation
import SwiftData

/// Mail from the label that was read but found no matter — a booking, a receipt — and is in no
/// matter yet. Offered to the owner to put into one; nothing is sent again, the answer is kept.
@MainActor
public enum Unplaced {
    /// The open matters, as a sorting run is told about them.
    public static func matters(in context: ModelContext) -> [(key: String, about: String)] {
        ((try? context.fetch(FetchDescriptor<Matter>())) ?? []).filter { !$0.isClosed }.map { matter in
            // What it is about from its brief, and what the owner said of it: a new mail is read knowing it.
            let brief = matter.shownBrief
            let about = brief?.gist ?? matter.summary?.split(separator: "\n").first.map(String.init)
            let said = brief?.said.suffix(3).map { "the owner says: \($0.text)" } ?? []
            return (matter.key, ([matter.name, about].compactMap { $0 } + said).joined(separator: " — "))
        }
    }

    /// What each open matter has on file, by its key: its appointments, and what the owner took out.
    public static func onFile(in context: ModelContext) -> [String: Extractor.OnFile] {
        var files: [String: Extractor.OnFile] = [:]
        let today = MatterStatus.day(Date().addingTimeInterval(-7 * 86_400))
        for matter in ((try? context.fetch(FetchDescriptor<Matter>())) ?? []) where !matter.isClosed {
            let coming = (matter.appointments ?? []).filter { $0.day >= today }.sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
            let unwanted = matter.shownBrief?.unwanted ?? []
            guard !coming.isEmpty || !unwanted.isEmpty else { continue }
            files[matter.key] = .init(appointments: coming.map { Extractor.line(day: $0.day, time: $0.time, what: $0.what) }, unwanted: unwanted)
        }
        return files
    }

    /// Where each mail is now, by its id: the matter the owner left it in or moved it to. A reply
    /// in its thread is sorted by this, not by where the mail was put first.
    public static func placed(in context: ModelContext) -> [String: String] {
        var placed: [String: String] = [:]
        for entry in (try? context.fetch(FetchDescriptor<Entry>())) ?? [] where !entry.messageID.isEmpty {
            if let matter = entry.matter { placed[entry.messageID] = matter.key }
        }
        return placed
    }

    /// The last month's mail with no matter, not in the store, not set aside — sorted on this
    /// device or on another.
    public static func find(log: URL, context: ModelContext, setAside: Set<String>, days: Int = 30) -> [Judgement] {
        let placed = Set(((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map(\.messageID))
        let since = Date().addingTimeInterval(-Double(days) * 86_400)
        return SortedMails.all(log: log, in: context).values
            .filter { !$0.isBulk && $0.matter == nil && Extractor.isSettled($0) && $0.extraction?.skipped == nil }
            .filter { !placed.contains($0.emailID) && !setAside.contains($0.emailID) && ($0.date ?? .distantPast) >= since }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Into the matter the owner chose, with what the answer found in it.
    public static func place(_ judgement: Judgement, in matter: Matter, context: ModelContext, owner: [String]) throws {
        var judgement = judgement
        judgement.matter = matter.key
        judgement.matterTitle = nil
        _ = try MatterImport.apply([judgement], to: context, owner: owner)
        try context.save()
    }
}
