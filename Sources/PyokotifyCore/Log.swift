import OSLog

/// アプリ全体で使用するロガー
///
/// Console.app または以下のコマンドで確認できる:
///   log stream --predicate 'subsystem == "com.haryoiro.pyokotify"' --level debug
enum Log {
    /// アプリ起動・設定・画像読み込みなど
    static let app = Logger(subsystem: "com.haryoiro.pyokotify", category: "app")
    /// ウィンドウフォーカス・AX API操作
    static let focus = Logger(subsystem: "com.haryoiro.pyokotify", category: "focus")
    /// Hooks JSON解析（Claude Code / GitHub Copilot CLI）
    static let hooks = Logger(subsystem: "com.haryoiro.pyokotify", category: "hooks")
    /// サウンド再生
    static let sound = Logger(subsystem: "com.haryoiro.pyokotify", category: "sound")
    /// git コマンド実行
    static let git = Logger(subsystem: "com.haryoiro.pyokotify", category: "git")
    /// プロセス検出・TTY操作
    static let process = Logger(subsystem: "com.haryoiro.pyokotify", category: "process")
}
