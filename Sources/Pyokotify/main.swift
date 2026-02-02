import AppKit
import PyokotifyCore

let args = CommandLine.arguments

// --version / -v
if args.contains("--version") || args.contains("-v") {
    print("pyokotify \(Version.string())")
    exit(0)
}

// uninstall サブコマンド
if args.count >= 2 && args[1] == "uninstall" {
    let subArgs = Array(args.dropFirst(2))

    // ヘルプ
    if subArgs.contains("-h") || subArgs.contains("--help") {
        Uninstaller.printUsage()
        exit(0)
    }

    // 確認スキップ
    let skipConfirmation = subArgs.contains("-y") || subArgs.contains("--yes")

    switch Uninstaller.run(skipConfirmation: skipConfirmation) {
    case .success:
        exit(0)
    case .failure(let error):
        if case .cancelled = error {
            exit(0)
        }
        print("\u{001B}[31mエラー:\u{001B}[0m \(error.localizedDescription)")
        exit(1)
    }
}

// 従来のNSApplication処理
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = PyokotifyAppDelegate()
app.delegate = delegate
app.run()
