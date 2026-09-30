import CryptoKit
import Foundation
import SwiftData

/// The list of names, between the owner's devices. Each device keeps its own `mapping.json` — the
/// iPhone too, once it sorts mail — and puts a copy into the store. Only the device that keeps a
/// list hands out its stand-ins: two devices each adding "[Person AB]" for two different people is
/// how a wrong name would come back. So a name another device learned is taken over with a
/// stand-in of this device's own, and a stand-in never travels between devices.
@MainActor
public enum NameLists {
    public enum Failure: Error, LocalizedError {
        case none, unreadable
        public var errorDescription: String? {
            switch self {
            case .none: "No list of names yet, so nothing can be sent: get new mail on this iPhone once, or open Matterbee on your Mac and wait until it has synced. Settings (⋯ on the overview) shows when it is here."
            case .unreadable: "The list of names from your Mac cannot be read, so nothing was sent."
            }
        }
    }

    /// This Mac's copy, written again when the list changed. Says whether it wrote.
    @discardableResult
    public static func publish(_ url: URL, device: String, deviceName: String, in context: ModelContext) throws -> Bool {
        guard let json = try? Data(contentsOf: url), !json.isEmpty else { return false }
        let digest = SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
        let lists = try context.fetch(FetchDescriptor<NameList>(predicate: #Predicate { $0.device == device }))
        if let list = lists.first, list.digest == digest { return false }
        let list = lists.first ?? {
            let made = NameList(device: device, deviceName: deviceName)
            context.insert(made)
            return made
        }()
        list.data = try (json as NSData).compressed(using: .lzfse) as Data
        list.digest = digest
        list.deviceName = deviceName
        list.updatedAt = Date()
        try context.save()
        return true
    }

    /// This device's own list when it keeps one — `own` — or else the newest in the store, and
    /// every name only the other lists know — so a name from another device's mail is disguised
    /// too, with a stand-in of its own for this one question.
    public static func current(in context: ModelContext, own: URL? = nil, device: String? = nil) throws -> (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry]) {
        let lists = try context.fetch(FetchDescriptor<NameList>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        let mapping: Pseudonymizer.Mapping
        var rest = lists
        if let own, let file = read(file: own) {
            mapping = file
            rest = lists.filter { $0.device != device }
        } else {
            guard let newest = lists.first else { throw Failure.none }
            mapping = try read(newest)
            rest = Array(lists.dropFirst())
        }
        let known = Set(mapping.placeholder.map { $0.original.lowercased() })
        var others: [Pseudonymizer.Entry] = []
        for list in rest {
            guard let other = try? read(list) else { continue }
            others += other.placeholder.filter { $0.partOf == nil && !known.contains($0.original.lowercased()) }
        }
        return (mapping, others)
    }

    /// Takes into this device's own list every name the other devices' lists know and it does
    /// not, each with a stand-in handed out here. A device without a list yet starts from the
    /// newest one in the store — the iPhone's first mail is disguised as the Mac would disguise
    /// it — or from nothing, when there is none. Writes the file only when it changed; says how
    /// many names came in.
    @discardableResult
    public static func adopt(into url: URL, device: String, in context: ModelContext) throws -> Int {
        let others = try context.fetch(FetchDescriptor<NameList>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
            .filter { $0.device != device }
        var mapping = read(file: url) ?? others.lazy.compactMap { try? read($0) }.first ?? Pseudonymizer.Mapping()
        let fresh = !FileManager.default.fileExists(atPath: url.path)
        var pseudonymizer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        let before = pseudonymizer.entries.count
        for list in others {
            guard let other = try? read(list) else { continue }
            for entry in other.placeholder where entry.partOf == nil && pseudonymizer.standIn(for: entry.original) == nil {
                _ = pseudonymizer.learn(entry.kind, entry.original)
            }
        }
        let added = pseudonymizer.entries.count - before
        guard added > 0 || fresh else { return 0 }
        mapping.placeholder = pseudonymizer.entries
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(mapping).write(to: url, options: .atomic)
        return added
    }

    private static func read(_ list: NameList) throws -> Pseudonymizer.Mapping {
        guard let json = try? (list.data as NSData).decompressed(using: .lzfse) as Data,
              var mapping = try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: json) else { throw Failure.unreadable }
        mapping.upgrade()
        return mapping
    }

    private static func read(file url: URL) -> Pseudonymizer.Mapping? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              var mapping = try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) else { return nil }
        mapping.upgrade()
        return mapping
    }
}
