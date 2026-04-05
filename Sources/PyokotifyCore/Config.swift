import Foxus
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
    /// テスト用: 表示後に自動クリックをシミュレート
    public var autoClick: Bool

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
        autoDetectCaller: Bool = true,
        autoClick: Bool = false
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
        self.autoClick = autoClick
    }
}

// MARK: - Caller Bundle ID Resolution

extension PyokotifyConfig {
    /// callerApp から バンドルID を解決する
    ///
    /// Foxus.focus() 失敗時のフォールバックで NSRunningApplication を直接アクティブ化するために使用。
    public func getCallerBundleId() -> String? {
        guard let caller = callerApp else { return nil }
        // 既知のTERM_PROGRAM名 → バンドルID
        if let bundleId = BundleIDRegistry.termProgramToBundleId[caller] {
            return bundleId
        }
        // callerがバンドルIDそのもの（プロセスツリー検出の結果はドット区切り）
        if caller.contains(".") {
            return caller
        }
        return nil
    }
}

// MARK: - Argument Parsing

extension PyokotifyConfig {
    /// コマンドライン引数を解析して設定を生成
    public static func parse(arguments: [String]) -> Result<PyokotifyConfig, ConfigError> {
        if arguments.contains("-h") || arguments.contains("--help") {
            return .failure(.helpRequested)
        }
        guard arguments.count >= 2 else {
            return .failure(.missingImagePath)
        }

        var config = PyokotifyConfig(imagePath: arguments[1])
        var i = 2
        while i < arguments.count {
            let next = i + 1 < arguments.count ? arguments[i + 1] : nil
            i += applyOption(arguments[i], nextArg: next, to: &config) ? 2 : 1
        }
        return .success(config)
    }

    // swiftlint:disable cyclomatic_complexity
    /// 1つのオプションを解析してconfigに適用する
    /// - Returns: 次の引数を値として消費した場合はtrue
    private static func applyOption(_ flag: String, nextArg: String?, to config: inout PyokotifyConfig) -> Bool {
        switch flag {
        case "-d", "--duration":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.displayDuration = val
            return true
        case "-a", "--animation":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.animationDuration = val
            return true
        case "-p", "--peek":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.peekHeight = CGFloat(val)
            return true
        case "-m", "--margin":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.rightMargin = CGFloat(val)
            return true
        case "--min":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.randomMinInterval = val
            return true
        case "--max":
            guard let val = nextArg.flatMap(Double.init) else { return false }
            config.randomMaxInterval = val
            return true
        case "-t", "--text":
            guard let val = nextArg else { return false }
            config.message = val
            return true
        case "-c", "--caller":
            guard let val = nextArg else { return false }
            config.callerApp = val
            return true
        case "--cwd":
            guard let val = nextArg else { return false }
            config.cwd = val
            return true
        case "-s", "--sound":
            guard let val = nextArg else { return false }
            config.soundPath = val
            return true
        case "--no-click":
            config.clickable = false
        case "-r", "--random":
            config.randomMode = true
        case "--random-direction":
            config.randomDirection = true
        case "--hooks", "--claude-hooks":
            config.hooksMode = true
        case "--no-auto-detect":
            config.autoDetectCaller = false
        case "--auto-click":
            config.autoClick = true
        default:
            Log.app.warning("不明なオプション: \(flag, privacy: .public)")
        }
        return false
    }
    // swiftlint:enable cyclomatic_complexity

    /// CommandLine.arguments から設定を生成（互換性のため）
    public static func fromArguments() -> PyokotifyConfig? {
        switch parse(arguments: CommandLine.arguments) {
        case .success(let config):
            return config
        case .failure(let error):
            if case .helpRequested = error {
                printUsage()
            } else {
                Log.app.error("\(error.localizedDescription, privacy: .public)")
                fputs("エラー: \(error.localizedDescription)\n", stderr)
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
