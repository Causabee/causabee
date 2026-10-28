import MatterCore
import StoreKit
import SwiftData
import SwiftUI

/// The plan, and buying it — in the App Store on the iPhone and the iPad. What was bought goes
/// into the profile, so the Mac — downloaded from the website, with no App Store purchases of its
/// own — has the same plan through iCloud. The demo has everything.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    static let mattersIDs = ["de.chille.causabee.matters.monthly", "de.chille.causabee.matters.yearly"]
    static let proIDs = ["de.chille.causabee.pro.monthly"]
    /// More Pro for this month, bought as often as needed: added by the beeserver, counted once.
    static let topUpIDs = ["de.chille.causabee.pro.topup"]
    /// The end of the Pro subscription the beeserver last took: a renewal is sent once.
    static let redeemedKey = "beeserver.redeemedUntil"

    /// Why the plan sheet is open: a fourth matter, Pro asked for, or chosen from Settings.
    enum Reason: String, Identifiable {
        case matters, pro, choose
        var id: String { rawValue }
    }

    private(set) var products: [Product] = []
    /// What this device's App Store says, and what another device bought, through iCloud.
    private(set) var bought: (plan: Plan, until: Date?) = (.free, nil)
    private(set) var shared: (plan: Plan, until: Date?) = (.free, nil)
    var asks: Reason?
    private(set) var buying: String?
    var problem: String?

    /// What happens at the end of the subscription's period, as the App Store says it.
    enum Renewal: Equatable {
        case renews(Date)
        case ends(Date)
        case changes(to: Plan, on: Date)
        /// The card could not be charged: Apple keeps trying, the plan goes on until then.
        case billingProblem(until: Date?)
    }
    private(set) var renewal: Renewal?
    /// This Apple Account may still have the group's free trial: it is offered once.
    private(set) var trialOpen = false

    /// The app's own id for this Apple Account, sent with every purchase so the beeserver puts them
    /// into one account — Plus's top-ups and a later Pro too. Kept in iCloud Keychain: the same on
    /// every device.
    static var accountID: UUID {
        if let kept = APIKeys.get("CAUSABEE_ACCOUNT_ID"), let id = UUID(uuidString: kept) { return id }
        let id = UUID()
        try? APIKeys.save(id.uuidString, as: "CAUSABEE_ACCOUNT_ID")
        return id
    }

    static func plan(of productID: String) -> Plan {
        proIDs.contains(productID) ? .pro : mattersIDs.contains(productID) ? .matters : .free
    }

    /// A purchase seen through iCloud counts a week past its end: the device that renews it may
    /// not have been opened since.
    private static let grace: TimeInterval = 7 * 86_400

    var plan: Plan {
        if DemoData.isRequested { return .pro }
        let elsewhere = (shared.until.map { $0.addingTimeInterval(Self.grace) > Date() } ?? false) ? shared.plan : .free
        return max(bought.plan, elsewhere)
    }

    private var listening: Task<Void, Never>?
    private var context: ModelContext?

    func start(_ context: ModelContext) {
        self.context = context
        readShared()
        guard listening == nil else { return }
        listening = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.settle(update)
                await self?.refresh()
            }
        }
        Task {
            await load()
            // A top-up bought while the server could not be reached: added now.
            for await unfinished in Transaction.unfinished { await settle(unfinished) }
            await refresh()
        }
    }

    func load() async {
        products = ((try? await Product.products(for: Self.mattersIDs + Self.proIDs + Self.topUpIDs)) ?? []).sorted { $0.price < $1.price }
        trialOpen = await products.first(where: { Self.proIDs.contains($0.id) })?.subscription?.isEligibleForIntroOffer ?? false
    }

    /// "1 week free, then €7.99 a month" while the trial is still open; otherwise the price alone.
    func offer(of product: Product) -> String {
        guard trialOpen, let intro = product.subscription?.introductoryOffer, intro.paymentMode == .freeTrial else { return Self.price(of: product) }
        let period = intro.period
        let unit = switch period.unit {
        case .day: period.value == 1 ? "day" : "days"
        case .week: period.value == 1 ? "week" : "weeks"
        case .month: period.value == 1 ? "month" : "months"
        case .year: period.value == 1 ? "year" : "years"
        @unknown default: "periods"
        }
        return "\(period.value) \(unit) free, then " + Self.price(of: product)
    }

    /// A transaction done with: a top-up only once the beeserver has added it — until then the
    /// App Store keeps offering it, and it is sent again.
    private func settle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if Self.topUpIDs.contains(transaction.productID) {
            guard await BeeServer.shared.topUp(transaction: result.jwsRepresentation) else { return }
        }
        await transaction.finish()
    }

    /// What the App Store says this account has now.
    func refresh() async {
        var best: (plan: Plan, until: Date?) = (.free, nil)
        var signed: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            let plan = Self.plan(of: transaction.productID)
            if plan > best.plan || (plan == best.plan && (transaction.expirationDate ?? .distantFuture) > (best.until ?? .distantPast)) {
                best = (plan, transaction.expirationDate)
                signed = plan == .pro ? result.jwsRepresentation : nil
            }
        }
        bought = best
        if best.plan != .free { share(best) }
        remember()
        await readRenewal()
        // Pro bought or renewed here: the beeserver is told, once for each end date.
        if best.plan == .pro, let signed, let until = best.until, !DemoData.isRequested {
            let told = UserDefaults.standard.object(forKey: Self.redeemedKey) as? Date ?? .distantPast
            if until > told || BeeServer.storedToken == nil, await BeeServer.shared.subscribe(transaction: signed) {
                UserDefaults.standard.set(until, forKey: Self.redeemedKey)
            }
        }
    }

    /// Renews, ends, changes to another plan, or waits for the card — for the subscription this
    /// Apple Account has in Causabee's group.
    private func readRenewal() async {
        guard let product = products.first(where: { Self.plan(of: $0.id) != .free }),
              let statuses = try? await product.subscription?.status else { renewal = nil; return }
        for status in statuses {
            guard case .verified(let info) = status.renewalInfo, case .verified(let transaction) = status.transaction else { continue }
            let end = transaction.expirationDate ?? Date()
            switch status.state {
            case .inGracePeriod, .inBillingRetryPeriod:
                renewal = .billingProblem(until: info.gracePeriodExpirationDate)
                return
            case .subscribed:
                if !info.willAutoRenew { renewal = .ends(end) }
                else if let next = info.autoRenewPreference, next != transaction.productID, Self.plan(of: next) != Self.plan(of: transaction.productID) {
                    renewal = .changes(to: Self.plan(of: next), on: end)
                } else { renewal = .renews(end) }
                return
            default:
                continue
            }
        }
        renewal = nil
    }

    func buy(_ product: Product) async {
        buying = product.id
        problem = nil
        defer { buying = nil }
        do {
            switch try await product.purchase(options: [.appAccountToken(Self.accountID)]) {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    problem = "The App Store could not confirm the purchase. Nothing was charged that is not confirmed."
                    return
                }
                if Self.topUpIDs.contains(transaction.productID) {
                    // Added: Pro goes on at once. Not yet: kept by the App Store, and sent again.
                    if await BeeServer.shared.topUp(transaction: result.jwsRepresentation) {
                        await transaction.finish()
                        UserDefaults.standard.set(true, forKey: AutoMode.key)
                        asks = nil
                    } else {
                        problem = "The top-up is bought and kept: it is added as soon as the beeserver answers."
                    }
                    return
                }
                await transaction.finish()
                await refresh()
                if plan >= .matters { asks = nil }
            case .pending:
                problem = "The purchase waits for approval — Ask to Buy, or the bank."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            problem = error.localizedDescription
        }
    }

    func restore() async {
        problem = nil
        do { try await AppStore.sync() } catch { problem = error.localizedDescription }
        await refresh()
    }

    /// How many more matters may start now; nil for no limit.
    func room(in context: ModelContext) -> Int? {
        plan.room(open: Matter.openCount(in: (try? context.fetch(FetchDescriptor<Matter>())) ?? []))
    }

    /// Room for one more matter — or the plan sheet, saying why.
    func mayStartMatter(in context: ModelContext) -> Bool {
        if (room(in: context) ?? 1) > 0 { return true }
        asks = .matters
        return false
    }

    /// Pro may be turned on — with Pro, or with a top-up left — or the plan sheet.
    func mayTurnOnPro() -> Bool {
        if plan == .pro || BeeServer.hasCredit { return true }
        asks = .pro
        return false
    }

    /// What another device bought, from the profile.
    func readShared() {
        guard let context, let profile = (try? context.fetch(FetchDescriptor<Profile>()))?.first else { return }
        shared = (Plan(rawValue: profile.plan ?? "") ?? .free, profile.planUntil)
        remember()
    }

    /// Into the profile, for the Mac: only ever more, or for longer.
    private func share(_ bought: (plan: Plan, until: Date?)) {
        guard !DemoData.isRequested, let context, let profile = (try? context.fetch(FetchDescriptor<Profile>()))?.first else { return }
        let known = Plan(rawValue: profile.plan ?? "") ?? .free
        let stale = (profile.planUntil ?? .distantPast) < Date()
        guard bought.plan > known || stale || (bought.until ?? .distantFuture) > (profile.planUntil ?? .distantPast) else { return }
        profile.plan = bought.plan.rawValue
        profile.planUntil = bought.until ?? Date().addingTimeInterval(31 * 86_400)
        try? context.save()
        shared = (bought.plan, profile.planUntil)
    }

    private func remember() {
        UserDefaults.standard.set(plan.rawValue, forKey: Plan.cacheKey)
    }

    /// "€0.99 a month", "€9.99 a year".
    static func price(of product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        let unit = switch period.unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
        return period.value == 1 ? "\(product.displayPrice) a \(unit)" : "\(product.displayPrice) every \(period.value) \(unit)s"
    }
}
