// swift-tools-version: 6.2
import PackageDescription

// How well a model on the Mac reads the owner's mail, scored against the store. Its own package,
// so the app never builds the model runtime. Build with xcodebuild: MLX's Metal shaders need it.
let package = Package(
    name: "LocalBench",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: ".."),
        // Pinned: guided generation and the FoundationModels bridge are on main, not yet released.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "ee673d6a71d76e67b532dc7eaf91d92edc3bb8bb"),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(name: "matter-bench", dependencies: [
            .product(name: "MatterCore", package: "causabee"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
            .product(name: "MLXFoundationModels", package: "mlx-swift-lm"),
            .product(name: "HuggingFace", package: "swift-huggingface"),
            .product(name: "Tokenizers", package: "swift-transformers"),
        ]),
    ]
)
