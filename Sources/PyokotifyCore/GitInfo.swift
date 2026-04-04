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

    private static func getBranch(cwd: String) -> String? {
        let result = runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], cwd: cwd)
        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func getRepositoryName(cwd: String) -> String? {
        // まずgit rev-parseでリポジトリルートを取得
        if let root = runGitCommand(["rev-parse", "--show-toplevel"], cwd: cwd)?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            return (root as NSString).lastPathComponent
        }
        // Gitリポジトリでない場合はcwdのディレクトリ名を返す
        return (cwd as NSString).lastPathComponent
    }

    private static func runGitCommand(_ args: [String], cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()

            // タイムアウト付きで待機（1秒）
            if semaphore.wait(timeout: .now() + 1.0) == .timedOut {
                process.terminate()
                Log.git.warning("git \(args.joined(separator: " "), privacy: .public) がタイムアウトしました")
                return nil
            }

            guard process.terminationStatus == 0 else {
                Log.git.debug("git \(args.joined(separator: " "), privacy: .public) が終了コード \(process.terminationStatus) で失敗しました")
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            Log.git.error("git \(args.joined(separator: " "), privacy: .public) の起動に失敗: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
