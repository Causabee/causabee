import Foundation
import SwiftData

/// A folder per matter — in iCloud Drive's Causabee, or a folder the owner chose — with the matter's files:
/// what mails had attached, fetched once and read-only, and what the owner dropped in. The mail
/// texts are not put there: they stay on this Mac. A file the owner hid is left out.
@MainActor
public enum MatterFolders {
    /// iCloud Drive as Finder shows it; nil when it is not switched on for this Mac.
    public static var drive: URL? {
        #if os(iOS)
        // The iPhone has no way to iCloud Drive but through a folder picked in Files: `picked`.
        return nil
        #else
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
        #endif
    }

    /// The folder the owner chose in the settings — any folder, synced or not — or else iCloud
    /// Drive's "Causabee" when it is switched on.
    public static let rootKey = "folders.root"
    public static var chosen: URL? {
        UserDefaults.standard.string(forKey: rootKey).flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
    }
    /// The folder picked in Files on the iPhone — iCloud Drive's "Causabee", the Mac's own — and
    /// held open by the app for as long as it runs.
    public static var picked: URL?
    /// Causabee's own folder in iCloud Drive — "Causabee", with the app's icon — which the Mac and
    /// the iPhone both find without being shown: nil while iCloud Drive is off, or not looked up yet.
    public static var container: URL?
    public nonisolated static let containerID = "iCloud.de.chille.causabee"
    public static var root: URL? { rootForTests ?? chosen ?? container ?? picked ?? drive?.appendingPathComponent("Causabee", isDirectory: true) }

    /// At the start, once: finds Causabee's own folder — asked off the main thread, as Apple says to
    /// — and on the Mac brings along what the earlier folder, iCloud Drive › Causabee, holds.
    public static func useContainer() async {
        let found = await Task.detached { () -> URL? in
            guard let base = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else { return nil }
            let documents = base.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            return documents
        }.value
        guard let found else { return }
        #if os(macOS)
        if chosen == nil, let old = drive?.appendingPathComponent("Causabee", isDirectory: true) {
            await Task.detached { bringAlong(from: old, to: found) }.value
        }
        #endif
        container = found
        listings.removeAll()
    }

    /// Everything of the earlier folder into the new one: a matter's folder as a whole when the new
    /// one has none of its name, else its files one by one. Nothing is overwritten, and the earlier
    /// folder goes only once it is empty.
    nonisolated static func bringAlong(from old: URL, to new: URL) {
        let files = FileManager.default
        var isFolder: ObjCBool = false
        guard files.fileExists(atPath: old.path, isDirectory: &isFolder), isFolder.boolValue,
              old.standardizedFileURL != new.standardizedFileURL else { return }
        for name in (try? files.contentsOfDirectory(atPath: old.path)) ?? [] where name != ".DS_Store" {
            let from = old.appendingPathComponent(name), to = new.appendingPathComponent(name)
            if !files.fileExists(atPath: to.path) { try? files.moveItem(at: from, to: to); continue }
            var inner: ObjCBool = false
            guard files.fileExists(atPath: from.path, isDirectory: &inner), inner.boolValue else { continue }
            for file in (try? files.contentsOfDirectory(atPath: from.path)) ?? [] where file != ".DS_Store" {
                let target = to.appendingPathComponent(file)
                if !files.fileExists(atPath: target.path) { try? files.moveItem(at: from.appendingPathComponent(file), to: target) }
            }
            if ((try? files.contentsOfDirectory(atPath: from.path)) ?? []).allSatisfy({ $0 == ".DS_Store" }) { try? files.removeItem(at: from) }
        }
        if ((try? files.contentsOfDirectory(atPath: old.path)) ?? []).allSatisfy({ $0 == ".DS_Store" }) { try? files.removeItem(at: old) }
    }

    /// What a folder holds, by name — asked of the folder itself, not of each path: in iCloud Drive
    /// on the iPhone a file that was never opened here is not at its path yet, but the folder lists
    /// it, under its name or — on older systems — as ".name.icloud". Names are compared composed, as
    /// one device may write "ä" as one sign and the other as two. Remembered for a few seconds.
    private static var listings: [String: (at: Date, names: [String: String])] = [:]
    public static func names(in folder: URL) -> [String: String] {
        if let known = listings[folder.path], Date().timeIntervalSince(known.at) < 5 { return known.names }
        var names: [String: String] = [:]
        for raw in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
            var name = raw
            if name.hasPrefix("."), name.hasSuffix(".icloud") { name = String(name.dropFirst().dropLast(".icloud".count)) }
            names[name.precomposedStringWithCanonicalMapping] = raw
        }
        listings[folder.path] = (Date(), names)
        return names
    }

    static func isThere(_ url: URL) -> Bool {
        names(in: url.deletingLastPathComponent())[url.lastPathComponent.precomposedStringWithCanonicalMapping] != nil
            || FileManager.default.fileExists(atPath: url.path)
    }

    /// A file of the matter in its folder, whichever device put it there. Nil when there is no
    /// folder, or the file is not in it. Makes nothing.
    public static func kept(_ document: Document) -> URL? {
        guard let root, let matter = document.matter else { return nil }
        // The folder picked may be iCloud Drive itself, one above "Causabee": looked for there too.
        for base in [root, root.appendingPathComponent("Causabee", isDirectory: true)] {
            let folders = names(in: base)
            for name in Set([matter.folderName, safe(matter.name)].compactMap { $0 }) {
                // The folder under the name it really has there, however its letters are composed.
                guard let real = folders[name.precomposedStringWithCanonicalMapping] else { continue }
                let folder = base.appendingPathComponent(real, isDirectory: true)
                let wanted = place(for: document, in: folder).lastPathComponent.precomposedStringWithCanonicalMapping
                guard let file = names(in: folder)[wanted] else { continue }
                // A placeholder stands for the file of the name without its dot and ".icloud".
                return folder.appendingPathComponent(file.hasPrefix(".") && file.hasSuffix(".icloud") ? String(file.dropFirst().dropLast(".icloud".count)) : file)
            }
        }
        return nil
    }

    /// Puts a file brought in on this device into its matter's folder, under the name every
    /// device looks for it by — so the Mac opens what the iPhone photographed, and the other way.
    @discardableResult
    public static func keep(_ file: URL, as document: Document) -> URL? {
        guard let matter = document.matter, let folder = folder(for: matter) else { return nil }
        let target = place(for: document, in: folder)
        if isThere(target) { return target }
        listings.removeAll()
        var failure: NSError?
        var done = false
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &failure) { url in
            done = (try? FileManager.default.copyItem(at: file, to: url)) != nil
        }
        listings.removeAll()
        return done ? target : nil
    }

    /// The file itself, ready to be opened: fetched from iCloud when only its name is here yet,
    /// and handed over as a copy of this device's own.
    public nonisolated static func fetched(_ url: URL) async throws -> URL {
        try await Task.detached {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-open-" + UUID().uuidString.prefix(8), isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent(url.lastPathComponent)
            var failure: NSError?
            var thrown: Error?
            // Reading through the coordinator waits for the download.
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &failure) { source in
                do { try FileManager.default.copyItem(at: source, to: copy) } catch { thrown = error }
            }
            if let error = failure ?? thrown { throw error }
            return copy
        }.value
    }
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
    /// Two of one day and one name, from two mails, are two files: the second is "… 2", the same
    /// on every device — counted by their mails' ids, not by which came first here.
    public static func place(for document: Document, in folder: URL) -> URL {
        let name = stamp(document.source.date) + document.name.replacingOccurrences(of: "/", with: "-")
        let twins = (document.matter?.documents ?? [])
            .filter { !$0.isHidden && !$0.isOwnFile && $0.name == document.name && stamp($0.source.date) == stamp(document.source.date) }
            .map(\.messageID)
        let before = Set(twins).filter { $0 < document.messageID }.count
        guard before > 0, !document.isOwnFile, !document.isHidden else { return folder.appendingPathComponent(name) }
        let file = name as NSString
        let numbered = file.deletingPathExtension + " \(before + 1)"
        return folder.appendingPathComponent(file.pathExtension.isEmpty ? numbered : numbered + "." + file.pathExtension)
    }

    /// A file in the folder with exactly these bytes, if there is one: the same attachment sent
    /// again is not kept twice. One that iCloud has not brought down yet cannot be compared, and
    /// counts as another.
    static func twin(of data: Data, in folder: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.first { file in
            (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) == data.count && (try? Data(contentsOf: file)) == data
        }
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
            guard let data else { result.failed.append(document.name); continue }
            // The same file, to the byte, is in the folder already — sent again with a reply: it is
            // not kept twice, and its second entry is put away. One that differs at all is kept.
            if twin(of: data, in: folder) != nil {
                document.isHidden = true
                try? document.modelContext?.save()
                result.already += 1
                continue
            }
            guard (try? data.write(to: target, options: .atomic)) != nil else { result.failed.append(document.name); continue }
            result.saved += 1
        }
        return result
    }
}
