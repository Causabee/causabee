import MatterCore
import StoreKit
import SwiftUI

/// The plans, side by side, when a fourth matter would start, when Pro is asked for, or from
/// Settings: what each holds, its price as the App Store says it, and buying it there. On the Mac
/// from the website there is no App Store to buy in: it says to buy on the iPhone or the iPad.
struct PlanSheet: View {
    let reason: Store.Reason
    @Environment(\.dismiss) private var dismiss
    @State private var store = Store.shared

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
        case .choose: "Causabee is free and stays on your device. Plus for every matter, Pro for the bigger AI — when you need them."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    BeeMark(size: 30).foregroundStyle(Theme.beeMark)
                    Text(title).font(Theme.titleFont)
                    Text(lead).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                plan("Causabee", "\(Plan.freeMatters) open matters · Apple Intelligence on your device · nothing leaves it",
                     price: "Free", current: store.plan == .free, products: [])
                plan("Causabee Plus", "Every matter you need · on your device, nothing leaves it",
                     price: nil, current: store.plan == .matters, products: store.products.filter { Store.mattersIDs.contains($0.id) })
                plan("Causabee Pro", "The bigger AI, up to a monthly limit · every matter · names always disguised",
                     price: nil, current: store.plan == .pro, products: store.products.filter { Store.proIDs.contains($0.id) })
                ProBar()
                // More Pro for this month, once Pro is yours: as often as needed, kept until used.
                if store.plan == .pro, let topUp = store.products.first(where: { Store.topUpIDs.contains($0.id) }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("More Pro this month").font(.subheadline.weight(.medium))
                            Text("A third of a month more, kept until it is used.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button { Task { await store.buy(topUp) } } label: {
                            if store.buying == topUp.id { BeeLoader(size: 14) } else { Text(topUp.displayPrice) }
                        }
                        .filledButton()
                        .disabled(store.buying != nil)
                    }
                }
                if store.products.isEmpty {
                    Text(Self.noStoreWords).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let problem = store.problem {
                    Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 14) {
                    Button("Restore Purchases") { Task { await store.restore() } }
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link("Privacy", destination: URL(string: "https://causabee.app/privacy.html")!)
                }
                .font(.footnote)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.gold)
                Text("Subscriptions renew until cancelled in your Apple Account settings.")
                    .font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
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

    #if os(macOS)
    private static let noStoreWords = "This Mac's Causabee comes from the website, where the App Store cannot sell. Choose a plan on your iPhone or iPad — this Mac follows through your iCloud."
    #else
    private static let noStoreWords = "The App Store does not answer right now. Try again in a moment."
    #endif

    /// One plan: what it holds, and its prices — each a button to buy it.
    private func plan(_ name: String, _ holds: String, price: String?, current: Bool, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(name).font(.headline)
                if current { BeeChip(text: "YOURS") }
                Spacer(minLength: 0)
                if let price { Text(price).foregroundStyle(.secondary) }
            }
            Text(holds).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !current, !products.isEmpty {
                HStack(spacing: 8) {
                    ForEach(products, id: \.id) { product in
                        Button {
                            Task { await store.buy(product) }
                        } label: {
                            if store.buying == product.id { BeeLoader(size: 14) } else { Text(Store.price(of: product)) }
                        }
                        .filledButton()
                        .disabled(store.buying != nil)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
        .overlay { if current { RoundedRectangle(cornerRadius: 12).stroke(Theme.bee, lineWidth: 2) } }
    }
}

/// Settings' first part, the same on every device: which plan this is and until when, Pro's bolt
/// in words with this month's bar, and changing or restoring the plan.
struct PlanSettings: View {
    @State private var store = Store.shared
    @State private var server = BeeServer.shared
    @State private var choosing = false
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

    private var until: String? {
        let end = [store.bought.until, store.shared.until].compactMap { $0 }.max()
        return end.map { "until " + $0.formatted(.dateTime.day().month(.wide)) }
    }

    private var pro: Binding<Bool> {
        Binding(get: { auto && store.plan == .pro },
                set: { on in if !on { auto = false } else if store.mayTurnOnPro() { auto = true } })
    }

    var body: some View {
        LabeledContent(name, value: store.plan == .free ? "Free" : until ?? "")
        Text(holds).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        if store.plan == .pro {
            Toggle("Pro on (the bolt)", isOn: pro)
            Text(pro.wrappedValue ? "GPT-6.1 Sol reads new mail as it comes and answers your questions — names disguised first. What is taken in, and into which matter, you still decide."
                 : "Off: Apple's model on this device reads new mail when you tap “Sort in”. Nothing leaves it.")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ProBar()
            if let topUp = store.products.first(where: { Store.topUpIDs.contains($0.id) }) {
                Button {
                    Task { await store.buy(topUp) }
                } label: {
                    if store.buying == topUp.id { BeeLoader(size: 14) } else { Text("More Pro this month · \(topUp.displayPrice)") }
                }
                .buttonStyle(.borderless)
                .disabled(store.buying != nil)
                Text("A third of a month more, kept until it is used.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        if let problem = server.problem ?? store.problem {
            Text(problem).font(.footnote).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 16) {
            Button(store.plan == .free ? "See the plans …" : "Change plan …") { choosing = true }
            Button("Restore Purchases") { Task { await store.restore() } }
        }
        // Two buttons on one row of a form: each its own, not the whole row.
        .buttonStyle(.borderless)
        .sheet(isPresented: $choosing) { PlanSheet(reason: .choose) }
    }
}

/// A part's name inside a section of Settings, where several parts share one heading.
struct SettingsPart: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View { Text(name).font(.subheadline.weight(.semibold)).padding(.top, 2) }
}
