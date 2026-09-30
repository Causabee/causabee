import AppKit
import MatterCore
import SwiftData

/// Puts this Mac's list of names into the store, where the other devices read it: at start, and
/// each time Matterbee goes to the background or quits. Written only when the list changed; only
/// this Mac ever writes its own. Before, it takes in the names the other devices' lists know — the
/// iPhone's, the other Mac's — each with a stand-in of this Mac's own, so a name first met on the
/// iPhone is disguised here too. And at start, what this Mac sorted before goes into the store's
/// record of sorted mail, so the iPhone never sends it again.
@MainActor
enum NameListPublisher {
    private static let deviceKey = "names.device"

    /// A random id this Mac keeps, and its name for the screen.
    static var device: String {
        if let id = UserDefaults.standard.string(forKey: deviceKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceKey)
        return id
    }

    private static var context: ModelContext?

    static func start(_ context: ModelContext) {
        self.context = context
        let log = MatterbeeApp.storeLocation().deletingLastPathComponent().appendingPathComponent("decisions-fetch.jsonl")
        _ = try? SortedMails.record(Array(DailyDoor.readLog(log).values), device: device, in: context)
        publish()
        // Reading a key shares it through iCloud Keychain, when it was saved before keys were:
        // the iPhone then asks with it without the owner pasting it there.
        for name in ["ANTHROPIC_API_KEY", "MISTRAL_API_KEY", "OPENAI_API_KEY"] { _ = APIKeys.get(name) }
        for name in [NSApplication.didResignActiveNotification, NSApplication.willTerminateNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { publish() }
            }
        }
    }

    static func publish() {
        guard let context else { return }
        adopt()
        _ = try? NameLists.publish(MatterbeeApp.mappingLocation(), device: device,
                                   deviceName: Host.current().localizedName ?? "Mac", in: context)
    }

    /// The other devices' names into this Mac's list. The list as it was before the first time
    /// is kept beside it.
    static func adopt() {
        guard let context else { return }
        let mapping = MatterbeeApp.mappingLocation()
        let before = mapping.deletingLastPathComponent().appendingPathComponent("mapping.before-other-devices.json")
        if !FileManager.default.fileExists(atPath: before.path) { try? FileManager.default.copyItem(at: mapping, to: before) }
        _ = try? NameLists.adopt(into: mapping, device: device, in: context)
    }
}
