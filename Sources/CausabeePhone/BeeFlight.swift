import SwiftUI

/// A task ticked by hand: the bee lifts out of its yellow button, beats its wings a few glad
/// times over it, and goes back in — a second, in nobody's way. Higher and longer for the last
/// open task of a matter. Never with Reduce Motion, and never two bees: while it is out, the
/// button stands empty. (A round about the ticked box was tried first, and was too much.)
@MainActor
@Observable
final class BeeFlight {
    static let shared = BeeFlight()

    struct Flight: Equatable {
        let home: CGPoint
        let about: CGPoint
        let big: Bool
        let began = Date()
        var length: TimeInterval { big ? 1.7 : 1.05 }
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
    /// Where the bee is, how large and how far it leans, `t` from 0 to 1: up out of its button,
    /// a few happy beats of its wings there, and back in.
    func pose(at t: Double) -> (place: CGPoint, scale: CGFloat, lean: Angle) {
        func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
        let up = 0.24, down = 0.78
        let height: CGFloat = big ? 78 : 52
        let lifted: Double, sway: Double
        if t < up {
            lifted = ease(t / up); sway = 0
        } else if t < down {
            // It bobs and rocks while its wings beat: glad, not busy.
            let x = (t - up) / (down - up)
            lifted = 1 + 0.07 * sin(x * .pi * 2 * rounds * 2)
            sway = sin(x * .pi * 2 * rounds * 1.5) * (big ? 11 : 7)
        } else {
            lifted = 1 - ease((t - down) / (1 - down)); sway = 0
        }
        return (CGPoint(x: home.x, y: home.y - height * lifted), 1 + (big ? 0.5 : 0.3) * min(1, lifted), .degrees(sway))
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
