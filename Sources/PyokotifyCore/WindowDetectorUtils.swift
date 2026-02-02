import AppKit
import ApplicationServices
import Darwin
import Foundation

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

    // MARK: - ウィンドウフォーカス

    /// アプリ内でタイトルにマッチするウィンドウをフォーカス
    /// - Returns: マッチしてフォーカスできた場合はtrue
    @discardableResult
    public static func focusWindowInApp(_ app: NSRunningApplication, matchingTitle titlePart: String) -> Bool {
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return false
        }

        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

            if let title = titleRef as? String, title.contains(titlePart) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                app.activate(options: [.activateIgnoringOtherApps])
                return true
            }
        }

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

    // MARK: - レガシー（VSCode固有処理用）

    /// コマンドを実行して出力を取得（VSCodeのIPC Handle検出用に残す）
    public static func runCommand(_ path: String, arguments: [String], timeout: TimeInterval = 2.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }

            if process.isRunning {
                process.terminate()
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
