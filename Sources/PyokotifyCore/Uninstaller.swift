import Foundation

/// アンインストールエラー
public enum UninstallError: Error, LocalizedError {
    case binaryNotFound(String)
    case deletionFailed(String, Error)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "バイナリが見つかりません: \(path)"
        case .deletionFailed(let path, let error):
            return "削除に失敗しました: \(path) (\(error.localizedDescription))"
        case .cancelled:
            return "アンインストールがキャンセルされました"
        }
    }
}

/// アンインストーラー
public struct Uninstaller {

    /// アンインストールを実行
    public static func run(skipConfirmation: Bool = false) -> Result<Void, UninstallError> {
        let manifest = Manifest.load()
        let version = manifest?.version

        // 削除対象のファイルを取得
        let filesToDelete: [String]
        if let manifest = manifest {
            filesToDelete = manifest.expandedFiles()
        } else {
            // manifest.jsonがない場合はデフォルトパスを使用
            printWarning("manifest.json が見つかりません。デフォルトパスを使用します。")
            filesToDelete = [Manifest.expandedBinaryPath()]
        }

        // バイナリの存在確認
        let binaryPath = Manifest.expandedBinaryPath()
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            return .failure(.binaryNotFound(binaryPath))
        }

        // 確認プロンプト
        if !skipConfirmation {
            guard confirmUninstall(version: version, files: filesToDelete) else {
                return .failure(.cancelled)
            }
        }

        // ファイル削除
        for file in filesToDelete {
            if FileManager.default.fileExists(atPath: file) {
                do {
                    try FileManager.default.removeItem(atPath: file)
                } catch {
                    return .failure(.deletionFailed(file, error))
                }
            }
        }

        // メタデータディレクトリ削除
        let dataDir = Manifest.expandedDataDir()
        if FileManager.default.fileExists(atPath: dataDir) {
            do {
                try FileManager.default.removeItem(atPath: dataDir)
            } catch {
                // メタデータディレクトリの削除失敗は警告のみ
                printWarning("メタデータディレクトリの削除に失敗しました: \(dataDir)")
            }
        }

        // 成功メッセージ
        printSuccessMessage()

        return .success(())
    }

    /// 確認プロンプト
    private static func confirmUninstall(version: String?, files: [String]) -> Bool {
        if let version = version {
            print("pyokotify \(version) をアンインストールします。")
        } else {
            print("pyokotify をアンインストールします。")
        }
        print("")
        print("削除対象:")
        for file in files {
            print("  - \(file)")
        }
        let dataDir = Manifest.expandedDataDir()
        if FileManager.default.fileExists(atPath: dataDir) {
            print("  - \(dataDir)/")
        }
        print("")
        print("続行しますか？ [y/N]: ", terminator: "")

        guard let input = readLine()?.lowercased() else {
            return false
        }
        return input == "y" || input == "yes"
    }

    /// 成功メッセージ
    private static func printSuccessMessage() {
        print("")
        print("\u{001B}[32m✓\u{001B}[0m pyokotify をアンインストールしました")
        print("")
        print("注意: shell設定ファイルのPATH設定は手動で削除してください:")
        print("  ~/.zshrc, ~/.bashrc, ~/.bash_profile, ~/.config/fish/config.fish など")
        print("")
        print("削除対象の行の例:")
        print("  export PATH=\"~/.local/bin:$PATH\"")
    }

    /// 警告メッセージ
    private static func printWarning(_ message: String) {
        print("\u{001B}[33m警告:\u{001B}[0m \(message)")
    }

    /// ヘルプを表示
    public static func printUsage() {
        print("""
        pyokotify uninstall - pyokotifyをアンインストール

        使い方:
            pyokotify uninstall [オプション]

        オプション:
            -y, --yes    確認なしでアンインストール
            -h, --help   このヘルプを表示

        説明:
            ~/.local/bin/pyokotify とメタデータを削除します。
            shell設定ファイルのPATH設定は手動で削除してください。
        """)
    }
}
