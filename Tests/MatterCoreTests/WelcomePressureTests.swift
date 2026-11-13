import Foundation
import Testing
@testable import MatterCore

/// F008's pressure test, by hand: ten made-up lines, typed as a first step, read by Apple's model on
/// this Mac — as without Pro. Each must give a matter, a sensible name or the line itself, and no
/// date that is not in the words. Run with `CAUSABEE_PRESSURE=1 swift test --filter WelcomePressure`.
/// Nothing leaves the Mac.
@Suite("F008 · Typed lines, read on the device", .enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_PRESSURE"] == "1"))
struct WelcomePressureTests {
    static let lines = [
        "Umzug im März",
        "Mum fell. The care service visits on Thursday at 10.",
        "Moving to Lisbon in March. Book the movers by Friday.",
        "Steuererklärung 2025 bis 31. Juli abgeben",
        "just thinking about the garden",
        "Car insurance claim after the parking-lot accident, the assessor calls next week",
        "Hochzeit von Mara und Sam am 12. Juni 2027, Location noch offen",
        "Bathroom renovation: the tiler comes on 3 December, the plumber before that, and we still need to choose the tiles and ask the landlord for permission.",
        "Science fair project with Lena, due 20 November",
        "Kita-Platz für Emil suchen",
    ]

    @Test("F008 · Ten typed lines become matters, read on this Mac")
    func tenLines() async throws {
        print("PRESSURE on device: \(DeviceReader.isAvailable)")
        let one = ProcessInfo.processInfo.environment["CAUSABEE_PRESSURE_LINE"]
        for line in one.map({ [$0] }) ?? Self.lines {
            // Each line a first start of its own: an empty store, nothing read before.
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pressure-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let door = ScreenshotDoor(besides: folder.appendingPathComponent("store.sqlite"))
            let look = try door.look(at: Welcome.typedFile(line, in: folder), owner: "Alex")
            let judgement = try await door.classify(look, claude: nil, owner: ["Alex"])
            let name = Welcome.matterName(proposed: judgement.matterTitle, typed: look.heading)
            let todos = judgement.todos.map { $0.text + ($0.due.map { " · \($0)" } ?? "") }
            let dates = judgement.appointments.map { "\($0.what) · \($0.date) \($0.time ?? "")" } + judgement.deadlines.map { "\($0.what) · by \($0.date)" }
            print("PRESSURE \"\(line)\"\n   → \(name)   [key \(judgement.matter ?? "nil"), \(judgement.matterReason ?? "")]\n   tasks: \(todos)\n   dates: \(dates)")
            #expect(!name.isEmpty)
        }
    }
}
