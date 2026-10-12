import SwiftUI

/// A task ticked by hand: the bee leaves its yellow button, flies a round about the box that was
/// ticked, and goes home — a second, over everything, in nobody's way. A larger round, twice, for
/// the last open task of a matter. Never with Reduce Motion, and never two bees: while it is out,
/// the button stands empty.
@MainActor
@Observable
final class BeeFlight {
    static let shared = BeeFlight()

    struct Flight: Equatable {
        let home: CGPoint
        let about: CGPoint
        let big: Bool
        let began = Date()
        var length: TimeInterval { big ? 2.0 : 1.15 }
        var radius: CGFloat { big ? 62 : 30 }
        var rounds: Double { big ? 2 : 1 }
    }

    /// The middle of the yellow button, in the window: where the bee lives.
    @ObservationIgnored var home: CGPoint?
    private(set) var flight: Flight?
    var isOut: Bool { flight != nil }

    /// `spot`: the middle of the box that was ticked, in the window.
    func celebrate(at spot: CGPoint, big: Bool) {
        guard flight == nil, let home, !UIAccessibility.isReduceMotionEnabled else { return }
        let flight = Flight(home: home, about: spot, big: big)
        self.flight = flight
        Task {
            try? await Task.sleep(for: .seconds(flight.length))
            if self.flight == flight { self.flight = nil }
        }
    }
}

extension BeeFlight.Flight {
    /// Where the bee is, how large and how far it leans, `t` from 0 to 1 of its way: out to the
    /// round, about it, and home.
    func pose(at t: Double) -> (place: CGPoint, scale: CGFloat, lean: Angle) {
        // The round begins and ends on the side of it that faces home.
        let toward = atan2(home.y - about.y, home.x - about.x)
        func onRound(_ angle: Double) -> CGPoint { CGPoint(x: about.x + radius * cos(angle), y: about.y + radius * sin(angle)) }
        let gate = onRound(toward)
        func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
        func between(_ a: CGPoint, _ b: CGPoint, _ x: Double, lift: CGFloat) -> CGPoint {
            // A bow, not a line: it rises on its way.
            let bow = sin(x * .pi) * lift
            return CGPoint(x: a.x + (b.x - a.x) * x, y: a.y + (b.y - a.y) * x - bow)
        }
        let out = 0.26, back = 0.74
        let place: CGPoint, size: CGFloat
        if t < out {
            let x = ease(t / out)
            place = between(home, gate, x, lift: 26)
            size = 1 + 0.25 * x
        } else if t < back {
            let x = (t - out) / (back - out)
            place = onRound(toward + ease(x) * 2 * .pi * rounds)
            size = 1.25
        } else {
            let x = ease((t - back) / (1 - back))
            place = between(gate, home, x, lift: 18)
            size = 1.25 - 0.25 * x
        }
        // It leans the way it goes: by where it will be a moment on.
        let ahead = t < 0.98 ? poseX(t + 0.02) - place.x : 0
        return (place, size, .degrees(max(-16, min(16, Double(ahead) * 1.6))))
    }

    private func poseX(_ t: Double) -> CGFloat {
        let toward = atan2(home.y - about.y, home.x - about.x)
        let gateX = about.x + radius * cos(toward)
        func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
        let out = 0.26, back = 0.74
        if t < out { return home.x + (gateX - home.x) * ease(t / out) }
        if t < back { return about.x + radius * cos(toward + ease((t - out) / (back - out)) * 2 * .pi * rounds) }
        return gateX + (home.x - gateX) * ease((t - back) / (1 - back))
    }
}

/// The bee on its way, over the whole window. It takes no touch.
struct BeeFlightLayer: View {
    private let flights = BeeFlight.shared

    var body: some View {
        if let flight = flights.flight {
            TimelineView(.animation) { timeline in
                let t = min(1, max(0, timeline.date.timeIntervalSince(flight.began) / flight.length))
                let pose = flight.pose(at: t)
                BeePulled(pull: 1, size: 26)
                    .foregroundStyle(.black)
                    .scaleEffect(pose.scale)
                    .rotationEffect(pose.lean)
                    .position(pose.place)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
