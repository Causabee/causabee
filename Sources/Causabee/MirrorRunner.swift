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
    /// A change came while a sync ran: once more after it, so it is not lost.
    @ObservationIgnored private var again = false
    /// The sync is saving what it brought in: that save is told while it happens, and is not a
    /// change to sync again — counted as one, every sync started the next, two seconds later, for good.
    @ObservationIgnored private var reconciling = false
    /// Calendar or Reminders may have changed — they said so, or Causabee was away: everything
    /// connected is looked up there. Otherwise only what changed here is.
    @ObservationIgnored private var theirsChanged = true

    @ObservationIgnored private var watching = false

    /// Again with the other store's context when the iPhone opens the demo or leaves it: a
    /// context of the store just closed must never be read again — SwiftData stops the app.
    func start(_ context: ModelContext) {
        guard self.context !== context else { return }
        pending?.cancel()
        self.context = context
        theirsChanged = true
        guard !watching else { soon(after: 0.5); return }
        watching = true
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MirrorRunner.shared.theirsChanged = true; MirrorRunner.shared.soon() }
        }
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard !MirrorRunner.shared.reconciling else { return }
                MirrorRunner.shared.soon()
            }
        }
        // Back to the front: what was changed in Reminders or Calendar meanwhile — on the iPhone no
        // change is told while Causabee is away — is looked at now.
        NotificationCenter.default.addObserver(forName: Self.becameActive, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                Calendars.shared.store.refreshSourcesIfNecessary()
                Task { await CalendarWorker.shared.refresh() }
                MirrorRunner.shared.theirsChanged = true
                MirrorRunner.shared.soon(after: 0.3)
            }
        }
        soon(after: 0.5)
    }

    #if os(iOS)
    static let becameActive = UIApplication.didBecomeActiveNotification
    #else
    static let becameActive = NSApplication.didBecomeActiveNotification
    #endif

    func soon(after seconds: Double = 1.5) {
        guard !running else { again = true; return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let context else { return }
            running = true
            let theirs = theirsChanged
            theirsChanged = false
            // Calendar and Reminders are asked by the worker, away from the screen: the page
            // scrolls on while they answer.
            let result = await Mirror.reconcile(context, onlyChangedHere: !theirs)
            if !Task.isCancelled, context.hasChanges {
                reconciling = true
                try? context.save()
                reconciling = false
            }
            if result.pushed + result.pulled > 0 { last = result; lastAt = Date() }
            try? await Task.sleep(for: .seconds(0.5))
            running = false
            if again { again = false; soon() }
        }
    }
}
