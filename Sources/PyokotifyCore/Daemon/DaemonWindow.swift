import AppKit
import Foundation

/// 吹き出しのフォーカス情報
public struct BubbleFocusInfo {
    public let cwd: String?
    public let callerApp: String?

    public init(cwd: String?, callerApp: String?) {
        self.cwd = cwd
        self.callerApp = callerApp
    }

    private static var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil
    }

    private func debug(_ message: String) {
        if Self.debugEnabled {
            fputs("[BubbleFocusInfo] \(message)\n", stderr)
        }
    }

    /// フォーカスを実行
    public func focus() {
        debug("focus() called: cwd=\(cwd ?? "nil"), callerApp=\(callerApp ?? "nil")")

        guard let cwd = cwd else {
            debug("focus() aborted: cwd is nil")
            return
        }

        // bundleIdを解決（複数候補を試す）
        var bundleIds: [String] = []

        if let callerApp = callerApp {
            // 直接マッチ
            if let bundleId = BundleIDRegistry.termProgramToBundleId[callerApp] {
                bundleIds.append(bundleId)
            }
            // 大文字小文字を無視してマッチ
            let lowerCaller = callerApp.lowercased()
            for (key, value) in BundleIDRegistry.termProgramToBundleId {
                if key.lowercased() == lowerCaller && !bundleIds.contains(value) {
                    bundleIds.append(value)
                }
            }
        }

        // bundleIdが見つからない場合、全ターミナルアプリを対象にする
        if bundleIds.isEmpty {
            debug("No bundleId found for callerApp, trying all terminal apps")
            bundleIds = Array(BundleIDRegistry.allTerminalBundleIds)
        }

        debug("Trying bundleIds: \(bundleIds)")

        // フルパスでマッチを試みる
        if WindowDetectorUtils.focusWindowByTitle(cwd, bundleIds: bundleIds) {
            debug("focus() success with full path")
            return
        }

        // フォールバック: フォルダ名でマッチ
        let dirName = (cwd as NSString).lastPathComponent
        debug("Trying with directory name: \(dirName)")
        if WindowDetectorUtils.focusWindowByTitle(dirName, bundleIds: bundleIds) {
            debug("focus() success with directory name")
            return
        }

        debug("focus() failed: no matching window found")
    }
}

/// 吹き出し情報
private struct BubbleInfo {
    let window: NSWindow
    let height: CGFloat
    let focusInfo: BubbleFocusInfo?
    var timer: DispatchWorkItem?
}

/// デーモンモードの常駐ウィンドウ
public class DaemonWindow: NSWindow {
    private let config: DaemonConfig
    private var characterView: DaemonCharacterView?
    private var bubbles: [BubbleInfo] = []
    private let bubbleSpacing: CGFloat = 8
    private let maxBubbles = 50  // ほぼ無制限

    public var onClick: (() -> Void)?

    public init(contentRect: NSRect, config: DaemonConfig) {
        self.config = config

        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupCharacterView()
    }

    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false
    }

    private func setupCharacterView() {
        let imagePath = (config.imagePath as NSString).expandingTildeInPath
        guard let image = NSImage(contentsOfFile: imagePath) else {
            fputs("Error: Cannot load image: \(config.imagePath)\n", stderr)
            return
        }

        characterView = DaemonCharacterView(image: image)
        characterView?.onClick = { [weak self] in
            self?.onClick?()
        }
        contentView = characterView
    }

    /// 最後の吹き出しのフォーカスを実行
    public func focusLastBubble() {
        bubbles.last?.focusInfo?.focus()
    }

    /// 吹き出しを表示（スタック形式）
    public func showBubble(
        message: String,
        level: NotificationLevel,
        duration: TimeInterval,
        focusInfo: BubbleFocusInfo? = nil
    ) {
        debug("showBubble called: message=\(message), level=\(level), duration=\(duration)")

        // 古い吹き出しが多すぎる場合は最古を削除
        while bubbles.count >= maxBubbles {
            removeBubble(at: 0)
        }

        // 吹き出しウィンドウを作成
        let bubbleView = DaemonBubbleView(message: message, level: level)
        bubbleView.onClick = { [weak self, focusInfo] in
            focusInfo?.focus()
            // クリックしたら消える
            if let bubble = self?.bubbles.first(where: { ($0.window.contentView as? DaemonBubbleView) === bubbleView })?.window {
                self?.removeBubbleWindow(bubble)
            }
        }
        let bubbleSize = bubbleView.intrinsicContentSize
        debug("bubbleSize: \(bubbleSize)")

        // 既存の吹き出しを上に押し上げる
        pushUpBubbles(by: bubbleSize.height + bubbleSpacing)

        // 新しい吹き出しの位置（キャラクターの左横、一番下）
        let charFrame = frame
        let bubbleX = charFrame.minX - bubbleSize.width - 10
        let bubbleY = charFrame.midY - bubbleSize.height / 2

        let bubbleFrame = NSRect(
            x: bubbleX,
            y: bubbleY,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        debug("bubbleFrame: \(bubbleFrame)")

        let bubble = NSWindow(
            contentRect: bubbleFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        bubble.backgroundColor = .clear
        bubble.isOpaque = false
        bubble.hasShadow = true
        bubble.level = .floating
        bubble.collectionBehavior = [.canJoinAllSpaces, .stationary]
        bubble.contentView = bubbleView
        bubble.orderFrontRegardless()

        // 配列に追加（タイマーなし、クリックでのみ消える）
        let info = BubbleInfo(window: bubble, height: bubbleSize.height, focusInfo: focusInfo, timer: nil)
        bubbles.append(info)

        debug("bubble window shown, total bubbles: \(bubbles.count)")
    }

    /// 既存の吹き出しを上に押し上げる
    private func pushUpBubbles(by offset: CGFloat) {
        for info in bubbles {
            var newFrame = info.window.frame
            newFrame.origin.y += offset
            info.window.setFrame(newFrame, display: true, animate: true)
        }
    }

    /// インデックスで吹き出しを削除
    private func removeBubble(at index: Int) {
        guard index < bubbles.count else { return }
        let info = bubbles[index]
        info.timer?.cancel()
        info.window.orderOut(nil)
        bubbles.remove(at: index)
    }

    /// ウィンドウで吹き出しを削除（右にスライドして消える）
    private func removeBubbleWindow(_ window: NSWindow) {
        guard bubbles.firstIndex(where: { $0.window === window }) != nil else { return }

        // 右にスライドするアニメーション
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            var newFrame = window.frame
            newFrame.origin.x += newFrame.width + 20  // 右に移動
            window.animator().setFrame(newFrame, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            window.orderOut(nil)

            // 配列から削除（下に詰めない）
            if let idx = self.bubbles.firstIndex(where: { $0.window === window }) {
                self.bubbles.remove(at: idx)
            }
            self.debug("bubble removed, remaining: \(self.bubbles.count)")
        })
    }

    private func debug(_ message: String) {
        if ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil {
            fputs("[DaemonWindow] \(message)\n", stderr)
        }
    }
}

/// キャラクター表示用ビュー
class DaemonCharacterView: NSView {
    private let imageView: NSImageView

    var onClick: (() -> Void)?

    init(image: NSImage) {
        imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown

        super.init(frame: .zero)

        wantsLayer = true
        imageView.wantsLayer = true

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    /// バウンスアニメーション
    func bounce() {
        guard let layer = imageView.layer else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, -10, 0, -5, 0]
        animation.keyTimes = [0, 0.2, 0.4, 0.6, 0.8]
        animation.duration = 0.4
        layer.add(animation, forKey: "bounce")
    }
}

/// 吹き出しビュー
class DaemonBubbleView: NSView {
    private let message: String
    private let level: NotificationLevel
    private let padding: CGFloat = 12
    private let cornerRadius: CGFloat = 10
    private let tailWidth: CGFloat = 8

    var onClick: (() -> Void)?

    init(message: String, level: NotificationLevel) {
        self.message = message
        self.level = level
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override var intrinsicContentSize: NSSize {
        let textSize = calculateTextSize()
        return NSSize(
            width: textSize.width + padding * 2 + tailWidth,
            height: textSize.height + padding * 2
        )
    }

    private func calculateTextSize() -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        // 幅制限をほぼなくす（画面幅の80%まで）
        let maxWidth = NSScreen.main?.frame.width ?? 1920
        let size = (message as NSString).boundingRect(
            with: NSSize(width: maxWidth * 0.8, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        ).size
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 吹き出し本体（右側に尻尾用のスペースを確保）
        let bubbleRect = NSRect(
            x: 0,
            y: 0,
            width: bounds.width - tailWidth,
            height: bounds.height
        )

        // 背景色（レベルに応じて変更）
        let bgColor: NSColor
        switch level {
        case .info:
            bgColor = NSColor.white
        case .success:
            bgColor = NSColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
        case .warning:
            bgColor = NSColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1.0)
        case .error:
            bgColor = NSColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
        }

        // 吹き出し本体
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // 吹き出しの尻尾（右側）
        let tailPath = NSBezierPath()
        let tailY = bubbleRect.midY
        tailPath.move(to: NSPoint(x: bubbleRect.maxX, y: tailY - 6))
        tailPath.line(to: NSPoint(x: bounds.width, y: tailY))
        tailPath.line(to: NSPoint(x: bubbleRect.maxX, y: tailY + 6))
        tailPath.close()

        bgColor.setFill()
        path.fill()
        tailPath.fill()

        // 枠線
        NSColor.lightGray.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.stroke()

        // テキスト
        let textRect = NSRect(
            x: padding,
            y: padding,
            width: bubbleRect.width - padding * 2,
            height: bounds.height - padding * 2
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle,
        ]

        (message as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
