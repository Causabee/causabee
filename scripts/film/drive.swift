import CoreGraphics
import Foundation
// drive click X Y | move X Y | scroll X Y DY | drag X1 Y1 X2 Y2
let a = CommandLine.arguments
func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(50_000)
}
switch a[1] {
case "click":
    let p = CGPoint(x: Double(a[2])!, y: Double(a[3])!)
    post(.mouseMoved, p); post(.leftMouseDown, p); post(.leftMouseUp, p)
case "move":
    post(.mouseMoved, CGPoint(x: Double(a[2])!, y: Double(a[3])!))
case "scroll":
    let p = CGPoint(x: Double(a[2])!, y: Double(a[3])!)
    post(.mouseMoved, p)
    let dy = Int32(a[4])!
    let steps = abs(dy) / 10
    for _ in 0..<max(steps, 1) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: dy > 0 ? -10 : 10, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
        usleep(16_000)
    }
case "drag":
    let p1 = CGPoint(x: Double(a[2])!, y: Double(a[3])!), p2 = CGPoint(x: Double(a[4])!, y: Double(a[5])!)
    post(.mouseMoved, p1); post(.leftMouseDown, p1)
    for i in 1...20 {
        let t = Double(i) / 20
        post(.leftMouseDragged, CGPoint(x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t))
    }
    post(.leftMouseUp, p2)
default: break
}
