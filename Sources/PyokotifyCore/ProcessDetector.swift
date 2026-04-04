import AppKit
import Foundation

/// 親プロセスからターミナルアプリを検出
///
/// プロセスツリーを遡り、最初に見つかったGUIアプリ（NSRunningApplication）を返す。
/// 既知のアプリはTERM_PROGRAM名で返し、未知のアプリはバンドルIDをそのまま返す。
/// これにより、レジストリに未登録のターミナルアプリも自動的に検出できる。
public enum ProcessDetector {

    /// バンドルID -> TERM_PROGRAM名のマッピング（既知アプリの名前解決用）
    private static var bundleIdToTermProgram: [String: String] { BundleIDRegistry.allTerminalApps }

    /// プロセスツリーを遡ってターミナルアプリを検出
    /// - Returns: 既知アプリのTERM_PROGRAM名、または未知アプリのバンドルID
    public static func detectTerminalApp() -> String? {
        var currentPid = getpid()
        var visitedPids: Set<pid_t> = []

        // 最大20階層まで遡る（無限ループ防止）
        for _ in 0..<20 {
            guard !visitedPids.contains(currentPid) else { break }
            visitedPids.insert(currentPid)

            let parentPid = WindowDetectorUtils.getParentPid(of: currentPid)
            guard parentPid > 1 else { break }  // init(1)に到達したら終了

            if let bundleId = getBundleId(for: parentPid) {
                // 既知アプリはTERM_PROGRAM名で返し、FocusStrategyResolverが特殊処理を判定する
                return bundleIdToTermProgram[bundleId] ?? bundleId
            }

            currentPid = parentPid
        }

        // TERM_PROGRAM環境変数をフォールバックとして使用
        let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"]

        // tmux環境の場合、クライアントPIDから実際のターミナルアプリを検出
        if termProgram == "tmux" {
            if let realTerminal = TmuxWindowDetector.detectRealTerminalApp() {
                return realTerminal
            }
        }

        // cmuxはTERM_PROGRAM=ghosttyを設定するが、CMUX_WORKSPACE_IDで区別可能
        if termProgram == "ghostty"
            && ProcessInfo.processInfo.environment["CMUX_WORKSPACE_ID"] != nil {
            return "cmux"
        }

        return termProgram
    }

    /// 指定PIDのバンドルIDを取得
    private static func getBundleId(for pid: pid_t) -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.processIdentifier == pid }?.bundleIdentifier
    }
}
