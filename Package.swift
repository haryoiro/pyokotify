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
            path: "Sources/PyokotifyCore"
        ),
        // テスト
        .testTarget(
            name: "PyokotifyTests",
            dependencies: ["PyokotifyCore"],
            path: "Tests/PyokotifyTests"
        ),
    ]
)
