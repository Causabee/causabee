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
        case .matters: String(localized: "Room for a fourth matter")
        case .pro: "Causabee Pro"
        case .choose: String(localized: "Your plan")
        case .topUp: String(localized: "Pro, now and then")
        }
    }

    private var lead: String {
        switch reason {
        case .matters: String(format: String(localized: "Causabee holds %lld open matters for free. Close one — or make room for all of them. Nothing you have is ever locked."), Plan.freeMatters)
        case .pro: String(localized: "The bigger AI reads what comes in, as it comes, writes each matter's brief and answers about everything — names always disguised.")
        case .choose: String(localized: "Free stays on your device. Plus for every matter, Pro for the bigger AI.")
        case .topUp: String(format: String(localized: "A top-up lets Pro read again: %@"), Self.topUpWords.prefix(1).lowercased() + Self.topUpWords.dropFirst())
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
        var all = [Choice(id: "free", name: "Causabee", holds: String(format: String(localized: "%lld open matters"), Plan.freeMatters), price: String(localized: "Free"), yours: store.plan == .free)]
        all.append(Choice(id: "plus", name: "Causabee Plus", holds: String(localized: "Every matter, on your device"),
                          price: monthly.map(Store.price) ?? PlanShot.current?.price("plus"), product: monthly, yours: store.plan == .matters))
        if store.plan != .matters, yearly != nil || PlanShot.current != nil {
            all.append(Choice(id: "yearly", name: String(localized: "Causabee Plus yearly"), holds: String(localized: "Every matter, on your device"),
                              price: yearly.map(Store.price) ?? PlanShot.current?.price("yearly"), product: yearly))
        }
        all.append(Choice(id: "pro", name: "Causabee Pro", holds: String(localized: "The bigger AI, up to a monthly limit, names always disguised"),
                          price: pro.map(Store.price) ?? PlanShot.current?.price("pro"), product: pro, yours: store.plan == .pro))
        if topUp != nil || PlanShot.current != nil {
            all.append(Choice(id: "topup", name: store.plan == .pro ? String(localized: "Add a top-up") : String(localized: "Pro, now and then"),
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
            ?? open.first { $0.id == (store.plan == .pro || reason == .topUp ? "topup" : reason == .matters ? "plus" : "pro") } ?? open.first
    }

    static let topUpWords = String(localized: "Adds a third of a month's Pro use, kept until it is used.")

    var body: some View {
        #if os(iOS)
        // The bar's own glass, with the system's cross: the plans are only looked at, nothing to save.
        NavigationStack {
            page
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { dismiss() }.accessibilityLabel("Done") } }
        }
        #else
        page.overlay(alignment: .topTrailing) {
            Button("Done") { dismiss() }.quietButton().padding(16)
        }
        #endif
    }

    private var page: some View {
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
        .task { if store.products.isEmpty { await store.load() } }
    }

    private func words(for choice: Choice) -> String {
        guard let product = choice.product else { return String(format: String(localized: "Continue with %@ · %@"), choice.short, choice.price ?? "") }
        let offer = store.offer(of: product)
        // A free week says so by itself, and a name in front would not fit.
        return offer == Store.price(of: product) ? String(format: String(localized: "Continue with %@ · %@"), choice.short, offer) : offer
    }

    #if os(macOS)
    private static let noStoreWords = String(localized: "This Mac's Causabee comes from the website, where the App Store cannot sell. Choose a plan on your iPhone or iPad: this Mac follows through iCloud.")
    #else
    private static let noStoreWords = String(localized: "The App Store does not answer right now. Try again in a moment.")
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
                        if choice.yours { BeeChip(text: String(localized: "YOURS")) }
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

/// What the plan says now, for the page, its row in Settings and the switch (F007): one set of words
/// on every device, from what is bought, what is left, and whether "Use Pro" is on.
@MainActor
enum PlanNow {
    static func meter(useOn: Bool) -> ProMeter { BeeServer.shared.meter(inUse: useOn) }

    static func words(useOn: Bool) -> PlanWords {
        let store = Store.shared
        let renewal: PlanWords.Renewal? = switch store.renewal {
        case .renews(let date): .renews(date)
        case .ends(let date): .ends(date)
        case .changes(let plan, let date): .changes(to: plan, on: date)
        case .billingProblem(let until): .billingProblem(until)
        case nil: nil
        }
        return PlanWords(plan: store.plan, renewal: renewal, until: [store.bought.until, store.shared.until].compactMap { $0 }.max(),
                         proEnded: store.proEnded, meter: meter(useOn: useOn), credit: BeeServer.hasCredit || BeeServer.shared.extraShare > 0,
                         useOn: useOn, wait: ProWait.stored, reader: AIJob.read.model.shortLabel)
    }
}

/// "Use Pro": whether Pro, or a top-up, is used now — never what is bought (F007). Without either, a
/// tap shows the plans; used up, it stays on and waits.
struct UseProToggle: View {
    @AppStorage(AutoMode.key) private var auto = false
    @State private var store = Store.shared

    var body: some View {
        let words = PlanNow.words(useOn: auto)
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { words.switchShownOn },
                                 set: { on in if !on { auto = false } else if store.mayTurnOnPro() { auto = true } })) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.gold)
                    Text("Use Pro")
                }
            }
            Text(words.switchLine)
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("settings.usePro")
    }
}

/// The top of Settings on the iPhone and the iPad (F007): the plan in one row that opens its page,
/// and "Use Pro" — so Settings opens with its own sections in view.
struct PlanUsageRows: View {
    @AppStorage(AutoMode.key) private var auto = false
    @State private var store = Store.shared
    @State private var server = BeeServer.shared

    var body: some View {
        let words = PlanNow.words(useOn: auto), meter = PlanNow.meter(useOn: auto)
        Section {
            NavigationLink {
                Form { PlanSettings() }
                    .navigationTitle("Plan and usage")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan and usage")
                    Text(words.row).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    // The bar now in use, thin: the month's while any is left, then the top-ups' — the
                    // first alone said "used up" while top-ups were in use (the owner's iPhone, 12 November:
                    // "it should always show what using").
                    if let bar = meter.bars.first(where: { $0.counted && $0.kind == meter.using }) {
                        GeometryReader { box in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.line)
                                Capsule().fill(!bar.inUse ? Theme.strongLine : bar.low ? Theme.warning : bar.kind == .month ? Theme.bee : Theme.topUp)
                                    .frame(width: max(4, box.size.width * bar.length))
                            }
                        }
                        .frame(maxWidth: 220).frame(height: 4)
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
            .accessibilityIdentifier("settings.plan")
            UseProToggle()
        }
        .task {
            if BeeServer.isSetUp { await server.refresh() }
            if let shot = PlanShot.current, shot.meters { shot.fill(server) }
        }
    }
}

/// The plan's page — "Plan and usage" on the iPhone and the iPad, the Plan pane on the Mac, the plan
/// in the setup assistant: what is bought, what is left of it, a top-up, "Use Pro", and changing it.
struct PlanSettings: View {
    @State private var store = Store.shared
    @State private var server = BeeServer.shared
    @State private var choosing = false
    @State private var managing = false
    @AppStorage(AutoMode.key) private var auto = false

    private var holds: String {
        switch store.plan {
        case .free: String(format: String(localized: "%lld open matters. Apple's model on this device reads what comes in — nothing leaves it."), Plan.freeMatters)
        case .matters: String(localized: "Every matter you need. Apple's model on this device reads what comes in — nothing leaves it.")
        case .pro: String(localized: "Every matter, and the bigger AI up to a monthly limit.")
        }
    }

    private var topUpPrice: String? { store.products.first { Store.topUpIDs.contains($0.id) }?.displayPrice ?? PlanShot.current?.price("topup") }

    var body: some View {
        let words = PlanNow.words(useOn: auto), meter = PlanNow.meter(useOn: auto)
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(words.name).font(Theme.cardTitleFont)
                    Spacer(minLength: 0)
                    Text(PlanShot.current?.end ?? words.corner).font(.footnote).foregroundStyle(.secondary)
                }
                if meter.bars.isEmpty { Text(holds).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if case .billingProblem(let until) = store.renewal {
                    Text(until.map { String(format: String(localized: "Apple could not charge your payment method. The plan goes on until %@; update it in your Apple Account, and it renews as before."), Dates.long($0)) }
                         ?? String(localized: "Apple could not charge your payment method. update it in your Apple Account, and it renews as before."))
                        .font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
                ProBar(meter: meter)
                if words.seesPlans {
                    Button("See the plans") { choosing = true }.filledButton()
                } else if let label = words.topUp, let price = topUpPrice {
                    topUp(label, price, low: meter.runsLow)
                }
                if let problem = server.problem ?? store.problem {
                    Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            // Asked of the server each time it is shown: here, where there is a view before the answer.
            .task {
                if BeeServer.isSetUp { await server.refresh() }
                if let shot = PlanShot.current, shot.meters { shot.fill(server) }
            }
            .sheetWhenAsked(isPresented: $choosing) { PlanSheet(reason: .choose) }
            #if os(iOS)
            .manageSubscriptionsSheet(isPresented: $managing)
            .onChange(of: managing) { if !managing { Task { await store.refresh() } } }
            #endif
        } header: { Text("Your plan") } footer: {
            if store.plan == .free { restore }
        }
        Section { UseProToggle() }
        if store.plan != .free {
            Section {
                PlanRow(String(localized: "Change plan")) { choosing = true }
                #if os(iOS)
                if store.bought.plan != .free || PlanShot.current != nil { PlanRow(String(localized: "Manage subscription")) { managing = true } }
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

    /// Quiet while there is plenty left; the one thing to do once Pro runs low.
    private func topUp(_ label: String, _ price: String, low: Bool) -> some View {
        let action = {
            if let product = store.products.first(where: { Store.topUpIDs.contains($0.id) }) { Task { await store.buy(product) } }
        }
        let text = label + " · " + price
        return VStack(alignment: .leading, spacing: 6) {
            if low {
                Button(action: action) { Text(text) }.filledButton().disabled(store.buying != nil)
            } else {
                Button(action: action) { Text(text) }.quietButton().disabled(store.buying != nil)
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
    /// `topups`: Pro bought once and ended, top-ups left — Free, with the top-ups' bar alone (F006).
    case pro, low, plus, free, topups

    static let current: PlanShot? = {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--plan-shot"), at + 1 < arguments.count else { return nil }
        return PlanShot(rawValue: arguments[at + 1])
    }()

    /// With `--plan-sheet` the plans, else Settings.
    static var showsSheet: Bool { current != nil && CommandLine.arguments.contains("--plan-sheet") }

    var plan: Plan { self == .plus ? .matters : self == .free || self == .topups ? .free : .pro }
    var meters: Bool { self == .pro || self == .low || self == .topups }
    var used: Double { self == .topups ? 1 : self == .low ? 0.88 : 0.41 }
    var extra: Double { self == .topups ? 0.37 : self == .low ? 0 : 0.33 }
    var end: String { self == .topups ? "Pro ended 7 November" : self == .free ? "Free" : self == .plus ? "renews 14 November" : "renews 31 October" }

    /// What the beeserver would say, for the picture.
    @MainActor func fill(_ server: BeeServer) {
        server.monthUsed = used; server.renewsOn = "2026-11-28"; server.extraShare = extra; server.kind = "apple"; server.counted = true
    }

    /// When Pro ended, in the picture of top-ups alone.
    var proEnded: Date? { self == .topups ? MatterStatus.date(of: "2026-11-07") : nil }

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
