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

    /// Mail the owner left out — "Leave out" on new mail, "Not needed" on mail that found no matter —
    /// on any device: a record with no answer in it. Kept in the store, not on the device, so the
    /// other devices do not offer it again. The same record as a sorted mail: nothing new for iCloud.
    public static func setAside(in context: ModelContext) -> Set<String> {
        Set(((try? context.fetch(FetchDescriptor<SortedMail>())) ?? []).filter { $0.data.isEmpty }.map(\.messageID))
    }

    /// Left out on this device: said in the store, for every device. Saved.
    public static func setAside(_ ids: some Sequence<String>, device: String, in context: ModelContext) {
        let known = Set(((try? context.fetch(FetchDescriptor<SortedMail>())) ?? []).map(\.messageID))
        var added = false
        for id in Set(ids) where !id.isEmpty && !known.contains(id) {
            context.insert(SortedMail(messageID: id, device: device))
            added = true
        }
        if added { try? context.save() }
    }

    /// Every mail some device has already dealt with, as the store has it now: sorted, stopped as
    /// bulk, in a matter, or left out. Asked again right before mail is sent to be read — iCloud may
    /// have brought another device's work in while this one was looking.
    public static func known(in context: ModelContext) -> Set<String> {
        // Only what is settled or bulk goes into the store, and a mark is a mail left out: every
        // record is a mail dealt with — its id is enough, nothing needs reading.
        let records = ((try? context.fetch(FetchDescriptor<SortedMail>())) ?? []).map(\.messageID)
        let entries = ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map(\.messageID)
        return Set(records).union(entries).subtracting([""])
    }

    /// The ids of every mail some device sorted, without reading the answers.
    public static func answeredIDs(in context: ModelContext) -> Set<String> {
        Set(((try? context.fetch(FetchDescriptor<SortedMail>())) ?? []).filter { !$0.data.isEmpty }.map(\.messageID))
    }

    /// Answers read before, by Message-ID, with the size of what they were read from: a record is
    /// read again only when it is new or changed. Each read took some fifty milliseconds for a few
    /// hundred mails, and it was asked after every save.
    private static var read: [String: (size: Int, judgement: Judgement)] = [:]

    /// Every answer in the store, by Message-ID.
    public static func answered(in context: ModelContext) -> [String: Judgement] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var out: [String: Judgement] = [:]
        for record in (try? context.fetch(FetchDescriptor<SortedMail>())) ?? [] where !record.data.isEmpty {
            if let known = read[record.messageID], known.size == record.data.count {
                out[known.judgement.emailID] = known.judgement
                continue
            }
            guard let json = try? (record.data as NSData).decompressed(using: .lzfse) as Data,
                  let judgement = try? decoder.decode(Judgement.self, from: json) else { continue }
            read[record.messageID] = (record.data.count, judgement)
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
        let records = try context.fetch(FetchDescriptor<SortedMail>())
        // A mail left out once and sorted after all: its answer takes the place of the mark.
        let known = Set(records.filter { !$0.data.isEmpty }.map(\.messageID))
        let marks = Dictionary(records.filter(\.data.isEmpty).map { ($0.messageID, $0) }, uniquingKeysWith: { first, _ in first })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var added = 0
        for judgement in judgements where !known.contains(judgement.emailID) && (Extractor.isSettled(judgement) || judgement.isBulk) {
            if let mark = marks[judgement.emailID] { context.delete(mark) }
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
