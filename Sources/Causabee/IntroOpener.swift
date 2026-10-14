import AppKit
import SwiftUI

/// The first start's opener, in the introduction's sheet before its first page — about six seconds,
/// without sound (docs/opener has the prototype and its film). The pieces a matter is made of come
/// in from the edges — a mail, a PDF, a screenshot, a chat — and are drawn into the middle, where
/// the app icon forms from them: its stripes sort in one after another and its wings beat twice, as
/// the website's icon does. Then the bee is glad once, as when a task is ticked (BeeJoyView), the
/// name and the line come, and all of it goes for the introduction's page 1.
///
/// Everything is worked out from the time since it began, so a frame is the same whenever it is
/// drawn. A click or a key goes on to page 1 at once. With Reduce Motion the icon and the name
/// stand for a moment and fade; nothing moves.
struct IntroOpener: View {
    /// Called once it is over, or skipped: the sheet then shows page 1.
    let done: () -> Void
    /// A moment of it held still, in seconds: for its previews and `--opener-frames`.
    var at: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()
    @State private var finished = false
    @FocusState private var focused: Bool

    /// When everything has gone and page 1 may come, in seconds; a moment, with Reduce Motion.
    private var length: Double { reduceMotion ? 1.6 : 5.85 }

    var body: some View {
        TimelineView(.animation(paused: finished)) { timeline in
            let t = at ?? timeline.date.timeIntervalSince(began)
            ZStack {
                if !reduceMotion { pieces(t) }
                VStack(spacing: 0) {
                    icon(t).frame(width: 200, height: 200)
                    Text("Causabee")
                        .font(.custom("Source Serif 4", size: 52, relativeTo: .largeTitle).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 40)
                        .modifier(Rise(t: t, at: 3.2, still: reduceMotion))
                    Text("Be organized. Be private.")
                        .font(.title2).foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .modifier(Rise(t: t, at: 3.45, still: reduceMotion))
                }
                .opacity(1 - leaving(t))
                .scaleEffect(1 - 0.1 * leaving(t))
                .offset(y: -20 * leaving(t))
                .offset(y: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress { _ in finish(); return .handled }
        .onAppear { began = Date(); focused = true }
        .task {
            guard at == nil else { return }
            try? await Task.sleep(for: .seconds(length))
            finish()
        }
        .accessibilityElement()
        .accessibilityLabel("Causabee. Be organized. Be private.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Goes on to the introduction")
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        done()
    }

    /// How far the icon, the name and the line have gone at the end, 0 to 1.
    private func leaving(_ t: Double) -> Double {
        reduceMotion ? Self.clamp((t - 1.2) / 0.4) : Self.easeIn(Self.clamp((t - 5.3) / 0.55))
    }

    // MARK: The icon

    private func icon(_ t: Double) -> some View {
        // In from nothing with a spring, as the pieces arrive in the middle.
        let popped = reduceMotion ? 1 : Self.springOut(Self.clamp((t - 2.05) / 0.7))
        // The stripes, one after another from the top, 0.08 s apart, each in 0.7 s.
        let stripes = (0..<6).map { reduceMotion ? 1.0 : Self.easeOut(Self.clamp((t - 2.3 - Double($0) * 0.08) / 0.7)) }
        // The wings beat twice, out to 16° and back, from 2.5 s: the website's icon.
        let beating = Self.clamp((t - 2.5) / 1.2)
        let flap = beating > 0 && beating < 1 ? 16 * sin(.pi * (beating * 2).truncatingRemainder(dividingBy: 1)) : 0
        // Then glad once, from 3.85 s: BeeJoyView's lift, bob and rock, and its wings 4.5 times a second.
        let glad = Glad(t: t - 3.85)
        return ZStack {
            RoundedRectangle(cornerRadius: 200 * 230 / 1024, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.882, blue: 0.302), Color(red: 1, green: 0.78, blue: 0)],
                                     startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                BeeLoader.drawIcon(in: context, size: size, stripes: stripes,
                                   wing: reduceMotion ? 0 : flap + glad.wing, grown: glad.grown, rocked: glad.rocked)
            }
            .foregroundStyle(Color(red: 0x22 / 255, green: 0x21 / 255, blue: 0x1B / 255))
        }
        .shadow(color: Color(red: 127 / 255, green: 94 / 255, blue: 0).opacity(0.32), radius: 25, y: 20)
        .scaleEffect(popped)
        .opacity(min(1, popped * 3))
    }

    /// The bee while it is glad, `t` seconds into its 1.05 s, as BeeJoyView moves it.
    private struct Glad {
        var wing = 0.0, grown = 1.0, rocked = 0.0
        init(t: Double) {
            let length = 1.05, x = t / length
            guard x > 0, x < 1 else { return }
            let up = 0.22, down = 0.8
            let lift = x < up ? IntroOpener.easeInOut(x / up) : x < down ? 1 : 1 - IntroOpener.easeInOut((x - down) / (1 - down))
            let held = x < up || x > down ? 0 : (x - up) / (down - up)
            let bob = sin(held * .pi * 2 * 3) * 0.05 * lift
            wing = (-5 + 30 * (0.5 - 0.5 * cos(2 * .pi * t * 4.5))) * lift
            grown = 1 + (0.34 + bob) * lift
            rocked = sin(held * .pi * 3) * 6 * lift
        }
    }

    // MARK: The pieces

    /// A mail, a PDF, a screenshot and a chat: each comes in from its edge, floats, and at 1.7 s all
    /// are drawn into the middle, small and fading, where the icon pops up.
    private func pieces(_ t: Double) -> some View {
        let gather = Self.easeIn(Self.clamp((t - 1.7) / 0.5))
        let middle = CGPoint(x: 440, y: 300)
        return ZStack {
            ForEach(Piece.all) { piece in
                let arrived = Self.easeOut(Self.clamp((t - piece.delay) / 1.1))
                let float = t > piece.delay + 1.1 ? 5 * sin((t - piece.delay - 1.1) * .pi / 2.4) : 0
                let x = piece.at.x + piece.from.width * (1 - arrived)
                let y = piece.at.y + piece.from.height * (1 - arrived) - float
                piece.view
                    .rotationEffect(.degrees(piece.turn))
                    .scaleEffect(1 - 0.88 * gather)
                    .position(x: x + (middle.x - x) * gather, y: y + (middle.y - y) * gather)
                    .opacity(arrived * (1 - gather))
            }
        }
        .frame(width: 880, height: 680)
    }

    private struct Piece: Identifiable {
        let id: Int
        let at: CGPoint
        let from: CGSize
        let turn: Double
        let delay: Double
        let view: AnyView

        @MainActor static let all: [Piece] = [
            Piece(id: 0, at: CGPoint(x: 260, y: 150), from: CGSize(width: -350, height: -40), turn: -6, delay: 0.2, view: AnyView(card {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dr. Brandt").font(.system(size: 15, weight: .semibold))
                    Text("Prescription for the bath seat is ready").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            })),
            Piece(id: 1, at: CGPoint(x: 630, y: 145), from: CGSize(width: 350, height: -30), turn: 5, delay: 0.45, view: AnyView(card {
                HStack(spacing: 9) {
                    Text("PDF").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 25, height: 31, alignment: .bottom).padding(.bottom, 3)
                        .background(Color(red: 0.91, green: 0.27, blue: 0.23), in: RoundedRectangle(cornerRadius: 4))
                    Text("Insurance_letter.pdf").font(.system(size: 15, weight: .semibold))
                }
            })),
            Piece(id: 2, at: CGPoint(x: 625, y: 430), from: CGSize(width: 350, height: 60), turn: -4, delay: 0.7, view: AnyView(card {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(Theme.bee).frame(width: 72, height: 8)
                    Capsule().fill(Theme.line).frame(width: 120, height: 8)
                    Capsule().fill(Theme.line).frame(width: 96, height: 8)
                    Capsule().fill(Theme.line).frame(width: 60, height: 8)
                }
                .frame(width: 128, height: 74, alignment: .topLeading)
            })),
            Piece(id: 3, at: CGPoint(x: 260, y: 440), from: CGSize(width: -350, height: 60), turn: 4, delay: 0.95, view: AnyView(
                Text("Nina: Who does what this week?").font(.system(size: 15)).foregroundStyle(.white)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(Color(red: 0.2, green: 0.78, blue: 0.35),
                                in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
            )),
        ]

        private static func card(@ViewBuilder _ content: () -> some View) -> some View {
            content()
                .padding(.horizontal, 15).padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06)))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
                .environment(\.colorScheme, .light)
        }
    }

    /// The name and the line: up and in, from `at` seconds.
    private struct Rise: ViewModifier {
        let t: Double, at: Double, still: Bool
        func body(content: Content) -> some View {
            let shown = still ? 1 : IntroOpener.easeOut(IntroOpener.clamp((t - at) / 0.7))
            content.opacity(shown).offset(y: 15 * (1 - shown))
        }
    }

    // MARK: Its frames

    /// `--opener-frames <folder>`: the opener drawn frame by frame, 30 a second at 2×, as PNGs in the
    /// folder — for its film (docs/opener) and for checking it — and the app quits.
    static func renderFramesIfAsked() {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--opener-frames"), at + 1 < arguments.count else { return }
        let folder = URL(fileURLWithPath: arguments[at + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let count = Int(6.2 * 30)
        for frame in 0..<count {
            let renderer = ImageRenderer(content: IntroOpener(done: {}, at: Double(frame) / 30)
                .frame(width: 880, height: 680)
                .environment(\.colorScheme, .light))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: folder.appendingPathComponent(String(format: "f%04d.png", frame)))
        }
        print("✓ \(count) frames of the opener in \(folder.path)")
        exit(0)
    }

    // MARK: Easing

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeIn(_ x: Double) -> Double { x * x * x }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
    /// Past 1 and back, once, as a spring lands.
    static func springOut(_ x: Double) -> Double { x <= 0 ? 0 : x >= 1 ? 1 : 1 + 2.2 * pow(x - 1, 3) + 1.2 * pow(x - 1, 2) }
}

#Preview("Pieces") { IntroOpener(done: {}, at: 1.5).frame(width: 880, height: 680) }
#Preview("Stripes") { IntroOpener(done: {}, at: 2.7).frame(width: 880, height: 680) }
#Preview("Glad") { IntroOpener(done: {}, at: 4.2).frame(width: 880, height: 680) }
#Preview("Name") { IntroOpener(done: {}, at: 5).frame(width: 880, height: 680) }
