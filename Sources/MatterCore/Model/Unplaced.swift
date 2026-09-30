import Foundation
import SwiftData

/// Mail from the label that was read but found no matter — a booking, a receipt — and is in no
/// matter yet. Offered to the owner to put into one; nothing is sent again, the answer is kept.
@MainActor
public enum Unplaced {
    /// The open matters, as a sorting run is told about them.
    public static func matters(in context: ModelContext) -> [(key: String, about: String)] {
        ((try? context.fetch(FetchDescriptor<Matter>())) ?? []).filter { !$0.isClosed }.map { matter in
            (matter.key, [matter.name, matter.summary?.split(separator: "\n").first.map(String.init)].compactMap { $0 }.joined(separator: " — "))
        }
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
