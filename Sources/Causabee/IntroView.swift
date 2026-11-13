import AppKit
import MatterCore
import SwiftUI

/// What Causabee is (F008): the promise, then three calm pages, each a cut-out of a demo matter —
/// shown once, the first time the app starts, and again from Help. Nothing is asked here, and no
/// setup follows it. The pictures ship with the app bundle; a build without them — from
/// `swift run` — shows an empty frame in their place.
struct IntroView: View {
    /// Set once the owner has seen the introduction to its end or skipped it.
    static let seenKey = "intro.seen"

    /// The promise, then `Welcome`'s three pages (F008): the same words as the iPhone's and the iPad's.
    private static let count = Welcome.pages.count + 1

    /// The pictures at three quarters of the 813 × 508 they filled before, and the sheet shorter by
    /// what that frees, so no gap opens under the text.
    private static let pictureWidth: CGFloat = 610
    private static let size = CGSize(width: 880, height: 680)

    @Environment(\.dismiss) private var dismiss
    @AppStorage(IntroView.seenKey) private var seen = false
    @State private var index = 0
    /// The opener plays first (IntroOpener) whenever the introduction opens — on the first start,
    /// from Help, in the demo — but not for the introduction's pictures or the UI tests. A click or a
    /// key goes on to page 1 at once.
    @State private var opening = IntroShot.current == nil && ProcessInfo.processInfo.environment["CAUSABEE_UI_TEST"] == nil

    var body: some View {
        ZStack {
            pageView
                .opacity(opening ? 0 : 1)
                .disabled(opening)
            if opening {
                IntroOpener { withAnimation(.easeOut(duration: 0.6)) { opening = false } }
                    .transition(.opacity)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Theme.canvas)
    }

    @ViewBuilder private var pageView: some View {
        VStack(spacing: 0) {
            if index == 0 {
                promise
            } else {
                let page = Welcome.pages[index - 1]
                picture(page.image)
                    .frame(maxWidth: Self.pictureWidth, maxHeight: 360)
                    .padding([.horizontal, .top], 28)
                VStack(spacing: 10) {
                    Text(page.title).font(Theme.titleFont)
                    Text(page.line)
                        .font(.title3).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 640)
                }
                .padding(.horizontal, 28).padding(.top, 22)
                .frame(minHeight: 120, alignment: .top)
                .id(index)
            }
            Spacer(minLength: 16)
            HStack {
                Button("Skip") { finish() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .opacity(index == Self.count - 1 ? 0 : 1)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<Self.count, id: \.self) { dot in
                        Circle()
                            .fill(dot == index ? Theme.ink : Theme.strongLine)
                            .frame(width: 7, height: 7)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { index = dot } }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if index > 0 {
                        // The grey one beside the black one, drawn alike: one height, one corner, one type size.
                        Button("Back") { withAnimation(.easeOut(duration: 0.2)) { index -= 1 } }
                            .quietButton()
                            .keyboardShortcut(.leftArrow, modifiers: [])
                    }
                    // Into the person's own Causabee and its first step; the demo is a quiet link there.
                    Button(index == Self.count - 1 ? "Start" : "Next") { next() }
                        .filledButton()
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 28).padding(.bottom, 24)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Theme.canvas)
    }

    /// The promise: the bee, two lines, an example matter, and the privacy line — said once (AC-2).
    private var promise: some View {
        VStack(alignment: .leading, spacing: 16) {
            BeeMark(size: 48, livesNowAndThen: true).foregroundStyle(Theme.beeMark)
            Text(Welcome.promise).font(Theme.planNumberFont).fixedSize(horizontal: false, vertical: true)
            Text(Welcome.promiseLine).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                BeeChip(text: "1 for you · waiting for 1")
                Text("Care for Mum (Helga) after her fall").font(Theme.cardTitleFont)
                Text("Next, on Oct 6: The medical service visits").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .outlinedCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("An example: Care for Mum after her fall. Next, on October 6, the medical service visits.")
            Label(Welcome.privacy, systemImage: "lock.fill")
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .quietBox(radius: 8)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 28).padding(.top, 48)
        .id(index)
    }

    /// One part of a matter, cut out, in a frame of its own — never the whole window.
    private func picture(_ name: String) -> some View {
        Group {
            if let image = NSImage(named: name) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Theme.box.aspectRatio(1.6, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .id(name)
        .transition(.opacity)
    }

    private func next() {
        if index < Self.count - 1 {
            withAnimation(.easeOut(duration: 0.2)) { index += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        // The demo shares the owner's settings: seeing it there does not count for the real start.
        if !DemoData.isRequested { seen = true }
        dismiss()
    }
}
