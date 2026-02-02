import AppKit
import ApplicationServices
import Foundation

/// VSCodeウィンドウを特定するためのユーティリティ
public enum VSCodeWindowDetector {

    private static var bundleIds: [String] { BundleIDRegistry.vscodeBundleIds }

    /// VSCode関連の環境変数からウィンドウを特定してフォーカス
    /// - Parameter cwd: 作業ディレクトリ
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow(cwd: String? = nil) -> Bool {
        // 方法1: cwdからプロジェクト名でマッチング
        if let cwd = cwd {
            let projectName = (cwd as NSString).lastPathComponent
            if !projectName.isEmpty {
                if WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                    return true
                }
            }
        }

        // 方法2: VSCODE_GIT_IPC_HANDLE からPlugin PIDを特定し、そのPWDでウィンドウをマッチ
        if let pluginPwd = detectPluginPwdFromIpcHandle() {
            let projectName = (pluginPwd as NSString).lastPathComponent
            if !projectName.isEmpty {
                if WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                    return true
                }
            }
        }

        // 方法3: worktreeの親リポジトリ名でマッチング
        // cwd が .worktrees を含む場合、親リポジトリ名を抽出
        if let cwd = cwd, let parentRepoName = extractWorktreeParentName(from: cwd) {
            if WindowDetectorUtils.focusWindowByTitle(parentRepoName, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法4: TTYから特定
        if let windowTitle = WindowDetectorUtils.detectWindowTitleFromTty() {
            if WindowDetectorUtils.focusWindowByTitle(windowTitle, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法5: フォールバック - VSCodeアプリにフォーカス（最後の手段）
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
    }

    /// worktreeパスから親リポジトリ名を抽出
    /// 例: /path/to/jigpo/.worktrees/feature/branch → jigpo
    private static func extractWorktreeParentName(from path: String) -> String? {
        guard let range = path.range(of: "/.worktrees/") else {
            return nil
        }
        let parentPath = String(path[..<range.lowerBound])
        let parentName = (parentPath as NSString).lastPathComponent
        return parentName.isEmpty ? nil : parentName
    }

    // MARK: - VSCode固有: IPC Handle検出

    /// VSCODE_GIT_IPC_HANDLEからPlugin PIDを特定し、そのPWDを取得
    private static func detectPluginPwdFromIpcHandle() -> String? {
        guard let ipcHandle = ProcessInfo.processInfo.environment["VSCODE_GIT_IPC_HANDLE"] else {
            return nil
        }

        guard let socketId = extractSocketId(from: ipcHandle) else {
            return nil
        }

        // lsofを使用してソケットを持つプロセスを検索
        guard let pluginPid = WindowDetectorUtils.findPidWithUnixSocket(containing: "vscode-git-\(socketId)") else {
            return nil
        }

        return WindowDetectorUtils.getProcessPwd(pid: pluginPid)
    }

    /// ソケットパスからIDを抽出
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
