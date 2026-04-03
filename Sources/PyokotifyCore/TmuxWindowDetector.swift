import AppKit
import ApplicationServices
import Foundation

/// tmux環境でウィンドウを特定するためのユーティリティ
///
/// tmux内からpyokotifyが起動された場合に、実際のGUIターミナルアプリを特定し、
/// 通知クリック時に正しいターミナル＋tmuxペインにフォーカスを戻す。
///
/// **検出フロー**:
/// 1. `TMUX`環境変数でtmux環境を判定
/// 2. `tmux list-clients`でクライアントPIDを取得
/// 3. クライアントPIDから親プロセスツリーを辿りGUIターミナルを特定
/// 4. クリック時は`tmux select-window` + `tmux select-pane`でペイン復元
public enum TmuxWindowDetector {

    // MARK: - tmux環境検出

    /// tmux環境かどうかを判定
    public static func isTmuxEnvironment() -> Bool {
        ProcessInfo.processInfo.environment["TMUX"] != nil
    }

    // MARK: - TMUX環境変数パース（テスタブル）

    /// TMUX環境変数からソケットパスを抽出
    /// - Parameter tmuxEnv: TMUX環境変数の値（例: `/tmp/tmux-501/default,12345,0`）
    /// - Returns: ソケットパス（例: `/tmp/tmux-501/default`）
    public static func parseSocketPath(from tmuxEnv: String) -> String? {
        guard !tmuxEnv.isEmpty else { return nil }
        let components = tmuxEnv.components(separatedBy: ",")
        let path = components[0]
        return path.isEmpty ? nil : path
    }

    /// TMUX環境変数からサーバーPIDを抽出
    /// - Parameter tmuxEnv: TMUX環境変数の値（例: `/tmp/tmux-501/default,12345,0`）
    /// - Returns: サーバーPID
    public static func parseServerPid(from tmuxEnv: String) -> pid_t? {
        let components = tmuxEnv.components(separatedBy: ",")
        guard components.count >= 2 else { return nil }
        return Int32(components[1])
    }

    // MARK: - 実際のターミナルアプリ検出

    /// tmuxクライアントのプロセスツリーを辿り、実際のターミナルアプリを検出
    /// - Returns: 既知アプリのTERM_PROGRAM名、または未知アプリのバンドルID
    public static func detectRealTerminalApp() -> String? {
        let clientPids = getClientPids()
        let bundleIdToTermProgram = BundleIDRegistry.allTerminalApps

        debug("detectRealTerminalApp: found \(clientPids.count) tmux client(s)")

        for clientPid in clientPids {
            var currentPid = clientPid
            var visitedPids: Set<pid_t> = []

            for _ in 0..<20 {
                guard !visitedPids.contains(currentPid) else { break }
                visitedPids.insert(currentPid)

                if let bundleId = getBundleId(for: currentPid) {
                    debug("  -> found app: \(bundleId) (pid=\(currentPid))")
                    // 既知アプリならTERM_PROGRAM名、未知ならバンドルIDをそのまま返す
                    return bundleIdToTermProgram[bundleId] ?? bundleId
                }

                let parentPid = WindowDetectorUtils.getParentPid(of: currentPid)
                guard parentPid > 1 else { break }
                currentPid = parentPid
            }
        }

        debug("  -> no terminal app found in client process trees")
        return nil
    }

    /// tmux環境でウィンドウを特定してフォーカス
    /// - Parameter cwd: 作業ディレクトリ
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow(cwd: String?) -> Bool {
        debug("focusCurrentWindow: cwd=\(cwd ?? "nil")")

        // 実際のターミナルアプリを特定
        if let detected = detectRealTerminalApp(),
            let bundleId = resolveBundleId(detected)
        {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first {
                // cwdでウィンドウマッチを試みる
                if let cwd = cwd {
                    // フルパスマッチ → フォルダ名マッチ の順
                    if WindowDetectorUtils.focusWindowInApp(app, matchingTitle: cwd) {
                        restoreTmuxPane()
                        return true
                    }
                    let folderName = (cwd as NSString).lastPathComponent
                    if !folderName.isEmpty,
                        WindowDetectorUtils.focusWindowInApp(app, matchingTitle: folderName)
                    {
                        restoreTmuxPane()
                        return true
                    }
                }
                // マッチしなければアプリ全体にフォーカス
                debug("  -> fallback: activating app \(bundleId)")
                app.activate(options: [.activateIgnoringOtherApps])
                restoreTmuxPane()
                return true
            }
        }

        // フォールバック: 全ターミナルアプリからcwdでマッチ
        if let cwd = cwd {
            let folderName = (cwd as NSString).lastPathComponent
            if !folderName.isEmpty {
                let allBundleIds = Array(BundleIDRegistry.terminalApps.keys)
                if WindowDetectorUtils.focusWindowByTitle(folderName, bundleIds: allBundleIds) {
                    restoreTmuxPane()
                    return true
                }
            }
        }

        debug("  -> focusCurrentWindow failed")
        return false
    }

    // MARK: - Private: tmuxバイナリ

    /// tmuxバイナリのパスを検索
    private static var tmuxPath: String? {
        WindowDetectorUtils.findBinary("tmux", fallbacks: [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ])
    }

    // MARK: - Private: tmux環境変数

    /// 現在のTMUX環境変数からソケットパスを取得
    private static func currentSocketPath() -> String? {
        guard let tmuxEnv = ProcessInfo.processInfo.environment["TMUX"] else {
            return nil
        }
        return parseSocketPath(from: tmuxEnv)
    }

    /// 現在のtmuxペインIDを取得
    private static func currentPaneId() -> String? {
        ProcessInfo.processInfo.environment["TMUX_PANE"]
    }

    // MARK: - Private: tmuxコマンド実行

    /// tmuxコマンドの基本引数を構築（ソケット指定付き）
    private static func baseArgs() -> [String] {
        if let socket = currentSocketPath() {
            return ["-S", socket]
        }
        return []
    }

    /// tmuxクライアントPIDを取得
    private static func getClientPids() -> [pid_t] {
        guard let tmux = tmuxPath else {
            debug("getClientPids: tmux binary not found")
            return []
        }
        let args = baseArgs() + ["list-clients", "-F", "#{client_pid}"]

        guard let output = WindowDetectorUtils.runCommand(tmux, arguments: args) else {
            return []
        }

        return output.components(separatedBy: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// tmuxペインを復元（ウィンドウ切替 + ペイン選択）
    private static func restoreTmuxPane() {
        guard let tmux = tmuxPath, let paneId = currentPaneId() else {
            debug("restoreTmuxPane: skipped (tmux=\(tmuxPath ?? "nil"), pane=\(currentPaneId() ?? "nil"))")
            return
        }

        debug("restoreTmuxPane: paneId=\(paneId)")

        let base = baseArgs()

        // ペインが所属するウィンドウに切替
        let displayArgs = base + ["display-message", "-t", paneId, "-p", "#{session_name}:#{window_index}"]
        if let target = WindowDetectorUtils.runCommand(tmux, arguments: displayArgs)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !target.isEmpty
        {
            debug("  -> select-window -t \(target)")
            let selectWindowArgs = base + ["select-window", "-t", target]
            _ = WindowDetectorUtils.runCommand(tmux, arguments: selectWindowArgs)
        }

        // ペインを選択
        debug("  -> select-pane -t \(paneId)")
        let selectPaneArgs = base + ["select-pane", "-t", paneId]
        _ = WindowDetectorUtils.runCommand(tmux, arguments: selectPaneArgs)
    }

    // MARK: - Private: ユーティリティ

    /// TERM_PROGRAM名またはバンドルIDからバンドルIDを解決
    private static func resolveBundleId(_ identifier: String) -> String? {
        // まず既知のTERM_PROGRAM名として逆引き
        if let bundleId = BundleIDRegistry.termProgramToBundleId[identifier] {
            return bundleId
        }
        // バンドルIDそのもの（未知アプリの汎用検出結果）
        if identifier.contains("."),
            !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty
        {
            return identifier
        }
        return nil
    }

    /// 指定PIDのバンドルIDを取得
    private static func getBundleId(for pid: pid_t) -> String? {
        NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }?.bundleIdentifier
    }

    // MARK: - Private: デバッグ

    private static var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil
    }

    private static func debug(_ message: String) {
        if debugEnabled {
            fputs("[pyokotify][tmux] \(message)\n", stderr)
        }
    }
}
