import MatterCore
import StoreKit
import SwiftUI

/// The plans, one under the other, when a fourth matter would start, when Pro is asked for, or from
/// Settings: what each holds, its price as the App Store says it, and one button for the one
/// chosen. On the Mac from the website there is no App Store to buy in: it says to buy on the
/// iPhone or the iPad.
struct PlanSheet: View {
    let reason: Store.Reason
    @Environment(\.dismiss) private var dismiss
    @State private var store = Store.shared
    /// The row chosen, when the owner has chosen one.
    @State private var picked: String?

    private var title: String {
        switch reason {
        case .matters: "Room for a fourth matter"
        case .pro: "Causabee Pro"
        case .choose: "Your plan"
        }
    }

    private var lead: String {
        switch reason {
        case .matters: "Causabee holds \(Plan.freeMatters) open matters for free. Close one — or make room for all of them. Nothing you have is ever locked."
        case .pro: "The bigger AI reads new mail as it comes, writes each matter's brief and answers about everything — names always disguised."
        case .choose: "Free stays on your device. Plus for every matter, Pro for the bigger AI."
        }
    }

    /// One line of the list: a plan or a top-up, with the product to buy it, if this device can.
    private struct Choice: Identifiable {
        let id: String
        let name: String
        let holds: String
        var price: String?
        var product: Product?
        var yours = false
        /// Buying it says this, not the whole name.
        var short: String { name.replacingOccurrences(of: "Causabee ", with: "") }
    }

    private var choices: [Choice] {
        func price(_ ids: [String]) -> Product? { store.products.first { ids.contains($0.id) } }
        let yearly = store.products.first { $0.id.hasSuffix(".yearly") }
        let monthly = store.products.first { Store.mattersIDs.contains($0.id) && $0 != yearly }
        let pro = price(Store.proIDs), topUp = price(Store.topUpIDs)
        var all = [Choice(id: "free", name: "Causabee", holds: "\(Plan.freeMatters) open matters", price: "Free", yours: store.plan == .free)]
        all.append(Choice(id: "plus", name: "Causabee Plus", holds: "Every matter, on your device",
                          price: monthly.map(Store.price) ?? PlanShot.current?.price("plus"), product: monthly, yours: store.plan == .matters))
        if store.plan != .matters, yearly != nil || PlanShot.current != nil {
            all.append(Choice(id: "yearly", name: "Causabee Plus yearly", holds: "Every matter, on your device",
                              price: yearly.map(Store.price) ?? PlanShot.current?.price("yearly"), product: yearly))
        }
        all.append(Choice(id: "pro", name: "Causabee Pro", holds: "The bigger AI, up to a monthly limit, names always disguised",
                          price: pro.map(Store.price) ?? PlanShot.current?.price("pro"), product: pro, yours: store.plan == .pro))
        if topUp != nil || PlanShot.current != nil {
            all.append(Choice(id: "topup", name: store.plan == .pro ? "Top up this month" : "Pro, now and then",
                              holds: Self.topUpWords, price: topUp?.displayPrice ?? PlanShot.current?.price("topup"), product: topUp))
        }
        return all
    }

    /// Whether a row can be chosen: there is something to buy, and it is not the plan already held.
    private func canChoose(_ choice: Choice) -> Bool { !choice.yours && (choice.product != nil || (PlanShot.current != nil && choice.id != "free")) }

    /// What the one button buys: the row chosen, else what brought the sheet up.
    private var chosen: Choice? {
        let open = choices.filter(canChoose)
        return open.first { $0.id == picked }
            ?? open.first { $0.id == (store.plan == .pro ? "topup" : reason == .matters ? "plus" : "pro") } ?? open.first
    }

    static let topUpWords = "Adds a third of a month's Pro use, kept until it is used."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    BeeMark(size: 30).foregroundStyle(Theme.beeMark)
                    Text(title).font(Theme.titleFont)
                    Text(lead).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 8) {
                    ForEach(choices) { row($0) }
                }
                if let choice = chosen {
                    Button {
                        if let product = choice.product { Task { await store.buy(product) } }
                    } label: {
                        Group {
                            if store.buying == choice.product?.id, choice.product != nil { BeeLoader(size: 14) } else { Text(words(for: choice)) }
                        }
                        .frame(maxWidth: .infinity)
                        #if os(macOS)
                        .padding(.vertical, 3)
                        #endif
                    }
                    .filledButton()
                    .disabled(store.buying != nil)
                }
                if store.plan != .free, !store.products.isEmpty {
                    Text("Changing between Plus and Pro: up to Pro at once, the rest of Plus paid back by Apple; down to Plus at the next renewal. Cancelling is in your Apple Account.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if store.products.isEmpty, PlanShot.current == nil {
                    Text(Self.noStoreWords).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let problem = store.problem {
                    Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) {
                        Button("Restore Purchases") { Task { await store.restore() } }
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("Privacy", destination: URL(string: "https://causabee.app/privacy.html")!)
                    }
                    .font(.footnote)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Text("Subscriptions renew until cancelled in your Apple Account settings.")
                        .font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        #if os(macOS)
        .frame(width: 520, height: 620)
        #endif
        .overlay(alignment: .topTrailing) {
            Button("Done") { dismiss() }.quietButton().padding(16)
        }
        .task { if store.products.isEmpty { await store.load() } }
    }

    private func words(for choice: Choice) -> String {
        guard let product = choice.product else { return "Continue with \(choice.short) · \(choice.price ?? "")" }
        let offer = store.offer(of: product)
        // A free week says so by itself, and a name in front would not fit.
        return offer == Store.price(of: product) ? "Continue with \(choice.short) · \(offer)" : offer
    }

    #if os(macOS)
    private static let noStoreWords = "This Mac's Causabee comes from the website, where the App Store cannot sell. Choose a plan on your iPhone or iPad: this Mac follows through iCloud."
    #else
    private static let noStoreWords = "The App Store does not answer right now. Try again in a moment."
    #endif

    /// One line: grey, for it waits for a choice; the one chosen in the bee's colour. Nothing to
    /// choose in it when it is the plan already held, or when this device cannot buy.
    private func row(_ choice: Choice) -> some View {
        let can = canChoose(choice), on = can && chosen?.id == choice.id
        return Button { if can { picked = choice.id } } label: {
            HStack(spacing: 12) {
                if can {
                    ZStack {
                        Circle().strokeBorder(on ? Color.clear : Theme.strongLine, lineWidth: 1.5)
                        if on {
                            Circle().fill(Theme.bee)
                            Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.black)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(choice.name).fontWeight(.medium).foregroundStyle(.primary)
                        if choice.yours { BeeChip(text: "YOURS") }
                    }
                    Text(choice.holds).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let price = choice.price { Text(price).font(.subheadline).foregroundStyle(on ? .primary : .secondary).fixedSize() }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Theme.beeSoft : Theme.box, in: RoundedRectangle(cornerRadius: 12))
            .overlay { if on { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bee, lineWidth: 2) } }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Settings' first part, the same on every device, in three blocks: the plan with what is left of
/// it and a top-up; Pro's bolt; changing or managing it.
struct PlanSettings: View {
    @State private var store = Store.shared
    @State private var server = BeeServer.shared
    @State private var choosing = false
    @State private var managing = false
    @AppStorage(AutoMode.key) private var auto = false

    private var name: String {
        switch store.plan {
        case .free: "Causabee"
        case .matters: "Causabee Plus"
        case .pro: "Causabee Pro"
        }
    }

    private var holds: String {
        switch store.plan {
        case .free: "\(Plan.freeMatters) open matters. Apple's model on this device reads new mail — nothing leaves it."
        case .matters: "Every matter you need. Apple's model on this device reads new mail — nothing leaves it."
        case .pro: "Every matter, and the bigger AI up to a monthly limit."
        }
    }


    /// Renews, ends or changes — as this device's App Store says; on the Mac, until when.
    private var end: String {
        if let shot = PlanShot.current { return shot.end }
        switch store.renewal {
        case .renews(let date): return "renews " + Dates.long(date)
        case .ends(let date): return "ends " + Dates.long(date)
        case .changes(let plan, let date): return (plan == .pro ? "Pro" : "Plus") + " from " + Dates.long(date)
        case .billingProblem: return "payment problem"
        case nil:
            if store.plan == .free { return "Free" }
            return [store.bought.until, store.shared.until].compactMap { $0 }.max().map { "until " + Dates.long($0) } ?? ""
        }
    }

    /// Pro's bolt: with Pro, or with a top-up left.
    private var canUsePro: Bool { store.plan == .pro || BeeServer.hasCredit }

    private var pro: Binding<Bool> {
        Binding(get: { auto && canUsePro },
                set: { on in if !on { auto = false } else if store.mayTurnOnPro() { auto = true } })
    }

    /// What is left is on the page: it says more than what the plan holds.
    private var showsMeter: Bool { (BeeServer.isSetUp || PlanShot.current?.meters == true) && (server.kind == "credit" || server.monthUsed != nil) }

    private var topUpPrice: String? { store.products.first { Store.topUpIDs.contains($0.id) }?.displayPrice ?? PlanShot.current?.price("topup") }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name).font(Theme.cardTitleFont)
                    Spacer(minLength: 0)
                    Text(end).font(.footnote).foregroundStyle(.secondary)
                }
                if !showsMeter { Text(holds).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if case .billingProblem(let until) = store.renewal {
                    Text("Apple could not charge your payment method. " + (until.map { "The plan goes on until \(Dates.long($0)); " } ?? "")
                         + "update it in your Apple Account, and it renews as before.")
                        .font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
                if showsMeter { ProBar() }
                if store.plan == .free {
                    Button("See the plans") { choosing = true }.filledButton()
                } else if let price = topUpPrice {
                    topUp(price)
                }
                if let problem = server.problem ?? store.problem {
                    Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            // Asked of the server each time it is shown: here, where there is a view before the answer.
            .task {
                if BeeServer.isSetUp { await server.refresh() }
                if let shot = PlanShot.current, shot.meters { server.monthUsed = shot.used; server.renewsOn = "2026-11-28"; server.extraShare = shot.extra }
            }
            .sheetWhenAsked(isPresented: $choosing) { PlanSheet(reason: .choose) }
            #if os(iOS)
            .manageSubscriptionsSheet(isPresented: $managing)
            .onChange(of: managing) { if !managing { Task { await store.refresh() } } }
            #endif
        } header: { Text("Your plan") } footer: {
            if store.plan == .free { restore }
        }
        if canUsePro {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: pro) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").foregroundStyle(Theme.gold)
                            Text("Pro on")
                        }
                    }
                    Text(pro.wrappedValue ? "GPT-6.1 Sol reads new mail as it comes, names disguised first. What goes where, you decide."
                         : "Off: Apple's model on this device reads new mail when you tap “Sort in”. Nothing leaves it.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if store.plan != .free {
            Section {
                PlanRow("Change plan") { choosing = true }
                #if os(iOS)
                if store.bought.plan != .free || PlanShot.current != nil { PlanRow("Manage subscription") { managing = true } }
                #endif
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    #if os(macOS)
                    Text("Change or cancel it on your iPhone or iPad: this Mac follows through iCloud.")
                    #endif
                    restore
                }
            }
        }
    }

    private var restore: some View {
        Button("Restore Purchases") { Task { await store.restore() } }
            .buttonStyle(.plain).font(.footnote).foregroundStyle(.secondary)
    }

    /// Quiet while there is plenty left; the one thing to do once the month runs low.
    private func topUp(_ price: String) -> some View {
        let action = {
            if let product = store.products.first(where: { Store.topUpIDs.contains($0.id) }) { Task { await store.buy(product) } }
        }
        let label = (store.plan == .pro ? "Top up this month · " : "Pro, now and then · ") + price
        return VStack(alignment: .leading, spacing: 6) {
            if server.runsLow {
                Button(action: action) { Text(label) }.filledButton().disabled(store.buying != nil)
            } else {
                Button(action: action) { Text(label) }.quietButton().disabled(store.buying != nil)
            }
            Text(PlanSheet.topUpWords).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A row of Settings that opens something: its words, and the arrow.
private struct PlanRow: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `--demo --plan-shot low`: the plan as a picture shows it, with no App Store to ask: Pro with
/// plenty left, Pro running low, Plus, or free. With `--plan-sheet` the plans are open.
enum PlanShot: String {
    case pro, low, plus, free

    static let current: PlanShot? = {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--plan-shot"), at + 1 < arguments.count else { return nil }
        return PlanShot(rawValue: arguments[at + 1])
    }()

    /// With `--plan-sheet` the plans, else Settings.
    static var showsSheet: Bool { current != nil && CommandLine.arguments.contains("--plan-sheet") }

    var plan: Plan { self == .plus ? .matters : self == .free ? .free : .pro }
    var meters: Bool { self == .pro || self == .low }
    var used: Double { self == .low ? 0.88 : 0.41 }
    var extra: Double { self == .low ? 0 : 0.33 }
    var end: String { self == .free ? "Free" : self == .plus ? "renews 14 November" : "renews 31 October" }

    func price(_ what: String) -> String {
        switch what {
        case "plus": "0,99 € a month"
        case "yearly": "9,99 € a year"
        case "pro": "7,99 € a month"
        default: "2,99 €"
        }
    }
}

/// A part's name inside a section of Settings, where several parts share one heading.
struct SettingsPart: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View { Text(name).font(.subheadline.weight(.semibold)).padding(.top, 2) }
}
