import Foundation
import MatterCore

/// The app was called Matterbee until version 0.5. On the first start as Causabee, the owner's
/// own Matterbee comes along: its settings, its store, its folders and its Keychain items. Each
/// is copied, so Matterbee still opens as it was — only iCloud Drive's folder is renamed, so the
/// files are not there twice — and each only when Causabee has none of its own yet, so it happens once.
@MainActor
enum FromMatterbee {
    /// The settings, before anything reads them — where the store is depends on them.
    static func settings() {
        guard Bundle.main.bundleIdentifier == "de.chille.causabee",
              let old = UserDefaults.standard.persistentDomain(forName: "de.chille.matterbee") else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "matterbee.settingsTaken") else { return }
        for (key, value) in old where !key.hasPrefix("CK") && !key.hasPrefix("NS") && !key.hasPrefix("Apple")
            && defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: "matterbee.settingsTaken")
    }

    /// The store and what lies beside it — the mapping, the name lists — from Matterbee's folder
    /// to Causabee's, then the Keychain and iCloud Drive's folder. Only for the owner's own store
    /// (`Causabee`, or `Causabee-Development`), and only when it is not there yet. The store is a
    /// fresh copy: Causabee syncs with a new iCloud container, and a copy without the record of
    /// what the old one has sends every matter there.
    static func store(at url: URL) {
        let arguments = CommandLine.arguments
        guard !arguments.contains("--store"), ProcessInfo.processInfo.environment["CAUSABEE_STORE"] == nil,
              !DemoData.isRequested, CloudSync.mode != .test else { return }
        let folder = url.deletingLastPathComponent()
        let oldFolder = folder.deletingLastPathComponent()
            .appendingPathComponent(folder.lastPathComponent.replacingOccurrences(of: "Causabee", with: "Matterbee"), isDirectory: true)
        let files = FileManager.default
        let oldStore = oldFolder.appendingPathComponent(url.lastPathComponent)
        guard folder.lastPathComponent != oldFolder.lastPathComponent,
              !files.fileExists(atPath: url.path), files.fileExists(atPath: oldStore.path) else { return }

        let storeFiles = [url.lastPathComponent, url.lastPathComponent + "-shm", url.lastPathComponent + "-wal", "matters_ckAssets"]
        for name in (try? files.contentsOfDirectory(atPath: oldFolder.path)) ?? [] where !storeFiles.contains(name) {
            let target = folder.appendingPathComponent(name)
            if !files.fileExists(atPath: target.path) { try? files.copyItem(at: oldFolder.appendingPathComponent(name), to: target) }
        }
        do {
            try CloudSync.freshCopy(from: oldStore, to: url)
            print("✓ Matterbee's matters are in \(url.path).")
        } catch {
            print("✗ Matterbee's store did not come along: \(error)")
        }

        // iCloud Drive's Matterbee folder, when it is the one in use: renamed, so the matters'
        // files are where Causabee looks.
        if MatterFolders.chosen == nil, let drive = MatterFolders.drive {
            let old = drive.appendingPathComponent("Matterbee", isDirectory: true)
            let new = drive.appendingPathComponent("Causabee", isDirectory: true)
            if files.fileExists(atPath: old.path), !files.fileExists(atPath: new.path) { try? files.moveItem(at: old, to: new) }
        }

        let copied = Keychain.takeOverFromMatterbee()
        if copied > 0 { print("✓ \(copied) Keychain items from Matterbee.") }
    }
}
