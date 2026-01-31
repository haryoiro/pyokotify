import Foundation

// MARK: - Configuration

/// Configuration for pyokotify
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
        cwd: String? = nil
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
    }
}

// MARK: - Terminal Bundle ID Mapping

extension PyokotifyConfig {
    /// TERM_PROGRAM to Bundle ID mapping
    public static let termProgramToBundleId: [String: String] = [
        "vscode": "com.microsoft.VSCode",
        "VSCode": "com.microsoft.VSCode",
        "iTerm.app": "com.googlecode.iterm2",
        "Apple_Terminal": "com.apple.Terminal",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "Hyper": "co.zeit.hyper",
        "Alacritty": "org.alacritty",
        "kitty": "net.kovidgoyal.kitty",
        "Tabby": "org.tabby",
        "ghostty": "com.mitchellh.ghostty",
        "Ghostty": "com.mitchellh.ghostty",
        "tmux": "com.apple.Terminal",
    ]

    public func getCallerBundleId() -> String? {
        guard let caller = callerApp else { return nil }
        return Self.termProgramToBundleId[caller]
    }
}

// MARK: - Argument Parsing

extension PyokotifyConfig {
    /// Parse command line arguments and generate configuration
    public static func parse(arguments: [String]) -> Result<PyokotifyConfig, ConfigError> {
        // Show help
        if arguments.contains("-h") || arguments.contains("--help") {
            return .failure(.helpRequested)
        }

        // Image path (required)
        guard arguments.count >= 2 else {
            return .failure(.missingImagePath)
        }

        var config = PyokotifyConfig(imagePath: arguments[1])

        // Parse options
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
            default:
                break
            }
            i += 1
        }

        return .success(config)
    }

    /// Generate configuration from CommandLine.arguments (for compatibility)
    public static func fromArguments() -> PyokotifyConfig? {
        switch parse(arguments: CommandLine.arguments) {
        case .success(let config):
            return config
        case .failure(let error):
            if case .helpRequested = error {
                printUsage()
            } else {
                print("Error: \(error.localizedDescription)")
                printUsage()
            }
            return nil
        }
    }

    public static func printUsage() {
        print(
            """
            pyokotify - Character peek notification app

            Usage:
                pyokotify <image-path> [options]

            Options:
                -d, --duration <sec>   Display duration (default: 3.0)
                -a, --animation <sec>  Animation duration (default: 0.4)
                -p, --peek <px>        Peek height (default: 200)
                -m, --margin <px>      Margin from edge (default: 50)
                --no-click             Disable click (pass-through mouse events)
                -t, --text <message>   Show message in speech bubble
                -c, --caller <app>     App to return to on click (TERM_PROGRAM value)
                --cwd <path>           Focus window containing this path
                -r, --random           Keep popping at random intervals
                --random-direction     Appear from random direction (bottom/left/right)
                --min <sec>            Min interval for random mode (default: 30)
                --max <sec>            Max interval for random mode (default: 120)
                -h, --help             Show help

            Examples:
                pyokotify ~/Pictures/character.png
                pyokotify ~/Pictures/character.png -d 5 -p 300
                pyokotify ~/Pictures/character.png -t "Task completed!"
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
            return "Please specify an image path"
        }
    }
}
