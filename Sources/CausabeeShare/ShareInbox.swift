import Foundation

/// What the share sheet and the app hand each other, in the App Group they share: the matters to
/// choose from, written by the app whenever it opens or goes away, and what was shared, waiting
/// in an inbox until the app opens and brings it into the assistant. Nothing here leaves the
/// iPhone; part of both the app and its share extension.
enum ShareInbox {
    static let group = "group.de.chille.causabee"

    /// One open matter, as the share sheet lists it.
    struct Choice: Codable, Identifiable, Hashable {
        let key: String
        let name: String
        let last: Date?
        var id: String { key }
    }

    /// One shared file, waiting: its file in the inbox, its own name, and the matter chosen — none
    /// when Causabee decides.
    struct Item: Codable {
        let file: String
        let name: String
        let matterKey: String?
        let date: Date
    }

    private static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    private static var inbox: URL? { folder?.appendingPathComponent("Inbox", isDirectory: true) }
    private static var choicesFile: URL? { folder?.appendingPathComponent("matters.json") }

    // MARK: The matters, from the app

    static func publish(_ choices: [Choice]) {
        guard let file = choicesFile, let data = try? JSONEncoder().encode(choices) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func choices() -> [Choice] {
        guard let file = choicesFile, let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([Choice].self, from: data)) ?? []
    }

    // MARK: What was shared, from the share sheet

    enum Failure: LocalizedError {
        case noGroup
        var errorDescription: String? { "Causabee's shared folder on this iPhone cannot be reached." }
    }

    static func put(_ data: Data, named name: String, into matterKey: String?) throws {
        guard let inbox else { throw Failure.noGroup }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let ending = (name as NSString).pathExtension
        let file = id + (ending.isEmpty ? "" : ".\(ending)")
        try data.write(to: inbox.appendingPathComponent(file))
        let item = Item(file: file, name: name, matterKey: matterKey, date: Date())
        try JSONEncoder().encode(item).write(to: inbox.appendingPathComponent(id + ".json"), options: .atomic)
    }

    /// What waits, the oldest first, with its data — taken out of the inbox as it is read.
    static func takeAll() -> [(item: Item, data: Data)] {
        guard let inbox, let names = try? FileManager.default.contentsOfDirectory(atPath: inbox.path) else { return [] }
        var taken: [(item: Item, data: Data)] = []
        for name in names where name.hasSuffix(".json") {
            let record = inbox.appendingPathComponent(name)
            guard let item = try? JSONDecoder().decode(Item.self, from: Data(contentsOf: record)) else {
                try? FileManager.default.removeItem(at: record)
                continue
            }
            let file = inbox.appendingPathComponent(item.file)
            if let data = try? Data(contentsOf: file) { taken.append((item, data)) }
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: record)
        }
        return taken.sorted { $0.item.date < $1.item.date }
    }
}
