import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// Puts matters' files into their iCloud Drive folders, in the background of the app: after
/// "Get new mail", after a file is taken in, and on "Save all files now".
@MainActor
@Observable
final class FolderSaver {
    static let shared = FolderSaver()
    var busy: String?
    var last: String?

    func save(_ matters: [Matter]) {
        guard MatterFolders.root != nil, busy == nil, !matters.isEmpty else { return }
        let account = Keychain.accounts().first
        busy = "Saving files …"
        Task {
            var password: String?
            if let account { password = try? await MailSecret.secret(for: account) }
            let result = await MatterFolders.save(matters, account: account, password: password) { done, total in
                MainActor.assumeIsolated { FolderSaver.shared.busy = "Saving files … \(done) of \(total)" }
            }
            busy = nil
            last = "\(result.saved) saved, \(result.already) there already"
                + (result.failed.isEmpty ? "" : ", \(result.failed.count) not found in their mail")
        }
    }

    static func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}

/// ⌘, · the matter folders.
struct FolderSettings: View {
    @Query private var matters: [Matter]
    @State private var saver = FolderSaver.shared
    @AppStorage(MatterFolders.rootKey) private var chosen = ""

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use this folder"
        panel.message = "The folder for Matterbee's matter folders — one subfolder per matter."
        if panel.runModal() == .OK, let url = panel.url { chosen = url.path }
    }

    var body: some View {
        HStack {
            Text(chosen.isEmpty ? (MatterFolders.drive != nil ? "iCloud Drive → Matterbee" : "No folder chosen yet")
                                : (chosen as NSString).abbreviatingWithTildeInPath)
                .font(.caption).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Choose folder …", action: choose)
            if !chosen.isEmpty, MatterFolders.drive != nil { Button("Use iCloud Drive") { chosen = "" } }
        }
        if let root = MatterFolders.root {
            HStack {
                Text("One folder per matter inside it").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open") { try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); FolderSaver.reveal(root) }
            }
            HStack {
                if let busy = saver.busy { ProgressView().controlSize(.small); Text(busy).font(.caption).foregroundStyle(.secondary) }
                else if let last = saver.last { Text(last).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Save all files now") { saver.save(matters) }.disabled(saver.busy != nil)
                    .help("Every matter's files into its folder: attachments fetched read-only from Gmail, and what you dropped in. Files you hid are left out.")
            }
        } else {
            Text("Choose a folder — in Documents, or a synced one like Google Drive or Dropbox. iCloud Drive is not switched on for this Mac.")
                .font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
        }
        Text("Files only — the texts of the mails stay on this Mac. New files are saved there by themselves.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
