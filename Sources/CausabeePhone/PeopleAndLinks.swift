import MatterCore
import SwiftData
import SwiftUI

/// A matter's people, as the Mac lists them: named most often first, "Same person?" asked where
/// two names are likely one, and each changed, merged, talked about or taken out of the matter.
struct PeopleSection: View {
    let matter: Matter
    /// A tap on a person: their part of the record.
    var choose: ((Party) -> Void)? = nil
    @Environment(\.modelContext) private var context
    @State private var merging: (Party, Party)?
    @State private var adding = false

    private var origin: String { "you, in \(matter.name), \(Dates.short(Date()))" }

    var body: some View {
        let memberships = MatterStatus(matter).memberships
        if memberships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "People")
                PhoneEmptyBox(text: "Who writes and who is named come in with mail and screenshots — or add a contact yourself.",
                              action: "Add Contact", symbol: "person.badge.plus") { adding = true }
            }
            .sheet(isPresented: $adding) { ContactEditor(matter: matter) }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "People", detail: memberships.count == 1 ? "1 name" : "\(memberships.count) names")
                let rules = (try? context.fetch(FetchDescriptor<Rule>())) ?? []
                let suggestions = PartyBook.suggestions(in: matter, rules: rules)
                if !suggestions.isEmpty {
                    PhoneSuggestionCard(suggestions: suggestions) { suggestion in
                        confirmSame(suggestion.party, as: suggestion.into)
                    } refuse: { suggestion in
                        PartyBook.refuseSame(suggestion.party, as: suggestion.into, in: matter, context: context, origin: origin)
                        try? context.save()
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(memberships.enumerated()), id: \.element.persistentModelID) { index, membership in
                        if index > 0 { Divider().padding(.leading, 50) }
                        if let party = membership.party {
                            PhonePartyRow(party: party, membership: membership, matter: matter,
                                          save: { name, role in edit(party, membership: membership, name: name, role: role) },
                                          remove: {
                                              withAnimation { membership.remove(in: context, origin: origin) }
                                              try? context.save()
                                          },
                                          merge: { other in merging = (party, other) })
                                .contentShape(Rectangle())
                                .onTapGesture { choose?(party) }
                        }
                    }
                }
                .phoneCard()
            }
            .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } }),
                                titleVisibility: .visible) {
                Button("Merge") { if let (party, other) = merging { confirmSame(party, as: other) } }
                Button("Cancel", role: .cancel) { merging = nil }
            } message: {
                Text("This also counts for the next mail. You can undo it in the rules.")
            }
        }
    }

    private var mergeQuestion: String {
        guard let (party, other) = merging else { return "" }
        return "Is “\(party.name)” the same as “\(other.name)”?"
    }

    /// By hand, and free: nothing is sent. A new name is kept as a rule, like one from the assistant.
    private func edit(_ party: Party, membership: Membership, name: String, role: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != party.name {
            let old = party.name
            party.rename(to: name)
            context.insert(Rule(.partyName, subject: old, object: name, matterKey: matter.key, origin: origin))
        }
        if role.trimmingCharacters(in: .whitespaces) != (membership.role ?? "") { membership.setRole(role) }
        try? context.save()
    }

    private func confirmSame(_ party: Party, as other: Party) {
        PartyBook.confirmSame(party, as: other, in: matter, context: context, origin: origin)
        try? context.save()
        merging = nil
    }
}

/// One person, as the Mac's row: name and role, other spellings, the other matters they are in,
/// how many of its mails name them — and the ⋯.
struct PhonePartyRow: View {
    let party: Party
    let membership: Membership
    let matter: Matter
    let save: (String, String) -> Void
    let remove: () -> Void
    let merge: (Party) -> Void
    @Environment(Navigation.self) private var navigation
    @State private var editing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Text(party.name).fontWeight(.medium))\(Text(membership.role.map { " · \($0)" } ?? "").foregroundStyle(.secondary))")
                    .fixedSize(horizontal: false, vertical: true)
                // How much they are in the matter — the one named most in gold.
                if let share = membership.share {
                    Text(share.isMost ? share.text + " · the most" : share.text).font(.caption)
                        .foregroundStyle(share.isMost ? Theme.gold : .secondary)
                }
                MailAddressLine(addresses: CardActions.addresses(of: party))
                ContactActions(party: party)
                let also = party.otherSpellings
                if !also.isEmpty {
                    Text("also written: " + also.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                let elsewhere = party.matters.filter { $0 !== matter }.map(\.name)
                if !elsewhere.isEmpty {
                    Text("also in: " + elsewhere.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Menu { items } label: {
                Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .tint(.secondary)
            .accessibilityLabel("More")
            // While reading, a long press still has everything.
            .tool()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { items }
        .findable(.model(party.persistentModelID), party.name, membership.role)
        .sheet(isPresented: $editing) {
            PartyEditor(party: party, membership: membership, matter: matter, save: save, remove: remove)
        }
    }

    @ViewBuilder
    private var items: some View {
        MailAddressItems(addresses: CardActions.addresses(of: party))
        ContactItems(party: party)
        AskCausabeeButton { navigation.talk(party.name, kind: "Person", in: matter) }
        Button("Edit", systemImage: "pencil") { editing = true }
        Menu("Merge with", systemImage: "arrow.triangle.merge") {
            ForEach(matter.parties.filter { $0 !== party }.sorted { $0.name < $1.name }) { other in
                Button(other.name) { merge(other) }
            }
        }
        Divider()
        Button("Remove", systemImage: "person.badge.minus", role: .destructive, action: remove)
    }
}

/// "Change person", as the Mac asks it.
struct PartyEditor: View {
    let party: Party
    let membership: Membership
    let matter: Matter
    let save: (String, String) -> Void
    let remove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = ""
    @State private var address = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Role in \(matter.name)", text: $role)
                } footer: {
                    Text("The old name stays as a spelling, so new mail still finds the person.")
                }
                Section {
                    TextField("Mail", text: $address).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                }
                Section {
                    Button("Remove from this matter", role: .destructive) { dismiss(); remove() }
                } footer: {
                    Text("Only from this matter. A later mail naming them will not put them back.")
                }
            }
            .navigationTitle("Change person")
            .navigationBarTitleDisplayMode(.inline)
            .keepsWhatWasTyped([name, role, address, phone])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(name, role)
                        let mail = address.trimmingCharacters(in: .whitespacesAndNewlines), number = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                        party.address = mail.isEmpty ? nil : mail
                        party.phone = number.isEmpty ? nil : number
                        try? party.modelContext?.save()
                        dismiss()
                    }
                }
            }
            .onAppear { name = party.name; role = membership.role ?? ""; address = party.address ?? ""; phone = party.phone ?? "" }
        }
    }
}

/// "Same person?" — what is only likely is asked, with its reason, and a no is kept.
struct PhoneSuggestionCard: View {
    let suggestions: [PartyBook.Suggestion]
    let accept: (PartyBook.Suggestion) -> Void
    let refuse: (PartyBook.Suggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Same person? · \(suggestions.count)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                if index > 0 { Divider().padding(.leading, 14) }
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(suggestion.party.name)  →  \(suggestion.into.name)").fontWeight(.medium)
                        Text(suggestion.reason).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Button("Not the same") { refuse(suggestion) }.buttonStyle(.phone(wide: true))
                        Button("Merge") { accept(suggestion) }.buttonStyle(.phone(filled: true, wide: true))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .padding(.bottom, 4)
        .box(radius: 12)
    }
}

/// A matter's links, as the Mac keeps them: a Google Doc, a sheet — opened with a tap, added,
/// changed or taken out; and what the mails hold, offered to keep.
struct LinksSection: View {
    let matter: Matter
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @State private var adding = false
    @State private var showsSuggestions = true
    @State private var searching: String?

    private func newestFirst(_ a: WebLink, _ b: WebLink) -> Bool { a.createdAt > b.createdAt }

    var body: some View {
        let all = (matter.links ?? []).filter(\.isKept).sorted(by: newestFirst)
        let offered = (matter.links ?? []).filter { $0.isSuggestion && !$0.isDismissed }.sorted(by: newestFirst)
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Links", detail: all.isEmpty ? nil : "\(all.count)")
            if !all.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(all.enumerated()), id: \.element.persistentModelID) { index, link in
                        if index > 0 { Divider().padding(.leading, 50) }
                        PhoneLinkRow(link: link, todos: matter.openTodos) {
                            withAnimation { context.deleteByHand([link], undo: undoManager, named: "Remove Link") }
                        }
                    }
                }
                .phoneCard()
            } else if offered.isEmpty {
                PhoneEmptyBox(text: "A Google Doc, a sheet — whatever belongs to this matter.",
                              action: "Add Link", symbol: "link.badge.plus") { adding = true }
            }
            if !offered.isEmpty {
                DisclosureGroup(isExpanded: $showsSuggestions) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(offered.enumerated()), id: \.element.persistentModelID) { index, link in
                            if index > 0 { Divider().padding(.leading, 50) }
                            PhoneSuggestedLinkRow(link: link, mail: (matter.entries ?? []).first { $0.messageID == link.messageID }) {
                                withAnimation { link.isSuggestion = false }
                                try? context.save()
                            } dismiss: {
                                withAnimation { link.isSuggestion = false; link.isDismissed = true }
                                try? context.save()
                            }
                        }
                    }
                    .phoneCard().padding(.top, 6)
                } label: {
                    Text("From the mails · \(offered.count) \(offered.count == 1 ? "suggestion" : "suggestions")").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 8) {
                if let searching {
                    if searching.hasSuffix("…") { ProgressView() }
                    Text(searching).font(.caption).foregroundStyle(.secondary)
                }
                if searching?.hasSuffix("…") != true, !(matter.entries ?? []).isEmpty {
                    Button(matter.linksSearchedAt == nil ? "Look for links in the mails" : "Look in the mails again", action: search)
                        .font(.caption).foregroundStyle(Theme.gold)
                        .tool()
                    if let at = matter.linksSearchedAt, searching == nil {
                        Text("last on \(Dates.short(at))").font(.caption).foregroundStyle(.secondary).tool()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $adding) {
            PhoneLinkEditor(link: nil, todos: matter.openTodos) { address, title, todo in
                guard !(matter.links ?? []).contains(where: { $0.address == address && $0.todo === todo }) else { return }
                let link = WebLink(address: address, title: title)
                context.insert(link)
                link.matter = matter
                link.todo = todo
                try? context.save()
            }
        }
    }

    /// Reads the matter's mails again — read-only, over one connection — and offers the links
    /// in them that matter. Free: nothing is sent but the reading itself.
    private func search() {
        guard let account = Keychain.accounts().first(where: { !$0.usesGoogle }) else {
            searching = "No mail account saved: add it in Settings (⋯ on the overview)."
            return
        }
        let mails = (matter.entries ?? []).filter { $0.source.pointer.hasPrefix("imap://") && !$0.messageID.isEmpty }
            .map { (pointer: $0.source.pointer, id: $0.messageID) }
        searching = "Reading 0 of \(mails.count) mails …"
        Task {
            var found = 0, missing = 0
            do {
                guard let password = try Keychain.password(for: account.user) else { throw MailFetch.Failure.gone(account.user) }
                let client = try await IMAPClient.connect(to: account, password: password)
                for (index, mail) in mails.enumerated() {
                    searching = "Reading \(index + 1) of \(mails.count) mails …"
                    guard let data = try? await MailFetch.message(pointer: mail.pointer, messageID: mail.id, from: client) else { missing += 1; continue }
                    let email = EMLParser.parse(data: data, url: URL(string: mail.pointer) ?? URL(fileURLWithPath: "/"))
                    found += MailLinks.suggest(email.links, messageID: mail.id, to: matter, in: context)
                }
                await client.logout()
                matter.linksSearchedAt = Date()
                try? context.save()
                searching = (found == 0 ? "No new important links found." : "\(found) \(found == 1 ? "link" : "links") suggested.")
                    + (missing > 0 ? " \(missing) \(missing == 1 ? "mail is" : "mails are") no longer in the mailbox." : "")
            } catch {
                searching = plainWords(error)
            }
        }
    }
}

enum LinkIcon {
    static func of(_ link: WebLink) -> String {
        switch link.kind {
        case "Google Doc": "doc.text"
        case "Google Sheet": "tablecells"
        case "Google Slides": "rectangle.on.rectangle"
        case "Google Form": "list.bullet.rectangle"
        case "Google Drive", "Google Docs": "folder"
        default: "link"
        }
    }
}

/// One link: its name, what kind of page, the task it goes with; a tap opens it.
struct PhoneLinkRow: View {
    let link: WebLink
    let todos: [Todo]
    let remove: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var editing = false

    var body: some View {
        // A link a card kept and Undo took out again: gone while this row is drawn once more.
        if link.isDeleted || link.modelContext == nil { EmptyView() } else { row }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: LinkIcon.of(link)).font(.title3).foregroundStyle(.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Button { if let url = link.url { openURL(url) } } label: {
                    Text(link.shownName).multilineTextAlignment(.leading)
                }
                .foregroundStyle(Theme.gold)
                Text("\(link.kind)\(link.todo.map { " · for: \($0.text)" } ?? "") · \(Dates.short(link.createdAt))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Menu { items } label: {
                Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .tint(.secondary)
            .accessibilityLabel("More")
            // While reading, a long press still has everything.
            .tool()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contextMenu { items }
        .findable(.model(link.persistentModelID), link.shownName, link.address)
        .sheet(isPresented: $editing) {
            PhoneLinkEditor(link: link, todos: todos) { address, title, todo in
                link.address = address
                link.title = title
                link.todo = todo
                try? context.save()
            }
        }
    }

    @ViewBuilder
    private var items: some View {
        LinkItems(link: link)
        Button("Edit", systemImage: "pencil") { editing = true }
        Divider()
        Button("Remove", systemImage: "trash", role: .destructive, action: remove)
    }
}

/// A link put in or put right, as the Mac's editor: the address, a name to read, and the task it
/// goes with, if any.
struct PhoneLinkEditor: View {
    let link: WebLink?
    let todos: [Todo]
    let save: (String, String, Todo?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var title = ""
    @State private var todo: PersistentIdentifier?

    var body: some View {
        let valid = WebLink.address(in: address)
        NavigationStack {
            Form {
                Section {
                    TextField("https://docs.google.com/…", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    if !address.isEmpty {
                        Text(valid.map { WebLink.kind(of: URL(string: $0)) } ?? "This is not a web address.")
                            .font(.caption).foregroundStyle(valid == nil ? Theme.warning : .secondary)
                    }
                    TextField("Name, e.g. Cost list", text: $title)
                } footer: {
                    Text("Causabee does not open the link by itself. The assistant learns only the name, never the address.")
                }
                if !todos.isEmpty {
                    Picker("For task", selection: $todo) {
                        Text("none — just for the matter").tag(PersistentIdentifier?.none)
                        ForEach(todos.sorted { $0.text < $1.text }, id: \.persistentModelID) { item in
                            Text(item.text).lineLimit(1).tag(Optional(item.persistentModelID))
                        }
                    }
                }
            }
            .navigationTitle(link == nil ? "Add link" : "Change link")
            .navigationBarTitleDisplayMode(.inline)
            .keepsWhatWasTyped([address, title, todo])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let valid else { return }
                        save(valid, title.trimmingCharacters(in: .whitespacesAndNewlines), todos.first { $0.persistentModelID == todo })
                        dismiss()
                    }
                    .disabled(valid == nil)
                }
            }
            .onAppear {
                if let link {
                    address = link.address
                    title = link.title
                    todo = link.todo?.persistentModelID
                } else if let pasted = UIPasteboard.general.string, let found = WebLink.address(in: pasted), found.lowercased().hasPrefix("http") {
                    // A link just copied is what the owner is about to add.
                    address = found
                }
            }
        }
    }
}

/// A link found in a mail, offered: kept with a tap, or set aside for good.
struct PhoneSuggestedLinkRow: View {
    let link: WebLink
    let mail: Entry?
    let keep: () -> Void
    let dismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: LinkIcon.of(link)).font(.title3).foregroundStyle(.secondary).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Button { if let url = link.url { openURL(url) } } label: {
                        Text(link.shownName).multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Theme.gold)
                    Text("\(link.kind)\(mail.map { " · from the mail of \($0.date.map(Dates.short) ?? "?"): \($0.title)" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            HStack(spacing: 8) {
                Button("Not important", action: dismiss).buttonStyle(.phone(wide: true))
                Button("Keep", action: keep).buttonStyle(.phone(filled: true, wide: true))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
