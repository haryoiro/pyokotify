import AppKit
import Foundation

/// cmux環境でのタブ（Surface）復元
///
/// cmuxはソケットAPI（JSON-RPC）を持ち、CMUX_SURFACE_IDで
/// 起動元のタブを特定してフォーカスを戻せる。
///
/// 検出フロー:
/// 1. CMUX_WORKSPACE_ID でcmux環境を判定
/// 2. cmuxアプリにフォーカス
/// 3. CMUX_SOCKET_PATH + CMUX_SURFACE_ID でソケットAPI経由でタブ復元
public enum CmuxWindowDetector {

    // MARK: - cmux環境検出

    public static func isCmuxEnvironment() -> Bool {
        ProcessInfo.processInfo.environment["CMUX_WORKSPACE_ID"] != nil
    }

    // MARK: - フォーカス復元

    /// cmuxアプリにフォーカスし、元のタブ（Surface）を復元
    public static func focusCurrentWindow(cwd: String?) -> Bool {
        Log.focus.debug("focusCurrentWindow(cmux): cwd=\(cwd ?? "nil", privacy: .public)")

        // cmuxアプリにフォーカス
        let bundleIds = ["com.cmuxterm.app", "com.cmuxterm.app.nightly"]
        var focused = false

        for bundleId in bundleIds {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first {
                // cwdでウィンドウマッチを試みる（フルパス → フォルダ名の順）
                if let cwd = cwd,
                    WindowDetectorUtils.focusWindowInApp(app, matchingCwd: cwd)
                {
                    focused = true
                    break
                }
                app.activate(options: [.activateIgnoringOtherApps])
                focused = true
                break
            }
        }

        guard focused else {
            Log.focus.warning("focusCurrentWindow(cmux): cmuxアプリが見つかりません")
            return false
        }

        // タブ（Surface）を復元
        restoreSurface()
        return true
    }

    // MARK: - Private: タブ復元

    /// CMUX_SURFACE_IDを使ってソケットAPI経由でタブにフォーカス
    private static func restoreSurface() {
        guard let surfaceId = ProcessInfo.processInfo.environment["CMUX_SURFACE_ID"] else {
            Log.focus.debug("restoreSurface: CMUX_SURFACE_ID 未設定")
            return
        }

        let socketPath = resolveSocketPath()
        guard !socketPath.isEmpty else {
            Log.focus.warning("restoreSurface: ソケットパスが見つかりません")
            return
        }

        Log.focus.debug("restoreSurface: surfaceId=\(surfaceId, privacy: .public), socket=\(socketPath, privacy: .public)")

        // JSON-RPC で surface.focus を送信
        let request = "{\"id\":\"pyokotify\",\"method\":\"surface.focus\",\"params\":{\"surface_id\":\"\(surfaceId)\"}}\n"

        sendSocketMessage(socketPath: socketPath, message: request)
    }

    /// ソケットパスを解決
    private static func resolveSocketPath() -> String {
        // 環境変数を優先
        if let path = ProcessInfo.processInfo.environment["CMUX_SOCKET_PATH"] {
            return path
        }
        // デフォルトパス
        let defaults = [
            "/tmp/cmux.sock",
            "/tmp/cmux-nightly.sock",
            "/tmp/cmux-debug.sock",
        ]
        return defaults.first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }

    /// Unixソケットにメッセージを送信
    private static func sendSocketMessage(socketPath: String, message: String) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Log.focus.error("sendSocketMessage: ソケット作成失敗 (errno=\(errno))")
            return
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
            let bound = pathPtr.withMemoryRebound(to: CChar.self, capacity: 104) { ptr in
                socketPath.withCString { cstr in
                    strncpy(ptr, cstr, 104)
                }
            }
            _ = bound
        }

        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            Log.focus.error("sendSocketMessage: ソケット接続失敗 \(socketPath, privacy: .public) (errno=\(errno))")
            return
        }

        message.withCString { cstr in
            _ = send(fd, cstr, strlen(cstr), 0)
        }

        Log.focus.debug("sendSocketMessage: surface.focus 送信完了")
    }

}
