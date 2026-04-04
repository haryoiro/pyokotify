import AppKit
import ApplicationServices
import Darwin
import Foundation

// MARK: - CGS プライベートAPI宣言
// macOSの非公開API。ウィンドウを別のSpace（仮想デスクトップ）に移動するために使用。
// 公開APIではSpace間のウィンドウ移動ができないため、これに頼っている。
// 将来のmacOSで動作しなくなる可能性がある。

private typealias CGSConnectionID = UInt32
private typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSMoveWindowsToManagedSpace")
private func CGSMoveWindowsToManagedSpace(_ cid: CGSConnectionID, _ windows: CFArray, _ space: CGSSpaceID)

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ outWindow: UnsafeMutablePointer<CGWindowID>) -> AXError

/// ウィンドウ検出の共通ユーティリティ
public enum WindowDetectorUtils {

    // MARK: - cwd取得（libproc直接呼び出し）

    /// 指定PIDのcwdを取得（proc_pidinfo使用）
    public static func getCwdForPid(_ pid: pid_t) -> String? {
        var vnodeInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnodeInfo, Int32(size))
        guard result == size else {
            return nil
        }

        // pvi_cdir.vip_path から文字列を取得
        let path = withUnsafePointer(to: &vnodeInfo.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { charPtr in
                String(cString: charPtr)
            }
        }

        return path.isEmpty ? nil : path
    }

    /// 親プロセスのcwdを取得
    public static func getParentCwd() -> String? {
        getCwdForPid(getppid())
    }

    // MARK: - プロセス情報取得（sysctl使用）

    /// 指定PIDの親PIDを取得
    public static func getParentPid(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else {
            return 0
        }

        return info.kp_eproc.e_ppid
    }

    /// 指定PIDのTTYデバイス番号を取得
    public static func getTtyDev(of pid: pid_t) -> dev_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else {
            return nil
        }

        let ttyDev = info.kp_eproc.e_tdev
        return ttyDev == -1 ? nil : ttyDev
    }

    /// 指定TTYデバイスを使用しているシェルプロセスのPIDを取得
    public static func findShellPidByTty(_ ttyDev: dev_t) -> pid_t? {
        let shellNames = ["zsh", "bash", "fish", "sh"]

        // 全プロセスを列挙
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0

        // サイズを取得
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return nil }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)

        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return nil }

        for proc in procs {
            if proc.kp_eproc.e_tdev == ttyDev {
                let name = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { charPtr in
                        String(cString: charPtr)
                    }
                }
                if shellNames.contains(name) {
                    return proc.kp_proc.p_pid
                }
            }
        }
        return nil
    }

    // MARK: - TTY検出

    /// 現在のTTYからcwdを取得
    public static func getCwdFromCurrentTty() -> String? {
        let ppid = getppid()

        // 親プロセスのTTYデバイスを取得
        guard let ttyDev = getTtyDev(of: ppid) else {
            return nil
        }

        // 同じTTYを使っているシェルプロセスを探す
        guard let shellPid = findShellPidByTty(ttyDev) else {
            return nil
        }

        // シェルプロセスのcwdを取得
        return getCwdForPid(shellPid)
    }

    /// TTYからウィンドウタイトル（ディレクトリ名）を推測
    public static func detectWindowTitleFromTty() -> String? {
        guard let cwd = getCwdFromCurrentTty() else { return nil }
        return (cwd as NSString).lastPathComponent
    }

    // MARK: - Space移動（CGSプライベートAPI）

    /// AXUIElementからCGWindowIDを取得
    private static func getWindowID(from axWindow: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(axWindow, &windowID)
        return result == .success ? windowID : nil
    }

    /// 指定ウィンドウを現在のSpaceに移動
    /// - Parameter windowID: 移動するウィンドウのID
    public static func moveWindowToCurrentSpace(_ windowID: CGWindowID) {
        let cid = CGSMainConnectionID()
        let currentSpace = CGSGetActiveSpace(cid)
        let windowArray = [windowID] as CFArray
        CGSMoveWindowsToManagedSpace(cid, windowArray, currentSpace)
    }

    /// AXUIElementのウィンドウを現在のSpaceに移動
    /// - Parameter axWindow: 移動するウィンドウのAXUIElement
    /// - Returns: 移動に成功した場合はtrue
    @discardableResult
    public static func moveWindowToCurrentSpace(_ axWindow: AXUIElement) -> Bool {
        guard let windowID = getWindowID(from: axWindow) else {
            return false
        }
        moveWindowToCurrentSpace(windowID)
        return true
    }

    // MARK: - ウィンドウフォーカス

    /// cwdでフルパスマッチ → フォルダ名マッチの順でウィンドウをフォーカス
    ///
    /// 各Detectorで繰り返し現れる「まずcwd全体でマッチ、次にlastPathComponentで再試行」
    /// というパターンを一箇所に集約したもの。
    /// - Returns: どちらかのマッチでフォーカスできた場合はtrue
    @discardableResult
    public static func focusWindowInApp(_ app: NSRunningApplication, matchingCwd cwd: String) -> Bool {
        if focusWindowInApp(app, matchingTitle: cwd) { return true }
        let folderName = (cwd as NSString).lastPathComponent
        guard !folderName.isEmpty else { return false }
        return focusWindowInApp(app, matchingTitle: folderName)
    }

    /// アプリ内でタイトルにマッチするウィンドウをフォーカス
    /// - Returns: マッチしてフォーカスできた場合はtrue
    @discardableResult
    public static func focusWindowInApp(_ app: NSRunningApplication, matchingTitle titlePart: String) -> Bool {
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        let appName = app.localizedName ?? "unknown"
        Log.focus.debug("focusWindowInApp: app=\(appName, privacy: .public), pid=\(pid), titlePart=\(titlePart, privacy: .public)")

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            Log.focus.warning("AXUIElementCopyAttributeValue 失敗: \(result.rawValue) (app=\(appName, privacy: .public))")
            return false
        }

        Log.focus.debug("  -> ウィンドウ数: \(windows.count) (app=\(appName, privacy: .public))")

        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? "(no title)"
            Log.focus.debug("  -> ウィンドウタイトル: \(title, privacy: .public)")

            if title.contains(titlePart) {
                Log.focus.debug("  -> マッチ: \(title, privacy: .public) — フォーカス試行中")

                // ウィンドウを現在のSpaceに移動（通常のSpaceの場合）
                let moved = moveWindowToCurrentSpace(window)
                Log.focus.debug("  -> moveWindowToCurrentSpace: \(moved)")

                // ウィンドウを前面に
                let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                switch raised {
                case .success:
                    Log.focus.debug("  -> AXRaiseAction: success")
                case .attributeUnsupported:
                    // このアプリはkAXRaiseActionを実装していない（Electron系など）
                    // activate()で代替されるため動作上は問題なし
                    Log.focus.debug("  -> AXRaiseAction: attributeUnsupported (スキップ)")
                default:
                    Log.focus.warning("  -> AXRaiseAction: \(raised.rawValue) (\(appName, privacy: .public))")
                }

                // アプリをアクティブ化（全画面Spaceの場合はこれでSpace移動される）
                let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                Log.focus.debug("  -> activate: \(activated)")

                return true
            }
        }

        Log.focus.debug("  -> マッチするウィンドウが見つかりません (titlePart=\(titlePart, privacy: .public))")
        return false
    }

    /// 指定バンドルIDのアプリでタイトルマッチするウィンドウをフォーカス
    @discardableResult
    public static func focusWindowByTitle(_ titlePart: String, bundleIds: [String]) -> Bool {
        for bundleId in bundleIds {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            for app in apps {
                if focusWindowInApp(app, matchingTitle: titlePart) {
                    return true
                }
            }
        }
        return false
    }

    /// 指定バンドルIDのいずれかのアプリにフォーカス
    @discardableResult
    public static func focusAnyApp(bundleIds: [String]) -> Bool {
        for bundleId in bundleIds {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first {
                app.activate(options: [.activateIgnoringOtherApps])
                return true
            }
        }
        return false
    }

    // MARK: - Unixソケット検索（lsof使用）

    /// 指定パスを含むUnixソケットを持つプロセスのPIDを検索
    /// - Parameter socketPathPart: ソケットパスに含まれる文字列（例: "vscode-git-abc123"）
    /// - Returns: マッチしたプロセスのPID、見つからない場合はnil
    public static func findPidWithUnixSocket(containing socketPathPart: String) -> pid_t? {
        let output = runCommand("/usr/sbin/lsof", arguments: ["-U"])
        guard let output = output else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.contains(socketPathPart) {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let pid = Int32(parts[1]) {
                    return pid
                }
            }
        }
        return nil
    }

    // MARK: - プロセス環境変数取得

    /// プロセスのPWD環境変数を取得（ps経由）
    public static func getProcessPwd(pid: pid_t) -> String? {
        let output = runCommand("/bin/ps", arguments: ["eww", "-o", "command=", "-p", "\(pid)"])
        guard let output = output else { return nil }

        // スペースまたは先頭に続くPWD=にマッチ（OLDPWDを除外）
        let pattern = "(?:^|\\s)PWD=([^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output)
        else {
            return nil
        }

        return String(output[range])
    }

    // MARK: - バイナリ検索

    /// PATH環境変数とフォールバックパスからコマンドバイナリを検索
    public static func findBinary(_ name: String, fallbacks: [String] = []) -> String? {
        // PATH から検索
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        // フォールバック
        return fallbacks.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - コマンド実行（PWD取得用に残す）

    /// コマンドを実行して出力を取得
    public static func runCommand(_ path: String, arguments: [String], timeout: TimeInterval = 5.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        // 出力を非同期で収集（パイプバッファ溢れ防止）
        var outputData = Data()
        let readQueue = DispatchQueue(label: "runCommand.read")
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            readQueue.sync {
                outputData.append(data)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()

            // 読み取りハンドラを解除
            pipe.fileHandleForReading.readabilityHandler = nil

            // 残りのデータを読み取り
            let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
            readQueue.sync {
                outputData.append(remainingData)
            }

            return String(data: outputData, encoding: .utf8)
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
    }
}
