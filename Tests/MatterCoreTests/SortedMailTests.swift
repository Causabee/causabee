import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Mail sorted on one device is known on the others, and each device hands out its own stand-ins")
@MainActor
struct SortedMailTests {
    func judgement(_ id: String, settled: Bool = true, bulk: Bool = false) throws -> Judgement {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var judgement = try decoder.decode(Judgement.self, from: Data(#"{"email_id":"\#(id)","source":"imap://x","date":"2026-09-30T07:00:00Z","subject":"Kaufvertrag","from":"Petra Lindner <p@example.org>","is_bulk":\#(bulk),"matter":"wohnung","matter_confidence":1,"matter_reason":"","decided_by":"pending","parties":[],"todos":[],"deadlines":[]}"#.utf8))
        if settled { judgement.extraction = Judgement.Extraction(model: "m", servedBy: "m", mode: "placeholder", prompt: "p") }
        judgement.entities = [Entity(kind: .person, text: "Petra Lindner", field: .body, start: 0, length: 13, source: .rule)]
        return judgement
    }

    func file(_ entries: [(Entity.Kind, String, String)]) throws -> URL {
        var mapping = Pseudonymizer.Mapping()
        mapping.placeholder = entries.map { Pseudonymizer.Entry(kind: $0.0, original: $0.1, standIn: $0.2) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mapping-\(UUID().uuidString).json")
        try JSONEncoder().encode(mapping).write(to: url)
        return url
    }

    func read(_ url: URL) throws -> [Pseudonymizer.Entry] {
        try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: Data(contentsOf: url)).placeholder
    }

    @Test("An answer goes into the store once, without the names found in it, and counts as known")
    func record() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        #expect(try SortedMails.record([judgement("a"), judgement("b", settled: false), judgement("c", settled: false, bulk: true)],
                                      device: "phone", in: context) == 2)
        #expect(try SortedMails.record([judgement("a")], device: "mac", in: context) == 0)
        let answered = SortedMails.answered(in: context)
        #expect(Set(answered.keys) == ["a", "c"])
        #expect(answered["a"]?.entities.isEmpty == true)
        #expect(answered["a"]?.matter == "wohnung")
        #expect(DailyDoor.done(in: answered) == ["a", "c"])
    }

    @Test("A device without a list starts from the newest one in the store")
    func startsFromNewest() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        try NameLists.publish(file([(.person, "Petra Lindner", "[Person A]")]), device: "mac", deviceName: "Home", in: context)
        let own = FileManager.default.temporaryDirectory.appendingPathComponent("own-\(UUID().uuidString)/mapping.json")
        try NameLists.adopt(into: own, device: "phone", in: context)
        #expect(try read(own).map(\.standIn) == ["[Person A]"])
    }

    @Test("A name another device learned comes in with a stand-in of this device's own, never one it gave someone else")
    func adoptsWithOwnTags() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        // Both handed out [Person B], to two different people.
        let mac = try file([(.person, "Petra Lindner", "[Person A]"), (.person, "Jonas Reiter", "[Person B]")])
        let phone = try file([(.person, "Petra Lindner", "[Person A]"), (.person, "Clara Wendt", "[Person B]")])
        try NameLists.publish(phone, device: "phone", deviceName: "iPhone", in: context)
        // The name, and its parts: "Clara" and "Wendt" alone are covered too.
        #expect(try NameLists.adopt(into: mac, device: "mac", in: context) > 0)
        let entries = try read(mac)
        #expect(entries.first { $0.original == "Jonas Reiter" }?.standIn == "[Person B]")
        let clara = entries.first { $0.original == "Clara Wendt" }?.standIn
        #expect(clara != nil && clara != "[Person B]" && clara != "[Person A]")
        #expect(try NameLists.adopt(into: mac, device: "mac", in: context) == 0)
    }

    @Test("A device asks with its own list, and the other lists' names are disguised too")
    func asksWithOwn() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let phone = try file([(.person, "Clara Wendt", "[Person A]")])
        try NameLists.publish(file([(.person, "Petra Lindner", "[Person A]")]), device: "mac", deviceName: "Home", in: context)
        let (mapping, others) = try NameLists.current(in: context, own: phone, device: "phone")
        #expect(mapping.placeholder.map(\.original) == ["Clara Wendt"])
        #expect(others.map(\.original) == ["Petra Lindner"])
    }
}
