import Foundation

/// Git情報を取得するユーティリティ
public struct GitInfo {
    public let branch: String?
    public let repositoryName: String?
    public let cwd: String

    public init(cwd: String) {
        self.cwd = cwd
        self.branch = GitInfo.getBranch(cwd: cwd)
        self.repositoryName = GitInfo.getRepositoryName(cwd: cwd)
    }

    /// カレントブランチ名を取得
    private static func getBranch(cwd: String) -> String? {
        let result = runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], cwd: cwd)
        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// リポジトリ名を取得
    private static func getRepositoryName(cwd: String) -> String? {
        // まずgit rev-parseでリポジトリルートを取得
        if let root = runGitCommand(["rev-parse", "--show-toplevel"], cwd: cwd)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        {
            return (root as NSString).lastPathComponent
        }
        // Gitリポジトリでない場合はcwdのディレクトリ名を返す
        return (cwd as NSString).lastPathComponent
    }

    /// Gitコマンドを実行（タイムアウト付き）
    private static func runGitCommand(_ args: [String], cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            // タイムアウト付きで待機（1秒）
            let deadline = Date().addingTimeInterval(1.0)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }

            if process.isRunning {
                process.terminate()
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
