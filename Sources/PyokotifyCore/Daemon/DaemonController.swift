import AppKit
import Foundation

/// デーモンモードのメインコントローラー
public class DaemonController {
    private let config: DaemonConfig
    private let server: DaemonServer
    private var window: DaemonWindow?
    private var soundPlayer: SoundPlayer?

    public init(config: DaemonConfig) {
        self.config = config
        self.server = DaemonServer()
        self.soundPlayer = SoundPlayer()
    }

    /// デーモンを起動
    public func start() throws {
        // 既にデーモンが起動しているか確認
        let client = NotifyClient()
        if client.isDaemonRunning() {
            throw DaemonError.alreadyRunning
        }

        // サーバー起動
        server.onNotification = { [weak self] message in
            self?.handleNotification(message)
        }
        try server.start()

        // ウィンドウ作成
        setupWindow()

        debug("Daemon started")
    }

    /// デーモンを停止
    public func stop() {
        server.stop()
        window?.close()
        debug("Daemon stopped")
    }

    /// ウィンドウをセットアップ
    private func setupWindow() {
        guard let screen = NSScreen.main else {
            debug("No main screen found")
            return
        }

        let screenFrame = screen.visibleFrame
        let windowSize = NSSize(width: config.size, height: config.size)

        // 初期位置（右下、ただし画面内に収まるように）
        let x = screenFrame.maxX - windowSize.width - config.margin - 100  // 100px 内側に
        let y = screenFrame.minY + config.margin + 50  // 50px 上に
        let frame = NSRect(origin: NSPoint(x: x, y: y), size: windowSize)

        debug("Creating window at: \(frame)")
        debug("Image path: \(config.imagePath)")

        window = DaemonWindow(contentRect: frame, config: config)
        window?.onClick = { [weak self] in
            self?.handleClick()
        }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        debug("Window created and shown")
    }

    /// 通知を処理（即座に表示、キューイングなし）
    private func handleNotification(_ message: NotificationMessage) {
        // hooksJsonがある場合は解析
        var displayMessage = message.message
        var cwd = message.cwd
        var callerApp = message.callerApp
        var eventName: String?
        var toolName: String?

        if let hooksJson = message.hooksJson,
           let jsonData = hooksJson.data(using: .utf8),
           let hooksContext = parseHooksContext(from: jsonData) {

            // cwdを取得（hooksContextを優先）
            if let hooksCwd = hooksContext.cwd {
                cwd = hooksCwd
            }

            // callerAppを自動検出
            if callerApp == nil {
                callerApp = ProcessDetector.detectTerminalApp()
            }

            // イベント名とツール名を取得
            switch hooksContext.source {
            case .claudeCode:
                eventName = hooksContext.claudeContext?.event.rawValue ?? hooksContext.event.rawValue
            case .copilot:
                eventName = hooksContext.event.rawValue
            }
            toolName = hooksContext.toolName

            // メッセージが未指定の場合はデフォルトメッセージを生成
            if displayMessage == nil {
                let gitInfo = cwd.map { GitInfo(cwd: $0) }
                displayMessage = hooksContext.generateDefaultMessage(
                    projectName: gitInfo?.repositoryName,
                    branch: gitInfo?.branch
                )
            }
        }

        // テンプレート展開（hooksJson有無に関わらず実行）
        if let template = displayMessage, template.contains("$") {
            let gitInfo = cwd.map { GitInfo(cwd: $0) }
            let context = TemplateContext(
                cwd: cwd,
                branch: gitInfo?.branch,
                eventName: eventName,
                toolName: toolName
            )
            displayMessage = TemplateExpander.expand(template, with: context)
        }

        guard let finalMessage = displayMessage else {
            debug("No message to display")
            return
        }

        // サウンド再生
        if let sound = message.sound {
            soundPlayer?.play(path: sound)
        }

        // フォーカス情報を作成
        let focusInfo = BubbleFocusInfo(cwd: cwd, callerApp: callerApp)

        // 吹き出し表示（スタック形式で即座に表示）
        window?.showBubble(
            message: finalMessage,
            level: message.level,
            duration: message.duration ?? config.defaultDuration,
            focusInfo: focusInfo
        )
    }

    /// HooksContextを解析
    private func parseHooksContext(from data: Data) -> HooksContext? {
        // JSONを辞書として解析
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Claude Code か Copilot かを判定
        if json["hook_event_name"] != nil {
            // Claude Code
            guard let claudeContext = ClaudeHooksContext.parse(from: data) else {
                return nil
            }
            return HooksContext(from: claudeContext)
        } else if json["timestamp"] != nil {
            // GitHub Copilot CLI (簡易対応)
            return nil
        }

        return nil
    }

    /// クリック時の処理（キャラクタークリック用、最後の通知にフォーカス）
    private func handleClick() {
        // 最後の吹き出しのフォーカス情報を使用
        window?.focusLastBubble()
    }

    private func debug(_ message: String) {
        if ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil {
            fputs("[pyokotify-daemon] \(message)\n", stderr)
        }
    }
}

/// デーモンの設定
public struct DaemonConfig {
    public var imagePath: String
    public var size: CGFloat
    public var margin: CGFloat
    public var defaultDuration: TimeInterval

    public init(
        imagePath: String,
        size: CGFloat = 80,
        margin: CGFloat = 20,
        defaultDuration: TimeInterval = 5.0
    ) {
        self.imagePath = imagePath
        self.size = size
        self.margin = margin
        self.defaultDuration = defaultDuration
    }

    /// コマンドライン引数から設定を生成
    public static func fromArguments() -> DaemonConfig? {
        let args = CommandLine.arguments

        // daemon サブコマンドの後の引数を処理
        guard let daemonIndex = args.firstIndex(of: "daemon"),
              args.count > daemonIndex + 1
        else {
            printUsage()
            return nil
        }

        let imagePath = args[daemonIndex + 1]
        var config = DaemonConfig(imagePath: imagePath)

        // オプション解析
        var i = daemonIndex + 2
        while i < args.count {
            switch args[i] {
            case "-s", "--size":
                if i + 1 < args.count, let size = Double(args[i + 1]) {
                    config.size = CGFloat(size)
                    i += 1
                }
            case "-m", "--margin":
                if i + 1 < args.count, let margin = Double(args[i + 1]) {
                    config.margin = CGFloat(margin)
                    i += 1
                }
            case "-d", "--duration":
                if i + 1 < args.count, let duration = Double(args[i + 1]) {
                    config.defaultDuration = duration
                    i += 1
                }
            default:
                break
            }
            i += 1
        }

        return config
    }

    public static func printUsage() {
        print("""
        Usage: pyokotify daemon <image> [options]

        Options:
          -s, --size <px>       キャラクターのサイズ (default: 80)
          -m, --margin <px>     画面端からのマージン (default: 20)
          -d, --duration <sec>  通知の表示時間 (default: 5.0)

        Example:
          pyokotify daemon ~/character.png --size 100
        """)
    }
}
