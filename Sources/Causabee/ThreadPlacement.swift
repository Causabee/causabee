import SwiftUI

/// Where an assistant's thread stands, on the iPhone and the Mac. Three things decide it, and
/// nothing else:
///
/// 1. The newest — the question on its way, or the last turn — is at least as tall as the thread's
///    part of the screen (`viewport`), so it can stand at the top with room for its answer under it.
/// 2. While the thread follows, the newest is put there whenever something could have moved it: it
///    was laid out, it changed its height, the room changed, the keyboard came or went.
/// 3. A finger that moves the thread ends the following; a question sent, the button, or the
///    thread brought back to its newest by hand begins it again.
///
/// The view makes the newest `viewport` tall, lays its things out at once — nothing glides into
/// place, or a place worked out meanwhile is one they are no longer in — and tells this what
/// happened. `ThreadTests` measures that it holds.
@MainActor
@Observable
final class ThreadPlacement {
    /// How the thread moves when it moves by itself: slowly enough to follow, not a jump.
    static let glide = Animation.easeInOut(duration: 0.3)

    // MARK: What the view draws from

    /// How tall the thread's part of the screen is: the newest is made at least that tall.
    private(set) var viewport: CGFloat = 0
    /// The thread is where the rule puts it. When not, the view offers the way back.
    private(set) var follows = true
    /// An answer that came while the thread did not follow: the button says "New answer".
    private(set) var newAnswer: AnyHashable?

    // MARK: What it keeps while the thread scrolls — read, and drawing nothing again

    @ObservationIgnored private var newest: AnyHashable?
    /// Where the newest stands under the thread's top edge, how tall it is made, and how tall it
    /// is by itself.
    @ObservationIgnored private var top: CGFloat?
    @ObservationIgnored private var height: CGFloat = 0
    @ObservationIgnored private var own: CGFloat = 0
    @ObservationIgnored private var laidOut: AnyHashable?
    /// Where the thread stood when a finger came down on it.
    @ObservationIgnored private var fingerAt: CGFloat?
    /// The keyboard came up over a newest taller than what is left of the screen: its end stands
    /// over the field — that is what is being answered — until the keyboard goes or a question is sent.
    @ObservationIgnored private var showsEnd = false

    // MARK: What the view tells it

    /// The thread's part of the screen, as tall as it is now — the keyboard, the field taking a
    /// line, a chip over it: the newest keeps its place, at once.
    func room(_ height: CGFloat, with scroller: ScrollViewProxy) {
        guard abs(height - viewport) > 0.5 else { return }
        viewport = height
        if follows { place(scroller) }
    }

    /// One of the thread's things, where it stands in the scroll view. The newest laid out for the
    /// first time, or with another height — an answer came, sources unfolded: now it can be put in
    /// its place, and is.
    func laidOut(_ id: AnyHashable, at frame: CGRect, newest isNewest: Bool, with scroller: ScrollViewProxy) {
        guard isNewest else { return }
        let changed = laidOut != id || abs(frame.height - height) > 0.5
        newest = id
        top = frame.minY
        height = frame.height
        laidOut = id
        if changed, follows { place(scroller) }
    }

    /// The newest's own height, before it is made as tall as the room.
    func own(_ height: CGFloat) { own = height }

    /// A finger — the trackpad, the wheel — on the thread. One that moves it ends the following. A
    /// tap on something in the thread comes down on it too and moves nothing; what the thread does
    /// by itself is never a finger.
    func finger(from old: ScrollPhase, to new: ScrollPhase, at offset: CGFloat) {
        if new == .interacting || new == .tracking, fingerAt == nil { fingerAt = offset }
        if old == .interacting || old == .tracking || old == .decelerating, let from = fingerAt, abs(offset - from) > 1 { follows = false }
        guard new == .idle else { return }
        fingerAt = nil
        // Brought back to its newest by hand: it follows again.
        if !follows, let top, abs(top) < 8 { follows = true; newAnswer = nil }
    }

    /// The owner's own doing — a question sent, a file brought in, the button: the newest goes to
    /// the top, wherever the thread was, and the thread follows again.
    func follow(_ newest: AnyHashable?, with scroller: ScrollViewProxy) {
        self.newest = newest
        follows = true
        showsEnd = false
        newAnswer = nil
        place(scroller, animated: true)
    }

    /// Another thread in the same place — another matter opened beside it.
    func opened(_ newest: AnyHashable?, with scroller: ScrollViewProxy) {
        self.newest = newest
        follows = true
        showsEnd = false
        newAnswer = nil
        place(scroller)
    }

    /// Something came into the thread by itself — an answer, a turn from another device. While the
    /// thread follows, the newest keeps its place; being read further up, it stays, and the button
    /// says something came.
    func arrived(_ id: AnyHashable, newest: AnyHashable?, with scroller: ScrollViewProxy) {
        self.newest = newest
        if follows { place(scroller, animated: true) } else if newAnswer == nil { newAnswer = id }
    }

    /// The field took the cursor, or gave it up. Only a newest taller than the room has an end to
    /// show: one that fits is all there, and stands by its top either way.
    func typing(_ on: Bool, with scroller: ScrollViewProxy) {
        showsEnd = on && follows && laidOut == newest && own > viewport
        if follows { place(scroller) }
    }

    // MARK: Putting it there

    /// The newest to its place — its beginning to the top, or its end over the field. Once the
    /// thread is laid out with what is new: asked for in the same moment, the newest is not there yet.
    private func place(_ scroller: ScrollViewProxy, animated: Bool = false) {
        DispatchQueue.main.async { [self] in
            guard let newest else { return }
            let anchor: UnitPoint = showsEnd ? .bottom : .top
            if animated { withAnimation(Self.glide) { scroller.scrollTo(newest, anchor: anchor) } } else { scroller.scrollTo(newest, anchor: anchor) }
        }
    }
}

/// Something new in a thread comes in from nothing, in a quarter of a second — its own doing, so
/// that the thread around it does not have to move for it.
struct FadesIn: ViewModifier {
    let fresh: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !fresh ? 1 : 0)
            .onAppear { if fresh { withAnimation(.easeIn(duration: 0.25)) { shown = true } } }
    }
}
