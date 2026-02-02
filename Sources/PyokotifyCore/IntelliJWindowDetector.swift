import AppKit
import ApplicationServices
import Foundation

/// IntelliJ/JetBrains IDEウィンドウを特定するためのユーティリティ
public enum IntelliJWindowDetector {

    /// JetBrains製品のバンドルID一覧
    private static var bundleIds: [String] { BundleIDRegistry.jetBrainsBundleIds }

    /// IntelliJ環境からウィンドウを特定してフォーカス
    /// - Returns: フォーカスに成功した場合はtrue
    public static func focusCurrentWindow() -> Bool {
        // 方法1: __CFBundleIdentifier + cwdからプロジェクトを特定（高精度）
        if let bundleId = ProcessInfo.processInfo.environment["__CFBundleIdentifier"],
            bundleIds.contains(bundleId)
        {
            if let cwd = WindowDetectorUtils.getParentCwd() {
                let projectName = (cwd as NSString).lastPathComponent
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

        // 方法2: cwdからプロジェクトを特定（全IDE検索）
        if let cwd = WindowDetectorUtils.getParentCwd() {
            let projectName = (cwd as NSString).lastPathComponent
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

        // 方法4: フォールバック - JetBrains IDEアプリにフォーカス
        return WindowDetectorUtils.focusAnyApp(bundleIds: bundleIds)
    }
}
