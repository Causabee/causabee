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

    nonisolated static let onKey = "beeserver.on"
    nonisolated static let addressKey = "beeserver.address"
    nonisolated static let tokenName = "CAUSABEE_PRO_TOKEN"

    var isOn: Bool = UserDefaults.standard.bool(forKey: onKey) {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.onKey); Money.hidden = isOn }
    }
    var address: String = UserDefaults.standard.string(forKey: addressKey) ?? "" {
        didSet { UserDefaults.standard.set(address, forKey: Self.addressKey) }
    }
    /// This month's Pro: the share used 0…1, and the day it starts anew — as the server said last.
    var monthUsed: Double?
    var renewsOn: String?
    var problem: String?

    var token: String? { Self.storedToken }
    var relay: URL? { Self.relay(on: isOn, address: address) }

    nonisolated static var storedToken: String? { APIKeys.get(tokenName) }

    nonisolated static func relay(on: Bool, address: String) -> URL? {
        guard on, storedToken != nil, let url = URL(string: address.trimmingCharacters(in: .whitespaces)), url.scheme == "https" else { return nil }
        return url
    }

    /// The client for a model through the beeserver; nil when it is off, or for Mistral, which
    /// Pro does not offer. Read from what is stored, so it can be asked from anywhere.
    nonisolated static func client(for model: Claude.Model) -> Claude? {
        let defaults = UserDefaults.standard
        guard !model.isMistral, let relay = relay(on: defaults.bool(forKey: onKey), address: defaults.string(forKey: addressKey) ?? ""),
              let token = storedToken else { return nil }
        return Claude(key: token, relay: relay)
    }

    /// Hears what the server says after each answer.
    static func listen() {
        Money.hidden = shared.isOn
        Claude.allowanceSeen = { used, renews in
            Task { @MainActor in
                BeeServer.shared.monthUsed = used
                if !renews.isEmpty { BeeServer.shared.renewsOn = renews }
            }
        }
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
            .task { if server.isOn, server.monthUsed == nil { await server.refresh() } }
    }

    @ViewBuilder private var bar: some View {
        if server.isOn, let used = server.monthUsed {
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
                    Text("Used for this month. Causabee goes on with Apple's models until it starts anew.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The hidden switch, for testing Pro through the beeserver: the address, the token, on or off.
/// Shown in Settings only once a token is kept — or while `--beeserver` is given at start.
struct BeeServerSettings: View {
    @State private var server = BeeServer.shared
    @State private var pastedToken = ""

    static var shows: Bool { BeeServer.shared.token != nil || CommandLine.arguments.contains("--beeserver") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Pro through the beeserver (test)", isOn: $server.isOn)
            TextField("https://beeserver…", text: $server.address)
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
            if server.isOn, server.relay == nil {
                Text("Needs an https address and a token.").font(.footnote).foregroundStyle(Theme.warning)
            }
            if let problem = server.problem { Text(problem).font(.footnote).foregroundStyle(Theme.warning) }
            ProBar()
        }
        .task { await server.refresh() }
    }
}
