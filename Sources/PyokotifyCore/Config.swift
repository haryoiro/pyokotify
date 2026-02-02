import Foundation

// MARK: - Configuration

/// pyokotify の設定
public struct PyokotifyConfig {
    public var imagePath: String
    public var displayDuration: TimeInterval
    public var animationDuration: TimeInterval
    public var peekHeight: CGFloat
    public var rightMargin: CGFloat
    public var clickable: Bool
    public var randomMode: Bool
    public var randomMinInterval: TimeInterval
    public var randomMaxInterval: TimeInterval
    public var randomDirection: Bool
    public var direction: PeekDirection
    public var message: String?
    public var callerApp: String?
    public var cwd: String?
    // Hooks連携（Claude Code / GitHub Copilot CLI）
    public var hooksMode: Bool
    public var soundPath: String?
    public var autoDetectCaller: Bool

    public init(
        imagePath: String,
        displayDuration: TimeInterval = 3.0,
        animationDuration: TimeInterval = 0.4,
        peekHeight: CGFloat = 200,
        rightMargin: CGFloat = 50,
        clickable: Bool = true,
        randomMode: Bool = false,
        randomMinInterval: TimeInterval = 30,
        randomMaxInterval: TimeInterval = 120,
        randomDirection: Bool = false,
        direction: PeekDirection = .bottom,
        message: String? = nil,
        callerApp: String? = nil,
        cwd: String? = nil,
        hooksMode: Bool = false,
        soundPath: String? = nil,
        autoDetectCaller: Bool = true
    ) {
        self.imagePath = imagePath
        self.displayDuration = displayDuration
        self.animationDuration = animationDuration
        self.peekHeight = peekHeight
        self.rightMargin = rightMargin
        self.clickable = clickable
        self.randomMode = randomMode
        self.randomMinInterval = randomMinInterval
        self.randomMaxInterval = randomMaxInterval
        self.randomDirection = randomDirection
        self.direction = direction
        self.message = message
        self.callerApp = callerApp
        self.cwd = cwd
        self.hooksMode = hooksMode
        self.soundPath = soundPath
        self.autoDetectCaller = autoDetectCaller
    }
}

// MARK: - Terminal Bundle ID Mapping

extension PyokotifyConfig {
    /// TERM_PROGRAM → バンドルID のマッピング
    public static var termProgramToBundleId: [String: String] { BundleIDRegistry.termProgramToBundleId }

    public func getCallerBundleId() -> String? {
        guard let caller = callerApp else { return nil }
        return Self.termProgramToBundleId[caller]
    }
}

// MARK: - Argument Parsing

extension PyokotifyConfig {
    /// コマンドライン引数を解析して設定を生成
    public static func parse(arguments: [String]) -> Result<PyokotifyConfig, ConfigError> {
        // ヘルプ表示
        if arguments.contains("-h") || arguments.contains("--help") {
            return .failure(.helpRequested)
        }

        // 画像パス（必須）
        guard arguments.count >= 2 else {
            return .failure(.missingImagePath)
        }

        var config = PyokotifyConfig(imagePath: arguments[1])

        // オプション解析
        var i = 2
        while i < arguments.count {
            switch arguments[i] {
            case "-d", "--duration":
                if i + 1 < arguments.count, let duration = Double(arguments[i + 1]) {
                    config.displayDuration = duration
                    i += 1
                }
            case "-a", "--animation":
                if i + 1 < arguments.count, let duration = Double(arguments[i + 1]) {
                    config.animationDuration = duration
                    i += 1
                }
            case "-p", "--peek":
                if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                    config.peekHeight = CGFloat(height)
                    i += 1
                }
            case "-m", "--margin":
                if i + 1 < arguments.count, let margin = Double(arguments[i + 1]) {
                    config.rightMargin = CGFloat(margin)
                    i += 1
                }
            case "--no-click":
                config.clickable = false
            case "-r", "--random":
                config.randomMode = true
            case "--random-direction":
                config.randomDirection = true
            case "--min":
                if i + 1 < arguments.count, let interval = Double(arguments[i + 1]) {
                    config.randomMinInterval = interval
                    i += 1
                }
            case "--max":
                if i + 1 < arguments.count, let interval = Double(arguments[i + 1]) {
                    config.randomMaxInterval = interval
                    i += 1
                }
            case "-t", "--text":
                if i + 1 < arguments.count {
                    config.message = arguments[i + 1]
                    i += 1
                }
            case "-c", "--caller":
                if i + 1 < arguments.count {
                    config.callerApp = arguments[i + 1]
                    i += 1
                }
            case "--cwd":
                if i + 1 < arguments.count {
                    config.cwd = arguments[i + 1]
                    i += 1
                }
            case "--hooks", "--claude-hooks":
                config.hooksMode = true
            case "-s", "--sound":
                if i + 1 < arguments.count {
                    config.soundPath = arguments[i + 1]
                    i += 1
                }
            case "--no-auto-detect":
                config.autoDetectCaller = false
            default:
                break
            }
            i += 1
        }

        return .success(config)
    }

    /// CommandLine.arguments から設定を生成（互換性のため）
    public static func fromArguments() -> PyokotifyConfig? {
        switch parse(arguments: CommandLine.arguments) {
        case .success(let config):
            return config
        case .failure(let error):
            if case .helpRequested = error {
                printUsage()
            } else {
                print("エラー: \(error.localizedDescription)")
                printUsage()
            }
            return nil
        }
    }

    public static func printUsage() {
        print(
            """
            pyokotify - ぴょこぴょこ通知アプリ

            使い方:
                pyokotify <画像パス> [オプション]
                pyokotify uninstall [-y]
                pyokotify --version

            サブコマンド:
                uninstall              pyokotifyをアンインストール

            オプション:
                -d, --duration <秒>    表示時間（デフォルト: 3.0秒）
                -a, --animation <秒>   アニメーション時間（デフォルト: 0.4秒）
                -p, --peek <px>        顔を出す高さ（デフォルト: 200px）
                -m, --margin <px>      右端からのマージン（デフォルト: 50px）
                --no-click             クリック無効化（マウスイベントを通過）
                -t, --text <メッセージ> 吹き出しでメッセージを表示
                -c, --caller <アプリ>  クリック時に戻るアプリ（TERM_PROGRAM値）
                --cwd <パス>           作業ディレクトリ（特定ウィンドウにフォーカス）
                -r, --random           ランダム間隔でぴょこぴょこし続ける
                --random-direction     ランダムな方向（下・左・右）から出現
                --min <秒>             ランダムモードの最小間隔（デフォルト: 30秒）
                --max <秒>             ランダムモードの最大間隔（デフォルト: 120秒）
                -h, --help             ヘルプを表示

            Hooks連携（Claude Code / GitHub Copilot CLI 自動検出）:
                --hooks                標準入力からhooks JSONを読み取る（自動検出）
                --claude-hooks         --hooks のエイリアス
                --no-auto-detect       親プロセス自動検出を無効化

            サウンド:
                -s, --sound <パス>     通知時に音声を再生

            テンプレート変数（-t オプションで使用可能）:
                $dir                   ディレクトリ名
                $branch                Gitブランチ名
                $cwd                   フルパス
                $event                 イベント名
                $tool                  ツール名

            例:
                pyokotify ~/Pictures/zundamon.png
                pyokotify ~/Pictures/zundamon.png -d 5 -p 300
                pyokotify ~/Pictures/zundamon.png -t "タスク完了なのだ！"
                pyokotify ~/Pictures/zundamon.png --hooks -t "[$dir:$branch] Done!"
            """)
    }
}

// MARK: - Config Error

public enum ConfigError: Error, LocalizedError {
    case helpRequested
    case missingImagePath

    public var errorDescription: String? {
        switch self {
        case .helpRequested:
            return nil
        case .missingImagePath:
            return "画像パスを指定してください"
        }
    }
}
