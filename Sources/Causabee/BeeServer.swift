import Foundation
import MatterCore
import StoreKit
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
    /// A top-up is left after the month, and how much, in Pro months.
    var extra = false
    var extraShare = 0.0
    /// Whose the account is: a subscriber's, one of top-ups only, or one made by hand.
    var kind = "hand"
    /// The beeserver has said what is left, since this launch: until then the bar is empty (F007).
    var counted = false
    /// F008: what is left beyond the month is only the start credit, as the server said last.
    var startCredit = UserDefaults.standard.bool(forKey: startCreditKey)
    nonisolated static let startCreditKey = "beeserver.startCredit"

    /// A top-up is left: Pro's bolt works with it, Pro bought or not. As the server said last.
    nonisolated static var hasCredit: Bool { storedToken != nil && UserDefaults.standard.bool(forKey: creditKey) }
    nonisolated static let creditKey = "beeserver.credit"

    /// What the server says of an account, after any answer of its own.
    private func take(_ object: [String: Any]) {
        if let used = object["monthUsed"] as? Double { monthUsed = used }
        if let renews = object["renewsOn"] as? String { renewsOn = renews }
        extra = object["extra"] as? Bool ?? false
        extraShare = object["extraShare"] as? Double ?? 0
        kind = object["kind"] as? String ?? kind
        startCredit = object["startCredit"] as? Bool ?? false
        UserDefaults.standard.set(startCredit, forKey: Self.startCreditKey)
        // F008 AC-16: the start credit is used — "Use Pro" on, unless the owner ever set it.
        if Welcome.switchesProOn(startCredit: startCredit, extra: extra,
                                 setByOwner: UserDefaults.standard.object(forKey: AutoMode.key) != nil) {
            UserDefaults.standard.set(true, forKey: AutoMode.key)
        }
        UserDefaults.standard.set(extra, forKey: Self.creditKey)
        counted = true
        // Something left again: the wait is over (F007).
        let wait = ProWait.stored
        if wait != .none, wait.over(monthUsed: monthUsed, extraShare: extraShare) { ProWait.clear() }
    }
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
        Claude.allowanceSeen = { used, renews in
            Task { @MainActor in
                BeeServer.shared.monthUsed = used
                if !renews.isEmpty { BeeServer.shared.renewsOn = renews }
            }
        }
        // Used up, or ended: "Use Pro" keeps the owner's setting and waits (F007); Apple's model on
        // the device reads meanwhile, and nothing is sent that would be refused.
        Claude.proStopped = { why in
            Task { @MainActor in
                ProWait.store(ProWait.after(why, renewsOn: BeeServer.shared.renewsOn))
                if why == "allowance_used" { BeeServer.shared.monthUsed = 1 }
                BeeServer.shared.problem = why == "subscription_ended"
                    ? "Causabee Pro has ended. A top-up goes on at once; meanwhile Apple's model on this device reads what comes in."
                    : "This month's Pro is used up. It waits until it starts anew — or a top-up. Apple's model on this device reads what comes in meanwhile."
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
            take(object)
            // Pro bought again: whatever it waited for is over (F007).
            ProWait.clear()
            problem = nil
            return true
        } catch {
            problem = plainWords(error)
            return false
        }
    }

    /// A top-up as the App Store signed it: added once, however often it is sent. Bought without
    /// Pro, it opens an account of its own, and its token comes back with the answer.
    func topUp(transaction jws: String) async -> Bool {
        guard let base = Self.base else { return false }
        var request = URLRequest(url: base.appendingPathComponent("v1/topup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transaction": jws])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let new = object["token"] as? String, new.hasPrefix("bee_") {
            try? APIKeys.save(new, as: Self.tokenName)
        }
        take(object)
        problem = nil
        return true
    }

    /// F008 AC-14: asks once, at the first start, for the start credit — with Apple's signed record
    /// of this download and the app's own id for the Apple account. Nothing to sign up for, nothing
    /// said when none is given. Asked once per install, whatever token is kept — the beeserver decides,
    /// once per Apple account in the App Store, again in TestFlight after the owner forgets it; not in
    /// the demo; asked again at a later start only when the beeserver could not be reached.
    func askStart() async {
        // A start credit given before Pro switched on by itself (TestFlight 250): on at this start.
        if Welcome.switchesProOn(startCredit: startCredit, extra: UserDefaults.standard.bool(forKey: Self.creditKey),
                                 setByOwner: UserDefaults.standard.object(forKey: AutoMode.key) != nil) {
            UserDefaults.standard.set(true, forKey: AutoMode.key)
        }
        if CommandLine.arguments.contains("--fresh-start") {
            UserDefaults.standard.removeObject(forKey: Welcome.startAskedKey)
            UserDefaults.standard.removeObject(forKey: Welcome.startUsedLaterKey)
        }
        guard !DemoData.isRequested, !UserDefaults.standard.bool(forKey: Welcome.startAskedKey), let base = Self.base,
              let download = try? await AppTransaction.shared else { return }
        var request = URLRequest(url: base.appendingPathComponent("v1/start"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["download": download.jwsRepresentation, "account": Store.accountID.uuidString])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // Answered, given or not: never asked again on this device.
        UserDefaults.standard.set(true, forKey: Welcome.startAskedKey)
        if let new = object["token"] as? String, new.hasPrefix("bee_") { try? APIKeys.save(new, as: Self.tokenName) }
        if object["monthUsed"] != nil || object["extraShare"] != nil { take(object) }
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
            take(object)
            problem = nil
        } catch {
            problem = plainWords(error)
        }
    }

    /// What the plan shows of it: the month's bar and the top-ups' (F006).
    var meter: ProMeter { meter(inUse: true) }

    /// What the plan shows of it, with "Use Pro" on or off (F007): until the beeserver has answered,
    /// an empty bar for Pro bought or a top-up known.
    func meter(inUse: Bool) -> ProMeter {
        let answered = counted || PlanShot.current?.meters == true
        return ProMeter(monthUsed: monthUsed, extraShare: extraShare, kind: answered ? kind : (Self.hasCredit ? "credit" : kind),
                        renewsOn: renewsOn, pro: Store.shared.plan == .pro || (answered && kind == "hand"), inUse: inUse, counted: answered,
                        startCredit: startCredit)
    }

    /// What is left, of the month and of top-ups together, is running out: a top-up is the thing to do.
    var runsLow: Bool { meter.runsLow }
}

/// What is left of this month’s Pro and of top-ups, each as one number and a bar, and when the month starts
/// anew — never money.
struct ProBar: View {
    let meter: ProMeter

    var body: some View {
        if !meter.bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // The month's bar, and under it the top-ups', on the same scale (F006).
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(meter.bars, id: \.words) { bar($0) }
                }
                if let line = meter.line { Text(line).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if let note = meter.note { Text(note).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    /// Off, greyed (F007): the plan is still there, only not in use.
    private func bar(_ bar: ProMeter.Bar) -> some View {
        let colour = !bar.inUse ? Theme.strongLine : bar.low ? Theme.warning : bar.kind == .month ? Theme.bee : Theme.topUp
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bar.number).font(Theme.planNumberFont)
                    .foregroundStyle(!bar.inUse ? Color.secondary : bar.low ? Theme.warning : Color.primary)
                Text(bar.words).font(.subheadline).foregroundStyle(.secondary)
            }
            GeometryReader { box in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    if bar.counted { Capsule().fill(colour).frame(width: max(6, box.size.width * bar.length)) }
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement()
        .accessibilityLabel(bar.spoken)
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
