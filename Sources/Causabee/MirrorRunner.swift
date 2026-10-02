import EventKit
import MatterCore
import SwiftData
import SwiftUI

/// Runs the mirror when the app starts, when Calendar or Reminders change, and a moment after the
/// store is saved — a moment, so a burst of changes is one sync, and a sync's own save does not
/// start another.
@MainActor
@Observable
final class MirrorRunner {
    static let shared = MirrorRunner()
    var last: Mirror.Result?
    var lastAt: Date?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var running = false

    @ObservationIgnored private var watching = false

    /// Again with the other store's context when the iPhone opens the demo or leaves it: a
    /// context of the store just closed must never be read again — SwiftData stops the app.
    func start(_ context: ModelContext) {
        guard self.context !== context else { return }
        pending?.cancel()
        self.context = context
        guard !watching else { soon(after: 0.5); return }
        watching = true
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MirrorRunner.shared.soon() }
        }
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MirrorRunner.shared.soon() }
        }
        soon(after: 0.5)
    }

    func soon(after seconds: Double = 1.5) {
        guard !running else { return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let context else { return }
            running = true
            let result = Mirror.reconcile(context)
            if result.pushed + result.pulled > 0 { last = result; lastAt = Date() }
            // What the sync saved itself is not a change to sync again.
            try? await Task.sleep(for: .seconds(0.5))
            running = false
        }
    }
}
