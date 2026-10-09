import CloudKit
import CoreData
import MatterCore
import SwiftData
import SwiftUI

/// The iPhone app: the same matters as the Mac, through the owner's private iCloud. It reads,
/// ticks and asks, and gets new mail as the Mac does; the mail itself stays in the mailbox.
///
/// `--demo` (or "Try the demo") opens the made-up matters in a store of their own, never synced.
@main
struct CausabeePhoneApp: App {
    @State private var store = PhoneStore()

    init() {
        Theme.registerFonts()
        PhoneCloudStatus.shared.watch()
        PhoneFolder.restore()
    }

    var body: some Scene {
        WindowGroup {
            switch store.opened {
            case .success(let container):
                RootView().modifier(ModelChoiceSync())
                    .modelContainer(container)
                    .environment(store)
                    // Another store is another app: nothing of the last one's screens is kept.
                    .id(store.url)
            case .failure(let error):
                ContentUnavailableView("The store cannot be opened", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("\(store.url.path)\n\(error.localizedDescription)"))
            }
        }
        .commands { PhoneCommands() }
    }
}

/// Which store is open — the owner's, or the demo's — and opening the other one. The Mac starts
/// again for that; the iPhone just opens the other store.
@MainActor
@Observable
final class PhoneStore {
    private(set) var url: URL
    private(set) var opened: Result<ModelContainer, Error>
    var isDemo: Bool { DemoData.isRequested }

    init() {
        (url, opened) = Self.open()
    }

    func switchDemo(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: DemoData.chosenKey)
        (url, opened) = Self.open()
    }

    private static func open() -> (URL, Result<ModelContainer, Error>) {
        let url = PhoneCloud.storeLocation()
        let cloud = PhoneCloud.container
        return (url, Result {
            let container = try MatterSchema.container(at: url, cloudKit: cloud)
            // The demo's made-up dates never go into the owner's calendars.
            Calendars.shared.isSealed = DemoData.isRequested
            if DemoData.isRequested { DemoData.seed(container.mainContext); DemoData.keepTalkBehindTheClock(container.mainContext) }
            StoredChanges.shared.watch(container.mainContext)
            return container
        })
    }
}

/// iCloud on the iPhone: the owner's container, in the environment this build is signed for.
enum PhoneCloud {
    static let ownContainer = "iCloud.de.chille.causabee"

    /// The container to sync with, or nil to keep the store on the iPhone: the demo's made-up
    /// matters never meet the owner's iCloud, and `--no-cloud` keeps a store local for a test.
    static var container: String? {
        DemoData.isRequested || CommandLine.arguments.contains("--no-cloud") ? nil : ownContainer
    }

    /// Signed for CloudKit's Production environment: from the App Store or TestFlight, which
    /// carry no profile of their own, or with a profile that says Production. The simulator and
    /// a build from Xcode talk to Development.
    static let isProduction: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else { return true }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>"),
              let plist = try? PropertyListSerialization.propertyList(from: Data(text[start.lowerBound..<end.upperBound].utf8), format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return false }
        if let environment = entitlements["com.apple.developer.icloud-container-environment"] as? String { return environment == "Production" }
        return (entitlements["aps-environment"] as? String) == "production"
        #endif
    }()

    /// As on the Mac: the demo keeps its own store, and so does a build syncing with CloudKit's
    /// Development environment — the owner's matters sync in Production, and one store must never
    /// meet both.
    static func storeLocation() -> URL {
        let name = DemoData.isRequested ? "Causabee-Demo" : container != nil && !isProduction ? "Causabee-Development" : "Causabee"
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("matters.store")
    }
}

/// What iCloud said last on this iPhone, as the Mac's Settings show it: sent, received, or why not.
@MainActor
@Observable
final class PhoneCloudStatus {
    static let shared = PhoneCloudStatus()
    var lastExport: Date?
    var lastImport: Date?
    var lastError: String?
    var account = "…"
    private var watching = false

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
                case .export: PhoneCloudStatus.shared.lastExport = ended
                case .import: PhoneCloudStatus.shared.lastImport = ended
                default: break
                }
                if let error { PhoneCloudStatus.shared.lastError = error } else if type != .setup { PhoneCloudStatus.shared.lastError = nil }
            }
        }
        // The demo has no iCloud, and CausabeeDemo is not signed for the container: asking would stop it.
        guard PhoneCloud.container != nil else { account = "the demo stays on this \(ThisDevice.name)"; return }
        Task {
            let status = try? await CKContainer(identifier: PhoneCloud.ownContainer).accountStatus()
            account = switch status {
            case .available: "signed in to iCloud"
            case .noAccount: "no iCloud account on this \(ThisDevice.name)"
            case .restricted: "iCloud is restricted on this \(ThisDevice.name)"
            case .temporarilyUnavailable: "iCloud is not available right now"
            default: "iCloud status unknown"
            }
        }
    }
}

/// The iPad's menu bar, and its keyboard: what the Mac has in its own — a new matter, the search,
/// the sidebar, the assistant, reading, new mail, Settings. On the iPhone nothing shows them.
struct PhoneCommands: Commands {
    @FocusedValue(\.phoneWindow) private var window

    var body: some Commands {
        // One window of matters, as on the Mac: ⌘N starts a matter.
        CommandGroup(replacing: .newItem) {
            Button("New Matter …") { post(.phoneNewMatter) }.keyboardShortcut("n", modifiers: .command)
            Button("Get New Mail") { post(.phoneGetMail) }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings …") { post(.phoneSettings) }.keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .pasteboard) {
            Button("Find …") { post(.phoneFind) }.keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(replacing: .sidebar) {
            if window?.isPad != false {
                Button(window?.showsSidebar == false ? "Show Sidebar" : "Hide Sidebar") { post(.phoneSidebar) }
                    .keyboardShortcut("s", modifiers: [.command, .control])
            }
            Button(window?.showsAssistant == true ? "Hide Assistant" : "Show Assistant") { post(.phoneAssistant) }
                .keyboardShortcut("k", modifiers: .command)
            Button(window?.reading == true ? "Deactivate Reading Mode" : "Activate Reading Mode") { post(.phoneReading) }
        }
    }

    private func post(_ name: Notification.Name) { NotificationCenter.default.post(name: name, object: nil) }
}

/// What the window shows, for the menu bar's words.
struct PhoneWindowState: Equatable {
    var isPad: Bool
    var showsSidebar: Bool
    var showsAssistant: Bool
    var reading: Bool
}

extension FocusedValues {
    @Entry var phoneWindow: PhoneWindowState?
}

extension Notification.Name {
    static let phoneNewMatter = Notification.Name("causabee.phone.newMatter")
    static let phoneGetMail = Notification.Name("causabee.phone.getMail")
    static let phoneSettings = Notification.Name("causabee.phone.settings")
    static let phoneFind = Notification.Name("causabee.phone.find")
    static let phoneSidebar = Notification.Name("causabee.phone.sidebar")
    static let phoneAssistant = Notification.Name("causabee.phone.assistant")
    static let phoneReading = Notification.Name("causabee.phone.reading")
}
