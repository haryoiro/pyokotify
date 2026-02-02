import AppKit
import Foundation

/// 親プロセスからターミナルアプリを検出
public enum ProcessDetector {

    /// ターミナルアプリのバンドルID一覧
    private static var terminalBundleIds: Set<String> { BundleIDRegistry.allTerminalBundleIds }

    /// バンドルID -> TERM_PROGRAM名のマッピング
    private static var bundleIdToTermProgram: [String: String] { BundleIDRegistry.allTerminalApps }

    /// プロセスツリーを遡ってターミナルアプリを検出
    /// - Returns: 検出したTERM_PROGRAM名（VSCodeなら"vscode"）
    public static func detectTerminalApp() -> String? {
        var currentPid = getpid()
        var visitedPids: Set<pid_t> = []

        // 最大20階層まで遡る（無限ループ防止）
        for _ in 0..<20 {
            guard !visitedPids.contains(currentPid) else { break }
            visitedPids.insert(currentPid)

            let parentPid = WindowDetectorUtils.getParentPid(of: currentPid)
            guard parentPid > 1 else { break }  // init(1)に到達したら終了

            // 親プロセスのバンドルIDを取得
            if let bundleId = getBundleId(for: parentPid),
                terminalBundleIds.contains(bundleId)
            {
                return bundleIdToTermProgram[bundleId]
            }

            currentPid = parentPid
        }

        // TERM_PROGRAM環境変数をフォールバックとして使用
        return ProcessInfo.processInfo.environment["TERM_PROGRAM"]
    }

    /// 指定PIDのバンドルIDを取得
    private static func getBundleId(for pid: pid_t) -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.processIdentifier == pid }?.bundleIdentifier
    }
}
