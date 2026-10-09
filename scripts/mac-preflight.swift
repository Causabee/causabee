// Before the Mac app is clicked through: is this Mac in a state in which that can work? Says what
// is in the way, each as one line with what to do, and ends with 1 — so a run that cannot pass is
// not started, and nobody reads a test's failure to find out that a window was not on the screen.
//   swift scripts/mac-preflight.swift
import AppKit

var inTheWay: [String] = []
let screens = NSScreen.screens
guard let main = screens.first else { print("✗ No screen."); exit(1) }

// Not checked: whether an app is "in full screen". A window that fills a screen whose menu bar
// and Dock hide themselves looks the same from here, and is no obstacle — said to be one on
// 2026-10-09, wrongly.
// Room for the window the tests click in: the smallest it may be is 960 × 640.
if main.visibleFrame.width < 960 || main.visibleFrame.height < 640 {
    inTheWay.append("The main screen has room for \(Int(main.visibleFrame.width)) × \(Int(main.visibleFrame.height)) only; the tests need 960 × 640.")
}
print("  screens: " + screens.map { "\(Int($0.frame.width)) × \(Int($0.frame.height))" }.joined(separator: ", ") + " — the first is the main one")
if inTheWay.isEmpty { exit(0) }
for line in inTheWay { print("✗ " + line) }
exit(1)
