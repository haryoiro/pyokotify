import AppKit
import PyokotifyCore

let args = CommandLine.arguments

// --version / -v
if args.contains("--version") || args.contains("-v") {
    print("pyokotify \(Version.string())")
    exit(0)
}

// ヘルプ
if args.contains("-h") || args.contains("--help") {
    printMainUsage()
    exit(0)
}

// サブコマンド処理
if args.count >= 2 {
    switch args[1] {
    case "uninstall":
        handleUninstall()

    case "daemon":
        handleDaemon()

    case "notify":
        handleNotify()

    case "status":
        handleStatus()

    default:
        // 通常の pyokotify 処理（画像パスとして解釈）
        runNormalMode()
    }
} else {
    printMainUsage()
    exit(1)
}

// MARK: - サブコマンドハンドラ

func handleUninstall() {
    let subArgs = Array(args.dropFirst(2))

    if subArgs.contains("-h") || subArgs.contains("--help") {
        Uninstaller.printUsage()
        exit(0)
    }

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

func handleDaemon() {
    let subArgs = Array(args.dropFirst(2))

    if subArgs.contains("-h") || subArgs.contains("--help") {
        DaemonConfig.printUsage()
        exit(0)
    }

    guard let config = DaemonConfig.fromArguments() else {
        exit(1)
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let delegate = DaemonAppDelegate(config: config)
    app.delegate = delegate
    app.run()
}

func handleNotify() {
    let subArgs = Array(args.dropFirst(2))

    if subArgs.contains("-h") || subArgs.contains("--help") {
        printNotifyUsage()
        exit(0)
    }

    // オプション解析
    var message: String?
    var level: NotificationLevel = .info
    var sound: String?
    var duration: TimeInterval?
    var cwd: String?
    var callerApp: String?
    var hooksMode = false

    var i = 0
    while i < subArgs.count {
        switch subArgs[i] {
        case "-l", "--level":
            if i + 1 < subArgs.count {
                level = NotificationLevel(rawValue: subArgs[i + 1]) ?? .info
                i += 1
            }
        case "-s", "--sound":
            if i + 1 < subArgs.count {
                sound = subArgs[i + 1]
                i += 1
            }
        case "-d", "--duration":
            if i + 1 < subArgs.count {
                duration = Double(subArgs[i + 1])
                i += 1
            }
        case "--cwd":
            if i + 1 < subArgs.count {
                cwd = subArgs[i + 1]
                i += 1
            }
        case "--caller":
            if i + 1 < subArgs.count {
                callerApp = subArgs[i + 1]
                i += 1
            }
        case "--hooks":
            hooksMode = true
        case "-t", "--text":
            if i + 1 < subArgs.count {
                message = subArgs[i + 1]
                i += 1
            }
        default:
            if message == nil && !subArgs[i].hasPrefix("-") {
                message = subArgs[i]
            }
        }
        i += 1
    }

    // hooksモードの場合、標準入力からJSONを読み取る
    var hooksJson: String?
    if hooksMode {
        if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
            let inputData = FileHandle.standardInput.readDataToEndOfFile()
            if !inputData.isEmpty {
                hooksJson = String(data: inputData, encoding: .utf8)
            }
        }
    }

    // メッセージが必須なのはhooksモードでない場合のみ
    if message == nil && hooksJson == nil {
        print("\u{001B}[31mエラー:\u{001B}[0m メッセージを指定してください")
        printNotifyUsage()
        exit(1)
    }

    let notification = NotificationMessage(
        message: message,
        level: level,
        sound: sound,
        duration: duration,
        cwd: cwd ?? FileManager.default.currentDirectoryPath,
        callerApp: callerApp ?? ProcessInfo.processInfo.environment["TERM_PROGRAM"],
        hooksJson: hooksJson
    )

    let client = NotifyClient()
    let isDebug = ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil
    if isDebug {
        print("[notify] Sending: \(message ?? "(from hooks)")")
        print("[notify] Socket: \(DaemonPaths.socketPath)")
        print("[notify] Hooks mode: \(hooksMode)")
    }
    do {
        let response = try client.send(notification)
        if isDebug {
            print("[notify] Response: success=\(response.success), error=\(response.error ?? "nil")")
        }
        if !response.success {
            print("\u{001B}[31mエラー:\u{001B}[0m \(response.error ?? "不明なエラー")")
            exit(1)
        }
    } catch DaemonError.notRunning {
        print("\u{001B}[31mエラー:\u{001B}[0m デーモンが起動していません")
        print("先に `pyokotify daemon <image>` でデーモンを起動してください")
        exit(1)
    } catch {
        print("\u{001B}[31mエラー:\u{001B}[0m \(error.localizedDescription)")
        exit(1)
    }
}

func handleStatus() {
    let client = NotifyClient()
    if client.isDaemonRunning() {
        print("✅ デーモンは起動中です")
        if let pidStr = try? String(contentsOfFile: DaemonPaths.pidFile, encoding: .utf8) {
            print("   PID: \(pidStr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        print("   Socket: \(DaemonPaths.socketPath)")
    } else {
        print("❌ デーモンは停止しています")
    }
}

func runNormalMode() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let delegate = PyokotifyAppDelegate()
    app.delegate = delegate
    app.run()
}

// MARK: - ヘルプ

func printMainUsage() {
    print("""
    pyokotify - デスクトップマスコット通知ツール

    Usage:
      pyokotify <image> [options]       通常モード（1回表示）
      pyokotify daemon <image> [opts]   デーモンモード（常駐）
      pyokotify notify <message> [opts] デーモンに通知を送信
      pyokotify status                  デーモンの状態を確認
      pyokotify uninstall               アンインストール

    Examples:
      pyokotify ~/char.png -t "Hello!"
      pyokotify daemon ~/char.png --size 100
      pyokotify notify "ビルド完了!" --level success

    Run `pyokotify <command> --help` for more information.
    """)
}

func printNotifyUsage() {
    print("""
    Usage: pyokotify notify [message] [options]

    Options:
      -t, --text <text>     メッセージテキスト（テンプレート変数使用可）
      -l, --level <level>   通知レベル: info, success, warning, error (default: info)
      -s, --sound <path>    再生するサウンドファイル
      -d, --duration <sec>  表示時間（秒）
      --cwd <path>          作業ディレクトリ（クリック時のフォーカス用）
      --caller <app>        呼び出し元アプリ名
      --hooks               Claude Code / Copilot hooks モード（標準入力からJSON）

    Template variables:
      $dir     ディレクトリ名
      $branch  Gitブランチ名
      $cwd     作業ディレクトリ（フルパス）
      $event   イベント名
      $tool    ツール名

    Examples:
      pyokotify notify "Hello!"
      pyokotify notify "成功!" --level success
      pyokotify notify --hooks -t "[$dir] $event"   # Claude Code hooks
      echo '{"hook_event_name":"Stop","cwd":"/path"}' | pyokotify notify --hooks
    """)
}

// MARK: - Daemon App Delegate

class DaemonAppDelegate: NSObject, NSApplicationDelegate {
    private let config: DaemonConfig
    private var controller: DaemonController?

    init(config: DaemonConfig) {
        self.config = config
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = DaemonController(config: config)

        do {
            try controller?.start()
            print("デーモンを起動しました")
            print("通知を送信: pyokotify notify \"メッセージ\"")
            print("停止: Ctrl+C")
        } catch DaemonError.alreadyRunning {
            print("\u{001B}[31mエラー:\u{001B}[0m デーモンは既に起動しています")
            NSApp.terminate(nil)
        } catch {
            print("\u{001B}[31mエラー:\u{001B}[0m \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
