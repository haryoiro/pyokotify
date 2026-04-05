import OSLog

// MARK: - PyokotifyCore Logging

/// アプリ固有のロガー（UI・CLIレイヤー）
///
/// ウィンドウ検出・hooks解析・プロセス検出のログは Foxus モジュール側に出力される:
///   log stream --predicate 'subsystem == "com.haryoiro.foxus"' --level debug
///
/// アプリ層のログ確認:
///   log stream --predicate 'subsystem == "com.haryoiro.pyokotify"' --level debug
enum Log {
    /// アプリ起動・設定・画像読み込みなど
    static let app   = Logger(subsystem: "com.haryoiro.pyokotify", category: "app")
    /// サウンド再生
    static let sound = Logger(subsystem: "com.haryoiro.pyokotify", category: "sound")
}
