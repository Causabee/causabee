import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The store's work away from the screen: the worker reads what the screen's context saved")
@MainActor
struct StoreWorkerTests {
    @Test("What a mail check must know comes from the worker: in a matter, left out, sorted — and a mark made there is seen here")
    func mailKnown() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let container = try MatterSchema.container(at: folder.appendingPathComponent("store.sqlite"))
        let context = container.mainContext
        let matter = Matter(key: "m")
        context.insert(matter)
        let entry = Entry(title: "Mail", from: "Anna <anna@example.com>", date: Date(),
                          source: Source(kind: .mail, pointer: "imap://mail.example/INBOX;UIDVALIDITY=7/;UID=1", messageID: "<1@x>"))
        entry.matter = matter
        context.insert(entry)
        try context.save()
        let worker = StoreWorker.for(container)
        let known = await worker.mailKnown(leftOutHere: ["<2@x>"], device: "mac")
        #expect(known.inMatters == ["<1@x>"])
        #expect(known.setAside == ["<2@x>"])
        // Made by the worker, read by the screen's context.
        #expect(SortedMails.setAside(in: context) == ["<2@x>"])
        #expect(await worker.dealtWith() == ["<1@x>", "<2@x>"])
    }
}
