import AppKit
import ApplicationServices
import Foundation

/// VSCode / Cursor / VSCodium のウィンドウを特定してフォーカスするユーティリティ。
///
/// 以下の優先順位で検出を試みる:
/// 1. `VSCODE_GIT_IPC_HANDLE` → Plugin PWD → プロジェクト名マッチ（最も確実）
/// 2. cwd のフォルダ名マッチ（cwdが提供されている場合）
/// 3. worktree の親リポジトリ名マッチ（cwd が `.worktrees/` を含む場合）
/// 4. TTY からウィンドウタイトルを推測
/// 5. フォールバック: VSCode アプリ全体をアクティブ化
public enum VSCodeWindowDetector {

    private static var bundleIds: [String] { BundleIDRegistry.vscodeBundleIds }

    /// VSCode ウィンドウを特定してフォーカスする。
    /// - Parameter cwd: hooks JSON から渡される作業ディレクトリ
    /// - Returns: 正しいウィンドウへのフォーカスに成功した場合は `true`
    public static func focusCurrentWindow(cwd: String? = nil) -> Bool {
        // 方法1: VSCODE_GIT_IPC_HANDLE からウィンドウを特定
        // ソケット保持プロセスの PWD = そのウィンドウのワークスペースパス
        if let pluginPwd = detectPluginPwdFromIpcHandle() {
            let projectName = (pluginPwd as NSString).lastPathComponent
            if !projectName.isEmpty,
               WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法2: cwd のフォルダ名でウィンドウタイトルをマッチ
        if let cwd = cwd {
            let projectName = (cwd as NSString).lastPathComponent
            if !projectName.isEmpty,
               WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法3: git worktree 内の場合、親リポジトリ名でマッチ
        // 例: /path/to/myrepo/.worktrees/feature/branch → "myrepo" でウィンドウを検索
        if let cwd = cwd, let parentRepoName = extractWorktreeParentName(from: cwd) {
            if WindowDetectorUtils.focusWindowByTitle(parentRepoName, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法4: TTY からシェルの cwd を取得してウィンドウタイトルを推測
        if let windowTitle = WindowDetectorUtils.detectWindowTitleFromTty(),
           WindowDetectorUtils.focusWindowByTitle(windowTitle, bundleIds: bundleIds) {
            return true
        }

        // 方法5: フォールバック — ウィンドウ特定を諦め、アプリ全体をアクティブ化
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
    }

    /// git worktree パスから親リポジトリ名を抽出する。
    ///
    /// `/.worktrees/` セグメントより前の最後のパスコンポーネントを返す。
    /// worktree でない通常のパスには `nil` を返す。
    private static func extractWorktreeParentName(from path: String) -> String? {
        guard let range = path.range(of: "/.worktrees/") else { return nil }
        let parentPath = String(path[..<range.lowerBound])
        let parentName = (parentPath as NSString).lastPathComponent
        return parentName.isEmpty ? nil : parentName
    }

    // MARK: - IPC Handle 検出

    /// `VSCODE_GIT_IPC_HANDLE` から Code Helper Plugin プロセスを特定し、
    /// そのプロセスの `PWD` 環境変数（= ワークスペースパス）を返す。
    ///
    /// ソケットはウィンドウごとにユニークなため、複数ウィンドウがある場合でも
    /// 正しいウィンドウを特定できる。
    private static func detectPluginPwdFromIpcHandle() -> String? {
        guard let ipcHandle = ProcessInfo.processInfo.environment["VSCODE_GIT_IPC_HANDLE"],
              let socketId = extractSocketId(from: ipcHandle),
              let pluginPid = WindowDetectorUtils.findPidWithUnixSocket(containing: "vscode-git-\(socketId)")
        else {
            return nil
        }
        return WindowDetectorUtils.getProcessPwd(pid: pluginPid)
    }

    /// `vscode-git-{socketId}.sock` 形式のパスから socketId を抽出する。
    private static func extractSocketId(from path: String) -> String? {
        let pattern = "vscode-git-([a-f0-9]+)\\.sock"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path)
        else {
            return nil
        }
        return String(path[range])
    }
}
