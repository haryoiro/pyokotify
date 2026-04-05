// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "pyokotify",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "pyokotify", targets: ["pyokotify"]),
        .library(name: "PyokotifyCore", targets: ["PyokotifyCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/haryoiro/foxus", from: "0.0.1"),
    ],
    targets: [
        // メインの実行ファイル
        .executableTarget(
            name: "pyokotify",
            dependencies: ["PyokotifyCore"],
            path: "Sources/Pyokotify"
        ),
        // テスト可能なコアロジック
        .target(
            name: "PyokotifyCore",
            dependencies: [.product(name: "Foxus", package: "foxus")],
            path: "Sources/PyokotifyCore"
        ),
        // テスト
        .testTarget(
            name: "PyokotifyTests",
            dependencies: [
                "PyokotifyCore",
                .product(name: "Foxus", package: "foxus"),
            ],
            path: "Tests/PyokotifyTests"
        ),
    ]
)
