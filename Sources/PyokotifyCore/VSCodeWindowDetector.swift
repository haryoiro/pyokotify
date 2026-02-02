import AppKit
import ApplicationServices
import Foundation

/// VSCodeウィンドウを特定するためのユーティリティ
public enum VSCodeWindowDetector {

    private static var bundleIds: [String] { BundleIDRegistry.vscodeBundleIds }

    /// VSCode関連の環境変数からウィンドウを特定してフォーカス
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow() -> Bool {
        // 方法1: VSCODE_GIT_IPC_HANDLE から特定
        if let windowId = detectWindowIdFromIpcHandle() {
            if focusWindowByConfigId(windowId) {
                return true
            }
        }

        // 方法2: TTYから特定
        if let windowTitle = WindowDetectorUtils.detectWindowTitleFromTty() {
            if WindowDetectorUtils.focusWindowByTitle(windowTitle, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法3: フォールバック
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
    }

    // MARK: - VSCode固有: IPC Handle検出

    /// VSCODE_GIT_IPC_HANDLEからウィンドウIDを特定
    private static func detectWindowIdFromIpcHandle() -> String? {
        guard let ipcHandle = ProcessInfo.processInfo.environment["VSCODE_GIT_IPC_HANDLE"]
        else {
            return nil
        }

        guard let socketId = extractSocketId(from: ipcHandle) else {
            return nil
        }

        guard let pluginPid = findPluginPidBySocket(socketId: socketId) else {
            return nil
        }

        guard let rendererPid = findRelatedRendererPid(pluginPid: pluginPid) else {
            return nil
        }

        return getWindowConfigId(forPid: rendererPid)
    }

    /// ソケットパスからIDを抽出
    private static func extractSocketId(from path: String) -> String? {
        let pattern = "vscode-git-([a-f0-9]+)\\.sock"
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: path, range: NSRange(path.startIndex..., in: path))
        else {
            return nil
        }

        if let range = Range(match.range(at: 1), in: path) {
            return String(path[range])
        }
        return nil
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

    /// 同時刻に起動したRendererプロセスを探す
    private static func findRelatedRendererPid(pluginPid: pid_t) -> pid_t? {
        guard let pluginStartTime = getProcessStartTime(pid: pluginPid) else {
            return nil
        }

        let output = WindowDetectorUtils.runCommand(
            "/bin/ps", arguments: ["-A", "-o", "pid,lstart,comm"])
        guard let output = output else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.contains("Code Helper (Renderer)") {
                let parts = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }

                if parts.count >= 6, let pid = Int32(parts[0]) {
                    if let startTime = getProcessStartTime(pid: pid),
                        abs(startTime.timeIntervalSince(pluginStartTime)) < 2.0
                    {
                        return pid
                    }
                }
            }
        }
        return nil
    }

    /// プロセスの起動時刻を取得
    private static func getProcessStartTime(pid: pid_t) -> Date? {
        let output = WindowDetectorUtils.runCommand("/bin/ps", arguments: ["-o", "lstart=", "-p", "\(pid)"])
        guard let output = output?.trimmingCharacters(in: .whitespacesAndNewlines),
            !output.isEmpty
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"

        if let date = formatter.date(from: output) {
            return date
        }

        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: output)
    }

    /// プロセスのコマンドラインから--vscode-window-configを取得
    private static func getWindowConfigId(forPid pid: pid_t) -> String? {
        let output = WindowDetectorUtils.runCommand("/bin/ps", arguments: ["-o", "args=", "-p", "\(pid)"])
        guard let output = output else { return nil }

        let pattern = "vscode-window-config=(vscode:[a-f0-9-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: output, range: NSRange(output.startIndex..., in: output))
        else {
            return nil
        }

        if let range = Range(match.range(at: 1), in: output) {
            return String(output[range])
        }
        return nil
    }

    // MARK: - ウィンドウフォーカス

    /// window-config IDでウィンドウをフォーカス
    private static func focusWindowByConfigId(_ configId: String) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIds[0])
        guard let app = apps.first else { return false }
        app.activate(options: [.activateIgnoringOtherApps])
        return true
    }
}
