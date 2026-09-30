import CryptoKit
import Foundation
import SwiftData

/// The list of names, between the owner's devices. A Mac keeps its `mapping.json` and puts a copy
/// into the store; a device without one — the iPhone — asks with the newest copy and never changes
/// it. The one who writes names down stays the one who hands out their stand-ins: two devices each
/// adding "[Person AB]" for two different people is how a wrong name would come back.
@MainActor
public enum NameLists {
    public enum Failure: Error, LocalizedError {
        case none, unreadable
        public var errorDescription: String? {
            switch self {
            case .none: "No list of names has come from your Mac yet, so nothing can be sent: open Matterbee on the Mac once, and wait until it has synced. Settings (⋯ on the overview) shows when it is here."
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

    /// The newest list, and every name only the other Macs' lists know — so a name from the
    /// other Mac's mail is disguised too, with a stand-in of its own for this one question.
    public static func current(in context: ModelContext) throws -> (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry]) {
        let lists = try context.fetch(FetchDescriptor<NameList>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        guard let newest = lists.first else { throw Failure.none }
        func read(_ list: NameList) throws -> Pseudonymizer.Mapping {
            guard let json = try? (list.data as NSData).decompressed(using: .lzfse) as Data,
                  var mapping = try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: json) else { throw Failure.unreadable }
            mapping.upgrade()
            return mapping
        }
        let mapping = try read(newest)
        let known = Set(mapping.placeholder.map { $0.original.lowercased() })
        var others: [Pseudonymizer.Entry] = []
        for list in lists.dropFirst() {
            guard let other = try? read(list) else { continue }
            others += other.placeholder.filter { $0.partOf == nil && !known.contains($0.original.lowercased()) }
        }
        return (mapping, others)
    }
}
