import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// Everything a new owner needs before the first mail is sorted, one step at a time: who they are,
/// which AI and its key, the mail account and its label, and the calendar. Each step shows whether
/// it is done already, so the assistant can be opened again at any time and only asks what is missing.
/// Nothing in it costs money: a key is checked by listing the models, which is free, and mail is
/// only read, never sorted, until the owner clicks "Sort in" later.
/// Where the setup keeps what it learns: the Keychain, the settings and the store — or, started with
/// `--fresh-setup`, only this run's memory. The test mode begins with nothing set up and keeps nothing,
/// so the owner can go through the whole setup as a new person would, on their own Mac, and their key,
/// mail password and settings stay as they were. Keys and logins are still checked for real.
@MainActor
enum SetupState {
    static let isFresh = CommandLine.arguments.contains("--fresh-setup")

    private static var keys: [String: String] = [:]
    private static var account: (MailAccount, String)?
    private static var calendarConnected = false
    private static var model = Claude.Model.opus
    /// The names typed in the test: the demo's store is not written to.
    static var names: [String] = []

    static var mailModel: Claude.Model { isFresh ? model : ModelChoice.mail }

    static func choose(_ chosen: Claude.Model) {
        if isFresh { model = chosen; return }
        UserDefaults.standard.set(chosen.id, forKey: ModelChoice.mailKey)
        UserDefaults.standard.set(chosen.id, forKey: ModelChoice.assistantKey)
    }

    static func hasKey(for model: Claude.Model) -> Bool {
        isFresh ? keys[model.keyName] != nil : Claude.key(for: model) != nil
    }

    static func saveKey(_ key: String, for model: Claude.Model) throws {
        if isFresh { keys[model.keyName] = key } else { try APIKeys.save(key, as: model.keyName) }
    }

    static var mailAccount: MailAccount? { isFresh ? account?.0 : Keychain.accounts().first }

    static func save(_ password: String, for mail: MailAccount) throws {
        if isFresh { account = (mail, password) } else { try Keychain.save(password, for: mail) }
    }

    /// The app password, or for an address signed in with Google a token that works now.
    static func password(for mail: MailAccount) async throws -> String? {
        isFresh ? account?.1 : try await MailSecret.secret(for: mail)
    }

    static func forget(_ mail: MailAccount) {
        if isFresh { account = nil } else { try? Keychain.delete(account: mail.user) }
    }

    static var isCalendarConnected: Bool {
        isFresh ? calendarConnected : Calendars.shared.canReadEvents || Calendars.shared.canReadReminders
    }

    /// In the test, only noted: asking macOS again changes nothing it already allowed.
    static func connectCalendar() async {
        if isFresh { calendarConnected = true } else { _ = await Calendars.shared.requestAccess() }
    }
}

struct SetupAssistant: View {
    /// The owner chose "Later": not shown by itself again. Still in the Causabee menu.
    static let laterKey = "setup.later"

    /// The two things Causabee cannot work without: a key for the model that sorts mail, and a mail account.
    @MainActor static var isMissingSomething: Bool {
        !SetupState.hasKey(for: SetupState.mailModel) || SetupState.mailAccount == nil
    }

    enum Step: Int, CaseIterable, Identifiable {
        case you, ai, mail, calendar, ready
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .you: "About you"
            case .ai: "AI and API key"
            case .mail: "Mail"
            case .calendar: "Calendar"
            case .ready: "Ready"
            }
        }
        var icon: String {
            switch self {
            case .you: "person"
            case .ai: "key"
            case .mail: "envelope"
            case .calendar: "calendar"
            case .ready: "checkmark.seal"
            }
        }
    }

    /// Starts "Get new mail" in the sidebar: reading only.
    var getMail: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @AppStorage(SetupAssistant.laterKey) private var later = false
    @State private var step: Step = .you
    /// Counts up after a step changed something outside SwiftUI — the Keychain, the calendar's access.
    @State private var tick = 0

    var body: some View {
        HStack(spacing: 0) {
            steps
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(step.title).font(Theme.titleFont)
                        page
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                buttons.padding(.horizontal, 24).padding(.vertical, 16)
            }
        }
        .frame(width: 860, height: 620)
        .background(Theme.canvas)
    }

    // MARK: The list of steps

    private func isDone(_ step: Step) -> Bool {
        _ = tick
        switch step {
        case .you: return !(SetupState.isFresh ? SetupState.names : profiles.first?.names ?? []).isEmpty
        case .ai: return SetupState.hasKey(for: SetupState.mailModel)
        case .mail: return SetupState.mailAccount != nil
        case .calendar: return SetupState.isCalendarConnected
        case .ready: return !SetupAssistant.isMissingSomething
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set up Causabee").font(.headline).padding(.bottom, SetupState.isFresh ? 4 : 12)
            if SetupState.isFresh {
                Text("Test mode: nothing is saved").font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.bee, in: Capsule()).foregroundStyle(.black)
                    .padding(.bottom, 12)
            }
            ForEach(Step.allCases) { item in
                Button { step = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isDone(item) ? "checkmark.circle.fill" : item.icon)
                            .foregroundStyle(isDone(item) ? Theme.done : .secondary)
                            .frame(width: 18)
                        Text(item.title)
                        Spacer()
                        if item == .calendar { Text("optional").font(.caption2).foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(step == item ? Theme.mark : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Label("Nothing here costs money. Mail is only read until you click “Sort in”.", systemImage: "lock")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 230)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SidebarMaterial())
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .you: YouStep(names: SetupState.isFresh ? SetupState.names : profiles.first?.names ?? []) { names in saveNames(names) }
        case .ai: AIStep { tick += 1 }
        case .mail: MailStep { tick += 1 }
        case .calendar: CalendarStep { tick += 1 }
        case .ready: readyPage
        }
    }

    private var buttons: some View {
        HStack {
            if step == .you {
                Button("Later") { if !SetupState.isFresh { later = true }; dismiss() }
                    .help("Close for now. Causabee → Set Up Causabee … opens it again.")
            } else {
                Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .you }
            }
            Spacer()
            if step == .ready {
                Button("Close") { dismiss() }
                // The test reads no mail: its account is only in memory, and its matters are the demo's.
                Button(SetupState.isFresh ? "Finish test" : "Get new mail") { dismiss(); if !SetupState.isFresh { getMail() } }
                    .buttonStyle(.borderedProminent).tint(Theme.ink)
                    .disabled(SetupAssistant.isMissingSomething)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(step == .calendar && !isDone(.calendar) ? "Skip" : "Next") { step = Step(rawValue: step.rawValue + 1) ?? .ready }
                    .buttonStyle(.borderedProminent).tint(Theme.ink)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }

    private func saveNames(_ names: [String]) {
        if SetupState.isFresh { SetupState.names = names; tick += 1; return }
        if let profile = profiles.first { profile.names = names } else { context.insert(Profile(names: names)) }
        try? context.save()
    }

    // MARK: Ready

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Step.allCases.filter { $0 != .ready }) { item in
                Button { step = item } label: {
                    Label {
                        Text(item.title + (isDone(item) ? "" : item == .calendar ? " — not connected, you can do it later" : " — still missing"))
                    } icon: {
                        Image(systemName: isDone(item) ? "checkmark.circle.fill" : item == .calendar ? "circle" : "exclamationmark.circle")
                            .foregroundStyle(isDone(item) ? Theme.done : item == .calendar ? .secondary : Theme.warning)
                    }
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.vertical, 4)
            Text("How it goes from here")
                .font(.headline)
            Hint(number: 1, text: "Put the label “Causabee” on the mails you want sorted. Start with a few from one matter.")
            Hint(number: 2, text: "Click “Get new mail”. Causabee reads them for free and tells you what sorting will cost.")
            Hint(number: 3, text: "Click “Sort in”. Each mail is sorted once, into a matter with its tasks, dates and people.")
            Hint(number: 4, text: "Drop a screenshot or a PDF onto the window any time. It is sorted the same way.")
        }
    }
}

private struct Hint: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)").font(.callout.weight(.semibold))
                .frame(width: 22, height: 22).background(Theme.bee, in: Circle()).foregroundStyle(.black)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A line under a field: grey, and wrapping.
private struct Explain: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}

/// A result: done in grey with a tick, a problem in orange.
private struct Outcome: View {
    let text: String
    let good: Bool
    var body: some View {
        Label(text, systemImage: good ? "checkmark.circle.fill" : "exclamationmark.triangle")
            .foregroundStyle(good ? Theme.done : Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

// MARK: 1 · About you

private struct YouStep: View {
    let names: [String]
    let save: ([String]) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Explain("Your name and the email addresses you use, one per line. Causabee needs them to tell you apart from everyone else: you are never listed as a person in your own matters, and tasks for you are marked “Mine”.")
            TextEditor(text: $text)
                .font(.body)
                .frame(height: 110)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.strongLine))
            Explain("Add a nickname if people write to you by it.")
        }
        .onAppear {
            text = (names.isEmpty ? [NSFullUserName()] : names).joined(separator: "\n")
        }
        .onChange(of: text) {
            let names = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            save(names)
        }
    }
}

// MARK: 2 · AI and key

private struct AIStep: View {
    let changed: () -> Void

    enum Provider: String, CaseIterable, Identifiable {
        case claude, mistral, openai
        var id: String { rawValue }
        var model: Claude.Model {
            switch self {
            case .claude: .opus
            case .mistral: .mistralLarge
            case .openai: .gptSol
            }
        }
        var name: String {
            switch self {
            case .claude: "Claude (Anthropic)"
            case .mistral: "Mistral"
            case .openai: "OpenAI"
            }
        }
        var about: String {
            switch self {
            case .claude: "Recommended. Best at finding the real tasks in a mail. Servers in the USA."
            case .mistral: "From Paris, in the EU. Cheaper, and sorts almost as well."
            case .openai: "Servers in the USA."
            }
        }
        var keyPage: URL {
            switch self {
            case .claude: URL(string: "https://console.anthropic.com/settings/keys")!
            case .mistral: URL(string: "https://console.mistral.ai/api-keys")!
            case .openai: URL(string: "https://platform.openai.com/api-keys")!
            }
        }
    }

    @State private var pasted = ""
    @State private var checking = false
    @State private var result: (text: String, good: Bool)?
    @State private var tick = 0

    private var provider: Provider {
        let _ = tick
        let model = SetupState.mailModel
        return model.isMistral ? .mistral : model.isOpenAI ? .openai : .claude
    }

    var body: some View {
        let _ = tick
        let hasKey = SetupState.hasKey(for: provider.model)
        VStack(alignment: .leading, spacing: 14) {
            Explain("Causabee uses an AI to read each mail and find its matter, tasks and dates. You pay the AI company yourself, by use. Before anything is sent, names, addresses and numbers are replaced.")
            Picker("AI", selection: Binding(get: { provider }, set: { choose($0) })) {
                ForEach(Provider.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Explain(provider.about + String(format: " About %.1f cents per mail.", provider.model.perMail * 100))

            if hasKey {
                Outcome(text: "The \(provider.name) key is saved\(SetupState.isFresh ? " for this test only" : " in the Keychain").", good: true)
            }
            Text(hasKey ? "Replace the key" : "Your API key").font(.headline).padding(.top, 6)
            HStack {
                SecureField("Paste the key", text: $pasted).textFieldStyle(.roundedBorder)
                Button(checking ? "Checking …" : "Check and save") { check() }
                    .disabled(checking || pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let result { Outcome(text: result.text, good: result.good) }
            Link("Where do I get a key? Open the \(provider.name) console →", destination: provider.keyPage)
                .foregroundStyle(Theme.gold)
            Explain("Make an account there, add a little credit — five or ten euros goes a long way — and make a new key. It is kept in your Mac's Keychain, never in a file. Checking it is free.")
        }
    }

    private func choose(_ provider: Provider) {
        SetupState.choose(provider.model)
        tick += 1
        result = nil
        changed()
    }

    private func check() {
        let key = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = provider
        checking = true
        result = nil
        Task {
            let answer = await KeyCheck.check(key, for: provider)
            if answer.good {
                do {
                    try SetupState.saveKey(key, for: provider.model)
                    pasted = ""
                    result = ("The key works, and is saved\(SetupState.isFresh ? " for this test only" : " in the Keychain").", true)
                } catch {
                    result = ("The key works, but could not be saved: \(error)", false)
                }
            } else {
                result = (answer.text, false)
            }
            checking = false
            tick += 1
            changed()
        }
    }
}

/// Asks the provider for its list of models with the key: free, and it says whether the key is good.
private enum KeyCheck {
    static func check(_ key: String, for provider: AIStep.Provider) async -> (text: String, good: Bool) {
        var request: URLRequest
        switch provider {
        case .claude:
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1")!)
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .mistral:
            request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/models")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .openai:
            request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 20
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200: return ("", true)
            case 401, 403: return ("\(provider.name) did not accept this key. Check that it was copied in full.", false)
            default: return ("Could not check the key: \(provider.name) answered \(status). Try again in a moment.", false)
            }
        } catch {
            return ("Could not reach \(provider.name): \(error.localizedDescription)", false)
        }
    }
}

// MARK: 3 · Mail

private struct MailStep: View {
    let changed: () -> Void
    @State private var address = ""
    @State private var password = ""
    @State private var server = ""
    @State private var working = false
    @State private var result: (text: String, good: Bool)?
    /// What the label check found: nil until it was looked at.
    @State private var label: (found: Bool, mails: Int)?
    @State private var flow = GoogleSignInFlow()
    /// The last result came from Google's button, and is shown under it.
    @State private var googleTried = false
    @State private var tick = 0

    private let labelName = "Causabee"

    private var known: MailAccount? { MailAccount(user: address.trimmingCharacters(in: .whitespaces)) }
    private var isGmail: Bool { (known?.host ?? server).contains("gmail") }

    var body: some View {
        let _ = tick
        let saved = SetupState.mailAccount
        VStack(alignment: .leading, spacing: 14) {
            Explain("Causabee reads your mail the way a mail app does, with a password made just for it. It only reads: it never sends, deletes, moves or marks mail as read.")
            if let saved {
                Outcome(text: "Connected: \(saved.user)" + (saved.usesGoogle ? ", signed in with Google" : " on \(saved.host)"), good: true)
                labelSection(saved)
            } else {
                login
            }
        }
    }

    // A password for Causabee alone, where the provider makes one.
    private var login: some View {
        VStack(alignment: .leading, spacing: 12) {
            if GoogleSignIn.isConfigured {
                google
            }
            TextField("Email address", text: $address).textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
            if !address.contains("@") || known != nil {
                EmptyView()
            } else {
                TextField("Mail server (IMAP), for example imap.example.com", text: $server).textFieldStyle(.roundedBorder)
                Explain("Only Gmail and iCloud addresses are known. For any other address, your mail provider tells you its IMAP server. A Google Workspace address on its own domain: imap.gmail.com.")
            }
            SecureField("App password", text: $password).textFieldStyle(.roundedBorder)
            if known?.host == "imap.mail.me.com" {
                Explain("iCloud: make an app-specific password at account.apple.com → Sign-In and Security → App-Specific Passwords.")
                Link("Open account.apple.com →", destination: URL(string: "https://account.apple.com")!).foregroundStyle(Theme.gold)
            } else {
                Explain("Gmail: turn on 2-Step Verification, then make an app password named “Causabee”. Your normal Google password does not work here.")
                Link("Open Google app passwords →", destination: URL(string: "https://myaccount.google.com/apppasswords")!).foregroundStyle(Theme.gold)
            }
            HStack {
                Button(working ? "Logging in …" : "Log in") { logIn() }
                    .disabled(working || !address.contains("@") || password.isEmpty || (known == nil && server.isEmpty))
                if working { ProgressView().controlSize(.small) }
            }
            if let result, !googleTried { Outcome(text: result.text, good: result.good) }
            Divider().padding(.vertical, 4)
            labelHowTo(gmail: known?.host != "imap.mail.me.com" && (known != nil || server.isEmpty || isGmail))
        }
    }

    /// How the mail gets to Causabee: one label in Gmail, one folder anywhere else — shown before
    /// logging in too, since it is the first thing a new owner has to understand.
    private func labelHowTo(gmail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(gmail ? "The label “\(labelName)” in Gmail" : "The folder “\(labelName)”").font(.headline).padding(.top, 6)
            Explain(gmail
                    ? "Causabee reads only the mail that has the label “\(labelName)”. Nothing else in your mailbox is read. You decide what it sees by putting the label on a mail."
                    : "Causabee reads only the mail in the folder “\(labelName)”. Nothing else in your mailbox is read. You decide what it sees by moving a mail there.")
            if gmail {
                Hint(number: 1, text: "In Gmail, on the left, click “+” next to Labels and make a label called “\(labelName)”.")
                Hint(number: 2, text: "Open a mail, click the label icon, and tick “\(labelName)”. Start with a few mails from one matter.")
                Hint(number: 3, text: "Replies in the same thread are found by themselves: label a thread once.")
                Explain("Tip: a Gmail filter can put the label on mail from the school, the landlord or the insurer by itself. The label stays on the mail; you can take it off at any time.")
            } else {
                Hint(number: 1, text: "In your mail app or on the provider's website, make a folder called “\(labelName)”.")
                Hint(number: 2, text: "Move or copy the mails you want sorted into it. Start with a few from one matter.")
                Hint(number: 3, text: "The name must be “\(labelName)”. Capitals do not matter.")
            }
        }
    }

    @ViewBuilder
    private func labelSection(_ account: MailAccount) -> some View {
        labelHowTo(gmail: account.host.contains("gmail"))
        if let label {
            if label.found {
                Outcome(text: "Found “\(labelName)”, with \(label.mails) \(label.mails == 1 ? "mail" : "mails").", good: true)
            } else {
                Outcome(text: "There is no “\(labelName)” yet. Make it, put it on a few mails, then check again.", good: false)
            }
        }
        HStack {
            Button(working ? "Looking …" : label == nil ? "Look for the label" : "Check again") { lookForLabel(account) }
                .disabled(working)
            if working { ProgressView().controlSize(.small) }
            Spacer()
            Button("Use another account") {
                SetupState.forget(account)
                label = nil
                tick += 1
                changed()
            }
            .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        if let result, !result.good { Outcome(text: result.text, good: false) }
    }

    /// Gmail and Google Workspace without an app password: Google's own page, in the Mac's sign-in window.
    private var google: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { signInWithGoogle() } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle.badge.checkmark")
            }
            .inkButton()
            .disabled(working)
            Explain("For Gmail and Google Workspace. No app password needed: you sign in on Google's page, and Google shows what Causabee may do. Causabee only reads, and writes nothing but a draft when you click for one.")
            if let result, working == false, googleTried { Outcome(text: result.text, good: result.good) }
            HStack {
                VStack { Divider() }
                Text("or with an app password").font(.caption).foregroundStyle(.secondary)
                VStack { Divider() }
            }
            .padding(.vertical, 6)
        }
    }

    private func signInWithGoogle() {
        working = true
        result = nil
        googleTried = true
        Task {
            do {
                let hint = address.contains("@") ? address.trimmingCharacters(in: .whitespaces) : nil
                let (account, token) = try await flow.signIn(hint: hint, keep: !SetupState.isFresh)
                // In the test only in memory; otherwise the refresh token is in the Keychain already.
                if SetupState.isFresh { try SetupState.save(token, for: account) }
                let client = try await IMAPClient.connect(to: account, password: token)
                label = await count(in: (try? await client.folders()) ?? [], client: client)
                await client.logout()
                result = ("Signed in with Google as \(account.user).", true)
            } catch where GoogleSignInFlow.wasCancelled(error) {
                result = nil
            } catch {
                result = ("Not signed in: \(error)", false)
            }
            working = false
            tick += 1
            changed()
        }
    }

    private func logIn() {
        googleTried = false
        let user = address.trimmingCharacters(in: .whitespaces)
        guard let account = known ?? (server.isEmpty ? nil : MailAccount(user: user, host: server.trimmingCharacters(in: .whitespaces))) else { return }
        // Google shows an app password as four groups of four. The spaces are not part of it.
        let secret = account.host == "imap.gmail.com" ? password.replacingOccurrences(of: " ", with: "") : password
        working = true
        result = nil
        Task {
            do {
                let client = try await IMAPClient.connect(to: account, password: secret)
                let folders = (try? await client.folders()) ?? []
                label = await count(in: folders, client: client)
                await client.logout()
                try SetupState.save(secret, for: account)
                password = ""
                result = ("Logged in. The password is saved\(SetupState.isFresh ? " for this test only" : " in the Keychain").", true)
            } catch {
                result = ("Not logged in: \(error)", false)
            }
            working = false
            tick += 1
            changed()
        }
    }

    private func lookForLabel(_ account: MailAccount) {
        working = true
        result = nil
        Task {
            do {
                guard let secret = try await SetupState.password(for: account) else { throw CocoaError(.userCancelled) }
                let client = try await IMAPClient.connect(to: account, password: secret)
                label = await count(in: try await client.folders(), client: client)
                await client.logout()
            } catch {
                result = ("Could not look: \(error)", false)
            }
            working = false
        }
    }

    private func count(in folders: [MailFolder], client: IMAPClient) async -> (found: Bool, mails: Int) {
        // Found as "Get new mail" finds it: the exact name first, then in any capitals.
        guard let folder = folders.first(where: { $0.name == labelName })
                ?? folders.first(where: { $0.name.lowercased() == labelName.lowercased() }) else { return (false, 0) }
        let opened = try? await client.examine(folder.name)
        return (true, opened?.exists ?? 0)
    }
}

// MARK: 4 · Calendar

private struct CalendarStep: View {
    let changed: () -> Void
    @State private var tick = 0

    var body: some View {
        let _ = tick
        let calendars = Calendars.shared
        VStack(alignment: .leading, spacing: 14) {
            Explain("Appointments and deadlines can go into Calendar, and tasks into Reminders, with one click. Causabee also sees what is already there, so nothing is added twice. It only adds what you click.")
            if SetupState.isCalendarConnected {
                Outcome(text: "Connected\(calendars.canReadEvents ? " to Calendar" : "")\(calendars.canReadEvents && calendars.canReadReminders ? " and" : "")\(calendars.canReadReminders ? " to Reminders" : "").", good: true)
            } else if calendars.asked, !SetupState.isFresh {
                Outcome(text: "No access. Allow it in System Settings → Privacy & Security → Calendars and Reminders.", good: false)
            } else {
                Button("Connect Calendar and Reminders") {
                    Task { await SetupState.connectCalendar(); tick += 1; changed() }
                }
            }
            Explain("You can skip this and connect later in Settings (⌘,).")
        }
    }
}
