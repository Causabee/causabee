import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The owner's matters, copied for the demo")
struct StoreCopyTests {
    @Test("A store copied while it is open has every matter in it, and the copy opens on its own")
    @MainActor
    func copiedWhileOpen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let real = folder.appendingPathComponent("real/matters.store")
        try FileManager.default.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
        let container = try MatterSchema.container(at: real)
        let context = container.mainContext
        for name in ["Care for Mum", "Lisbon"] { context.insert(Matter(key: name, name: name)) }
        try context.save()
        // Still open, with its last writes perhaps only in the journal.
        let copy = folder.appendingPathComponent("demo/matters.store")
        try StoreCopy.copy(from: real, to: copy)
        let copied = try MatterSchema.container(at: copy)
        let names = try copied.mainContext.fetch(FetchDescriptor<Matter>()).map(\.name).sorted()
        #expect(names == ["Care for Mum", "Lisbon"])
        // Made anew each time: a matter added in the demo is gone with the next copy.
        copied.mainContext.insert(Matter(key: "only in the demo", name: "Only in the demo"))
        try copied.mainContext.save()
        try StoreCopy.copy(from: real, to: copy)
        let again = try MatterSchema.container(at: copy)
        #expect(try again.mainContext.fetchCount(FetchDescriptor<Matter>()) == 2)
    }
}
