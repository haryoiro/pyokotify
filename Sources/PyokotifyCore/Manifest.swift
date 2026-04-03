import Foundation

/// インストールメタデータ
public struct Manifest: Codable {
    public let version: String
    public let installedAt: String
    public let files: [String]

    public static let defaultPath = "~/.local/share/pyokotify/manifest.json"
    public static let defaultBinaryPath = "~/.local/bin/pyokotify"
    public static let defaultDataDir = "~/.local/share/pyokotify"

    private enum CodingKeys: String, CodingKey {
        case version
        case installedAt = "installed_at"
        case files
    }

    public static func load() -> Manifest? {
        let path = (defaultPath as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    public func expandedFiles() -> [String] {
        files.map { ($0 as NSString).expandingTildeInPath }
    }

    public static func expandedDataDir() -> String {
        (defaultDataDir as NSString).expandingTildeInPath
    }

    public static func expandedBinaryPath() -> String {
        (defaultBinaryPath as NSString).expandingTildeInPath
    }
}
