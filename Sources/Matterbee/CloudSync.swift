import CloudKit
import CoreData
import MatterCore
import SwiftData
import SwiftUI

/// iCloud for the store: off, a test with made-up data in its own container, or the owner's own
/// data. Chosen in the settings, and taken up when Matterbee starts, since a store is opened once.
@MainActor
@Observable
final class CloudSync {
    enum Mode: String, CaseIterable {
        case off, test, on
        var container: String? {
            switch self {
            case .off: nil
            case .test: "iCloud.de.chille.matterbee.test"
            case .on: "iCloud.de.chille.matterbee"
            }
        }
        var label: String {
            switch self {
            case .off: "Off — on this Mac only"
            case .test: "Test — made-up data, its own container"
            case .on: "On — your matters, in your private iCloud"
            }
        }
    }

    nonisolated static let modeKey = "cloud.mode"
    nonisolated static var mode: Mode {
        // The demo's made-up matters never meet the owner's iCloud, in either direction.
        guard isEntitled, !DemoData.isRequested else { return .off }
        let chosen = Mode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .off
        return available.contains(chosen) ? chosen : .off
    }

    /// The containers this build may ask. A build without the entitlement — from `swift build`, or
    /// started from the terminal — is stopped by CloudKit the moment it tries, so it stays on this
    /// Mac; a release may ask only the owner's real container, not the test one.
    nonisolated static let containers: Set<String> = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil)
        else { return [] }
        return Set(value as? [String] ?? [])
    }()
    nonisolated static var isEntitled: Bool { !containers.isEmpty }

    /// Signed for CloudKit's Production environment — a release, or the owner's own copy of one.
    /// A development build without the entitlement talks to Development.
    nonisolated static let isProduction: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-environment" as CFString, nil)
        else { return false }
        return (value as? String) == "Production"
    }()

    /// Off, and each mode whose container this build may ask.
    nonisolated static var available: [Mode] {
        Mode.allCases.filter { mode in mode.container.map(containers.contains) ?? true }
    }

    static let shared = CloudSync()

    /// `--fresh-cloud-copy <from> <to>`: the store's matters in a new store without the record of what
    /// iCloud has, so the first start in Production sends every one. A store that synced with
    /// Development believes all of it is sent already, and Production would stay empty. Only the
    /// models' own records are copied; the mirroring's are not.
    nonisolated static func freshCopy(from source: URL, to target: URL) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: MatterSchema.models) else {
            throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "The models make no Core Data model."])
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let history: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]
        let store = try coordinator.addPersistentStore(type: .sqlite, at: source, options: history)
        _ = try coordinator.migratePersistentStore(store, to: target, options: history, type: .sqlite)
    }

    /// `--init-cloudkit-schema`: makes every record type and field in the container's Development
    /// schema — a type only appears there once a record of it was sent — so the schema can be
    /// deployed to Production whole. Works on an empty store of its own, never the owner's, and is
    /// for a development-signed build: only that one reaches Development.
    nonisolated static func initializeSchema(container id: String) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("matterbee-schema-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: MatterSchema.models) else {
            throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "The models make no Core Data model."])
        }
        // Released before SwiftData opens anything, as Apple's own example does.
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: folder.appendingPathComponent("schema.store"))
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: id)
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(name: "Matterbee", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var failure: Error?
            container.loadPersistentStores { _, error in failure = error }
            if let failure { throw failure }
            try container.initializeCloudKitSchema()
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }

    /// What iCloud said last: sent, received, or why not.
    var lastExport: Date?
    var lastImport: Date?
    var lastError: String?
    var account: String = "…"
    private var watching = false

    /// Listens to the store's own reports of what it sent to and got from iCloud.
    func watch() {
        guard !watching else { return }
        watching = true
        NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  let ended = event.endDate else { return }
            let error = event.error.map { ($0 as NSError).localizedDescription }
            let type = event.type
            MainActor.assumeIsolated {
                switch type {
                case .export: CloudSync.shared.lastExport = ended
                case .import:
                    CloudSync.shared.lastImport = ended
                    NotificationCenter.default.post(name: .threadMayHaveChanged, object: nil)
                default: break
                }
                if let error { CloudSync.shared.lastError = error } else if type != .setup { CloudSync.shared.lastError = nil }
            }
        }
        Task { await checkAccount() }
    }

    func checkAccount() async {
        guard Self.isEntitled else { account = "not available in this build"; return }
        // Off, the account is still worth knowing: asked through a container this build may use.
        guard let id = Self.mode.container ?? Self.available.compactMap(\.container).first else { return }
        let status = try? await CKContainer(identifier: id).accountStatus()
        account = switch status {
        case .available: "signed in to iCloud"
        case .noAccount: "no iCloud account on this Mac"
        case .restricted: "iCloud is restricted on this Mac"
        case .temporarilyUnavailable: "iCloud is not available right now"
        default: "iCloud status unknown"
        }
    }

    /// Two made-up matters in an empty test store, to see them arrive in iCloud.
    static func seedTest(_ context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Matter>())) ?? 0) == 0 else { return }
        for (key, name, tasks) in [("test-umzug", "Test: Umzug Honigtauer Str.", ["Umzugskartons bestellen", "Nachsendeauftrag stellen"]),
                                   ("test-reise", "Test: Reise nach Lyon", ["Hotel in Lyon buchen"])] {
            let matter = Matter(key: key, name: name)
            context.insert(matter)
            for text in tasks {
                let todo = Todo(text: text, owner: .me, due: nil, source: Source(kind: .conversation, pointer: "test"), origin: "test#" + text)
                context.insert(todo)
                todo.matter = matter
            }
        }
        try? context.save()
    }
}

/// ⌘, · iCloud: the choice, and what iCloud last said.
struct CloudSettings: View {
    @AppStorage(CloudSync.modeKey) private var mode = CloudSync.Mode.off.rawValue
    @State private var sync = CloudSync.shared
    private let started = CloudSync.mode

    var body: some View {
        // A build without the entitlement — the downloaded beta — never syncs, whatever is chosen:
        // it says so instead of offering a choice that does nothing.
        if !CloudSync.isEntitled {
            LabeledContent("iCloud", value: "Not in this version")
            Text("This version of Matterbee has no iCloud: your matters stay on this Mac.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } else {
            choice
        }
    }

    @ViewBuilder
    private var choice: some View {
        // A mode this build may not use (the test one, in a release) shows as off, as it acts.
        Picker("iCloud", selection: Binding(get: { CloudSync.available.map(\.rawValue).contains(mode) ? mode : CloudSync.Mode.off.rawValue },
                                            set: { mode = $0 })) {
            ForEach(CloudSync.available, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
        }
        if DemoData.isRequested {
            Text("In the demo, iCloud stays off: the made-up matters never meet your iCloud. Your choice counts again when you leave the demo.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } else if (CloudSync.available.map(\.rawValue).contains(mode) ? mode : CloudSync.Mode.off.rawValue) != started.rawValue {
            HStack {
                Text("Takes effect when Matterbee starts again.").font(.caption).foregroundStyle(Theme.warning)
                Spacer()
                Button("Quit Matterbee") { NSApp.terminate(nil) }
            }
        }
        if started != .off {
            VStack(alignment: .leading, spacing: 3) {
                Text("Now: \(started.label) · \(sync.account)").font(.caption)
                Text("Last sent: \(sync.lastExport.map { $0.formatted(date: .omitted, time: .shortened) } ?? "not yet") · last received: \(sync.lastImport.map { $0.formatted(date: .omitted, time: .shortened) } ?? "not yet")")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = sync.lastError { Text(error).font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled) }
            }
        }
        Text("Only the store syncs: matters, tasks, dates, people, digests and the assistant's history. Full mail texts and files stay on this Mac.")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
