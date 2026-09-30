import Foundation
import SwiftData

/// The record of what the label has answered, between the owner's devices. Each device keeps its
/// own log (`decisions-fetch.jsonl`) and puts every answer into the store, where the others read
/// it: a mail sorted on the iPhone is not sent again from the Mac, nor the other way round.
@MainActor
public enum SortedMails {
    /// What the store keeps of an answer: the answer, without the disguised text that was sent and
    /// the names found in it — those stay in the log of the device that sorted it.
    public static func slim(_ judgement: Judgement) -> Judgement {
        var judgement = judgement
        judgement.disguise = nil
        judgement.entities = []
        judgement.notDisguised = []
        return judgement
    }

    /// Every answer in the store, by Message-ID.
    public static func answered(in context: ModelContext) -> [String: Judgement] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var out: [String: Judgement] = [:]
        for record in (try? context.fetch(FetchDescriptor<SortedMail>())) ?? [] {
            guard let json = try? (record.data as NSData).decompressed(using: .lzfse) as Data,
                  let judgement = try? decoder.decode(Judgement.self, from: json) else { continue }
            out[judgement.emailID] = judgement
        }
        return out
    }

    /// This device's log and the store together: what any device has sorted. Where both have a
    /// mail, the log's answer is kept — it is the whole one.
    public static func all(log: URL, in context: ModelContext) -> [String: Judgement] {
        answered(in: context).merging(DailyDoor.readLog(log)) { _, own in own }
    }

    /// Into the store, what it does not have yet: only answers with nothing left to do — sorted,
    /// or stopped as bulk. A mail whose try failed is tried again, by whichever device comes first.
    /// Says how many went in.
    @discardableResult
    public static func record(_ judgements: [Judgement], device: String, in context: ModelContext) throws -> Int {
        let known = Set(try context.fetch(FetchDescriptor<SortedMail>()).map(\.messageID))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var added = 0
        for judgement in judgements where !known.contains(judgement.emailID) && (Extractor.isSettled(judgement) || judgement.isBulk) {
            let record = SortedMail(messageID: judgement.emailID, device: device)
            record.date = judgement.date
            record.data = try (try encoder.encode(slim(judgement)) as NSData).compressed(using: .lzfse) as Data
            context.insert(record)
            added += 1
        }
        if added > 0 { try context.save() }
        return added
    }
}
