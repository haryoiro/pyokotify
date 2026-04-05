import Foundation
import Testing

@testable import PyokotifyCore

@Suite("Manifest Tests")
struct ManifestTests {

    @Test("デフォルトパスが正しい")
    func defaultPath() {
        #expect(Manifest.defaultPath == "~/.local/share/pyokotify/manifest.json")
    }

    @Test("デフォルトバイナリパスが正しい")
    func defaultBinaryPath() {
        #expect(Manifest.defaultBinaryPath == "~/.local/bin/pyokotify")
    }

    @Test("デフォルトデータディレクトリが正しい")
    func defaultDataDir() {
        #expect(Manifest.defaultDataDir == "~/.local/share/pyokotify")
    }

    @Test("チルダ展開が正しく動作する")
    func expandedPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(Manifest.expandedBinaryPath() == "\(home)/.local/bin/pyokotify")
        #expect(Manifest.expandedDataDir() == "\(home)/.local/share/pyokotify")
    }

    @Test("JSONデコードが正しく動作する")
    func jsonDecode() throws {
        let json = """
        {
          "version": "v0.1.0",
          "installed_at": "2024-01-01T00:00:00Z",
          "files": [
            "/Users/test/.local/bin/pyokotify"
          ]
        }
        """
        let data = json.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

        #expect(manifest.version == "v0.1.0")
        #expect(manifest.installedAt == "2024-01-01T00:00:00Z")
        #expect(manifest.files == ["/Users/test/.local/bin/pyokotify"])
    }

    @Test("expandedFilesがチルダを展開する")
    func expandedFiles() throws {
        let json = """
        {
          "version": "v0.1.0",
          "installed_at": "2024-01-01T00:00:00Z",
          "files": [
            "~/.local/bin/pyokotify"
          ]
        }
        """
        let data = json.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(manifest.expandedFiles() == ["\(home)/.local/bin/pyokotify"])
    }
}

@Suite("Uninstaller Tests")
struct UninstallerTests {

    @Test("binaryNotFoundエラーのメッセージが正しい")
    func binaryNotFoundError() {
        let error = UninstallError.binaryNotFound("/path/to/binary")
        #expect(error.errorDescription?.contains("見つかりません") == true)
        #expect(error.errorDescription?.contains("/path/to/binary") == true)
    }

    @Test("cancelledエラーのメッセージが正しい")
    func cancelledError() {
        let error = UninstallError.cancelled
        #expect(error.errorDescription?.contains("キャンセル") == true)
    }

    @Test("deletionFailedエラーのメッセージが正しい")
    func deletionFailedError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        let error = UninstallError.deletionFailed("/path/to/file", underlyingError)
        #expect(error.errorDescription?.contains("削除に失敗") == true)
        #expect(error.errorDescription?.contains("/path/to/file") == true)
    }
}
