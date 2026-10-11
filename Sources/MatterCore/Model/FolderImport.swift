import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A folder brought into a matter: every file in it and in the folders under it, each a file of
/// the matter by its own name — the folders themselves are not kept. Read once; the folder is not
/// watched. Nothing of it is sent anywhere.
public enum FolderImport {
    /// The files to take in, for what was picked or dropped: a file is itself, a folder is all
    /// that is in it, however deep. Left out: what the system hides, what iCloud has not brought
    /// down yet, and what is inside a package — a ".app", a ".pages" — which is one thing, and is
    /// taken as one only when it is a file.
    public static func files(in picked: [URL]) -> [URL] {
        var found: [URL] = []
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        for url in picked {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, values?.isPackage != true else {
                if !isLeftOut(url) { found.append(url) }
                continue
            }
            let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            var inside: [URL] = []
            while let next = walk?.nextObject() as? URL {
                let kind = try? next.resourceValues(forKeys: Set(keys))
                if kind?.isDirectory == true, kind?.isPackage != true { continue }
                if !isLeftOut(next) { inside.append(next) }
            }
            // By their paths: the same folder brings the same order every time.
            found += inside.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
        return found
    }

    static func isLeftOut(_ file: URL) -> Bool {
        let name = file.lastPathComponent
        return name.hasPrefix(".") || name.hasSuffix(".icloud")
    }

    /// What the matter has of its owner's own files: each name, with the sizes kept under it.
    public static func taken(by documents: [Document]) -> [String: Set<Int>] {
        var taken: [String: Set<Int>] = [:]
        for document in documents where document.isOwnFile { taken[key(document.name), default: []].insert(document.byteCount) }
        return taken
    }

    /// The name a file gets in the matter, and nil when it is there already — the same name with
    /// the same size, as when a folder is brought a second time. Two files of one name that are
    /// not the same, from two folders, are both kept: the second is "… 2". The name is noted as taken.
    public static func name(for file: String, size: Int, taken: inout [String: Set<Int>]) -> String? {
        // "Rechnung 2.pdf" given at an earlier time is this file again, too.
        var number = 1
        var name = file
        while let sizes = taken[key(name)] {
            if sizes.contains(size) { return nil }
            number += 1
            let whole = file as NSString
            let numbered = whole.deletingPathExtension + " \(number)"
            name = whole.pathExtension.isEmpty ? numbered : numbered + "." + whole.pathExtension
        }
        taken[key(name), default: []].insert(size)
        return name
    }

    /// Names are one name however their letters are composed and whatever their case: as the Mac's disk has it.
    private static func key(_ name: String) -> String { name.precomposedStringWithCanonicalMapping.lowercased() }

    public struct Result: Sendable, Equatable {
        public var added = 0
        public var already = 0
        public var failed = 0
        public var stopped = false
        public var said: String? {
            let said = FolderImport.said(added: added, already: already, failed: failed)
            return stopped ? "Stopped · " + (said ?? (added == 1 ? "1 file added" : "Nothing new")) : said
        }
    }

    /// A file copied in, not yet a file of the matter.
    public struct Brought: Sendable {
        public let name: String
        public let size: Int
        public let type: String
        public let kept: URL
    }

    public struct Outcome: Sendable {
        public var brought: [Brought] = []
        public var already = 0
        public var failed = 0
        /// Stopped by the owner before the last file.
        public var stopped = false
    }

    /// The slow part, off the main thread: finds the files, and copies each to where this device
    /// keeps the owner's own files — `copy` does, under the name given, and says where; nil when
    /// it could not. A file in iCloud Drive is brought down for it first, which is what takes
    /// time. `taken` is what the matter has already (`taken(by:)`). Says before each file how far
    /// it is — which of how many, and its name — and stops between two files when its task is cancelled.
    public nonisolated static func bring(_ picked: [URL], taken: [String: Set<Int>], copy: (URL, String) -> URL?,
                                         progress: (Int, Int, String) -> Void = { _, _, _ in }) -> Outcome {
        // A folder picked in Files or in an open panel is open only between these two.
        let scoped = picked.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        var outcome = Outcome()
        var taken = taken
        let all = files(in: picked)
        for (index, file) in all.enumerated() {
            if Task.isCancelled { outcome.stopped = true; break }
            progress(index + 1, all.count, file.lastPathComponent)
            guard let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { outcome.failed += 1; continue }
            guard let name = name(for: file.lastPathComponent, size: size, taken: &taken) else { outcome.already += 1; continue }
            guard let kept = copy(file, name) else {
                // Not there after all: the name is free again.
                taken[key(name)]?.remove(size)
                if taken[key(name)]?.isEmpty == true { taken[key(name)] = nil }
                outcome.failed += 1
                continue
            }
            let type = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            outcome.brought.append(Brought(name: name, size: size, type: type, kept: kept))
        }
        return outcome
    }

    /// What was copied in becomes files of the matter. Not saved: the caller saves, and then has
    /// the matter's folder in iCloud Drive filled.
    @MainActor
    @discardableResult
    public static func take(_ outcome: Outcome, into matter: Matter, context: ModelContext) -> Result {
        for file in outcome.brought {
            let source = Source(kind: .document, pointer: file.kept.path, messageID: "file-" + UUID().uuidString, date: Date())
            let document = Document(name: file.name, contentType: file.type, byteCount: file.size, source: source)
            context.insert(document)
            document.matter = matter
        }
        return Result(added: outcome.brought.count, already: outcome.already, failed: outcome.failed, stopped: outcome.stopped)
    }

    /// Both at once, where nothing has to wait: files and folders picked or dropped, each file a
    /// file of the matter — the same on the Mac, the iPhone and the iPad.
    @MainActor
    public static func add(_ picked: [URL], to matter: Matter, context: ModelContext, copy: (URL, String) -> URL?) -> Result {
        take(bring(picked, taken: taken(by: matter.documents ?? []), copy: copy), into: matter, context: context)
    }

    /// A file's bytes, brought down from iCloud Drive first when only its name is on this device.
    public nonisolated static func data(of file: URL) -> Data? {
        var data: Data?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: nil) { data = try? Data(contentsOf: $0) }
        return data
    }

    /// What is said once it is done; nil when there is nothing to say — one file added, as before.
    public static func said(added: Int, already: Int, failed: Int) -> String? {
        guard added + already + failed > 1 || already > 0 || failed > 0 else { return nil }
        var parts = [added == 0 ? "Nothing new" : "\(added) \(added == 1 ? "file" : "files") added"]
        if already > 0 { parts.append("\(already) already here") }
        if failed > 0 { parts.append("\(failed) could not be read") }
        return parts.joined(separator: " · ")
    }
}
