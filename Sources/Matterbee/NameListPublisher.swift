import AppKit
import MatterCore
import SwiftData

/// Puts this Mac's list of names into the store, where the iPhone reads it to ask: at start, and
/// each time Matterbee goes to the background or quits. Written only when the list changed; only
/// this Mac ever writes its own.
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
        _ = try? NameLists.publish(MatterbeeApp.mappingLocation(), device: device,
                                   deviceName: Host.current().localizedName ?? "Mac", in: context)
    }
}
