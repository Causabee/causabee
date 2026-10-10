import Foundation

/// What the device is called in the words Causabee shows: "on this iPad", not "on this iPhone",
/// where it runs on one. Read without the main actor — errors say it too.
public enum ThisDevice {
    public static let name: String = {
        #if os(macOS)
        return "Mac"
        #else
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        // In the simulator the machine is the Mac's; the device it plays is named beside it.
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        return model.hasPrefix("iPad") ? "iPad" : "iPhone"
        #endif
    }()
}
