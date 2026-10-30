import MatterCore
import SwiftData
import SwiftUI

/// The app's side of the share sheet: it tells the share sheet which matters there are — the
/// open ones, the newest mail first — and brings in what was shared meanwhile, each into the
/// assistant of the matter chosen, scanned, waiting for "Sort in", as the paperclip does.
struct SharedIn: ViewModifier {
    let matters: [Matter]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Environment(Navigation.self) private var navigation
    @Query private var profiles: [Profile]

    func body(content: Content) -> some View {
        content
            .onAppear { publish(); takeIn() }
            .onChange(of: phase) { _, now in
                if now == .active { takeIn() }
                if now != .active { publish() }
            }
            .onChange(of: matters.count) { publish() }
    }

    /// Every mail's day read for it — a third of a second as Causabee started, on the main thread:
    /// by the worker now.
    private func publish() {
        let worker = StoreWorker.for(context.container)
        Task {
            let open = await worker.openMattersByLastMail()
            ShareInbox.publish(open.map { ShareInbox.Choice(key: $0.key, name: $0.name, last: $0.last) })
        }
    }

    private func takeIn() {
        let waiting = ShareInbox.takeAll()
        guard !waiting.isEmpty else { return }
        var into: Matter?
        for (item, data) in waiting {
            guard let file = PhoneShots.shared.keep(data, named: item.name) else { continue }
            let matter = item.matterKey.flatMap { key in matters.first { $0.key == key } }
            PhoneShots.shared.bring(file, matter: matter?.persistentModelID, context: context, owner: profiles.first?.names.first)
            into = matter
        }
        // Where the last one went, with the assistant open over it.
        if let into { navigation.open(into) } else { navigation.path = [] }
        navigation.showsAssistant = true
    }
}
