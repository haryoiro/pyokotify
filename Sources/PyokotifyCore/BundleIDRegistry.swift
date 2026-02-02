import Foundation

/// アプリケーションのバンドルID定義を一元管理
public enum BundleIDRegistry {

    // MARK: - JetBrains IDEs

    /// JetBrains IDE のバンドルID → TERM_PROGRAM名 マッピング
    public static let jetBrainsIDEs: [String: String] = [
        "com.jetbrains.intellij": "idea",
        "com.jetbrains.intellij.ce": "idea",
        "com.jetbrains.intellij-EAP": "idea",
        "com.jetbrains.AppCode": "appcode",
        "com.jetbrains.CLion": "clion",
        "com.jetbrains.CLion-EAP": "clion",
        "com.jetbrains.WebStorm": "webstorm",
        "com.jetbrains.WebStorm-EAP": "webstorm",
        "com.jetbrains.pycharm": "pycharm",
        "com.jetbrains.pycharm.ce": "pycharm",
        "com.jetbrains.PyCharm-EAP": "pycharm",
        "com.jetbrains.PhpStorm": "phpstorm",
        "com.jetbrains.PhpStorm-EAP": "phpstorm",
        "com.jetbrains.goland": "goland",
        "com.jetbrains.goland-EAP": "goland",
        "com.jetbrains.rubymine": "rubymine",
        "com.jetbrains.rubymine-EAP": "rubymine",
        "com.jetbrains.rider": "rider",
        "com.jetbrains.rider-EAP": "rider",
        "com.jetbrains.datagrip": "datagrip",
        "com.jetbrains.datagrip-EAP": "datagrip",
        "com.jetbrains.fleet": "fleet",
    ]

    /// JetBrains IDE のバンドルID一覧
    public static var jetBrainsBundleIds: [String] {
        Array(jetBrainsIDEs.keys)
    }

    // MARK: - VSCode

    /// VSCode のバンドルID
    public static let vscodeBundleIds: [String] = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
    ]

    // MARK: - Terminals

    /// ターミナルアプリのバンドルID → TERM_PROGRAM名 マッピング
    public static let terminalApps: [String: String] = [
        "com.microsoft.VSCode": "vscode",
        "com.microsoft.VSCodeInsiders": "vscode",
        "com.googlecode.iterm2": "iTerm.app",
        "com.apple.Terminal": "Apple_Terminal",
        "dev.warp.Warp-Stable": "WarpTerminal",
        "co.zeit.hyper": "Hyper",
        "org.alacritty": "Alacritty",
        "net.kovidgoyal.kitty": "kitty",
        "org.tabby": "Tabby",
        "com.mitchellh.ghostty": "ghostty",
    ]

    /// 全ターミナル関連アプリのバンドルID → TERM_PROGRAM名 マッピング（JetBrains含む）
    public static var allTerminalApps: [String: String] {
        terminalApps.merging(jetBrainsIDEs) { current, _ in current }
    }

    /// 全ターミナル関連アプリのバンドルID一覧
    public static var allTerminalBundleIds: Set<String> {
        Set(allTerminalApps.keys)
    }

    // MARK: - TERM_PROGRAM → バンドルID 逆引き

    /// TERM_PROGRAM名 → バンドルID マッピング
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
        // JetBrains
        "idea": "com.jetbrains.intellij",
        "appcode": "com.jetbrains.AppCode",
        "clion": "com.jetbrains.CLion",
        "webstorm": "com.jetbrains.WebStorm",
        "pycharm": "com.jetbrains.pycharm",
        "phpstorm": "com.jetbrains.PhpStorm",
        "goland": "com.jetbrains.goland",
        "rubymine": "com.jetbrains.rubymine",
        "rider": "com.jetbrains.rider",
        "datagrip": "com.jetbrains.datagrip",
        "fleet": "com.jetbrains.fleet",
    ]
}
