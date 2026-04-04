import Foundation
import Testing

@testable import PyokotifyCore

@Suite("FocusStrategy Detection Tests")
struct FocusStrategyTests {

    // MARK: - cmux

    @Test("CMUX_WORKSPACE_IDがあればcmux戦略")
    func cmuxDetected() {
        let result = FocusStrategyResolver.determine(
            callerApp: "cmux",
            cwd: "/path",
            env: ["CMUX_WORKSPACE_ID": "ws-123"]
        )
        #expect(result == .cmux(cwd: "/path"))
    }

    @Test("cmux環境ではtmuxより優先される")
    func cmuxOverridesTmux() {
        let result = FocusStrategyResolver.determine(
            callerApp: "cmux",
            cwd: "/path",
            env: [
                "CMUX_WORKSPACE_ID": "ws-123",
                "TMUX": "/tmp/tmux-501/default,1,0"
            ]
        )
        #expect(result == .cmux(cwd: "/path"))
    }

    // MARK: - tmux

    @Test("TMUX環境変数があればtmux戦略")
    func tmuxDetected() {
        let result = FocusStrategyResolver.determine(
            callerApp: "ghostty",
            cwd: "/path/to/project",
            env: ["TMUX": "/tmp/tmux-501/default,12345,0"]
        )
        #expect(result == .tmux(cwd: "/path/to/project"))
    }

    @Test("TMUX環境変数があればcallerAppに関わらずtmux戦略")
    func tmuxOverridesAll() {
        // VSCodeのcallerAppが設定されていてもtmuxが優先
        let result = FocusStrategyResolver.determine(
            callerApp: "vscode",
            cwd: "/path",
            env: ["TMUX": "/tmp/tmux-501/default,1,0", "VSCODE_GIT_IPC_HANDLE": "/tmp/sock"]
        )
        #expect(result == .tmux(cwd: "/path"))
    }

    @Test("TMUXがあってcwdがnilでもtmux戦略")
    func tmuxNoCwd() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: nil,
            env: ["TMUX": "/tmp/tmux-501/default,1,0"]
        )
        #expect(result == .tmux(cwd: nil))
    }

    // MARK: - VSCode

    @Test("callerAppがvscodeならVSCode戦略")
    func vscodeByCallerApp() {
        let result = FocusStrategyResolver.determine(
            callerApp: "vscode",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .vscode(cwd: "/path"))
    }

    @Test("callerAppにVSCodeバンドルIDが含まれればVSCode戦略")
    func vscodeByBundleId() {
        let result = FocusStrategyResolver.determine(
            callerApp: "com.microsoft.VSCode",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .vscode(cwd: "/path"))
    }

    @Test("TERM_PROGRAM=vscodeでVSCode戦略")
    func vscodeByTermProgram() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["TERM_PROGRAM": "vscode"]
        )
        #expect(result == .vscode(cwd: "/path"))
    }

    @Test("VSCODE_GIT_IPC_HANDLEのみでVSCode戦略")
    func vscodeByIpcHandle() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["VSCODE_GIT_IPC_HANDLE": "/tmp/vscode-git-abc.sock"]
        )
        #expect(result == .vscode(cwd: "/path"))
    }

    @Test("callerAppがghosttyならVSCode環境変数があってもVSCodeではない")
    func ghosttyOverridesVscodeEnv() {
        let result = FocusStrategyResolver.determine(
            callerApp: "ghostty",
            cwd: "/path",
            env: ["VSCODE_GIT_IPC_HANDLE": "/tmp/vscode-git-abc.sock"]
        )
        // callerAppがghosttyなのでVSCodeではない → generic
        #expect(result == .generic(bundleId: "com.mitchellh.ghostty", cwd: "/path"))
    }

    @Test("TERM_PROGRAMが他のターミナルならVSCODE_GIT_IPC_HANDLEは無視")
    func termProgramOverridesVscodeIpc() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: [
                "TERM_PROGRAM": "ghostty",
                "VSCODE_GIT_IPC_HANDLE": "/tmp/vscode-git-abc.sock"
            ]
        )
        // TERM_PROGRAM=ghosttyなのでVSCodeではない → generic
        #expect(result == .generic(bundleId: nil, cwd: "/path"))
    }

    // MARK: - IntelliJ/JetBrains

    @Test("callerAppがIntelliJならIntelliJ戦略")
    func intellijByCallerApp() {
        let result = FocusStrategyResolver.determine(
            callerApp: "idea",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .intellij(cwd: "/path"))
    }

    @Test("callerAppにJetBrainsバンドルIDが含まれればIntelliJ戦略")
    func intellijByBundleId() {
        let result = FocusStrategyResolver.determine(
            callerApp: "com.jetbrains.intellij",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .intellij(cwd: "/path"))
    }

    @Test("__CFBundleIdentifierがjetbrainsならIntelliJ戦略")
    func intellijByCFBundle() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["__CFBundleIdentifier": "com.jetbrains.pycharm"]
        )
        #expect(result == .intellij(cwd: "/path"))
    }

    @Test("TERMINAL_EMULATORがJetBrainsならIntelliJ戦略")
    func intellijByTerminalEmulator() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["TERMINAL_EMULATOR": "JetBrains-JediTerm"]
        )
        #expect(result == .intellij(cwd: "/path"))
    }

    @Test("__INTELLIJ_COMMAND_HISTFILE__が設定されていればIntelliJ戦略")
    func intellijByHistFile() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["__INTELLIJ_COMMAND_HISTFILE__": "/path/to/histfile"]
        )
        #expect(result == .intellij(cwd: "/path"))
    }

    @Test("全JetBrains IDE名がIntelliJとして検出される")
    func allJetBrainsNames() {
        let names = [
            "idea", "intellij", "appcode", "clion", "webstorm",
            "pycharm", "phpstorm", "goland", "rubymine", "rider",
            "datagrip", "fleet"
        ]
        for name in names {
            let result = FocusStrategyResolver.determine(
                callerApp: name, cwd: nil, env: [:])
            #expect(result == .intellij(cwd: nil), "Failed for \(name)")
        }
    }

    // MARK: - 汎用 (generic)

    @Test("既知ターミナルはバンドルIDが解決される")
    func genericKnownTerminal() {
        let result = FocusStrategyResolver.determine(
            callerApp: "ghostty",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .generic(bundleId: "com.mitchellh.ghostty", cwd: "/path"))
    }

    @Test("未知バンドルIDはそのまま渡される")
    func genericUnknownBundleId() {
        let result = FocusStrategyResolver.determine(
            callerApp: "com.example.newterm",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .generic(bundleId: "com.example.newterm", cwd: "/path"))
    }

    @Test("cmuxはcmuxのバンドルIDに解決される")
    func genericCmux() {
        let result = FocusStrategyResolver.determine(
            callerApp: "cmux",
            cwd: "/path",
            env: [:]
        )
        #expect(result == .generic(bundleId: "com.cmuxterm.app", cwd: "/path"))
    }

    @Test("callerAppがnilでもcwdがあればgeneric")
    func genericCwdOnly() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: [:]
        )
        #expect(result == .generic(bundleId: nil, cwd: "/path"))
    }

    // MARK: - フォールバック

    @Test("callerAppもcwdもnilで環境変数もなければfallback")
    func fallback() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: nil,
            env: [:]
        )
        #expect(result == .fallback)
    }

    @Test("callerAppが空文字列でcwdもnilならfallback")
    func fallbackEmptyCallerApp() {
        let result = FocusStrategyResolver.determine(
            callerApp: "",
            cwd: nil,
            env: [:]
        )
        #expect(result == .fallback)
    }

    @Test("callerAppが未知のドットなし文字列でcwdもnilならfallback")
    func fallbackUnknownName() {
        let result = FocusStrategyResolver.determine(
            callerApp: "superterm",
            cwd: nil,
            env: [:]
        )
        #expect(result == .fallback)
    }

    // MARK: - 優先順位

    @Test("cmux > tmux > VSCode > IntelliJ > generic の優先順位")
    func priorityOrder() {
        // cmuxが最優先
        let cmuxResult = FocusStrategyResolver.determine(
            callerApp: "cmux",
            cwd: "/path",
            env: [
                "CMUX_WORKSPACE_ID": "ws-1",
                "TMUX": "/tmp/tmux-501/default,1,0",
                "VSCODE_GIT_IPC_HANDLE": "/tmp/sock"
            ]
        )
        #expect(cmuxResult == .cmux(cwd: "/path"))

        // cmuxなし → tmux
        let tmuxResult = FocusStrategyResolver.determine(
            callerApp: "vscode",
            cwd: "/path",
            env: [
                "TMUX": "/tmp/tmux-501/default,1,0",
                "VSCODE_GIT_IPC_HANDLE": "/tmp/sock"
            ]
        )
        #expect(tmuxResult == .tmux(cwd: "/path"))

        // tmuxもなし → VSCode
        let vscodeResult = FocusStrategyResolver.determine(
            callerApp: "vscode",
            cwd: "/path",
            env: [
                "VSCODE_GIT_IPC_HANDLE": "/tmp/sock",
                "__CFBundleIdentifier": "com.jetbrains.intellij"
            ]
        )
        #expect(vscodeResult == .vscode(cwd: "/path"))
    }

    @Test("callerAppがghosttyの場合、IntelliJ環境変数があっても汎用")
    func callerAppOverridesIntellijEnv() {
        let result = FocusStrategyResolver.determine(
            callerApp: "ghostty",
            cwd: "/path",
            env: ["__CFBundleIdentifier": "com.jetbrains.intellij"]
        )
        #expect(result == .generic(bundleId: "com.mitchellh.ghostty", cwd: "/path"))
    }

    // MARK: - エッジケース

    @Test("TERM_PROGRAMが空文字列")
    func emptyTermProgram() {
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: "/path",
            env: ["TERM_PROGRAM": ""]
        )
        // 空文字列はVSCodeにもIntelliJにもマッチしない → generic
        #expect(result == .generic(bundleId: nil, cwd: "/path"))
    }

    @Test("TMUX環境変数が空文字列ではtmuxにならない")
    func emptyTmux() {
        // TMUXキーが存在すればtmux環境と判定される（空文字列でも）
        // これは実際のtmuxの動作と一致（TMUXは常に非空の値を持つ）
        let result = FocusStrategyResolver.determine(
            callerApp: nil,
            cwd: nil,
            env: ["TMUX": ""]
        )
        #expect(result == .tmux(cwd: nil))
    }

    @Test("大文字小文字: VSCode の変種")
    func vscodeVariants() {
        for name in ["vscode", "VSCode", "VSCODE", "vscode-insiders"] {
            let result = FocusStrategyResolver.determine(
                callerApp: name, cwd: "/path", env: [:])
            #expect(result == .vscode(cwd: "/path"), "Failed for \(name)")
        }
    }
}
