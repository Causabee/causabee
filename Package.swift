// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MatterCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MatterCore", targets: ["MatterCore"]),
        .executable(name: "matter-spike", targets: ["MatterSpike"]),
        .executable(name: "Matterbee", targets: ["Matterbee"]),
        .executable(name: "matter-bench", targets: ["MatterBench"]),
    ],
    targets: [
        .target(name: "MatterCore"),
        .executableTarget(name: "MatterSpike", dependencies: ["MatterCore"]),
        // The Mac app. A SwiftPM target for now, run with `swift run Matterbee`; it becomes an
        // app bundle when it needs one (a signed build, the share extension, Reminders access).
        .executableTarget(name: "Matterbee", dependencies: ["MatterCore"]),
        // How well a model on the Mac reads the mail, scored against what the owner's store says.
        .executableTarget(name: "MatterBench", dependencies: ["MatterCore"]),
        .testTarget(name: "MatterCoreTests", dependencies: ["MatterCore"]),
    ]
)
