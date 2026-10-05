// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnimateBlockPitfall",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AnimateBlockPitfall", targets: ["AnimateBlockPitfall"]),
    ],
    targets: [
        .target(name: "AnimateBlockPitfall"),
        .testTarget(name: "AnimateBlockPitfallTests", dependencies: ["AnimateBlockPitfall"]),
    ]
)
