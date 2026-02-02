import AppKit
import ApplicationServices
import Foundation

// MARK: - Pyokotify Controller

/// アプリケーションのメインコントローラー
public class PyokotifyController {
    private let config: PyokotifyConfig
    private var window: PyokotifyWindow?
    private let originalImage: NSImage
    private let fallbackCallerApp: NSRunningApplication?
    private var hideTimer: DispatchWorkItem?
    private var currentDirection: PeekDirection

    public init(config: PyokotifyConfig, image: NSImage, fallbackCallerApp: NSRunningApplication?) {
        self.config = config
        self.originalImage = image
        self.fallbackCallerApp = fallbackCallerApp
        self.currentDirection = config.randomDirection ? .random() : .bottom
    }

    public func run() {
        guard let screen = NSScreen.main else {
            print("エラー: スクリーンが見つかりません")
            NSApp.terminate(nil)
            return
        }

        let screenFrame = screen.visibleFrame
        let displaySize = calculateDisplaySize(screenFrame: screenFrame)
        let initialFrame = getInitialFrame(screenFrame: screenFrame, displaySize: displaySize)

        window = PyokotifyWindow(contentRect: initialFrame, clickable: config.clickable)

        let rotatedImage = getRotatedImage()
        let view = PyokotifyView(image: rotatedImage, message: config.message, direction: currentDirection)
        view.onClick = { [weak self] in self?.handleClick() }

        window?.contentView = view
        window?.makeKeyAndOrderFront(nil)

        animateIn { self.scheduleHide() }
    }
}

// MARK: - Image & Size Calculation

extension PyokotifyController {
    private func getRotatedImage() -> NSImage {
        originalImage.rotated(byDegrees: currentDirection.rotationDegrees)
    }

    private func calculateDisplaySize(screenFrame: NSRect) -> (width: CGFloat, height: CGFloat) {
        let rotatedImage = getRotatedImage()
        let imageSize = rotatedImage.size
        let aspectRatio = imageSize.width / imageSize.height

        let maxHeight = screenFrame.height * 0.8
        var displayHeight = min(config.peekHeight * 2, maxHeight)
        let charWidth = displayHeight * aspectRatio

        var bubbleSize = NSSize.zero
        if let message = config.message, !message.isEmpty {
            let tempBubble = SpeechBubbleView(message: message)
            bubbleSize = tempBubble.intrinsicContentSize
        }

        let padding: CGFloat = 30
        var displayWidth: CGFloat

        if currentDirection == .bottom {
            displayWidth = charWidth + bubbleSize.width + padding
        } else {
            displayWidth = max(charWidth, bubbleSize.width + padding * 2)
            displayHeight += bubbleSize.height + padding
        }

        let maxWidth = screenFrame.width * 0.5
        if displayWidth > maxWidth {
            displayWidth = maxWidth
        }

        return (displayWidth, displayHeight)
    }

    private func getInitialFrame(screenFrame: NSRect, displaySize: (width: CGFloat, height: CGFloat)) -> NSRect {
        let (displayWidth, displayHeight) = displaySize

        switch currentDirection {
        case .bottom:
            let x = screenFrame.maxX - displayWidth - config.rightMargin
            let y = screenFrame.minY - displayHeight
            return NSRect(x: x, y: y, width: displayWidth, height: displayHeight)

        case .left:
            let x = screenFrame.minX - displayWidth
            let y = screenFrame.minY + (screenFrame.height - displayHeight) / 2
            return NSRect(x: x, y: y, width: displayWidth, height: displayHeight)

        case .right:
            let x = screenFrame.maxX
            let y = screenFrame.minY + (screenFrame.height - displayHeight) / 2
            return NSRect(x: x, y: y, width: displayWidth, height: displayHeight)
        }
    }
}

// MARK: - Animation

extension PyokotifyController {
    private func animateIn(completion: @escaping () -> Void) {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let bounceOvershoot: CGFloat = 30

        let (targetFrame, overshootFrame) = getAnimateInFrames(
            screenFrame: screenFrame,
            windowFrame: window.frame,
            overshoot: bounceOvershoot
        )

        // フェーズ1: オーバーシュート
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = config.animationDuration * 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(overshootFrame, display: true)
            },
            completionHandler: {
                // フェーズ2: バウンス
                NSAnimationContext.runAnimationGroup(
                    { context in
                        context.duration = self.config.animationDuration * 0.4
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        context.allowsImplicitAnimation = true
                        window.animator().setFrame(targetFrame, display: true)
                    }, completionHandler: completion)
            })
    }

    private func getAnimateInFrames(
        screenFrame: NSRect,
        windowFrame: NSRect,
        overshoot: CGFloat
    ) -> (target: NSRect, overshoot: NSRect) {
        var targetFrame = windowFrame
        var overshootFrame = windowFrame

        switch currentDirection {
        case .bottom:
            let targetY = screenFrame.minY - windowFrame.height + config.peekHeight
            targetFrame.origin.y = targetY
            overshootFrame.origin.y = targetY + overshoot

        case .left:
            let targetX = screenFrame.minX - windowFrame.width + config.peekHeight
            targetFrame.origin.x = targetX
            overshootFrame.origin.x = targetX + overshoot

        case .right:
            let targetX = screenFrame.maxX - config.peekHeight
            targetFrame.origin.x = targetX
            overshootFrame.origin.x = targetX - overshoot
        }

        return (targetFrame, overshootFrame)
    }

    private func animateOut(completion: @escaping () -> Void) {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let displaySize = calculateDisplaySize(screenFrame: screenFrame)
        let targetFrame = getInitialFrame(screenFrame: screenFrame, displaySize: displaySize)

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = config.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(targetFrame, display: true)
            }, completionHandler: completion)
    }
}

// MARK: - Timer & Random Mode

extension PyokotifyController {
    private func scheduleHide() {
        hideTimer?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.animateOut {
                if self.config.randomMode {
                    self.scheduleNextPyoko()
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
        hideTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.displayDuration, execute: workItem)
    }

    private func scheduleNextPyoko() {
        let interval = TimeInterval.random(in: config.randomMinInterval...config.randomMaxInterval)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.pyoko()
        }
    }

    private func pyoko() {
        guard let window = window, let screen = NSScreen.main else { return }

        if config.randomDirection {
            currentDirection = .random()
        }

        let screenFrame = screen.visibleFrame
        let displaySize = calculateDisplaySize(screenFrame: screenFrame)

        let rotatedImage = getRotatedImage()
        let view = PyokotifyView(image: rotatedImage, message: config.message, direction: currentDirection)
        view.onClick = { [weak self] in self?.handleClick() }
        window.contentView = view

        let resetFrame = getInitialFrame(screenFrame: screenFrame, displaySize: displaySize)
        window.setFrame(resetFrame, display: false)

        animateIn { self.scheduleHide() }
    }
}

// MARK: - Click Handling & App Focus

extension PyokotifyController {
    private func handleClick() {
        hideTimer?.cancel()

        // VSCode専用の高精度ウィンドウ検出を試行
        if isVSCodeEnvironment() && VSCodeWindowDetector.focusCurrentWindow(cwd: config.cwd) {
            // 成功
        } else if isIntelliJEnvironment() && IntelliJWindowDetector.focusCurrentWindow(cwd: config.cwd) {
            // 成功
        } else if !focusWindowByCwd() {
            // フォールバック: アプリにフォーカス
            if let app = getCallerApp() {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }

        animateOut { NSApp.terminate(nil) }
    }

    /// VSCode環境かどうかを判定
    private func isVSCodeEnvironment() -> Bool {
        // TERM_PROGRAM または callerApp が VSCode を示している
        if let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"],
            termProgram.lowercased().contains("vscode")
        {
            return true
        }
        if let caller = config.callerApp,
            caller.lowercased().contains("vscode")
        {
            return true
        }
        // VSCODE_GIT_IPC_HANDLE が設定されている
        if ProcessInfo.processInfo.environment["VSCODE_GIT_IPC_HANDLE"] != nil {
            return true
        }
        return false
    }

    /// IntelliJ/JetBrains IDE環境かどうかを判定
    private func isIntelliJEnvironment() -> Bool {
        // JetBrains IDE名のリスト
        let jetBrainsNames = [
            "idea", "intellij", "appcode", "clion", "webstorm",
            "pycharm", "phpstorm", "goland", "rubymine", "rider",
            "datagrip", "fleet",
        ]

        // __CFBundleIdentifier が JetBrains IDE を示している（最も信頼性が高い）
        if let bundleId = ProcessInfo.processInfo.environment["__CFBundleIdentifier"],
            bundleId.contains("jetbrains")
        {
            return true
        }

        // TERMINAL_EMULATOR が JetBrains-JediTerm を示している
        if let termEmulator = ProcessInfo.processInfo.environment["TERMINAL_EMULATOR"],
            termEmulator.contains("JetBrains")
        {
            return true
        }

        // callerApp が JetBrains IDE を示している
        if let caller = config.callerApp?.lowercased() {
            for name in jetBrainsNames {
                if caller.contains(name) {
                    return true
                }
            }
        }

        // __INTELLIJ_COMMAND_HISTFILE__ が設定されている（IntelliJターミナル固有）
        if ProcessInfo.processInfo.environment["__INTELLIJ_COMMAND_HISTFILE__"] != nil {
            return true
        }

        return false
    }

    private func getCallerApp() -> NSRunningApplication? {
        if let bundleId = config.getCallerBundleId() {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first {
                return app
            }
        }
        return fallbackCallerApp
    }

    private func focusWindowByCwd() -> Bool {
        guard let cwd = config.cwd, let bundleId = config.getCallerBundleId() else {
            return false
        }

        let folderName = (cwd as NSString).lastPathComponent
        guard !folderName.isEmpty else { return false }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard let app = apps.first else { return false }

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

            if let title = titleRef as? String, title.contains(folderName) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                app.activate(options: [.activateIgnoringOtherApps])
                return true
            }
        }

        return false
    }
}

// MARK: - App Delegate

public class PyokotifyAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PyokotifyController?
    private var callerApp: NSRunningApplication?
    private var soundPlayer: SoundPlayer?

    override public init() {
        self.callerApp = NSWorkspace.shared.frontmostApplication
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. コマンドライン引数を解析
        guard var config = PyokotifyConfig.fromArguments() else {
            NSApp.terminate(nil)
            return
        }

        // 2. Hooks モード処理（Claude Code / GitHub Copilot CLI 自動検出）
        if config.hooksMode {
            config = processHooksMode(config: config)
        }

        // 3. 親プロセス自動検出（callerAppが未指定の場合）
        if config.callerApp == nil && config.autoDetectCaller {
            config.callerApp = ProcessDetector.detectTerminalApp()
        }

        // 4. テンプレート変数展開
        if let message = config.message, message.contains("$") {
            let gitInfo = config.cwd.map { GitInfo(cwd: $0) }
            let context = TemplateContext(
                cwd: config.cwd,
                branch: gitInfo?.branch,
                eventName: nil,
                toolName: nil
            )
            config.message = TemplateExpander.expand(message, with: context)
        }

        // 5. 画像読み込み
        let imagePath = (config.imagePath as NSString).expandingTildeInPath
        guard let image = NSImage(contentsOfFile: imagePath) else {
            print("エラー: 画像を読み込めません: \(config.imagePath)")
            NSApp.terminate(nil)
            return
        }

        // 6. サウンド再生
        if let soundPath = config.soundPath {
            soundPlayer = SoundPlayer()
            soundPlayer?.play(path: soundPath)
        }

        // 7. コントローラー起動
        controller = PyokotifyController(config: config, image: image, fallbackCallerApp: callerApp)
        controller?.run()
    }

    /// Hooks モードの処理（Claude Code / GitHub Copilot CLI 自動検出）
    private func processHooksMode(config: PyokotifyConfig) -> PyokotifyConfig {
        var config = config

        // 標準入力からJSONを読み取り（自動検出）
        guard let hooksContext = HooksContext.readFromStdin() else {
            return config
        }

        // cwdを設定（明示的指定がない場合のみ）
        if config.cwd == nil {
            config.cwd = hooksContext.cwd
        }

        // Git情報を取得
        let gitInfo = config.cwd.map { GitInfo(cwd: $0) }

        // メッセージを設定（明示的指定がない場合のみ）
        if config.message == nil {
            config.message = hooksContext.generateDefaultMessage(
                projectName: gitInfo?.repositoryName,
                branch: gitInfo?.branch
            )
        } else if let message = config.message, message.contains("$") {
            // テンプレート変数展開
            let eventName: String
            switch hooksContext.source {
            case .claudeCode:
                eventName = hooksContext.claudeContext?.event.rawValue ?? hooksContext.event.rawValue
            case .copilot:
                eventName = hooksContext.event.rawValue
            }

            let context = TemplateContext(
                cwd: config.cwd,
                branch: gitInfo?.branch,
                eventName: eventName,
                toolName: hooksContext.toolName
            )
            config.message = TemplateExpander.expand(message, with: context)
        }

        return config
    }
}
