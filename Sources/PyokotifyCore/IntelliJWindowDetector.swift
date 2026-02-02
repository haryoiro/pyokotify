import AppKit
import ApplicationServices
import Foundation

/// IntelliJ/JetBrains IDEウィンドウを特定するためのユーティリティ
public enum IntelliJWindowDetector {

    /// JetBrains製品のバンドルID一覧
    private static var bundleIds: [String] { BundleIDRegistry.jetBrainsBundleIds }

    /// IntelliJ環境からウィンドウを特定してフォーカス
    /// - Parameter cwd: 作業ディレクトリ（指定された場合はこれを優先してウィンドウを特定）
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow(cwd: String? = nil) -> Bool {
        // 方法1: 明示的に指定されたcwdからプロジェクト名でマッチング（最も確実）
        if let cwd = cwd {
            let projectName = (cwd as NSString).lastPathComponent
            if !projectName.isEmpty {
                if WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                    return true
                }
            }
        }

        // 方法2: __CFBundleIdentifier + 親プロセスのcwdからプロジェクトを特定
        if let bundleId = ProcessInfo.processInfo.environment["__CFBundleIdentifier"],
            bundleIds.contains(bundleId)
        {
            if let parentCwd = WindowDetectorUtils.getParentCwd() {
                let projectName = (parentCwd as NSString).lastPathComponent
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                for app in apps {
                    if WindowDetectorUtils.focusWindowInApp(app, matchingTitle: projectName) {
                        return true
                    }
                }
            }
            // バンドルIDが分かっているのでそのアプリにフォーカス
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first {
                app.activate(options: [.activateIgnoringOtherApps])
                return true
            }
        }

        // 方法3: 親プロセスのcwdからプロジェクトを特定（全IDE検索）
        if let parentCwd = WindowDetectorUtils.getParentCwd() {
            let projectName = (parentCwd as NSString).lastPathComponent
            if !projectName.isEmpty {
                if WindowDetectorUtils.focusWindowByTitle(projectName, bundleIds: bundleIds) {
                    return true
                }
            }
        }

        // 方法4: TTYから特定
        if let windowTitle = WindowDetectorUtils.detectWindowTitleFromTty() {
            if WindowDetectorUtils.focusWindowByTitle(windowTitle, bundleIds: bundleIds) {
                return true
            }
        }

        // 方法5: フォールバック - JetBrains IDEアプリにフォーカス
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
    }
}
