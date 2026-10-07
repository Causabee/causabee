import SwiftUI

/// Where an assistant's thread stands, on the iPhone and the Mac — one rule, kept in one place:
///
/// 1. The newest — the question just asked, or the last turn — stands at the top of what is shown,
///    its answer under it, and room is left open below: an answer grows downwards, and nothing
///    above it moves.
/// 2. Left alone, the thread keeps the newest there: while the answer comes, while a card under it
///    grows, when the keyboard comes or goes.
/// 3. Once the owner has moved the thread, it is theirs. Nothing moves it; what comes in is added
///    below, and a button says so. The next question gives it back.
///
/// The view tells this what the thread holds and how tall its things are, and what happened —
/// asked, answered, brought in; this decides where the thread goes and how much room is left open.
@MainActor
@Observable
final class ThreadPlacement {
    struct Metrics {
        /// The room kept between the edge and what stands "at the top".
        var topRoom: CGFloat
        /// Between two things in the thread.
        var spacing: CGFloat
        /// Around the thread's content.
        var padding: CGFloat
        /// What a bar over the thread takes of the scroll view's height.
        var header: CGFloat = 0
    }

    static let bottom = "thread-bottom"
    /// How the thread moves when it moves by itself: slowly enough to follow, not a jump.
    static let glide = Animation.easeInOut(duration: 0.3)

    let metrics: Metrics

    // MARK: What the view draws from

    /// The empty room under the thread's end: with it, the newest can stand at the top.
    private(set) var roomBelow: CGFloat = 1
    /// The button over the thread's lower edge: there is something to go to.
    private(set) var showsButton = false
    /// An answer that came while the thread was the owner's: the button says "New answer".
    private(set) var newAnswer: AnyHashable?

    // MARK: What it knows

    /// The owner moved the thread since the last question.
    @ObservationIgnored private(set) var held = false
    /// The field has the cursor: with the keyboard up, the end of the newest is what counts.
    @ObservationIgnored var typing = false
    /// Room for what stands between the newest and the empty room without being part of the
    /// thread — a line that says a question could not go out.
    @ObservationIgnored var extra: CGFloat = 0

    @ObservationIgnored private var order: [AnyHashable] = []
    @ObservationIgnored private var newest: AnyHashable?
    @ObservationIgnored private var heights: [AnyHashable: CGFloat] = [:]
    /// The height the room is cut for: the smallest the newest has had. Sources unfolded under an
    /// answer make it taller for a while; taken in for that while the answer still grew, the room
    /// left the thread too short, and the thread slid down.
    @ObservationIgnored private var roomHeight: CGFloat = 0
    @ObservationIgnored private var viewport: CGFloat = 0
    @ObservationIgnored private var placed = false
    @ObservationIgnored private var fingerAt: CGFloat?
    /// Scrolled up into what came before; and: more of the thread under the lower edge.
    @ObservationIgnored private var up = false
    @ObservationIgnored private var below = false

    init(_ metrics: Metrics) { self.metrics = metrics }

    // MARK: What the thread holds

    /// The thread as it is now: its things in order, and which of them is the newest.
    func holds(_ ids: [AnyHashable], newest: AnyHashable?) {
        order = ids
        if newest != self.newest {
            self.newest = newest
            roomHeight = newest.flatMap { heights[$0] } ?? 0
        }
        cutRoom()
    }

    /// One of its things, as tall as it was laid out. The newest changing its height — an answer
    /// that came, a card that grew — is followed, unless the thread is the owner's.
    func measured(_ id: AnyHashable, _ height: CGFloat, with scroller: ScrollViewProxy) {
        let before = heights[id]
        heights[id] = height
        guard id == newest else { cutRoom(); return }
        if roomHeight == 0 || height < roomHeight { roomHeight = height }
        cutRoom()
        guard before != height, !held else { return }
        if placed { settle(scroller) }
        place(scroller, animated: false)
        placed = true
        again(scroller)
    }

    private var newestHeight: CGFloat { newest.flatMap { heights[$0] } ?? 0 }

    /// What stands after the newest — a turn from a device whose clock runs ahead: each thing and
    /// the gap before it.
    private var tail: CGFloat {
        guard let newest, let at = order.firstIndex(of: newest) else { return 0 }
        return order[(at + 1)...].reduce(0) { $0 + (heights[$1] ?? 0) + metrics.spacing }
    }

    /// A little more than it takes: cut to the point, the newest stood a few points short of its
    /// place until something under it made the thread longer.
    private func cutRoom() {
        let room = max(1, viewport - roomHeight - tail - metrics.topRoom - metrics.spacing - metrics.padding + 24)
        if abs(room - roomBelow) > 0.5 { roomBelow = room }
    }

    // MARK: Where the thread is

    /// What of a scroll view's geometry the placement goes by: how tall the thread is, which part
    /// of it is seen, and how tall the view is.
    struct Geometry: Equatable {
        var content: CGFloat, top: CGFloat, bottom: CGFloat, container: CGFloat

        init(_ geometry: ScrollGeometry) {
            content = geometry.contentSize.height
            top = geometry.visibleRect.minY
            bottom = geometry.visibleRect.maxY
            container = geometry.containerSize.height
        }
    }

    /// The thread's geometry, whenever it changes. The room it shows growing or shrinking — the
    /// keyboard, the field taking a line — moves the thread with it, in the same motion.
    func geometry(_ geometry: Geometry, with scroller: ScrollViewProxy) {
        let (content, top, bottom, container) = (geometry.content, geometry.top, geometry.bottom, geometry.container)
        let shows = container - metrics.header
        if abs(shows - viewport) > 0.5 {
            viewport = shows
            cutRoom()
            if !held { settle(scroller); return }
        }
        // What lies from the top edge to the thread's end when the newest stands in its place.
        let rest = metrics.topRoom + newestHeight + metrics.spacing + tail + roomBelow + metrics.padding + extra
        up = content - top > rest + 60
        // The thread's own end — not the empty room after it — under the lower edge.
        below = (content - roomBelow - metrics.spacing - metrics.padding) - bottom > 40
        if !up { newAnswer = nil }
        // Gone at once; shown only when it is still so a moment later: something unfolding under an
        // answer made the button blink while the thread took its new height.
        let wanted = up || below
        if !wanted { if showsButton { withAnimation(.easeOut(duration: 0.15)) { showsButton = false } } }
        else if !showsButton {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [self] in
                if up || below, !showsButton { withAnimation(.easeOut(duration: 0.15)) { showsButton = true } }
            }
        }
    }

    /// A finger — or the trackpad, the wheel — on the thread. Only one that moves it makes the
    /// thread the owner's: a tap on something in it comes down on the thread too, and moves nothing.
    func finger(from old: ScrollPhase, to new: ScrollPhase, at offset: CGFloat) {
        if new == .interacting || new == .tracking, fingerAt == nil { fingerAt = offset }
        if new == .idle || new == .decelerating || new == .animating, let from = fingerAt {
            if abs(offset - from) > 6 { held = true }
            fingerAt = nil
        }
        if new == .decelerating { held = true }
    }

    // MARK: What happened

    /// A question was sent, or a file brought in: the owner's own doing. It goes to the top,
    /// wherever the thread was, and the thread is no longer held.
    func asked(_ scroller: ScrollViewProxy) {
        held = false
        newAnswer = nil
        place(scroller)
    }

    /// The answer to what was asked here. It takes its question's place at once — no glide across
    /// what lies between — and the thread is put right once more when all has come to rest. If the
    /// thread is the owner's, it stays where it is read, and the button says so.
    func answered(_ id: AnyHashable, with scroller: ScrollViewProxy) {
        if held { newAnswer = id; return }
        scroller.scrollTo(id, anchor: .top)
        place(scroller, animated: false)
        again(scroller)
    }

    /// Something that came by itself — a turn from another device.
    func arrived(_ id: AnyHashable, with scroller: ScrollViewProxy) {
        if held { newAnswer = id } else { place(scroller) }
    }

    /// Another thread is shown in the same place — another matter opened beside it.
    func opened(_ scroller: ScrollViewProxy) {
        held = false
        newAnswer = nil
        place(scroller, animated: false)
    }

    /// The button: from further up, to the newest; at the newest with more under the edge, down to
    /// the thread's end — and there the thread is the owner's, as if scrolled.
    func buttonTapped(_ scroller: ScrollViewProxy) {
        if up || newAnswer != nil {
            newAnswer = nil
            place(scroller)
        } else {
            held = true
            withAnimation(Self.glide) { scroller.scrollTo(Self.bottom, anchor: .bottom) }
        }
    }

    /// Something under the newest that is not part of the thread came into view's way — a line that
    /// says a question could not go out: shown where it can be seen, when there is no room for it.
    func show(_ id: AnyHashable, with scroller: ScrollViewProxy) {
        guard !held, newestHeight + 150 > viewport else { return }
        DispatchQueue.main.async { withAnimation(Self.glide) { scroller.scrollTo(id, anchor: .bottom) } }
    }

    // MARK: Putting it there

    /// The newest to the top — after the thread has been laid out with what is new: asked for in the
    /// same moment, its edges are still the old ones. By its top edge: a point part of the way down
    /// moves with the height of what is put there.
    private func place(_ scroller: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async { [self] in
            guard let newest else { return }
            if animated { withAnimation(Self.glide) { scroller.scrollTo(newest, anchor: .top) } } else { scroller.scrollTo(newest, anchor: .top) }
        }
    }

    /// At once, without a glide — for the moment the room changes, so that the thread moves with it
    /// and not after it. While the field has the cursor and the newest is taller than what is left
    /// to see, its end stands over the field: that is what is being answered. Else its beginning.
    private func settle(_ scroller: ScrollViewProxy) {
        guard let newest else { return }
        scroller.scrollTo(newest, anchor: typing && newestHeight + metrics.topRoom > viewport ? .bottom : .top)
    }

    /// Once more, when everything has come to rest — unless the owner has taken the thread.
    private func again(_ scroller: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            if !held { place(scroller, animated: false) }
        }
    }
}
