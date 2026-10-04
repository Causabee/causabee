import AppKit
import SwiftUI

/// What Causabee is, in five pictures of the demo's matters: shown once, the first time the app
/// starts, and again from Help. The pictures ship with the app bundle; a build without them — from
/// `swift run` — shows an empty frame in their place.
struct IntroView: View {
    /// Set once the owner has seen the introduction to its end or skipped it.
    static let seenKey = "intro.seen"

    struct Page {
        let image: String
        let title: String
        let text: String
        /// A line of its own under the text, with a lock: what stays private.
        var privacy: String? = nil
    }

    static let pages = [
        Page(image: "intro-1", title: "Mail, files, screenshots: sorted into matters",
             text: "Give Causabee whatever you have: a mail, a PDF, a screenshot. It sorts everything into matters, like a trip, a move or care for a parent, and the overview shows what comes next and what is late.",
             privacy: "Private by design: your mail and files stay on your Mac. Before anything goes to the AI, names, addresses and numbers are replaced."),
        Page(image: "intro-2", title: "One page for each matter",
             text: "The next step, a short summary, your own notes and every task, all in one place. On the left is the assistant for this matter."),
        Page(image: "intro-3", title: "Who does what, and by when",
             text: "Tasks are yours, shared, or someone else's you wait for, and some can only start after another. Dates and tasks go to Calendar and Reminders with one click."),
        Page(image: "intro-4", title: "Files, links and people",
             text: "Attachments, shared documents and everyone involved, each with their role. Every fact links back to the mail it came from."),
        Page(image: "intro-5", title: "Ask about a matter",
             text: "Ask a question and get an answer with its sources. A suggestion becomes a task with one click. Your question goes out disguised, like everything else."),
    ]

    /// The pictures at three quarters of the 813 × 508 they filled before, and the sheet shorter by
    /// what that frees, so no gap opens under the text.
    private static let pictureWidth: CGFloat = 610
    private static let size = CGSize(width: 880, height: 680)

    @Environment(\.dismiss) private var dismiss
    @AppStorage(IntroView.seenKey) private var seen = false
    @State private var index = 0

    var body: some View {
        let page = Self.pages[index]
        VStack(spacing: 0) {
            picture(page.image)
                .frame(maxWidth: Self.pictureWidth)
                .padding([.horizontal, .top], 28)
            VStack(spacing: 10) {
                Text(page.title).font(Theme.titleFont)
                Text(page.text)
                    .font(.title3).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640)
                if let privacy = page.privacy {
                    Label(privacy, systemImage: "lock.fill")
                        .font(.callout)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Theme.box, in: RoundedRectangle(cornerRadius: 8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 680)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28).padding(.top, 22)
            .frame(minHeight: 170, alignment: .top)
            .id(index)
            Spacer(minLength: 16)
            HStack {
                Button("Skip") { finish() }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .opacity(index == Self.pages.count - 1 ? 0 : 1)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(Self.pages.indices, id: \.self) { dot in
                        Circle()
                            .fill(dot == index ? Theme.ink : Theme.strongLine)
                            .frame(width: 7, height: 7)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { index = dot } }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if index > 0 {
                        Button("Back") { withAnimation(.easeOut(duration: 0.2)) { index -= 1 } }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                    }
                    // A look around first, with nothing to set up: the made-up matters, apart from any real ones.
                    if index == Self.pages.count - 1, !DemoData.isRequested {
                        Button("Try the demo") { seen = true; DemoData.restart(demo: true) }
                            .help("Starts Causabee again with nine made-up matters, kept apart from your own. The sidebar has the way back.")
                    }
                    Button(index == Self.pages.count - 1 ? "Get started" : "Next") { next() }
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

    /// The screenshot in a frame of its own, so a window shows as a window on the sheet.
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
        if index < Self.pages.count - 1 {
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
