// Before the Mac app is clicked through: is this Mac in a state in which that can work? Says what
// is in the way, each as one line with what to do, and ends with 1 — so a run that cannot pass is
// not started, and nobody reads a test's failure to find out that a window was not on the screen.
//   swift scripts/mac-preflight.swift
import AppKit

var inTheWay: [String] = []
let screens = NSScreen.screens
guard let main = screens.first else { print("✗ No screen."); exit(1) }

// The test's window opens on the main screen — the one with the menu bar. An app in full screen
// there has a space of its own: the test's window opens on another, and nothing in it can be clicked.
let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let menuBarShows = onScreen.contains { ($0[kCGWindowOwnerName as String] as? String) == "Window Server" && ($0[kCGWindowName as String] as? String) == "Menubar" }
    || main.visibleFrame.height < main.frame.height
if !menuBarShows {
    // Whose it is: the frontmost window that covers the whole main screen.
    let covering = onScreen.first { window in
        guard (window[kCGWindowLayer as String] as? Int) == 0, let bounds = window[kCGWindowBounds as String] as? [String: Double] else { return false }
        return bounds["X"] == 0 && bounds["Y"] == 0 && bounds["Width"] == Double(main.frame.width) && bounds["Height"] == Double(main.frame.height)
    }
    let front = covering?[kCGWindowOwnerName as String] as? String ?? "An app"
    inTheWay.append("\(front) is in full screen on the main screen. Leave full screen (⌃⌘F, or the green button), so the desktop shows.")
}
// Room for the window the tests click in: the smallest it may be is 960 × 640.
if main.visibleFrame.width < 960 || main.visibleFrame.height < 640 {
    inTheWay.append("The main screen has room for \(Int(main.visibleFrame.width)) × \(Int(main.visibleFrame.height)) only; the tests need 960 × 640.")
}
print("  screens: " + screens.map { "\(Int($0.frame.width)) × \(Int($0.frame.height))" }.joined(separator: ", ") + " — the first is the main one")
if inTheWay.isEmpty { exit(0) }
for line in inTheWay { print("✗ " + line) }
exit(1)
