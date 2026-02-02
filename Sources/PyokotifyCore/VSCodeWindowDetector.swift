import AppKit
import ApplicationServices
import Foundation

/// VSCodeウィンドウを特定するためのユーティリティ
public enum VSCodeWindowDetector {

    private static var bundleIds: [String] { BundleIDRegistry.vscodeBundleIds }

    /// VSCode関連の環境変数からウィンドウを特定してフォーカス
    /// - Parameter cwd: 作業ディレクトリ（指定された場合はこれを優先してウィンドウを特定）
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow(cwd: String? = nil) -> Bool {
        // 方法1: 明示的に指定されたcwdからプロジェクト名でマッチング
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

        // 方法3: TTYから特定
        if let windowTitle = WindowDetectorUtils.detectWindowTitleFromTty() {
            if WindowDetectorUtils.focusWindowByTitle(windowTitle, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法4: フォールバック - VSCodeアプリにフォーカス（最後の手段）
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
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

        guard let pluginPid = findPluginPidBySocket(socketId: socketId) else {
            return nil
        }

        return getProcessPwd(pid: pluginPid)
    }

    /// プロセスのPWD環境変数を取得
    private static func getProcessPwd(pid: pid_t) -> String? {
        let output = WindowDetectorUtils.runCommand("/bin/ps", arguments: ["eww", "-o", "command=", "-p", "\(pid)"])
        guard let output = output else { return nil }

        let pattern = "PWD=([^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return nil
        }

        return String(output[range])
    }

    /// ソケットパスからIDを抽出
    private static func extractSocketId(from path: String) -> String? {
        let pattern = "vscode-git-([a-f0-9]+)\\.sock"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path) else {
            return nil
        }
        return String(path[range])
    }

    /// lsofでソケットを持つCode Helper (Plugin) PIDを取得
    private static func findPluginPidBySocket(socketId: String) -> pid_t? {
        let output = WindowDetectorUtils.runCommand("/usr/sbin/lsof", arguments: ["-U"])
        guard let output = output else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.contains("vscode-git-\(socketId)") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let pid = Int32(parts[1]) {
                    return pid
                }
            }
        }
        return nil
    }
}
