import MatterCore
import SwiftData
import SwiftUI

/// The first start on the iPhone and the iPad, and again from ⋯ on the overview (F008): the
/// promise, then three calm pages — each a cut-out of a matter, a title and one line — then Start,
/// into the person's own Causabee and its first step. Nothing is asked here. The words are
/// `Welcome`'s, the same as the Mac's.
struct WelcomeSheet: View {
    static let seenKey = "intro.seen"

    /// The promise and the pages.
    private static let count = Welcome.pages.count + 1

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                page { promise }.tag(0)
                ForEach(Array(Welcome.pages.enumerated()), id: \.offset) { offset, item in
                    page { picturePage(item) }.tag(offset + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // The dots and the buttons stay at the foot, whatever the page.
            .safeAreaInset(edge: .bottom) { foot }
            .background(Theme.canvas)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetConfirm("Done") { finish() } } }
        }
    }

    /// One page: as wide as the sheet, its words in a column a person reads comfortably — on an
    /// iPad's wide sheet too — and scrolling when a large type size needs more than the screen.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var promise: some View {
        VStack(alignment: .leading, spacing: 16) {
            BeeMark(size: 44, livesNowAndThen: true).foregroundStyle(Theme.beeMark)
            Text(Welcome.promise).font(Theme.phoneTitleFont).fixedSize(horizontal: false, vertical: true)
            Text(Welcome.promiseLine)
                .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            sample.padding(.top, 8)
            // Said once, here (F008 AC-2).
            Label(Welcome.privacy, systemImage: "lock.fill")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .phoneBox()
        }
        .padding(.top, 24)
    }

    /// One matter as the overview shows it — a picture of what is to come, not a real one.
    private var sample: some View {
        VStack(alignment: .leading, spacing: 8) {
            BeeChip(text: "1 for you · waiting for 1")
            Text("Care for Mum (Helga) after her fall").font(Theme.phoneCardTitleFont).fixedSize(horizontal: false, vertical: true)
            Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .phoneCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("An example: Care for Mum after her fall. Next, on October 6, the medical service visits.")
    }

    /// A cut-out of a demo matter, its title and one line.
    private func picturePage(_ item: Welcome.Page) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            picture("phone-" + item.image + ".jpg")
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            Text(item.title).font(Theme.phoneCardTitleFont).fixedSize(horizontal: false, vertical: true)
            Text(item.line).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }

    /// One part of a matter, cut out — never the whole screen: rounded and framed, the frame on the
    /// picture's own edge, so nothing is cut and no empty band shows; at most 280 points high.
    private func picture(_ name: String) -> some View {
        Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image).resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
            } else {
                Theme.box.aspectRatio(1.4, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))
        .frame(maxHeight: 280)
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .accessibilityHidden(true)
    }

    /// The dots, and the way on: Next through the pages, Skip and Start both into Causabee.
    private var foot: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<Self.count, id: \.self) { dot in
                    Circle().fill(dot == index ? Theme.ink : Theme.strongLine).frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Page \(index + 1) of \(Self.count)")
            VStack(spacing: 8) {
                if index < Self.count - 1 {
                    Button("Next") { go(index + 1) }.buttonStyle(.phone(filled: true, wide: true))
                    Button("Skip") { finish() }.buttonStyle(.phone(wide: true))
                } else {
                    // Into the person's own Causabee: the first step, or their matters.
                    Button("Start") { finish() }.buttonStyle(.phone(filled: true, wide: true))
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas)
    }

    private func go(_ page: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index = page }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        dismiss()
    }
}
