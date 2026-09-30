import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The list of names between the devices: written by each Mac, read by the iPhone, never changed there")
@MainActor
struct NameListTests {
    func file(_ mapping: Pseudonymizer.Mapping) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mapping-\(UUID().uuidString).json")
        try JSONEncoder().encode(mapping).write(to: url)
        return url
    }

    func mapping(_ entries: [(Entity.Kind, String, String)]) -> Pseudonymizer.Mapping {
        var mapping = Pseudonymizer.Mapping()
        mapping.placeholder = entries.map { Pseudonymizer.Entry(kind: $0.0, original: $0.1, standIn: $0.2) }
        return mapping
    }

    @Test("A Mac's list goes in compressed, comes back whole, and is written again only when it changed")
    func roundTrip() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let url = try file(mapping([(.person, "Petra Lindner", "[Person A]"), (.organization, "Berger Hausverwaltung", "[Company A]")]))
        #expect(try NameLists.publish(url, device: "mac-1", deviceName: "Home", in: context))
        #expect(try !NameLists.publish(url, device: "mac-1", deviceName: "Home", in: context))
        let (read, others) = try NameLists.current(in: context)
        #expect(read.placeholder.map(\.original) == ["Petra Lindner", "Berger Hausverwaltung"])
        #expect(others.isEmpty)

        try JSONEncoder().encode(mapping([(.person, "Petra Lindner", "[Person A]"), (.person, "Jonas Reiter", "[Person B]")])).write(to: url)
        #expect(try NameLists.publish(url, device: "mac-1", deviceName: "Home", in: context))
        #expect(try context.fetchCount(FetchDescriptor<NameList>()) == 1)
        #expect(try NameLists.current(in: context).mapping.placeholder.map(\.original) == ["Petra Lindner", "Jonas Reiter"])
    }

    @Test("No list yet: nothing can be sent")
    func none() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        #expect(throws: NameLists.Failure.self) { try NameLists.current(in: context) }
    }

    @Test("Two Macs: the newest list is the one asked with, and the other Mac's own names are disguised too, kept nowhere")
    func twoMacs() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let home = try file(mapping([(.person, "Petra Lindner", "[Person A]")]))
        let work = try file(mapping([(.person, "Petra Lindner", "[Person A]"), (.person, "Clara Wendt", "[Person B]")]))
        try NameLists.publish(work, device: "mac-work", deviceName: "Work", in: context)
        try NameLists.publish(home, device: "mac-home", deviceName: "Home", in: context)
        let (mapping, others) = try NameLists.current(in: context)
        #expect(mapping.placeholder.map(\.original) == ["Petra Lindner"])
        #expect(others.map(\.original) == ["Clara Wendt"])

        let facts = Facts(text: "T1: Send Clara Wendt the signed form. T2: Call Petra Lindner.", refs: [:], seen: "2 tasks")
        var saved = false
        let prepared = try AssistantAsk.prepare(question: "What is next?", inHand: nil, earlier: [], facts: facts, owner: nil,
                                                today: "2026-09-30", mapping: mapping, others: others) { _ in saved = true }
        #expect(!prepared.sent.contains("Clara Wendt"))
        #expect(!prepared.sent.contains("Petra Lindner"))
        #expect(prepared.sent.contains("[Person A]"))
        #expect(prepared.pseudonymizer.restorer.apply(prepared.sent).text.contains("Clara Wendt"))
        #expect(!saved)
    }
}
