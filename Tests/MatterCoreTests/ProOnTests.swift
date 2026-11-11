import Foundation
import Testing
@testable import MatterCore

/// Fix, 12 November 2026: on the Mac, with a top-up left and no Pro subscription, "Turn on Pro"
/// kept the bee grey and the chat sent nothing — the views counted Pro only with the subscription,
/// while the plan sheet and what is read count a top-up too ("Pro, now and then").
@Suite("Pro is on with its switch and Pro to use: the subscription or a top-up")
struct ProOnTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("A top-up turns Pro on without the subscription; the switch off keeps it off")
    func rule() {
        #expect(Plan.proIsOn(switched: true, plan: .pro, credit: false))
        #expect(Plan.proIsOn(switched: true, plan: .free, credit: true))
        #expect(Plan.proIsOn(switched: true, plan: .matters, credit: true))
        #expect(!Plan.proIsOn(switched: true, plan: .matters, credit: false))
        #expect(!Plan.proIsOn(switched: false, plan: .pro, credit: true))
    }

    @Test("Every view asks the one rule, none keeps its own")
    func oneRule() throws {
        let views = ["Sources/Causabee/Components.swift", "Sources/Causabee/AssistantView.swift", "Sources/Causabee/Theme.swift",
                     "Sources/CausabeePhone/Parts.swift", "Sources/CausabeePhone/AssistantSheet.swift", "Sources/CausabeePhone/PhoneShots.swift"]
        for path in views {
            let source = try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
            #expect(!source.contains("auto && Store.shared.plan == .pro"), "\(path) counts Pro only with the subscription")
        }
        let theme = try String(contentsOf: Self.root.appendingPathComponent("Sources/Causabee/Theme.swift"), encoding: .utf8)
        #expect(theme.contains("Plan.proIsOn("))
    }
}
