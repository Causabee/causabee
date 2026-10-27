import Foundation
import Testing
@testable import MatterCore

/// Mail read by Apple's model on this device, the way the app reads it without a key or Pro:
/// through the same run as the cloud model, into a judgement the import takes.
@Suite struct DeviceIntakeTests {
    @Test(.enabled(if: DeviceReader.isAvailable))
    func readOnTheDevice() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("device-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try """
        Message-ID: <a@hv.example>
        From: Petra Berger <berger@hv-berger.example>
        To: jan@example.net
        Date: Mon, 22 Sep 2025 09:00:00 +0200
        Subject: Wohnungsübergabe Honigwabenallee 47

        Hallo Herr Kramer,

        die Übergabe Ihrer neuen Wohnung ist am 9. Oktober 2025 um 10:00 Uhr. Bitte schicken Sie mir
        bis zum 1. Oktober den unterschriebenen Mietvertrag zurück.

        Viele Grüße
        Petra Berger
        """.write(to: folder.appendingPathComponent("01.eml"), atomically: true, encoding: .utf8)

        var report = try Spike(detector: EntityDetector(runsTagger: false))
            .run(folder: folder, log: nil, pseudonymizer: Pseudonymizer(mode: .placeholder))
        var extractor = Extractor(model: .opus, claude: nil, cache: folder.appendingPathComponent("cache"))
        extractor.onDevice = true
        extractor.storeMatters = [("umzug-berlin", "Umzug nach Berlin: neue Wohnung, Mietvertrag, Übergabe")]
        let summary = try await extractor.run(&report.outcomes, pseudonymizer: try #require(report.pseudonymizer), owner: ["jan@example.net"])

        let judgement = try #require(report.outcomes.first).judgement
        print("device read:", judgement.matter ?? "-", "|", judgement.todos.map(\.text), "|",
              judgement.appointments.map { "\($0.date) \($0.what)" }, "|", judgement.deadlines.map { "\($0.date) \($0.what)" },
              "|", judgement.digest ?? "", String(format: "| %.1f s", summary.seconds))
        #expect(summary.failed.isEmpty)
        #expect(judgement.decidedBy == .onDevice)
        #expect(judgement.extraction?.model == DeviceReader.modelID && judgement.extraction?.error == nil)
        #expect(Extractor.isSettled(judgement))
        #expect(summary.cost == 0)
        #expect(!(judgement.digest ?? "").isEmpty)
        #expect(judgement.todos.count <= 2)
        // Dates only from the date finder: never one the model made up.
        #expect((judgement.appointments.map(\.date) + judgement.deadlines.map(\.date)).allSatisfy { ["2025-10-09", "2025-10-01"].contains($0) })
    }
}
