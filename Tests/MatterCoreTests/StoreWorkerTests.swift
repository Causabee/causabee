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
        let worker = await StoreWorker.for(container)
        #expect(await worker.isAwayFromScreen())
        let known = await worker.mailKnown(leftOutHere: ["<2@x>"], device: "mac")
        #expect(known.inMatters == ["<1@x>"])
        #expect(known.setAside == ["<2@x>"])
        // Made by the worker, read by the screen's context.
        #expect(SortedMails.setAside(in: context) == ["<2@x>"])
        #expect(await worker.dealtWith() == ["<1@x>", "<2@x>"])
    }
}

@Suite("The overview after a change: prepared by the worker, the page before standing until it comes")
@MainActor
struct OverviewByWorkerTests {
    @Test("A task ticked: the page as it was at once, the new one from the worker a moment later")
    func staleThenFresh() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let container = try MatterSchema.container(at: folder.appendingPathComponent("store.sqlite"))
        let context = container.mainContext
        let matter = Matter(key: "m", name: "M")
        context.insert(matter)
        let todo = Todo(text: "Call", owner: .me, due: nil, source: Source(kind: .mail, pointer: "x"), origin: "t")
        todo.matter = matter
        context.insert(todo)
        try context.save()
        let pages = OverviewPages()
        pages.worker = await StoreWorker.for(container)
        #expect(pages.page(for: [matter], version: 1).summaries.first?.openCount == 1)
        todo.isDone = true
        try context.save()
        // At once: the page before.
        #expect(pages.page(for: [matter], version: 2).summaries.first?.openCount == 1)
        for _ in 0..<100 where pages.arrived == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(pages.page(for: [matter], version: 2).summaries.first?.openCount == 0)
    }
}
