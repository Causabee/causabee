import Foundation
import SwiftData

public extension ModelContext {
    /// The one this context holds already for that id — only when it is of that kind. SwiftData
    /// asked for a task with an appointment's id it holds does not answer "none": it stops the app
    /// (10 November: "Set again" on a date changed in the chat asked "a task?" first, and closed it).
    func known<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? {
        guard id.entityName == Schema.entityName(for: type) else { return nil }
        guard let found: T = registeredModel(for: id), !found.isDeleted, found.modelContext != nil else { return nil }
        return found
    }

    /// The one in the store with that id — only when it is of that kind. Fetched by another kind's
    /// id, SwiftData answers with whatever of the kind asked has the same row number: "Change date"
    /// on an appointment changed an unrelated task, and the appointment kept no time (10 November).
    func stored<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? {
        guard id.entityName == Schema.entityName(for: type) else { return nil }
        if let found = known(id, as: type) { return found }
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? fetch(descriptor))?.first
    }
}
