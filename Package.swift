// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "pokkofy",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "pokkofy", targets: ["pokkofy"]),
        .library(name: "PokkofyCore", targets: ["PokkofyCore"]),
    ],
    targets: [
        // メインの実行ファイル
        .executableTarget(
            name: "pokkofy",
            dependencies: ["PokkofyCore"],
            path: "Sources/pokkofy"
        ),
        // テスト可能なコアロジック
        .target(
            name: "PokkofyCore",
            path: "Sources/PokkofyCore"
        ),
        // テスト
        .testTarget(
            name: "PokkofyTests",
            dependencies: ["PokkofyCore"],
            path: "Tests/PokkofyTests"
        ),
    ]
)
