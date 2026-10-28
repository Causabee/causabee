import Foundation

/// Whether the screens may show money. With Causabee Pro the AI is part of the plan: what a request
/// cost is the beeserver's business, and the owner sees only how much of the month is left.
public enum Money {
    nonisolated(unsafe) public static var hidden = false
}
