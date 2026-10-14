import Foundation
import SQLite3

/// The owner's matters, copied for the demo to test with: one way, from the real store to the
/// demo's own, never back. SQLite's own backup reads the store whole — with what its journal holds
/// that is not written into the file yet — even while the real Causabee has it open.
public enum StoreCopy {
    public enum Failure: Error { case open(String), copy(String) }

    /// The copy at `target`, made anew: whatever stood there before is gone.
    public static func copy(from source: URL, to target: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: target.path + suffix))
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var from: OpaquePointer?, into: OpaquePointer?
        defer { sqlite3_close(from); sqlite3_close(into) }
        guard sqlite3_open_v2(source.path, &from, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw Failure.open(String(cString: sqlite3_errmsg(from)))
        }
        guard sqlite3_open_v2(target.path, &into, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            throw Failure.open(String(cString: sqlite3_errmsg(into)))
        }
        guard let backup = sqlite3_backup_init(into, "main", from, "main") else {
            throw Failure.copy(String(cString: sqlite3_errmsg(into)))
        }
        let step = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE else { throw Failure.copy(String(cString: sqlite3_errmsg(into))) }
    }
}
