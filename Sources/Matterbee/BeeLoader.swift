import SwiftUI

/// Matterbee at work: the icon's bee, its stripes lighting up one after another from the top as if
/// sorting, its wings beating, the whole bee hovering. One beat of 2.4 seconds holds one sort, two
/// wing beats and one hover, so the three never drift apart.
///
/// For the waits on the AI and on longer work; a short check keeps the Mac's own spinner. Ink in the
/// light, honey in the dark, as the icon. With Reduce Motion the bee stands still and only fades.
struct BeeLoader: View {
    /// The height, as a small `ProgressView`'s; the bee is half as wide again.
    var size: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15 : nil)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvas in
                Self.draw(in: context, size: canvas, time: time, still: reduceMotion)
            }
        }
        .frame(width: size * Self.aspect, height: size)
        .foregroundStyle(Theme.beeMark)
        // The words beside it say what is going on.
        .accessibilityHidden(true)
    }

    // MARK: The drawing, in the icon's own units (App/Resources/BeeStripesWings.icon)

    /// The bee with room above it for the hover and the stripes dropping in, and at each side for
    /// the wings: swung out to 16°, a wing's tip reaches about 300 past the body's drawing — so 450,
    /// the same on both sides, and the bee stays in the middle.
    private static let box = CGRect(x: -450, y: -300, width: 4201 + 900, height: 2900)
    static let aspect = box.width / box.height
    private static let beat = 2.4

    private static let bars: [(x: CGFloat, y: CGFloat, width: CGFloat)] = [
        (1525, 0, 1151), (1241, 436, 1719), (1241, 872, 1719), (1436, 1308, 1329), (1729.5, 1744, 742), (1925.5, 2180, 350),
    ]

    /// The left wing: a drop hanging from the body's top. The right one is its mirror.
    private static let leftWing: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 840.879, y: 830.165))
        path.addCurve(to: CGPoint(x: 1064.5, y: 915.257), control1: CGPoint(x: 919.099, y: 742.266), control2: CGPoint(x: 1064.5, y: 797.594))
        path.addLine(to: CGPoint(x: 1064.5, y: 1953.13))
        path.addCurve(to: CGPoint(x: 1065, y: 1976.37), control1: CGPoint(x: 1064.83, y: 1960.84), control2: CGPoint(x: 1065, y: 1968.59))
        path.addCurve(to: CGPoint(x: 1064.5, y: 1999.61), control1: CGPoint(x: 1065, y: 1984.16), control2: CGPoint(x: 1064.83, y: 1991.9))
        path.addLine(to: CGPoint(x: 1064.5, y: 2052.87))
        path.addLine(to: CGPoint(x: 1059.83, y: 2050.87))
        path.addCurve(to: CGPoint(x: 532.5, y: 2508.87), control1: CGPoint(x: 1023.6, y: 2309.69), control2: CGPoint(x: 801.309, y: 2508.87))
        path.addCurve(to: CGPoint(x: 0, y: 1976.37), control1: CGPoint(x: 238.408, y: 2508.87), control2: CGPoint(x: 0, y: 2270.46))
        path.addCurve(to: CGPoint(x: 155.956, y: 1599.85), control1: CGPoint(x: 0, y: 1829.33), control2: CGPoint(x: 59.598, y: 1696.21))
        path.closeSubpath()
        return path
    }()
    private static let rightWing = leftWing.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 4201, ty: 0))
    /// Where each wing meets the body, which it turns around.
    private static let leftRoot = CGPoint(x: 1010, y: 880)
    private static let rightRoot = CGPoint(x: 3191, y: 880)

    /// `asIcon`: the pose of the app icon — wings straight, nothing moving.
    fileprivate static func draw(in context: GraphicsContext, size: CGSize, time: TimeInterval, still: Bool, asIcon: Bool = false) {
        var context = context
        let scale = size.height / box.height
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        // Still, the whole bee breathes in and out every two seconds.
        let fade = still ? 0.45 + 0.55 * (0.5 + 0.5 * cos(2 * .pi * time / 2)) : 1
        if !still { context.translateBy(x: 0, y: -90 * (1 - cos(2 * .pi * time / beat)) / 2) }

        // The wings, half see-through as on the icon: out to 16° and back in 1.2 s.
        let swing = still ? 0 : easeInOut(triangle(time / (beat / 2)))
        let angle = Angle.degrees(asIcon ? 0 : -4 + 20 * swing)
        fill(leftWing, turned: angle, around: leftRoot, opacity: 0.55 * fade, in: context)
        fill(rightWing, turned: -angle, around: rightRoot, opacity: 0.55 * fade, in: context)

        for (index, bar) in bars.enumerated() {
            let turn = still ? (opacity: 1.0, drop: CGFloat(0)) : sorting(fraction((time - Double(index) * 0.16) / beat))
            var layer = context
            layer.opacity = turn.opacity * fade
            let rect = CGRect(x: bar.x, y: bar.y + turn.drop, width: bar.width, height: 264)
            layer.fill(Path(roundedRect: rect, cornerRadius: 112), with: .foreground)
        }
    }

    private static func fill(_ wing: Path, turned angle: Angle, around root: CGPoint, opacity: Double, in context: GraphicsContext) {
        var layer = context
        layer.opacity = opacity
        layer.translateBy(x: root.x, y: root.y)
        layer.rotate(by: angle)
        layer.translateBy(x: -root.x, y: -root.y)
        layer.fill(wing, with: .foreground)
    }

    /// One stripe's turn in the sort: it drops in and lights up, stays, then fades back to a trace.
    private static func sorting(_ phase: Double) -> (opacity: Double, drop: CGFloat) {
        switch phase {
        case ..<0.18:
            let arrived = easeOut(phase / 0.18)
            return (0.14 + 0.86 * arrived, CGFloat(-160 * (1 - arrived)))
        case ..<0.62: return (1, 0)
        case ..<0.85: return (1 - 0.86 * easeInOut((phase - 0.62) / 0.23), 0)
        default: return (0.14, 0)
        }
    }

    private static func fraction(_ value: Double) -> Double { value - value.rounded(.down) }
    /// 0 → 1 → 0 over each whole number.
    private static func triangle(_ value: Double) -> Double { 1 - abs(2 * fraction(value) - 1) }
    private static func easeInOut(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

/// The icon's bee standing still: the assistant's own mark, where another app would put a speech
/// bubble. It takes the colour it is given — black on the bee's yellow, as the icon has it.
struct BeeMark: View {
    var size: CGFloat = 16

    var body: some View {
        // Still and at full strength, the wings straight: the pose the icon has (and Figma's iOS/BeeMark).
        Canvas { context, canvas in BeeLoader.draw(in: context, size: canvas, time: 0, still: true, asIcon: true) }
            .frame(width: size * BeeLoader.aspect, height: size)
            // The drawing keeps room above the bee for its hover; a mark that stands still sits in the middle.
            .offset(y: -size * 0.036)
            .accessibilityHidden(true)
    }
}

#Preview("Bee at work") {
    VStack(alignment: .leading, spacing: 20) {
        BeeLoader(size: 88)
        BeeMark(size: 24).foregroundStyle(.black).frame(width: 60, height: 60).background(Theme.bee, in: Circle())
        HStack(spacing: 8) { BeeLoader(); Text("Sorting in 12 mails …").foregroundStyle(.secondary) }
        HStack(spacing: 6) { BeeLoader(size: 14); Text("Matterbee is on it …").font(.caption).foregroundStyle(.secondary) }
    }
    .padding(32)
}
