import MatterCore
import SwiftData
import SwiftUI

/// The iPhone app: the same matters as the Mac, through the owner's private iCloud. It reads and
/// ticks; the mail itself stays on the Mac, which takes it in.
///
/// `--demo` (or "Try the demo") opens the made-up matters in a store of their own, never synced.
@main
struct MatterbeePhoneApp: App {
    @State private var store = PhoneStore()

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            switch store.opened {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(store)
                    // Another store is another app: nothing of the last one's screens is kept.
                    .id(store.url)
            case .failure(let error):
                ContentUnavailableView("The store cannot be opened", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("\(store.url.path)\n\(error.localizedDescription)"))
            }
        }
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
            if DemoData.isRequested { DemoData.seed(container.mainContext) }
            return container
        })
    }
}

/// iCloud on the iPhone: the owner's container, in the environment this build is signed for.
enum PhoneCloud {
    static let ownContainer = "iCloud.de.chille.matterbee"

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
        let name = DemoData.isRequested ? "Matterbee-Demo" : container != nil && !isProduction ? "Matterbee-Development" : "Matterbee"
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("matters.store")
    }
}
