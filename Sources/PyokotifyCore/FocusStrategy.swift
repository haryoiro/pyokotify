import Foundation

/// 通知クリック時にどの検出パスを取るかを表す
///
/// GUI操作から切り離された純粋なデータ型。
/// 「どのDetectorを使うか」の判定ロジックだけをテスト可能にする。
public enum FocusStrategy: Equatable {
    /// cmux環境: cmuxアプリにフォーカス + タブ（Surface）復元
    case cmux(cwd: String?)
    /// tmux環境: 実ターミナルにフォーカス + ペイン復元
    case tmux(cwd: String?)
    /// VSCode: 専用ウィンドウ検出
    case vscode(cwd: String?)
    /// IntelliJ/JetBrains: 専用ウィンドウ検出
    case intellij(cwd: String?)
    /// 汎用: cwdベースのウィンドウマッチング
    case generic(bundleId: String?, cwd: String?)
    /// 最終フォールバック: frontmostApplicationに戻す
    case fallback
}

/// 環境情報からフォーカス戦略を決定する（純粋関数）
///
/// `ProcessInfo.processInfo.environment` に依存しないため、
/// 任意の環境変数の組み合わせでテスト可能。
public enum FocusStrategyResolver {

    /// 環境情報からフォーカス戦略を決定
    /// - Parameters:
    ///   - callerApp: ProcessDetectorが検出したアプリ名（TERM_PROGRAM名またはバンドルID）
    ///   - cwd: 作業ディレクトリ
    ///   - env: 環境変数辞書
    /// - Returns: 採用すべきフォーカス戦略
    public static func determine(
        callerApp: String?,
        cwd: String?,
        env: [String: String]
    ) -> FocusStrategy {
        // 1. cmux（タブ復元が必要なため、tmuxより先に判定）
        if env["CMUX_WORKSPACE_ID"] != nil {
            return .cmux(cwd: cwd)
        }

        // 2. tmux
        if env["TMUX"] != nil {
            return .tmux(cwd: cwd)
        }

        // 3. VSCode
        if isVSCodeEnvironment(callerApp: callerApp, env: env) {
            return .vscode(cwd: cwd)
        }

        // 4. IntelliJ/JetBrains
        if isIntelliJEnvironment(callerApp: callerApp, env: env) {
            return .intellij(cwd: cwd)
        }

        // 5. 汎用（callerAppからバンドルIDを解決）
        let bundleId = resolveBundleId(callerApp)
        if bundleId != nil || cwd != nil {
            return .generic(bundleId: bundleId, cwd: cwd)
        }

        // 6. フォールバック
        return .fallback
    }

    // MARK: - Private

    private static func isVSCodeEnvironment(
        callerApp: String?,
        env: [String: String]
    ) -> Bool {
        if let caller = callerApp {
            let lower = caller.lowercased()
            if lower.contains("vscode") { return true }
            return false
        }

        if let termProgram = env["TERM_PROGRAM"] {
            if termProgram.lowercased().contains("vscode") { return true }
            return false
        }

        if env["VSCODE_GIT_IPC_HANDLE"] != nil {
            return true
        }

        return false
    }

    private static func isIntelliJEnvironment(
        callerApp: String?,
        env: [String: String]
    ) -> Bool {
        let jetBrainsNames = [
            "idea", "intellij", "appcode", "clion", "webstorm",
            "pycharm", "phpstorm", "goland", "rubymine", "rider",
            "datagrip", "fleet",
        ]

        if let caller = callerApp?.lowercased() {
            for name in jetBrainsNames {
                if caller.contains(name) { return true }
            }
            return false
        }

        if let bundleId = env["__CFBundleIdentifier"],
            bundleId.contains("jetbrains")
        {
            return true
        }

        if let termEmulator = env["TERMINAL_EMULATOR"],
            termEmulator.contains("JetBrains")
        {
            return true
        }

        if env["__INTELLIJ_COMMAND_HISTFILE__"] != nil {
            return true
        }

        return false
    }

    private static func resolveBundleId(_ callerApp: String?) -> String? {
        guard let caller = callerApp, !caller.isEmpty else { return nil }
        if let bundleId = BundleIDRegistry.termProgramToBundleId[caller] {
            return bundleId
        }
        if caller.contains(".") {
            return caller
        }
        return nil
    }
}
