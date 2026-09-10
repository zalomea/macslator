// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macslator",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "macslator", targets: ["macslator"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMajor(from: "1.3.0")),
        .package(url: "https://github.com/huggingface/swift-huggingface", .upToNextMajor(from: "0.10.0"))
    ],
    targets: [
        .executableTarget(
            name: "macslator",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface")
            ],
            path: "Sources/macslator"
        ),
        .testTarget(
            name: "macslatorTests",
            dependencies: ["macslator"],
            path: "Tests/macslatorTests"
        )
    ]
)
