import MatterCore
import SwiftUI
import UniformTypeIdentifiers

/// The folder the matters' files are kept in, picked once in Files: iCloud Drive › Causabee, the
/// one the Mac fills — a folder per matter. What is photographed or brought in here goes into it,
/// and what the Mac put there opens here. Without one, a file stays on the device it came to.
@MainActor
enum PhoneFolder {
    static let key = "folders.bookmark"

    /// At the start: the folder picked before, opened again for this run.
    static func restore() {
        guard !DemoData.isRequested, let data = UserDefaults.standard.data(forKey: key) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() else { return }
        MatterFolders.picked = url
        if stale, let fresh = try? url.bookmarkData() { UserDefaults.standard.set(fresh, forKey: key) }
    }

    /// False when the folder cannot be remembered.
    static func choose(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource(), let data = try? url.bookmarkData() else { return false }
        MatterFolders.picked?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.set(data, forKey: key)
        MatterFolders.picked = url
        return true
    }

    static func forget() {
        MatterFolders.picked?.stopAccessingSecurityScopedResource()
        MatterFolders.picked = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Settings › Files: which folder, and how to pick it.
struct FolderSetting: View {
    @State private var picks = false
    @State private var name = MatterFolders.picked?.lastPathComponent
    @State private var failure: String?

    var body: some View {
        if DemoData.isRequested {
            Text("In the demo, files stay in the demo.").font(.footnote).foregroundStyle(.secondary)
        } else {
            LabeledContent("Folder", value: name ?? "None")
            Button(name == nil ? "Choose a folder …" : "Choose another …") { picks = true }
                .fileImporter(isPresented: $picks, allowedContentTypes: [.folder]) { result in
                    guard case .success(let url) = result else { return }
                    if PhoneFolder.choose(url) { name = url.lastPathComponent; failure = nil } else { failure = "This folder cannot be used. Choose one in iCloud Drive or on this iPhone." }
                }
            if name != nil { Button("Use none", role: .destructive) { PhoneFolder.forget(); name = nil } }
            if let failure { Text(failure).font(.footnote).foregroundStyle(Theme.warning) }
            Text("Choose iCloud Drive › Causabee — the folder your Mac keeps a folder per matter in. Then a letter photographed here opens on the Mac, and the Mac's files open here. The files are in your own iCloud Drive; Causabee has no server.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
