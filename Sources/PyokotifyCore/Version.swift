import Foundation

/// pyokotifyのバージョン情報
public enum Version {
    /// 現在のバージョン
    public static let current = "0.3.3"

    /// バージョン文字列を取得
    public static func string() -> String {
        return current
    }
}
