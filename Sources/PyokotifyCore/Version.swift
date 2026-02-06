import Foundation

/// pyokotifyのバージョン情報
public enum Version {
    /// 現在のバージョン（リリース時に更新）
    public static let current = "0.3.2"

    /// バージョン文字列を取得（manifest.json優先、なければハードコード値）
    public static func string() -> String {
        if let manifest = Manifest.load() {
            return manifest.version
        }
        return current
    }
}
