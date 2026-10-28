import MatterCore
import Network
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Connecting a mail account, one thing per screen — the same on the iPhone, the iPad and the Mac
/// (Figma: Proposals › "Mail setup", 2026-10-28). Errors are prevented rather than reported: the
/// provider is known from the address, a pasted password is checked before it is sent, and the
/// label Causabee reads is made by Causabee when it is not there. The end is how to give Causabee
/// its first mail.
struct MailSetupFlow: View {
    /// Keeps the password: in the Keychain, or — in the Mac's test of the setup — nowhere.
    var save: (String, MailAccount) throws -> Void = { try Keychain.save($0, for: $1) }
    /// In the Mac's setup window: no "Later" of its own, the window has one.
    var embedded = false
    /// Done with an account, or left for later (nil).
    var finished: (MailAccount?) -> Void = { _ in }

    enum Page: Hashable {
        case intro, provider, address, outlook, password, notFound, ownSettings, connecting
        case label, labelFound, done
        case notAccepted, twoStep, offline, failed
    }

    @Environment(\.openURL) private var openURL
    @State private var path: [Page] = [.intro]
    @State private var chosen: MailDiscovery.Kind = .other
    @State private var address = ""
    @State private var provider: MailProvider?
    @State private var finding = false
    @State private var host = ""
    @State private var port = "993"
    @State private var password = ""
    @State private var account: MailAccount?
    @State private var secret = ""
    @State private var steps: [(text: String, state: StatusRow.State)] = []
    @State private var mails = 0
    @State private var working = false
    @State private var failure = ""
    @State private var usualPasswordSent = false
    @State private var clipboardHasText = false
    /// Back from Google's 2-Step page: the check turns to going on.
    @State private var checkedAtGoogle = false
    @FocusState private var typingAddress: Bool

    static let labelName = "Causabee"
    #if os(iOS)
    static let tap = "Tap"
    #else
    static let tap = "Click"
    #endif

    private var page: Page { path.last ?? .intro }
    private var name: String { provider?.name ?? (chosen == .gmail ? "Gmail" : chosen == .icloud ? "iCloud Mail" : "your provider") }
    private var kind: MailProvider.Password { provider?.password ?? (chosen == .gmail ? .google : chosen == .icloud ? .apple : .usual) }
    private var isGmail: Bool { (provider?.kind ?? chosen) == .gmail }
    private var check: PasswordCheck { PasswordCheck.of(password, for: kind) }

    private func step(_ page: Page) -> Int? {
        switch page {
        case .intro, .outlook: nil
        case .provider: 1
        case .address, .notFound, .ownSettings: 2
        case .password, .connecting, .notAccepted, .twoStep, .offline, .failed: 3
        case .label, .labelFound, .done: 4
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
            if !embedded {
                // The system's navigation, in Liquid Glass: its back button and the swipe from the
                // edge, the steps on the bar, and a close button for later.
                NavigationStack(path: Binding(get: { Array(path.dropFirst()) }, set: { path = [path.first ?? .intro] + $0 })) {
                    screen(path.first ?? .intro)
                        .navigationDestination(for: Page.self) { screen($0) }
                }
            } else { framed }
            #else
            framed
            #endif
        }
        .onAppear(perform: lookAtClipboard)
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in lookAtClipboard() }
        #else
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in lookAtClipboard() }
        #endif
    }

    // MARK: The frame

    /// No way back while connecting, nor once it is done.
    private func backHidden(_ page: Page) -> Bool { [.connecting, .labelFound, .done].contains(page) }

    #if os(iOS)
    private func screen(_ page: Page) -> some View {
        ScrollView {
            content(page).padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.canvas)
        .safeAreaBar(edge: .bottom, spacing: 0) { actions(page) }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(backHidden(page))
        .toolbar {
            if let step = step(page) { ToolbarItem(placement: .principal) { Progress(step: step) } }
            if page != .connecting && page != .done {
                ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { finished(nil) }.accessibilityLabel("Later") }
            }
        }
    }
    #endif

    /// In the Mac's setup window: the steps, the page, the buttons under it.
    private var framed: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if path.count > 1, !backHidden(page) { Button("Back") { back() }.buttonStyle(.borderless).foregroundStyle(Theme.gold) }
                Spacer()
                if let step = step(page) { Progress(step: step) }
            }
            content(page)
            Spacer(minLength: 0)
            actions(page)
        }
        .padding(4)
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    @ViewBuilder private func content(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch page {
            case .intro: intro
            case .provider: providers
            case .address: addressPage
            case .outlook: outlook
            case .password: passwordPage
            case .notFound: notFound
            case .ownSettings: ownSettings
            case .connecting: connecting
            case .label: labelPage
            case .labelFound: labelFound
            case .done: done
            case .notAccepted: notAccepted
            case .twoStep: twoStep
            case .offline: offline
            case .failed: failed
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(page)
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
    }

    @ViewBuilder private func actions(_ page: Page) -> some View {
        VStack(spacing: 6) {
            switch page {
            case .intro: primary("Connect my mail") { go(.provider) }
            case .connecting: EmptyView()
            case .address: primary(finding ? "Looking …" : "Continue", enabled: !finding && MailDiscovery.domain(of: address) != nil) { lookUp() }
            case .outlook: primary("Choose another mail") { path = [.intro, .provider] }
            case .password:
                if let catchURL = provider.flatMap(Self.settings) { secondary("Open \(name) settings") { openURL(catchURL) } }
                if kind == .google || kind == .apple || kind == .appPassword, check != .right {
                    primary(kind == .apple ? "Open Apple Account" : kind == .google ? "Open Google" : "Open \(name)") { if let page = provider?.passwordPage ?? makePasswordURL { openURL(page) } }
                    if kind == .google { secondary("Google says app passwords aren’t available") { go(.twoStep) } }
                } else {
                    primary("Connect", enabled: check == .right && !working) { connect() }
                }
            case .ownSettings: primary("Connect", enabled: !host.isEmpty && !password.isEmpty && !working) { connect() }
            case .label: primary(working ? "Making it …" : "Make the label", enabled: !working) { makeLabel() }
            case .labelFound: primary("Continue") { go(.done) }
            case .done: primary("Done") { finished(account) }
            case .notAccepted:
                if kind == .google || kind == .apple || kind == .appPassword { primary("Make a new app password") { if let page = provider?.passwordPage ?? makePasswordURL { openURL(page) }; password = ""; path.removeLast() } }
                else { primary("Type it again") { password = ""; path.removeLast() } }
                secondary("Paste again") { password = ""; path.removeLast() }
            case .twoStep:
                if checkedAtGoogle {
                    primary("It’s on — continue") { toAppPassword() }
                    secondary("Open Google again") { openTwoStep() }
                } else {
                    primary("Check at Google") { openTwoStep() }
                    secondary("It’s already on") { toAppPassword() }
                }
            case .offline, .failed: primary("Try again now") { replaceTop(.connecting); connect() }; secondary("Check the settings") { path.removeLast() }
            default: EmptyView()
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, embedded ? 4 : 24)
        .padding(.top, 12)
        .padding(.bottom, embedded ? 4 : 8)
    }

    // MARK: 1 · Start

    @ViewBuilder private var intro: some View {
        BeeMark(size: 30).foregroundStyle(Theme.beeMark)
        title("Let Causabee read the mail you choose")
        lead("It sorts that mail into matters, with its tasks and dates. Three promises first:")
        Promise(icon: "envelope", title: "Only the mail you choose", detail: "Causabee reads mail you give the label “\(Self.labelName)” — nothing else in your mailbox.")
        Promise(icon: "checkmark.shield", title: "It only reads", detail: "It never sends, deletes or moves mail, and leaves it unread. The one thing it adds is its label, when you say so.")
        Promise(icon: "key", title: "Your password stays yours", detail: "You make a password just for Causabee. It is kept in your iCloud Keychain and goes only to your mail provider.")
    }

    @ViewBuilder private var providers: some View {
        title("Which mail do you use?")
        lead("Pick the one you want Causabee to read. You can add another later.")
        ProviderTile(mark: "G", title: "Gmail", detail: "Also Google Workspace at work") { choose(.gmail) }
        ProviderTile(mark: "iC", title: "iCloud Mail", detail: "@icloud.com, @me.com, @mac.com") { choose(.icloud) }
        ProviderTile(mark: "@", title: "Another provider", detail: "GMX, Web.de, T-Online, Posteo, IONOS, Yahoo …") { choose(.other) }
        note("Outlook and Hotmail can’t be read by apps like Causabee yet — Microsoft only lets its own apps in.", quiet: true)
    }

    // MARK: 2 · The address

    @ViewBuilder private var addressPage: some View {
        title(chosen == .gmail ? "Your Gmail address" : chosen == .icloud ? "Your iCloud address" : "Your mail address")
        lead("The one whose mail Causabee should read.")
        TextField(chosen == .gmail ? "name@gmail.com" : chosen == .icloud ? "name@icloud.com" : "name@example.com", text: $address)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.emailAddress).textInputAutocapitalization(.never)
            #endif
            .font(.body)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(known != nil ? Theme.done : Theme.strongLine, lineWidth: known != nil ? 2 : 1))
            .focused($typingAddress)
            .onAppear { typingAddress = true }
            .onSubmit { if MailDiscovery.domain(of: address) != nil { lookUp() } }
            .onChange(of: address) { provider = nil }
        if let known {
            Label("\(known.name) — Causabee knows how to connect it.", systemImage: "checkmark").font(.footnote).foregroundStyle(Theme.done)
            if known.password == .google || known.password == .apple {
                note("Next, \(known.password == .google ? "Google" : "Apple") makes a password just for Causabee. It takes about a minute.")
            }
        } else if MailProvider.isOutlook(address) {
            Label("Outlook can’t be connected yet — continue to see what works instead.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// The provider known from the address alone, before anything is asked.
    private var known: MailProvider? { MailProvider.by(address: address.trimmingCharacters(in: .whitespaces)) }

    @ViewBuilder private var outlook: some View {
        title("Outlook can’t be connected yet")
        lead("Microsoft lets only its own apps read Outlook and Hotmail mail. That isn’t something Causabee can change.")
        Text("What works instead:").font(.headline)
        SetupHint(number: 1, text: "Forward the mails you want sorted to a Gmail or iCloud address, and connect that.")
        SetupHint(number: 2, text: "Or drop a mail’s PDF or a screenshot into Causabee — it sorts those too.")
    }

    @ViewBuilder private var notFound: some View {
        title("Which provider is it?")
        lead("Causabee couldn’t find the settings for \(address) by itself. Pick your provider:")
        ForEach(MailProvider.others) { other in
            ProviderTile(mark: String(other.name.prefix(1)), title: other.name, detail: "") { provider = other; host = other.host; port = String(other.port); go(.password) }
        }
        Button("Not listed? Enter the settings yourself ›") { go(.ownSettings) }.buttonStyle(.borderless).foregroundStyle(Theme.gold)
    }

    @ViewBuilder private var ownSettings: some View {
        title("Your provider’s settings")
        lead("Your provider’s help pages name them — look for “IMAP”. Causabee connects securely, usually on port 993.")
        field("Incoming mail server", text: $host, prompt: "imap.example.com")
        field("Port", text: $port, prompt: "993")
        SecureField("Password", text: $password).textContentType(.password)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.strongLine))
        note("Many providers want a password made for apps rather than your usual one. Their settings say so.", quiet: true)
    }

    // MARK: 3 · The password

    private var makePasswordURL: URL? { chosen == .gmail ? MailProvider.gmail.passwordPage : chosen == .icloud ? MailProvider.icloud.passwordPage : nil }

    @ViewBuilder private var passwordPage: some View {
        switch kind {
        case .google:
            if check == .right || !password.isEmpty {
                title("Paste the 16 letters")
                lead(check == .right ? "That’s it — \(Self.tap.lowercased()) Connect." : clipboardHasText ? "Causabee noticed something on your clipboard — \(Self.tap.lowercased()) Paste to use it." : "Copy the 16 letters at Google, then \(Self.tap.lowercased()) Paste.")
            } else {
                title("Make a password for Causabee")
                lead("Google gives apps like Causabee their own password, so your real one is never shared.")
                SetupHint(number: 1, text: "\(Self.tap) “Open Google” and sign in if asked.")
                SetupHint(number: 2, text: "Type “Causabee” as the app name, then \(Self.tap.lowercased()) Create.")
                SetupHint(number: 3, text: "Google shows 16 letters. Copy them and come back here.")
                Sketch(url: "myaccount.google.com", heading: "App passwords", fieldLabel: "App name", button: "Create")
            }
        case .apple:
            if check == .right || !password.isEmpty {
                title("Paste the code")
                lead(check == .right ? "That’s it — \(Self.tap.lowercased()) Connect." : clipboardHasText ? "Causabee noticed something on your clipboard — \(Self.tap.lowercased()) Paste to use it." : "Copy the code at Apple, then \(Self.tap.lowercased()) Paste.")
            } else {
                title("Make a password for Causabee")
                lead("Apple gives apps like Causabee their own password, so your Apple Account password is never shared.")
                SetupHint(number: 1, text: "\(Self.tap) “Open Apple Account” and sign in.")
                SetupHint(number: 2, text: "Choose Sign-In and Security, then App-Specific Passwords.")
                SetupHint(number: 3, text: "Name it “Causabee”, \(Self.tap.lowercased()) Create, and copy the code.")
                Sketch(url: "account.apple.com", heading: "App-Specific Passwords", fieldLabel: "Name", button: "Create")
            }
        case .appPassword:
            title("A password for Causabee")
            lead("\(name) wants a password made for apps. Make one named “Causabee”, copy it, and paste it here.")
        case .usual:
            if case .allowIMAP = provider?.catch {
                title("One setting at \(name) first")
                lead("\(name) only lets apps read mail once you allow it. It’s a single switch.")
                SetupHint(number: 1, text: "\(Self.tap) “Open \(name) settings” and sign in.")
                SetupHint(number: 2, text: "Under POP3 & IMAP, turn on “Allow access”.")
                SetupHint(number: 3, text: "Come back and type your \(name) password here.")
            } else if case .mailPassword = provider?.catch {
                title("Your \(name) mail password")
                lead("\(name) has a password just for mail, set in its mail settings — not the one you sign in to Telekom with.")
            } else {
                title("Your \(name) password")
                lead("Causabee uses it only to read the mail you give it, and keeps it in your iCloud Keychain.")
            }
        }
        if kind != .google && kind != .apple || check == .right || !password.isEmpty {
            PasteField(text: $password, kind: kind, check: check, providerName: name)
        } else {
            // Already copied: pasted straight from here, the page turns to the field.
            PasteButton(payloadType: String.self) { pasted in if let first = pasted.first { password = first } }
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: Connecting

    @ViewBuilder private var connecting: some View {
        title("Connecting to \(name)")
        lead("This takes a few seconds.")
        BeeLoader(size: 28)
        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in StatusRow(text: step.text, state: step.state) }
    }

    // MARK: 4 · The label

    @ViewBuilder private var labelPage: some View {
        title(isGmail ? "One label for Causabee" : "One folder for Causabee")
        lead(isGmail ? "Causabee reads only mail with the label “\(Self.labelName)”. Shall it make the label in your Gmail now?"
                     : "Causabee reads only mail in the folder “\(Self.labelName)”. Shall it make the folder in your mailbox now?")
        MailWithLabel(isGmail: isGmail)
        note("Making this \(isGmail ? "label" : "folder") is the only change Causabee ever makes to your mailbox. You can rename or delete it there.")
        if !failure.isEmpty { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warning).font(.footnote) }
    }

    @ViewBuilder private var labelFound: some View {
        title(isGmail ? "Your label is ready" : "Your folder is ready")
        lead("Causabee found “\(Self.labelName)” in your mailbox, with \(mails) \(mails == 1 ? "mail" : "mails") in it.")
        StatusRow(text: "Connected to \(account?.user ?? address)", state: .done)
        StatusRow(text: "Found “\(Self.labelName)” · \(mails) \(mails == 1 ? "mail" : "mails")", state: .done)
    }

    @ViewBuilder private var done: some View {
        ZStack { Circle().fill(Theme.bee); Image(systemName: "checkmark").font(.system(size: 30, weight: .semibold)).foregroundStyle(.black) }
            .frame(width: 72, height: 72)
        title("You’re all set")
        lead(mails > 0 ? "Causabee reads the \(mails) \(mails == 1 ? "mail" : "mails") in “\(Self.labelName)” now. More come the same way:" : "Here is how Causabee gets its first mail:")
        if isGmail {
            SetupHint(number: 1, text: "In Gmail, open a mail about something you’re dealing with — a move, a claim, a parent’s care.")
            SetupHint(number: 2, text: "\(Self.tap) the label button, and tick “\(Self.labelName)”.")
        } else {
            SetupHint(number: 1, text: "In Mail, open a mail about something you’re dealing with — a move, a claim, a parent’s care.")
            SetupHint(number: 2, text: "Move it to the folder “\(Self.labelName)”.")
        }
        SetupHint(number: 3, text: "Come back here. Causabee reads it and sorts it into a matter.")
        StatusRow(text: "Connected · \(account?.user ?? address)", state: .done)
        StatusRow(text: "\(isGmail ? "Label" : "Folder") “\(Self.labelName)” \(mails > 0 ? "found" : "made")", state: .done)
        StatusRow(text: "Password kept in iCloud Keychain — your other devices have it too", state: .done)
    }

    // MARK: When something goes wrong

    @ViewBuilder private var notAccepted: some View {
        title("\(kind == .google ? "Google" : kind == .apple ? "Apple" : name) didn’t take that password")
        lead("Nothing is wrong with your account. Usually it’s one of these:")
        switch kind {
        case .google, .apple, .appPassword:
            ReasonTile(number: 1, title: "It was your usual password", detail: "Causabee needs the one made for apps", first: usualPasswordSent)
            ReasonTile(number: 2, title: "Only part of it was copied", detail: "Copy all of it, then paste again", first: false)
            ReasonTile(number: 3, title: "The app password was deleted", detail: "Make a new one — it takes a minute", first: false)
        case .usual:
            ReasonTile(number: 1, title: "A letter was typed wrong", detail: "Capitals count — type it again", first: true)
            if case .allowIMAP = provider?.catch { ReasonTile(number: 2, title: "Access for apps is still off", detail: "Turn on POP3 & IMAP in \(name)’s settings", first: false) }
            if case .mailPassword = provider?.catch { ReasonTile(number: 2, title: "It was the login password", detail: "\(name) wants its separate mail password", first: false) }
        }
    }

    @ViewBuilder private var twoStep: some View {
        title("First, one check at Google")
        lead("Google makes a password for apps only when 2-Step Verification is on. Many accounts have it — but not always when you sign in with a passkey.")
        SetupHint(number: 1, text: "\(Self.tap) “Check at Google” and sign in if asked.")
        SetupHint(number: 2, text: "If Google offers to turn it on, do it and add your phone number. Your passkey stays as it is.")
        SetupHint(number: 3, text: "Come back here — Causabee keeps your place.")
        if isWorkspace {
            note("At work or on your own domain, whoever runs your Google account may have to allow 2-Step Verification first.", quiet: true)
        }
    }

    private var isWorkspace: Bool {
        guard let domain = MailDiscovery.domain(of: address) else { return false }
        return !MailProvider.gmail.domains.contains(domain)
    }

    private func openTwoStep() {
        openURL(URL(string: "https://myaccount.google.com/signinoptions/twosv")!)
        checkedAtGoogle = true
    }

    /// On to the app password — back to it when the check came from there.
    private func toAppPassword() {
        if path.dropLast().last == .password { path.removeLast() } else { go(.password) }
    }

    @ViewBuilder private var offline: some View {
        title("No connection right now")
        lead("This device is offline. Nothing was lost — try again as soon as you’re back online.")
        StatusRow(text: "Can’t reach \(name) — no internet", state: .problem)
        StatusRow(text: "Connecting, once you’re online", state: .waiting)
    }

    @ViewBuilder private var failed: some View {
        title("Couldn’t reach \(name)")
        lead("The mail server didn’t answer as expected. Check the address and the settings, then try again.")
        Text(failure).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
    }

    // MARK: Moving on

    private func go(_ next: Page) { path.append(next) }
    /// In place of the page shown — connecting gives way to what came of it, not to a page more.
    private func replaceTop(_ next: Page) { if path.count > 1 { path[path.count - 1] = next } else { path.append(next) } }
    private func back() { if path.count > 1 { path.removeLast() } }

    private func choose(_ kind: MailDiscovery.Kind) {
        chosen = kind
        provider = kind == .gmail ? .gmail : kind == .icloud ? .icloud : nil
        go(.address)
    }

    /// The provider from the address, its server found by itself; Outlook said at once.
    private func lookUp() {
        let typed = address.trimmingCharacters(in: .whitespaces)
        if MailProvider.isOutlook(typed) { go(.outlook); return }
        if let known = MailProvider.by(address: typed) { use(known); return }
        // Gmail or iCloud chosen, on an own domain: the choice is trusted — where the domain's mail
        // is delivered doesn't always say where the account is.
        if chosen == .gmail { use(.gmail); return }
        if chosen == .icloud { use(.icloud); return }
        finding = true
        Task {
            let found = await MailDiscovery.find(typed)
            finding = false
            if let found, let named = MailProvider.by(host: found.host) { use(named); return }
            if let found {
                provider = MailProvider(id: "found", name: MailDiscovery.domain(of: typed) ?? "your provider", domains: [], host: found.host, port: found.port, kind: found.kind)
                host = found.host; port = String(found.port); go(.password)
            } else {
                go(.notFound)
            }
        }
    }

    private func use(_ known: MailProvider) {
        provider = known; chosen = known.kind; host = known.host; port = String(known.port)
        password = ""
        // Gmail asks for 2-Step Verification before any app password — checked first, so no one meets "not available".
        go(known.kind == .gmail ? .twoStep : .password)
    }

    private static func settings(_ provider: MailProvider) -> URL? {
        switch provider.catch {
        case .allowIMAP(let url), .mailPassword(let url): url
        case nil: nil
        }
    }

    /// Logs in, finds the label, keeps the password — each shown as it happens.
    private func connect() {
        let user = address.trimmingCharacters(in: .whitespaces)
        let server = (host.isEmpty ? provider?.host ?? "" : host).trimmingCharacters(in: .whitespaces)
        let trying = MailAccount(user: user, host: server, port: UInt16(port) ?? 993)
        let typed = PasswordCheck.cleaned(password, for: kind)
        usualPasswordSent = false
        working = true
        steps = [("Reaching \(name)", .working), ("Signing in as \(user)", .waiting), ("Looking for “\(Self.labelName)”", .waiting)]
        if page != .connecting { go(.connecting) }
        Task {
            do {
                let client = try await IMAPClient.connect(to: trying, password: typed)
                steps[0].state = .done; steps[1] = ("Signed in as \(user)", .done); steps[2].state = .working
                let folders = (try? await client.folders()) ?? []
                let label = folders.first { $0.name == Self.labelName } ?? folders.first { $0.name.lowercased() == Self.labelName.lowercased() }
                if let label { mails = (try? await client.examine(label.name))?.exists ?? 0 }
                await client.logout()
                try save(typed, trying)
                steps[2] = (label == nil ? "No “\(Self.labelName)” yet — next" : "Found “\(Self.labelName)”", .done)
                account = trying
                secret = typed
                try? await Task.sleep(for: .milliseconds(500))
                replaceTop(label == nil ? .label : .labelFound)
            } catch {
                failure = plainWords(error)
                replaceTop(Self.kind(of: error, usual: &usualPasswordSent))
            }
            working = false
        }
    }

    /// Which screen says what went wrong.
    static func kind(of error: Error, usual: inout Bool) -> Page {
        if let imap = error as? IMAPError, case .refused(let command, let answer) = imap, ["LOGIN", "AUTHENTICATE"].contains(command) {
            // Gmail says so when the account's own password was sent instead of an app password.
            usual = answer.lowercased().contains("application-specific") || answer.lowercased().contains("app password")
            return .notAccepted
        }
        if isDroppedConnection(error) { return .offline }
        if let url = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(url.code) { return .offline }
        if let nw = error as? NWError, case .dns = nw { return .offline }
        return .failed
    }

    /// The label or folder, made — the one change Causabee makes to a mailbox, asked first.
    private func makeLabel() {
        guard let account else { return }
        working = true
        failure = ""
        Task {
            do {
                let client = try await IMAPClient.connect(to: account, password: secret)
                try await client.create(Self.labelName)
                await client.logout()
                mails = 0
                go(.done)
            } catch {
                failure = "It couldn’t be made: \(plainWords(error)) Make it yourself in \(isGmail ? "Gmail" : "your mailbox"), then come back."
            }
            working = false
        }
    }

    private func lookAtClipboard() {
        #if os(iOS)
        clipboardHasText = UIPasteboard.general.hasStrings
        #else
        clipboardHasText = NSPasteboard.general.availableType(from: [.string]) != nil
        #endif
    }

    // MARK: Small parts

    private func title(_ text: String) -> some View {
        Text(text).font(.custom("Source Serif 4", size: 30 * Theme.textScale, relativeTo: .largeTitle)).fixedSize(horizontal: false, vertical: true)
    }

    private func lead(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String, quiet: Bool = false) -> some View {
        Text(text).font(quiet ? .footnote : .subheadline).foregroundStyle(quiet ? .secondary : .primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(quiet ? 0 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(quiet ? .clear : Theme.box, in: RoundedRectangle(cornerRadius: 12))
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.strongLine))
        }
    }

    private func primary(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity) }
            .filledButton()
            .disabled(!enabled)
    }

    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action).buttonStyle(.borderless).foregroundStyle(Theme.gold).padding(.vertical, 6)
    }
}

/// The four steps of the setup, the ones done in bee yellow.
private struct Progress: View {
    let step: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { index in
                Capsule().fill(index <= step ? Theme.bee : Theme.line).frame(width: 26, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of 4")
    }
}

/// What Causabee will and won't do, said before anything is asked.
private struct Promise: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.body).frame(width: 36, height: 36).background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A provider to choose, large enough to tap without aiming.
private struct ProviderTile: View {
    let mark: String
    let title: String
    let detail: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(mark).font(.headline).frame(width: 44, height: 44).background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if !detail.isEmpty { Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A likely reason a password was refused, the likeliest marked.
private struct ReasonTile: View {
    let number: Int
    let title: String
    let detail: String
    let first: Bool
    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)").font(.headline).frame(width: 36, height: 36).background(first ? Theme.beeSoft : Theme.box, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(first ? Theme.bee : Theme.line, lineWidth: first ? 2 : 1))
    }
}

/// One part of connecting, as it happens.
struct StatusRow: View {
    enum State { case done, working, waiting, problem }
    let text: String
    let state: State
    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch state {
                case .done: Image(systemName: "checkmark").foregroundStyle(Theme.done)
                case .working: ProgressView().controlSize(.small)
                case .waiting: Image(systemName: "circle").foregroundStyle(.tertiary)
                case .problem: Image(systemName: "exclamationmark").foregroundStyle(Theme.warning)
                }
            }
            .frame(width: 24)
            Text(text).fontWeight(state == .waiting ? .regular : .medium).foregroundStyle(state == .waiting ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The password, pasted rather than typed, and looked at as it comes in.
private struct PasteField: View {
    @Binding var text: String
    let kind: MailProvider.Password
    let check: PasswordCheck
    let providerName: String

    private var placeholder: String {
        switch kind {
        case .google: "abcd efgh ijkl mnop"
        case .apple: "abcd-efgh-ijkl-mnop"
        case .appPassword: "The password for apps"
        case .usual: "Your \(providerName) password"
        }
    }

    private var words: (String, Color) {
        switch (kind, check) {
        case (.google, .right): ("✓ 16 letters — that’s the right kind.", Theme.done)
        case (.apple, .right): ("✓ That’s an app-specific password — the right kind.", Theme.done)
        case (.google, .partial): ("Only part of it — Google shows 16 letters.", Theme.warning)
        case (.apple, .partial): ("Only part of it — Apple’s code has four groups of four letters.", Theme.warning)
        case (.google, .wrongKind): ("That looks like your usual Google password. Causabee needs the 16-letter one made for it.", Theme.warning)
        case (.apple, .wrongKind): ("That looks like your Apple Account password. Causabee needs the code made for it.", Theme.warning)
        case (.google, _): ("Google shows 16 letters. Copy them, then paste.", .secondary)
        case (.apple, _): ("Apple shows a code like abcd-efgh-ijkl-mnop. Copy it, then paste.", .secondary)
        default: ("Kept in your iCloud Keychain. It goes only to \(providerName).", .secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if kind == .google || kind == .apple { TextField(placeholder, text: $text) } else { SecureField(placeholder, text: $text) }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.body.monospaced())
                PasteButton(payloadType: String.self) { pasted in if let first = pasted.first { text = first } }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.gold)
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(check == .right && kind != .usual && kind != .appPassword ? Theme.done : check == .wrongKind || check == .partial ? Theme.warning : Theme.strongLine,
                                                               lineWidth: check == .empty ? 1 : 2))
            Text(words.0).font(.footnote).foregroundStyle(words.1).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A sketch of the provider's page — words only, no logos — with the one place to tap ringed in yellow.
private struct Sketch: View {
    let url: String
    let heading: String
    let fieldLabel: String
    let button: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(url, systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 5).background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
            Text(heading).font(.headline)
            Text(fieldLabel).font(.caption).foregroundStyle(.secondary)
            Text("Causabee").font(.subheadline).padding(.horizontal, 12).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.bee, lineWidth: 2))
            HStack(spacing: 10) {
                Text(button).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Theme.box, in: Capsule()).overlay(Capsule().stroke(Theme.bee, lineWidth: 2))
                Text("← \(MailSetupFlow.tap.lowercased()) here").font(.caption).foregroundStyle(Theme.gold)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
        .accessibilityElement(children: .combine)
    }
}

/// A mail as the mailbox lists it, with the label on it: what the label is, shown rather than told.
private struct MailWithLabel: View {
    let isGmail: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sunrise Care").font(.headline)
                Spacer()
                Text("09:12").font(.footnote).foregroundStyle(.tertiary)
            }
            Text("Your contract for the care at home").font(.subheadline)
            Text(isGmail ? MailSetupFlow.labelName : "📁 " + MailSetupFlow.labelName).font(.footnote.weight(.semibold)).foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.bee, in: Capsule())
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
        .accessibilityElement(children: .combine)
    }
}

/// A step's number on the bee's yellow, and what to do.
struct SetupHint: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)").font(.callout.weight(.semibold))
                .frame(width: 24, height: 24).background(Theme.bee, in: Circle()).foregroundStyle(.black)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
