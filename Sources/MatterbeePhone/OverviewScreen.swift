import MatterCore
import SwiftData
import SwiftUI

/// The overview, with each matter pushed on it, and the assistant as a sheet over both.
struct RootView: View {
    @State private var navigation = Navigation()
    @Environment(\.modelContext) private var context
    @Query private var matters: [Matter]
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            OverviewScreen(matters: matters)
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    if let matter = matters.first(where: { $0.persistentModelID == id }) {
                        MatterScreen(matter: matter)
                    } else {
                        ContentUnavailableView("This matter is gone", systemImage: "folder.badge.questionmark",
                                               description: Text("It was merged or removed on another device."))
                    }
                }
        }
        .tint(Theme.gold)
        .sheet(isPresented: $navigation.showsAssistant) {
            AssistantSheet(matter: navigation.path.last.flatMap { id in matters.first { $0.persistentModelID == id } })
                .presentationDragIndicator(.visible)
        }
        .modifier(MatterQuestions())
        // What is connected to Calendar and Reminders is kept in step both ways, as on the Mac.
        .onAppear { MirrorRunner.shared.start(context) }
        // This iPhone's list of names into the store when it goes to the background, as the Mac's.
        .onChange(of: phase) { _, now in if now == .background { PhoneNames.publish(in: context) } }
        .environment(\.reading, navigation.reading)
        .environment(navigation)
    }
}

/// Every matter with something going on, as cards, each a door into its page. Worked out on the
/// iPhone; nothing is sent.
struct OverviewScreen: View {
    let matters: [Matter]
    @Environment(Navigation.self) private var navigation
    @Environment(PhoneStore.self) private var store
    @State private var search = ""
    @Environment(\.modelContext) private var context
    @State private var editsAccount = false

    private var ordered: [Matter] { activeMatters(matters) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Overview").font(Theme.phoneTitleFont)
                    Text(summary).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                // The demo's matters are made up: no real mail comes into them.
                if !store.isDemo { PhoneMailCheckView() }
                searchField
                if matters.isEmpty {
                    empty
                }
                ForEach(ordered) { matter in
                    PhoneMatterCard(matter: matter) { todo in navigation.open(matter, showing: todo) }
                }
                ForEach(matters.filter { $0.isClosed && !MatterStatus($0).mailsSinceClosed.isEmpty }) { matter in
                    let new = MatterStatus(matter).mailsSinceClosed.count
                    Button { navigation.open(matter) } label: {
                        HStack {
                            Image(systemName: "archivebox").foregroundStyle(.secondary)
                            Text("\(new) new \(new == 1 ? "mail" : "mails") in the closed matter “\(matter.name)”").multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .font(.subheadline).padding(14).phoneBox()
                    }
                    .buttonStyle(.plain)
                }
                let quiet = matters.filter { !$0.isClosed }.count - ordered.count
                if quiet > 0 {
                    Text("\(quiet) \(quiet == 1 ? "matter is" : "matters are") quiet: nothing open, no date.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                // Every matter, as the Mac's sidebar lists them: the quiet and the closed ones too.
                if !matters.isEmpty { AllMattersList(matters: matters) }
                if store.isDemo {
                    Button("Leave the demo") { store.switchDemo(false) }
                        .font(.footnote).foregroundStyle(Theme.gold).padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.immediately)
        // Pulled down: new mail is read — free — and waits for "Sort in".
        .refreshable { if !store.isDemo { PhoneMailCheck.shared.look(context: context) } }
        .background(Theme.canvas)
        // No assistant here, as on the Mac: it opens from a matter, about that matter.
        // The ⋯ in the bar, drawn by the system as in a matter: a glass of our own on it, and the
        // bar hidden here and shown there, broke the swipe back from a matter (iOS 27).
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Settings …") { editsAccount = true }
                    Button(store.isDemo ? "Leave the demo" : "Try the demo") { store.switchDemo(!store.isDemo) }
                } label: { Image(systemName: "ellipsis") }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editsAccount) { SettingsSheet() }
    }

    private var summary: String {
        let open = ordered.count
        let overdue = ordered.filter { !MatterStatus($0).overdue.isEmpty }.count
        var text = open == 1 ? "One matter is going on." : "\(open) matters are going on."
        if overdue > 0 { text += overdue == 1 ? " One has something overdue." : " \(overdue) have something overdue." }
        return text
    }

    /// On top of the cards: a matter found by its name, a task or a mail.
    @ViewBuilder
    private var searchField: some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find or start a matter", text: $search)
                    .font(.body)
                    .submitLabel(.go)
                    .onSubmit {
                        let hits = MatterSearch.find(query, in: matters)
                        if let first = hits.first { search = ""; navigation.open(first.matter) } else if !query.isEmpty { start(query) }
                    }
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
            if !query.isEmpty {
                let hits = MatterSearch.find(query, in: matters)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                        if index > 0 { Divider().padding(.leading, 14) }
                        Button { search = ""; navigation.open(hit.matter) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.matter.name + (hit.matter.isClosed ? " · closed" : "")).foregroundStyle(.primary)
                                if let because = hit.because { Text(because).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if !hits.isEmpty { Divider().padding(.leading, 14) }
                    // Made here, nothing sent: the Mac sorts mail into it from the next "Get new mail".
                    Button { start(query) } label: {
                        Label("Start new matter: “\(query)”", systemImage: "plus.circle")
                            .fontWeight(.medium).foregroundStyle(.primary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .phoneCard()
            }
        }
    }

    private func start(_ name: String) {
        guard let matter = try? Matter.make(named: name, in: context) else { return }
        search = ""
        navigation.open(matter)
    }

    /// Nothing here yet: iCloud may still be bringing the matters, or they are made on the Mac.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No matters yet").font(.headline)
            Text(PhoneCloud.container == nil
                 ? "This store stays on the iPhone."
                 : "Matterbee on your Mac takes in the mail and makes the matters. They come here through your iCloud — the first time can take a few minutes.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !store.isDemo {
                Button("Try the demo") { store.switchDemo(true) }.buttonStyle(.phoneFilled)
            }
        }
        .phoneBox()
    }
}
