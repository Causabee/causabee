#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import QuartzCore
import SwiftUI

/// How smoothly the screen draws, counted frame by frame — with `--frame-meter` only, for the
/// scrolling tests. A frame that comes later than one and a half frames after the last was lost
/// time the owner sees as a stutter: counted, and how long. A test reads the count from a label
/// before and after it scrolls.
@MainActor
@Observable
final class ScreenMeter: NSObject {
    static let shared = ScreenMeter()
    static let isOn = CommandLine.arguments.contains("--frame-meter")
    /// `--print-changes`: the big pages say what made them draw again.
    static let printsChanges = CommandLine.arguments.contains("--print-changes")

    /// Said as "frames 1200 · late 3 · lost 41 ms": what the test reads.
    private(set) var words = "frames 0 · late 0 · lost 0 ms"
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var late = 0
    @ObservationIgnored private var lost = 0.0
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var started = false

    // MARK: The tour

    /// `--scroll-tour <name>`: a few seconds after the screen is up, its biggest scroll view is
    /// scrolled down and up again four times, a frame at a time, as a quick finger would — and what
    /// came late meanwhile is said at the end: `TOUR <name> · late 3 · lost 41 ms`.
    static var tourName: String? {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--scroll-tour"), at + 1 < arguments.count else { return nil }
        return arguments[at + 1]
    }
    @ObservationIgnored private var touring: (scroll: AnyObject, top: CGFloat, bottom: CGFloat, began: CFTimeInterval, late: Int, lost: Double)?
    /// One way, top to bottom or back, in seconds.
    private static let leg = 1.6
    private static let legs = 8

    func start() {
        guard Self.isOn || Self.tourName != nil, !started else { return }
        started = true
        #if canImport(UIKit)
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        #else
        guard let link = NSScreen.main?.displayLink(target: self, selector: #selector(tick(_:))) else { return }
        link.add(to: .main, forMode: .common)
        #endif
        if Self.tourName != nil {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                self.beginTour()
            }
        }
    }

    private func beginTour() {
        #if canImport(UIKit)
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var found: [UIScrollView] = []
        func look(_ view: UIView) { if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 200 { found.append(scroll) }; view.subviews.forEach(look) }
        windows.forEach(look)
        guard let scroll = found.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) else {
            fputs("TOUR \(Self.tourName ?? "") · nothing to scroll\n", stderr); return
        }
        let top = -scroll.adjustedContentInset.top
        let bottom = min(scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom, top + 6000)
        #else
        var found: [NSScrollView] = []
        func look(_ view: NSView) { if let scroll = view as? NSScrollView, (scroll.documentView?.frame.height ?? 0) > scroll.contentView.bounds.height + 200 { found.append(scroll) }; view.subviews.forEach(look) }
        NSApp.windows.compactMap(\.contentView).forEach(look)
        guard let scroll = found.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
            fputs("TOUR \(Self.tourName ?? "") · nothing to scroll\n", stderr); return
        }
        let top: CGFloat = -scroll.contentInsets.top
        let bottom = min((scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height, top + 6000)
        #endif
        touring = (scroll, top, bottom, CACurrentMediaTime(), late, lost)
    }

    /// Moves the tour on to where this frame wants it.
    private func moveTour(at now: CFTimeInterval) {
        guard let tour = touring else { return }
        let elapsed = now - tour.began
        let leg = Int(elapsed / Self.leg)
        guard leg < Self.legs else {
            let words = "TOUR \(Self.tourName ?? "") · late \(late - tour.late) · lost \(Int(lost - tour.lost)) ms"
            fputs(words + "\n", stderr)
            NSLog("%@", words)
            touring = nil
            return
        }
        // Eased within each leg, as a flick slows down.
        let t = (elapsed - Double(leg) * Self.leg) / Self.leg
        let eased = 1 - pow(1 - t, 3)
        // `--tour-changes`: twice a second a change to the store, as a sync brings one.
        if CommandLine.arguments.contains("--tour-changes"), Int(elapsed * 2) != Int((elapsed - 1.0 / 60) * 2) {
            StoredChanges.shared.nudgeForTour()
        }
        let progress = leg % 2 == 0 ? eased : 1 - eased
        let y = tour.top + (tour.bottom - tour.top) * progress
        #if canImport(UIKit)
        (tour.scroll as? UIScrollView)?.contentOffset.y = y
        #else
        if let scroll = tour.scroll as? NSScrollView {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        #endif
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let frame = max(link.targetTimestamp - link.timestamp, 1.0 / 120)
        defer { last = now; moveTour(at: now) }
        guard last > 0 else { return }
        frames += 1
        let gap = now - last
        // Only while something moves: a still screen may skip frames as it likes.
        if gap > frame * 1.5, gap < 1 {
            late += 1
            lost += (gap - frame) * 1000
            words = "frames \(frames) · late \(late) · lost \(Int(lost)) ms"
        } else if frames % 60 == 0 {
            words = "frames \(frames) · late \(late) · lost \(Int(lost)) ms"
        }
    }
}

/// The meter's words, out of the way and nearly unseen: for the tests to read.
private struct ScreenMeterLabel: View {
    var body: some View {
        Text(ScreenMeter.shared.words)
            .font(.system(size: 6)).opacity(0.02)
            .accessibilityIdentifier("frame-meter")
            .allowsHitTesting(false)
    }
}

extension View {
    /// With `--frame-meter`, the frames counted over the whole window.
    @ViewBuilder
    func screenMeter() -> some View {
        if ScreenMeter.isOn || ScreenMeter.tourName != nil {
            overlay(alignment: .bottomLeading) { ScreenMeterLabel() }
                .onAppear { ScreenMeter.shared.start() }
        } else {
            self
        }
    }
}
