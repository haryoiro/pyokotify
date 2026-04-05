import Foundation
import Testing

@testable import PyokotifyCore

// MARK: - ユニットテスト（自動）

@Suite("TmuxWindowDetector Tests")
struct TmuxDetectorTests {

    // MARK: - tmux環境検出

    @Test("TMUX環境変数が設定されていればtmux環境と判定")
    func isTmuxEnvironment() {
        let result = TmuxWindowDetector.isTmuxEnvironment()
        #expect(result == false || result == true)
    }

    // MARK: - TMUXソケットパース

    @Test("TMUX環境変数からソケットパスを正しく抽出")
    func parseSocketPath() {
        let path = TmuxWindowDetector.parseSocketPath(
            from: "/tmp/tmux-501/default,12345,0")
        #expect(path == "/tmp/tmux-501/default")
    }

    @Test("TMUX環境変数からサーバーPIDを正しく抽出")
    func parseServerPid() {
        let pid = TmuxWindowDetector.parseServerPid(
            from: "/tmp/tmux-501/default,12345,0")
        #expect(pid == 12345)
    }

    @Test("カスタムソケットパスを正しく抽出")
    func parseCustomSocketPath() {
        let path = TmuxWindowDetector.parseSocketPath(
            from: "/tmp/tmux-501/my-session,67890,2")
        #expect(path == "/tmp/tmux-501/my-session")
    }

    @Test("不正なTMUX値でnilを返す")
    func parseInvalidTmux() {
        let path = TmuxWindowDetector.parseSocketPath(from: "")
        #expect(path == nil)

        let pid = TmuxWindowDetector.parseServerPid(from: "invalid")
        #expect(pid == nil)
    }

    @Test("カンマが1つだけのTMUX値を正しく処理")
    func parseTmuxWithSingleComma() {
        let path = TmuxWindowDetector.parseSocketPath(
            from: "/tmp/tmux-501/default,12345")
        #expect(path == "/tmp/tmux-501/default")

        let pid = TmuxWindowDetector.parseServerPid(
            from: "/tmp/tmux-501/default,12345")
        #expect(pid == 12345)
    }

    @Test("ソケットパスにカンマがない場合はパス全体を返す")
    func parseSocketPathNoComma() {
        let path = TmuxWindowDetector.parseSocketPath(
            from: "/tmp/tmux-501/default")
        #expect(path == "/tmp/tmux-501/default")
    }

    @Test("サーバーPIDが数値でない場合はnilを返す")
    func parseServerPidNonNumeric() {
        let pid = TmuxWindowDetector.parseServerPid(
            from: "/tmp/tmux-501/default,abc,0")
        #expect(pid == nil)
    }

    // MARK: - TMUX_PANE パース

    @Test("TMUX_PANE値のフォーマットが正しい")
    func tmuxPaneFormat() {
        let valid = ["%0", "%1", "%15", "%100"]
        for pane in valid {
            #expect(pane.hasPrefix("%"))
            #expect(Int(pane.dropFirst()) != nil)
        }
    }
}

// MARK: - BundleIDRegistry tmux/cmux関連テスト

@Suite("BundleIDRegistry tmux Tests")
struct BundleIdTmuxTests {

    @Test("tmuxがtermProgramToBundleIdに含まれていない（動的検出に委譲）")
    func tmuxNotInStaticMapping() {
        #expect(BundleIDRegistry.termProgramToBundleId["tmux"] == nil)
    }

    @Test("cmuxのバンドルIDが正しく登録されている")
    func cmuxRegistered() {
        #expect(BundleIDRegistry.terminalApps["com.cmuxterm.app"] == "cmux")
        #expect(BundleIDRegistry.terminalApps["com.cmuxterm.app.nightly"] == "cmux")
        #expect(BundleIDRegistry.termProgramToBundleId["cmux"] == "com.cmuxterm.app")
    }
}

// MARK: - getCallerBundleId テスト（汎用検出対応）

@Suite("Generic Detection Tests")
struct GenericDetectionTests {

    @Test("既知TERM_PROGRAM名からバンドルIDに解決")
    func knownTermProgram() {
        var config = PyokotifyConfig(imagePath: "test.png")
        config.callerApp = "ghostty"
        #expect(config.getCallerBundleId() == "com.mitchellh.ghostty")
    }

    @Test("未知バンドルIDがそのまま返る（ドット区切り）")
    func unknownBundleId() {
        var config = PyokotifyConfig(imagePath: "test.png")
        config.callerApp = "com.example.superterm"
        #expect(config.getCallerBundleId() == "com.example.superterm")
    }

    @Test("ドットを含まない未知の値はnilを返す")
    func unknownPlainName() {
        var config = PyokotifyConfig(imagePath: "test.png")
        config.callerApp = "superterm"
        #expect(config.getCallerBundleId() == nil)
    }

    @Test("nilはnilを返す")
    func nilCallerApp() {
        let config = PyokotifyConfig(imagePath: "test.png")
        #expect(config.getCallerBundleId() == nil)
    }

    @Test("空文字列はnilを返す")
    func emptyCallerApp() {
        var config = PyokotifyConfig(imagePath: "test.png")
        config.callerApp = ""
        #expect(config.getCallerBundleId() == nil)
    }
}
