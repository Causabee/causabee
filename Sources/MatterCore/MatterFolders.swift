import Foundation
import SwiftData

/// A folder per matter — in iCloud Drive's Matterbee, or a folder the owner chose — with the matter's files:
/// what mails had attached, fetched once and read-only, and what the owner dropped in. The mail
/// texts are not put there: they stay on this Mac. A file the owner hid is left out.
@MainActor
public enum MatterFolders {
    /// iCloud Drive as Finder shows it; nil when it is not switched on for this Mac.
    public static var drive: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The folder the owner chose in the settings — any folder, synced or not — or else iCloud
    /// Drive's "Matterbee" when it is switched on.
    public static let rootKey = "folders.root"
    public static var chosen: URL? {
        UserDefaults.standard.string(forKey: rootKey).flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
    }
    public static var root: URL? { rootForTests ?? chosen ?? drive?.appendingPathComponent("Matterbee", isDirectory: true) }
    /// A folder of its own for a test, never the owner's iCloud Drive.
    static var rootForTests: URL?

    /// A folder name from the matter's name: no slashes or colons, which Finder would not take.
    static func safe(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Sache" : cleaned
    }

    /// The matter's folder, made if missing, and renamed when the matter was.
    public static func folder(for matter: Matter) -> URL? {
        guard let root else { return nil }
        let name = safe(matter.name)
        let target = root.appendingPathComponent(name, isDirectory: true)
        let files = FileManager.default
        if let old = matter.folderName, old != name {
            let before = root.appendingPathComponent(old, isDirectory: true)
            if files.fileExists(atPath: before.path), !files.fileExists(atPath: target.path) { try? files.moveItem(at: before, to: target) }
        }
        try? files.createDirectory(at: target, withIntermediateDirectories: true)
        if matter.folderName != name { matter.folderName = name }
        return target
    }

    static func stamp(_ date: Date?) -> String { date.map { MatterStatus.day($0) + " " } ?? "" }

    /// Where a file of the matter goes: its day first, so two mails' "Rechnung.pdf" do not meet.
    public static func place(for document: Document, in folder: URL) -> URL {
        folder.appendingPathComponent(stamp(document.source.date) + document.name.replacingOccurrences(of: "/", with: "-"))
    }

    /// The files of the matter worth a place in its folder: not hidden, not a logo.
    public static func wanted(_ matter: Matter) -> [Document] {
        (matter.documents ?? []).filter { !$0.isHidden && !$0.isSmallImage }
    }

    /// What the owner dropped in themselves: screenshots and documents, but not a mail file —
    /// its words stay on this Mac; its attachments are among the documents.
    /// One that is a file of the matter by now is saved with the documents instead.
    public static func dropped(_ matter: Matter) -> [(file: URL, name: String)] {
        let documented = Set((matter.documents ?? []).filter(\.isOwnFile).map(\.messageID))
        return (matter.entries ?? []).compactMap { entry in
            guard [.screenshot, .document].contains(entry.source.kind), !documented.contains(entry.messageID),
                  let file = entry.source.fileURL else { return nil }
            return (file, stamp(entry.date) + file.lastPathComponent)
        }
    }

    public struct Result: Sendable {
        public var saved = 0
        public var already = 0
        public var failed: [String] = []
    }

    /// Everything of these matters into their folders: what is there already is left as it is.
    /// Attachments come out of their mail — out of the dropped mail file, or from the server over
    /// one read-only connection.
    public static func save(_ matters: [Matter], account: MailAccount?, password: String?,
                            progress: (Int, Int) -> Void = { _, _ in }) async -> Result {
        var result = Result()
        var client: IMAPClient?
        defer { if let client { Task { await client.logout() } } }
        let jobs = matters.flatMap { matter in wanted(matter).map { (matter, $0) } }
        for matter in matters {
            guard let folder = folder(for: matter) else { continue }
            for (file, name) in dropped(matter) {
                let target = folder.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target.path) { result.already += 1; continue }
                if (try? FileManager.default.copyItem(at: file, to: target)) != nil { result.saved += 1 } else { result.failed.append(name) }
            }
        }
        for (index, (matter, document)) in jobs.enumerated() {
            progress(index + 1, jobs.count)
            guard let folder = folder(for: matter) else { continue }
            let target = place(for: document, in: folder)
            if FileManager.default.fileExists(atPath: target.path) { result.already += 1; continue }
            // A file the owner dropped in is copied as it is — unless it was saved already, before it
            // was a document, under the name its copy had.
            if document.isOwnFile {
                guard let file = document.source.fileURL else { result.failed.append(document.name); continue }
                let before = folder.appendingPathComponent(stamp(document.source.date) + file.lastPathComponent)
                if FileManager.default.fileExists(atPath: before.path) { result.already += 1; continue }
                if (try? FileManager.default.copyItem(at: file, to: target)) != nil { result.saved += 1 } else { result.failed.append(document.name) }
                continue
            }
            var data: Data?
            if let file = document.source.fileURL, let mail = try? Data(contentsOf: file) {
                data = EMLParser.attachment(named: document.name, in: mail)
            } else if let account, let password, document.source.pointer.hasPrefix("imap://") {
                if client == nil { client = try? await IMAPClient.connect(to: account, password: password) }
                if let client, let mail = try? await MailFetch.message(pointer: document.source.pointer, messageID: document.messageID, from: client) {
                    data = EMLParser.attachment(named: document.name, in: mail)
                }
            }
            guard let data, (try? data.write(to: target, options: .atomic)) != nil else { result.failed.append(document.name); continue }
            result.saved += 1
        }
        return result
    }
}
