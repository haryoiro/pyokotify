import Foundation
import Testing

@testable import PokkofyCore

@Suite("Config Tests")
struct ConfigTests {
    @Test("デフォルト値が正しく設定される")
    func defaultValues() {
        let config = PokkofyConfig(imagePath: "/path/to/image.png")

        #expect(config.imagePath == "/path/to/image.png")
        #expect(config.displayDuration == 3.0)
        #expect(config.animationDuration == 0.4)
        #expect(config.peekHeight == 200)
        #expect(config.rightMargin == 50)
        #expect(config.clickable == true)
        #expect(config.randomMode == false)
        #expect(config.randomMinInterval == 30)
        #expect(config.randomMaxInterval == 120)
        #expect(config.randomDirection == false)
        #expect(config.direction == .bottom)
        #expect(config.message == nil)
        #expect(config.callerApp == nil)
        #expect(config.cwd == nil)
    }

    @Test("画像パスのみの引数を正しく解析")
    func parseImagePathOnly() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "/path/to/image.png"])
        let config = try result.get()

        #expect(config.imagePath == "/path/to/image.png")
    }

    @Test("durationオプションを正しく解析")
    func parseDuration() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-d", "5.0"])
        let config = try result.get()

        #expect(config.displayDuration == 5.0)
    }

    @Test("animationオプションを正しく解析")
    func parseAnimation() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "--animation", "0.8"])
        let config = try result.get()

        #expect(config.animationDuration == 0.8)
    }

    @Test("peekオプションを正しく解析")
    func parsePeek() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-p", "300"])
        let config = try result.get()

        #expect(config.peekHeight == 300)
    }

    @Test("marginオプションを正しく解析")
    func parseMargin() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-m", "100"])
        let config = try result.get()

        #expect(config.rightMargin == 100)
    }

    @Test("no-clickオプションを正しく解析")
    func parseNoClick() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "--no-click"])
        let config = try result.get()

        #expect(config.clickable == false)
    }

    @Test("randomオプションを正しく解析")
    func parseRandom() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-r"])
        let config = try result.get()

        #expect(config.randomMode == true)
    }

    @Test("random-directionオプションを正しく解析")
    func parseRandomDirection() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "--random-direction"])
        let config = try result.get()

        #expect(config.randomDirection == true)
    }

    @Test("min/maxオプションを正しく解析")
    func parseMinMax() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "--min", "60", "--max", "300"])
        let config = try result.get()

        #expect(config.randomMinInterval == 60)
        #expect(config.randomMaxInterval == 300)
    }

    @Test("textオプションを正しく解析")
    func parseText() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-t", "Hello!"])
        let config = try result.get()

        #expect(config.message == "Hello!")
    }

    @Test("callerオプションを正しく解析")
    func parseCaller() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "-c", "vscode"])
        let config = try result.get()

        #expect(config.callerApp == "vscode")
    }

    @Test("cwdオプションを正しく解析")
    func parseCwd() throws {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "image.png", "--cwd", "/path/to/project"])
        let config = try result.get()

        #expect(config.cwd == "/path/to/project")
    }

    @Test("複合オプションを正しく解析")
    func parseMultipleOptions() throws {
        let result = PokkofyConfig.parse(arguments: [
            "pokkofy", "image.png",
            "-d", "5",
            "-p", "300",
            "-t", "タスク完了！",
            "-c", "vscode",
            "--cwd", "/path/to/project",
            "-r",
            "--random-direction",
        ])
        let config = try result.get()

        #expect(config.displayDuration == 5.0)
        #expect(config.peekHeight == 300)
        #expect(config.message == "タスク完了！")
        #expect(config.callerApp == "vscode")
        #expect(config.cwd == "/path/to/project")
        #expect(config.randomMode == true)
        #expect(config.randomDirection == true)
    }

    @Test("画像パスがない場合はエラー")
    func missingImagePath() {
        let result = PokkofyConfig.parse(arguments: ["pokkofy"])

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            #expect(error == .missingImagePath)
        }
    }

    @Test("ヘルプオプションでhelpRequestedエラー")
    func helpOption() {
        let result = PokkofyConfig.parse(arguments: ["pokkofy", "-h"])

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            #expect(error == .helpRequested)
        }
    }
}

@Suite("Bundle ID Mapping Tests")
struct BundleIdMappingTests {
    @Test("VSCode の Bundle ID を正しく取得")
    func vscodeMapping() {
        var config = PokkofyConfig(imagePath: "test.png")
        config.callerApp = "vscode"

        #expect(config.getCallerBundleId() == "com.microsoft.VSCode")
    }

    @Test("iTerm の Bundle ID を正しく取得")
    func itermMapping() {
        var config = PokkofyConfig(imagePath: "test.png")
        config.callerApp = "iTerm.app"

        #expect(config.getCallerBundleId() == "com.googlecode.iterm2")
    }

    @Test("Ghostty の Bundle ID を正しく取得")
    func ghosttyMapping() {
        var config = PokkofyConfig(imagePath: "test.png")
        config.callerApp = "ghostty"

        #expect(config.getCallerBundleId() == "com.mitchellh.ghostty")
    }

    @Test("Terminal.app の Bundle ID を正しく取得")
    func terminalMapping() {
        var config = PokkofyConfig(imagePath: "test.png")
        config.callerApp = "Apple_Terminal"

        #expect(config.getCallerBundleId() == "com.apple.Terminal")
    }

    @Test("未知のターミナルは nil を返す")
    func unknownTerminal() {
        var config = PokkofyConfig(imagePath: "test.png")
        config.callerApp = "unknown_terminal"

        #expect(config.getCallerBundleId() == nil)
    }

    @Test("callerApp が nil の場合は nil を返す")
    func nilCallerApp() {
        let config = PokkofyConfig(imagePath: "test.png")

        #expect(config.getCallerBundleId() == nil)
    }
}
