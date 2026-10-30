import CoreData
import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Every field of the models must be in iCloud's Production schema before a build with it goes out:
/// one that is not makes iCloud refuse each upload that holds it, and then all that come after — on
/// 29 October `Appointment.endDay` and `endTime` stopped every device's uploads for a day, and the
/// iPad saw nothing new. The fields deployed are listed in `scripts/cloudkit-schema.txt`.
@Suite("iCloud's schema")
struct CloudKitSchemaTests {
    static let deployedFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("scripts/cloudkit-schema.txt")

    /// Each entity's fields and relationships, one a line, as iCloud gets them.
    static func fields() throws -> [String] {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: MatterSchema.models))
        var lines: [String] = []
        for entity in model.entities {
            let name = entity.name ?? "?"
            for (field, property) in entity.propertiesByName {
                if let relationship = property as? NSRelationshipDescription {
                    lines.append("\(name).\(field) -> \(relationship.destinationEntity?.name ?? "?")")
                } else if property is NSAttributeDescription {
                    lines.append("\(name).\(field)")
                }
            }
        }
        return lines.sorted()
    }

    @Test("Every field is in Production already: a new one is deployed first")
    func deployed() throws {
        // Right after "Deploy Schema Changes": `CAUSABEE_SCHEMA_DEPLOYED=1 swift test --filter CloudKitSchemaTests`
        // writes the list anew.
        if ProcessInfo.processInfo.environment["CAUSABEE_SCHEMA_DEPLOYED"] == "1" {
            try (Self.fields().joined(separator: "\n") + "\n").write(to: Self.deployedFile, atomically: true, encoding: .utf8)
        }
        let deployed = Set(try String(contentsOf: Self.deployedFile, encoding: .utf8).split(separator: "\n").map(String.init))
        let missing = try Self.fields().filter { !deployed.contains($0) }
        #expect(missing.isEmpty, """
            Not in iCloud's Production schema yet: \(missing.joined(separator: ", ")).
            Run a development build with --init-cloudkit-schema, then "Deploy Schema Changes" in the CloudKit Console — \
            then CAUSABEE_SCHEMA_DEPLOYED=1 swift test --filter CloudKitSchemaTests.
            """)
    }
}
