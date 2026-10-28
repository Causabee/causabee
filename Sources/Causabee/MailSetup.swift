import MatterCore
import SwiftUI

/// Connecting a mail account, the same on the Mac, the iPhone and the iPad: the address first,
/// then the way in that fits it — Google's own sign-in or an app password for Gmail, a short
/// walkthrough for iCloud's app-specific password, the server for any other provider — a login
/// that is tried before anything is kept, and last the label or folder Causabee reads.
struct MailSetup: View {
    /// Keeps the password or token: in the Keychain, or — in the Mac's test of the setup — nowhere.
    var save: (String, MailAccount) throws -> Void = { try Keychain.save($0, for: $1) }
    /// Whether Google's refresh token is kept: not in that test.
    var keepsGoogle = true
    /// Told when an account is connected.
    var connected: (MailAccount) -> Void = { _ in }

    @State private var address = ""
    @State private var found: MailDiscovery.Found?
    @State private var looked = false
    @State private var finding = false
    @State private var host = ""
    @State private var port = "993"
    @State private var password = ""
    @State private var working = false
    @State private var result: (text: String, good: Bool)?
    @State private var account: MailAccount?
    @State private var label: (found: Bool, mails: Int)?
    @State private var secret: String?
    @State private var google = GoogleSignInFlow()
    @State private var appPassword = false

    static let labelName = "Causabee"
    /// "Click" on the Mac, "Tap" where a finger does it.
    #if os(iOS)
    static let click = "Tap"
    #else
    static let click = "Click"
    #endif

    private var kind: MailDiscovery.Kind { found?.kind ?? .other }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let account {
                SetupOutcome(text: "Connected: \(account.user)" + (account.usesGoogle ? ", signed in with Google" : ""), good: true)
                labelStep(account)
            } else {
                addressStep
                if looked { way }
                if let result { SetupOutcome(text: result.text, good: result.good) }
            }
        }
    }

    // MARK: 1 · The address

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            SetupNote("Causabee reads your mail the way a mail app does, and only reads: it never sends, deletes, moves or marks mail as read. It reads only the mail you give it a label for.")
            HStack {
                TextField("Your mail address", text: $address)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(look)
                    .onChange(of: address) { looked = false; found = nil; result = nil }
                if !looked {
                    Button(finding ? "Looking …" : "Continue", action: look)
                        .disabled(finding || !address.contains("@"))
                }
            }
        }
    }

    private func look() {
        let typed = address.trimmingCharacters(in: .whitespaces)
        guard typed.contains("@") else { return }
        finding = true
        Task {
            let found = await MailDiscovery.find(typed)
            self.found = found
            host = found?.host ?? ""
            port = String(found?.port ?? 993)
            finding = false
            looked = true
        }
    }

    @ViewBuilder private var way: some View {
        switch kind {
        case .gmail: gmailWay
        case .icloud: icloudWay
        case .other: otherWay
        }
    }

    // MARK: 2 · Gmail

    @ViewBuilder private var gmailWay: some View {
        SettingsPart(found?.source == "MX" ? "Google Workspace" : "Gmail")
        if GoogleSignIn.isConfigured && !appPassword {
            Button { signInWithGoogle() } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle.badge.checkmark")
            }
            .filledButton()
            .disabled(working)
            SetupNote("On Google's own page: you type your Google password there, not in Causabee, and Google shows what Causabee may do.")
            Button("Use an app password instead") { appPassword = true }.buttonStyle(.borderless).foregroundStyle(.secondary)
        } else {
            SetupHint(number: 1, text: "Google lets an app read mail with an app password once 2-Step Verification is on for your account.")
            Link("Turn on 2-Step Verification →", destination: URL(string: "https://myaccount.google.com/signinoptions/twosv")!).foregroundStyle(Theme.gold)
            SetupHint(number: 2, text: "Make an app password, and name it “Causabee”.")
            Link("Open Google's app passwords →", destination: URL(string: "https://myaccount.google.com/apppasswords")!).foregroundStyle(Theme.gold)
            SetupHint(number: 3, text: "Google shows 16 letters. Copy them, and paste them here.")
            passwordField("16 letters from Google")
            logInButton
        }
    }

    private func signInWithGoogle() {
        working = true
        result = nil
        Task {
            do {
                let (signedIn, token) = try await google.signIn(hint: address.trimmingCharacters(in: .whitespaces), keep: keepsGoogle)
                if !keepsGoogle { try save(token, signedIn) }
                let client = try await IMAPClient.connect(to: signedIn, password: token)
                label = await Self.count(in: (try? await client.folders()) ?? [], client: client)
                await client.logout()
                secret = token
                account = signedIn
                connected(signedIn)
            } catch where GoogleSignInFlow.wasCancelled(error) {
                result = nil
            } catch {
                result = ("Not signed in: \(plainWords(error))", false)
            }
            working = false
        }
    }

    // MARK: 2 · iCloud

    @ViewBuilder private var icloudWay: some View {
        SettingsPart("iCloud Mail")
        SetupNote("Apple lets an app read iCloud Mail with an app-specific password — made in a minute, and taken back there whenever you like.")
        SetupHint(number: 1, text: "Open account.apple.com and sign in with your Apple Account.")
        Link("Open account.apple.com →", destination: URL(string: "https://account.apple.com/account/manage")!).foregroundStyle(Theme.gold)
        SetupHint(number: 2, text: "Choose “Sign-In and Security”, then “App-Specific Passwords”.")
        SetupHint(number: 3, text: "\(Self.click) “+”, name it “Causabee”, and confirm with your password.")
        SetupHint(number: 4, text: "Apple shows a code like abcd-efgh-ijkl-mnop. Copy it, and paste it here.")
        passwordField("abcd-efgh-ijkl-mnop")
        logInButton
    }

    // MARK: 2 · Any other provider

    @ViewBuilder private var otherWay: some View {
        SettingsPart("Your mail provider")
        if let found {
            SetupNote("Found its mail server" + (found.source == "Thunderbird" ? " in Thunderbird's list of providers" : found.source == "autoconfig" ? " in its own settings" : "") + ". Change it if your provider says otherwise.")
        } else {
            SetupNote("Your provider's help pages name its IMAP server — often imap. and the domain. Causabee connects over TLS, usually on port 993.")
        }
        HStack {
            TextField("IMAP server, e.g. imap.example.com", text: $host)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never).keyboardType(.URL)
                #endif
                .textFieldStyle(.roundedBorder)
            TextField("Port", text: $port)
                .frame(width: 64)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .textFieldStyle(.roundedBorder)
        }
        SetupNote("Many providers want a password made for one app — an app password — rather than your usual one. Their settings say so.")
        passwordField("Password")
        logInButton
    }

    // MARK: The password and the login

    private func passwordField(_ prompt: String) -> some View {
        HStack {
            SecureField(prompt, text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(logIn)
            PasteButton(payloadType: String.self) { pasted in
                if let first = pasted.first { password = first.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .labelStyle(.iconOnly)
        }
    }

    private var logInButton: some View {
        HStack {
            Button(working ? "Logging in …" : "Log in", action: logIn)
                .filledButton()
                .disabled(working || password.isEmpty || (kind == .other && host.isEmpty))
            if working { ProgressView().controlSize(.small) }
        }
    }

    private func logIn() {
        let user = address.trimmingCharacters(in: .whitespaces)
        let server = host.trimmingCharacters(in: .whitespaces)
        guard !password.isEmpty, !server.isEmpty else { return }
        let trying = MailAccount(user: user, host: server, port: UInt16(port) ?? 993)
        // Google shows an app password in four groups of four, Apple in four groups with dashes: the
        // spaces are not part of Google's; Apple's dashes are.
        let typed = kind == .gmail ? password.replacingOccurrences(of: " ", with: "") : password.trimmingCharacters(in: .whitespaces)
        working = true
        result = nil
        Task {
            do {
                let client = try await IMAPClient.connect(to: trying, password: typed)
                label = await Self.count(in: (try? await client.folders()) ?? [], client: client)
                await client.logout()
                try save(typed, trying)
                password = ""
                secret = typed
                account = trying
                connected(trying)
            } catch {
                result = ("Not logged in: " + Self.why(error, kind: kind), false)
            }
            working = false
        }
    }

    /// What to do about a refused login, for the way it was tried.
    static func why(_ error: Error, kind: MailDiscovery.Kind) -> String {
        let words = plainWords(error)
        guard "\(error)".lowercased().contains("auth") || "\(error)".lowercased().contains("login") else { return words }
        switch kind {
        case .gmail: return "Google did not accept it. It has to be an app password — 16 letters — not your Google password."
        case .icloud: return "Apple did not accept it. It has to be an app-specific password, and the address your Apple Account's iCloud Mail uses."
        case .other: return words
        }
    }

    // MARK: 3 · The label

    @ViewBuilder private func labelStep(_ account: MailAccount) -> some View {
        let gmail = account.host == "imap.gmail.com"
        SettingsPart(gmail ? "The label “\(Self.labelName)”" : "The folder “\(Self.labelName)”")
        SetupNote(gmail
                  ? "Causabee reads only mail with the label “\(Self.labelName)”. Nothing else in your mailbox is read: you decide what it sees by putting the label on a mail."
                  : "Causabee reads only mail in the folder “\(Self.labelName)”. Nothing else in your mailbox is read: you decide what it sees by moving a mail there.")
        if gmail {
            SetupHint(number: 1, text: "In Gmail, next to Labels, \(Self.click.lowercased()) “+” and make a label called “\(Self.labelName)”.")
            SetupHint(number: 2, text: "Put it on a few mails of one matter. Replies in the same thread are found by themselves.")
            SetupNote("Tip: a Gmail filter can put the label on mail from the school, the landlord or the insurer by itself.")
        } else {
            SetupHint(number: 1, text: account.host == "imap.mail.me.com"
                      ? "In Mail, or at icloud.com/mail, make a folder called “\(Self.labelName)”."
                      : "In your mail app, or on your provider's website, make a folder called “\(Self.labelName)”.")
            SetupHint(number: 2, text: "Move a few mails of one matter into it.")
        }
        if let label {
            SetupOutcome(text: label.found ? "Found “\(Self.labelName)”, with \(label.mails) \(label.mails == 1 ? "mail" : "mails")."
                                           : "There is no “\(Self.labelName)” yet. Make it, put a few mails in it, then check again.",
                         good: label.found)
        }
        HStack {
            Button(working ? "Looking …" : "Check again") { check(account) }.disabled(working || secret == nil)
            if working { ProgressView().controlSize(.small) }
        }
    }

    private func check(_ account: MailAccount) {
        guard let secret else { return }
        working = true
        Task {
            if let client = try? await IMAPClient.connect(to: account, password: secret) {
                label = await Self.count(in: (try? await client.folders()) ?? [], client: client)
                await client.logout()
            }
            working = false
        }
    }

    static func count(in folders: [MailFolder], client: IMAPClient) async -> (found: Bool, mails: Int) {
        // Found as "Get new mail" finds it: the exact name first, then in any capitals.
        guard let folder = folders.first(where: { $0.name == labelName })
                ?? folders.first(where: { $0.name.lowercased() == labelName.lowercased() }) else { return (false, 0) }
        let opened = try? await client.examine(folder.name)
        return (true, opened?.exists ?? 0)
    }
}

/// A step's number on the bee's yellow, and what to do.
struct SetupHint: View {
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

/// A line of explanation: grey, and wrapping.
struct SetupNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}

/// A result: done with a tick, a problem in orange.
struct SetupOutcome: View {
    let text: String
    let good: Bool
    var body: some View {
        Label(text, systemImage: good ? "checkmark.circle.fill" : "exclamationmark.triangle")
            .foregroundStyle(good ? Theme.done : Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
