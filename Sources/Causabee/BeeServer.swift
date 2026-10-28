import Foundation
import MatterCore
import SwiftUI

/// Causabee Pro through the beeserver — for now a switch for testing, with a token made by hand
/// (concept/pro-service.md, step 1). On, the AI's requests go to the beeserver with the Pro token
/// and Causabee's own keys are added there; the app shows how much of this month's Pro is used,
/// never what anything cost. The token is kept like the API keys: in iCloud Keychain, so the
/// owner's other devices have it too.
@MainActor
@Observable
final class BeeServer {
    static let shared = BeeServer()

    nonisolated static let addressKey = "beeserver.address"
    nonisolated static let tokenName = "CAUSABEE_PRO_TOKEN"
    /// Until subscriptions hand out tokens and the server has its own name.
    nonisolated static let defaultAddress = "https://beeserver.ralf-e2a.workers.dev"

    var address: String = UserDefaults.standard.string(forKey: addressKey) ?? "" {
        didSet { UserDefaults.standard.set(address, forKey: Self.addressKey) }
    }
    /// This month's Pro: the share used 0…1, and the day it starts anew — as the server said last.
    var monthUsed: Double?
    var renewsOn: String?
    /// A top-up is left after the month.
    var extra = false
    var problem: String?

    var token: String? { Self.storedToken }
    var relay: URL? { Self.relay }

    nonisolated static var storedToken: String? { APIKeys.get(tokenName) }

    /// A token is kept: Pro goes through the beeserver, and the bolt turns it on and off.
    nonisolated static var isSetUp: Bool { relay != nil }

    nonisolated static var relay: URL? { storedToken == nil ? nil : base }

    /// The client for a model through the beeserver; nil when none is set up, or for Mistral,
    /// which Pro does not offer. Read from what is stored, so it can be asked from anywhere.
    nonisolated static func client(for model: Claude.Model) -> Claude? {
        guard !model.isMistral, let relay, let token = storedToken else { return nil }
        return Claude(key: token, relay: relay)
    }

    /// Hears what the server says after each answer.
    static func listen() {
        Money.hidden = isSetUp
        Claude.allowanceSeen = { used, renews in
            Task { @MainActor in
                BeeServer.shared.monthUsed = used
                if !renews.isEmpty { BeeServer.shared.renewsOn = renews }
            }
        }
        // Used up, or ended: the bolt goes off by itself, and Apple's model on the device takes over.
        Claude.proStopped = { why in
            Task { @MainActor in
                UserDefaults.standard.set(false, forKey: AutoMode.key)
                if why == "allowance_used" { BeeServer.shared.monthUsed = 1 }
                BeeServer.shared.problem = why == "subscription_ended"
                    ? "Causabee Pro has ended, so Pro is off. Apple's model on this device reads new mail."
                    : "This month's Pro is used up, so Pro is off until it starts anew — or until a top-up. Apple's model on this device reads new mail meanwhile."
            }
        }
    }

    /// Where a purchase is redeemed: the address typed for testing, or the beeserver's own.
    nonisolated static var base: URL? {
        let typed = (UserDefaults.standard.string(forKey: addressKey) ?? "").trimmingCharacters(in: .whitespaces)
        return URL(string: typed.isEmpty ? defaultAddress : typed).flatMap { $0.scheme == "https" ? $0 : nil }
    }

    /// The Pro subscription as the App Store signed it, for this Apple Account's token — kept in
    /// iCloud Keychain, so the Mac and the other devices have it too. Sent again with each renewal:
    /// then it only moves the end. Returns whether the server took it.
    @discardableResult
    func subscribe(transaction jws: String) async -> Bool {
        guard let base = Self.base else { return false }
        var request = URLRequest(url: base.appendingPathComponent("v1/subscribe"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transaction": jws])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                problem = "Causabee Pro could not be set up just now. It is tried again when Causabee next opens."
                return false
            }
            if let new = object["token"] as? String, new.hasPrefix("bee_") { try APIKeys.save(new, as: Self.tokenName) }
            monthUsed = object["monthUsed"] as? Double
            renewsOn = object["renewsOn"] as? String
            extra = object["extra"] as? Bool ?? false
            problem = nil
            Money.hidden = true
            return true
        } catch {
            problem = plainWords(error)
            return false
        }
    }

    /// A top-up as the App Store signed it: added to this month once, however often it is sent.
    func topUp(transaction jws: String) async -> Bool {
        guard let relay, let token else { return false }
        var request = URLRequest(url: relay.appendingPathComponent("v1/topup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transaction": jws])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        monthUsed = object["monthUsed"] as? Double
        extra = object["extra"] as? Bool ?? false
        problem = nil
        return true
    }

    /// Asks the server how much of this month is used.
    func refresh() async {
        guard let relay, let token else { return }
        var request = URLRequest(url: relay.appendingPathComponent("v1/allowance"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                problem = "The beeserver did not answer as it should."
                return
            }
            monthUsed = object["monthUsed"] as? Double
            renewsOn = object["renewsOn"] as? String
            extra = object["extra"] as? Bool ?? false
            problem = nil
        } catch {
            problem = plainWords(error)
        }
    }

    /// "Renews 1 November", from the server's "2026-11-01".
    var renewsWords: String? {
        guard let renewsOn, let date = MatterStatus.date(of: renewsOn) else { return nil }
        return "renews " + date.formatted(.dateTime.day().month(.wide))
    }
}

/// This month's Pro as a bar: how much is left, and when it starts anew — never money.
struct ProBar: View {
    @State private var server = BeeServer.shared

    var body: some View {
        Group { bar }
            // Shown before any answer came this time: asked of the server once.
            .task { if BeeServer.isSetUp, server.monthUsed == nil { await server.refresh() } }
    }

    @ViewBuilder private var bar: some View {
        if BeeServer.isSetUp, let used = server.monthUsed {
            let left = max(0, 1 - used)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("This month's Pro").font(.subheadline.weight(.medium))
                    Spacer(minLength: 0)
                    Text("\(Int((left * 100).rounded())) % left" + (server.renewsWords.map { " · \($0)" } ?? ""))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                GeometryReader { box in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.box)
                        Capsule().fill(left > 0.2 ? Theme.bee : Theme.warning).frame(width: max(6, box.size.width * left))
                    }
                }
                .frame(height: 8)
                .accessibilityElement()
                .accessibilityLabel("This month's Pro: \(Int((left * 100).rounded())) percent left")
                if left <= 0 {
                    Text(server.extra ? "This month's share is used; your top-up carries on." : "Used for this month. Causabee goes on with Apple's model on this device until it starts anew — or with a top-up.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Where Pro's token is kept until subscriptions hand them out, and the address it goes to. The
/// bolt turns Pro on and off.
/// Shown in Settings only once a token is kept, after the version line is tapped five times, or
/// while `--beeserver` is given at start.
struct BeeServerSettings: View {
    @State private var server = BeeServer.shared
    @State private var pastedToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(server.token == nil ? "Pro's token comes with the subscription. Here a server for testing, and a token made by hand."
                 : "A token is kept: Pro goes through this server. It came with the subscription, or was pasted here.")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField(BeeServer.defaultAddress, text: $server.address)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            HStack(spacing: 8) {
                SecureField(server.token == nil ? "Pro token (bee_…)" : "Pro token kept — paste to replace", text: $pastedToken)
                    .textFieldStyle(.roundedBorder)
                Button("Keep") {
                    try? APIKeys.save(pastedToken.trimmingCharacters(in: .whitespacesAndNewlines), as: BeeServer.tokenName)
                    pastedToken = ""
                    Task { await server.refresh() }
                }
                .disabled(!pastedToken.hasPrefix("bee_"))
            }
            if server.token != nil, server.relay == nil {
                Text("The address must start with https://").font(.footnote).foregroundStyle(Theme.warning)
            }
            if let problem = server.problem { Text(problem).font(.footnote).foregroundStyle(Theme.warning) }
        }
        .task { await server.refresh() }
    }
}
