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

    private func publish() {
        let open = matters.filter { !$0.isClosed }
            .map { ($0, MatterStatus($0).lastDate) }
            .sorted { ($0.1 ?? .distantPast) > ($1.1 ?? .distantPast) }
        ShareInbox.publish(open.map { ShareInbox.Choice(key: $0.0.key, name: $0.0.name, last: $0.1) })
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
