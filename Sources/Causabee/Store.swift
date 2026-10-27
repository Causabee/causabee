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
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task {
            await load()
            await refresh()
        }
    }

    func load() async {
        products = ((try? await Product.products(for: Self.mattersIDs + Self.proIDs)) ?? []).sorted { $0.price < $1.price }
    }

    /// What the App Store says this account has now.
    func refresh() async {
        var best: (plan: Plan, until: Date?) = (.free, nil)
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            let plan: Plan = Self.proIDs.contains(transaction.productID) ? .pro : Self.mattersIDs.contains(transaction.productID) ? .matters : .free
            if plan > best.plan || (plan == best.plan && (transaction.expirationDate ?? .distantFuture) > (best.until ?? .distantPast)) {
                best = (plan, transaction.expirationDate)
            }
        }
        bought = best
        if best.plan != .free { share(best) }
        remember()
    }

    func buy(_ product: Product) async {
        buying = product.id
        problem = nil
        defer { buying = nil }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refresh()
                if plan >= .matters { asks = nil }
            case .success(.unverified):
                problem = "The App Store could not confirm the purchase. Nothing was charged that is not confirmed."
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

    /// Pro may be turned on — or the plan sheet.
    func mayTurnOnPro() -> Bool {
        if plan == .pro { return true }
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
