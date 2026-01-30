import AppKit
import Foundation

// MARK: - Speech Bubble View

/// 吹き出しビュー（しっぽ付き）
public class SpeechBubbleView: NSView {
    private let label: NSTextField
    private let padding: CGFloat = 12
    private let tailLength: CGFloat = 15
    private var calculatedSize: NSSize = .zero

    /// しっぽが向かうターゲット位置（親ビュー座標系）
    public var tailTarget: CGPoint? {
        didSet { needsDisplay = true }
    }

    public init(message: String) {
        self.label = NSTextField(labelWithString: message)
        super.init(frame: .zero)

        wantsLayer = true
        setupLabel()
        calculateSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabel() {
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .black
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 4
        label.preferredMaxLayoutWidth = 160
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        addSubview(label)
    }

    private func calculateSize() {
        label.sizeToFit()
        let labelSize = label.fittingSize
        calculatedSize = NSSize(
            width: min(labelSize.width, 160) + padding * 2 + tailLength,
            height: labelSize.height + padding * 2 + tailLength
        )

        label.frame = NSRect(
            x: padding + tailLength / 2,
            y: padding + tailLength / 2,
            width: min(labelSize.width, 160),
            height: labelSize.height
        )
    }

    override public var intrinsicContentSize: NSSize {
        calculatedSize
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 吹き出し本体の領域
        let margin = tailLength / 2
        let bubbleRect = NSRect(
            x: bounds.minX + margin,
            y: bounds.minY + margin,
            width: bounds.width - margin * 2,
            height: bounds.height - margin * 2
        )

        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)
        let tailPath = createTailPath(bubbleRect: bubbleRect)

        // 影付きで描画
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 4
        shadow.set()

        // しっぽを先に描画（吹き出し本体の後ろ）
        NSColor.white.setFill()
        tailPath.fill()
        bubblePath.fill()

        // 影をリセットして枠線描画
        NSShadow().set()
        NSColor(white: 0.85, alpha: 1.0).setStroke()
        bubblePath.lineWidth = 1
        bubblePath.stroke()
    }

    private func createTailPath(bubbleRect: NSRect) -> NSBezierPath {
        let tailPath = NSBezierPath()

        guard let target = tailTarget, let superview = superview else {
            return tailPath
        }

        let localTarget = convert(target, from: superview)

        guard
            let points = Geometry.calculateTailPoints(
                bubbleRect: bubbleRect,
                targetPoint: localTarget,
                tailLength: tailLength,
                tailWidth: 10,
                insetAmount: 12
            )
        else {
            return tailPath
        }

        tailPath.move(to: points.left)
        tailPath.line(to: points.tip)
        tailPath.line(to: points.right)
        tailPath.close()

        return tailPath
    }
}

// MARK: - Pokkofy View

/// メインのキャラクター表示ビュー
public class PokkofyView: NSView {
    private let imageView: NSImageView
    private var bubbleView: SpeechBubbleView?
    private let direction: PeekDirection
    public var onClick: (() -> Void)?

    public init(image: NSImage, message: String? = nil, direction: PeekDirection = .bottom) {
        self.imageView = NSImageView()
        self.direction = direction
        super.init(frame: .zero)

        setupImageView(image: image)
        setupBubbleView(message: message)
        setupTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupImageView(image: NSImage) {
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func setupBubbleView(message: String?) {
        guard let message = message, !message.isEmpty else { return }

        let bubble = SpeechBubbleView(message: message)
        addSubview(bubble)
        self.bubbleView = bubble
    }

    private func setupTrackingArea() {
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
    }

    override public var isFlipped: Bool { false }

    override public func layout() {
        super.layout()
        layoutBubble()
    }

    private func layoutBubble() {
        guard let bubble = bubbleView, let image = imageView.image else { return }

        let bubbleSize = bubble.intrinsicContentSize
        let imageRect = Geometry.calculateImageRect(imageSize: image.size, viewSize: bounds.size)

        let (bubbleX, bubbleY) = calculateBubblePosition(
            bubbleSize: bubbleSize,
            imageRect: imageRect
        )

        bubble.frame = CGRect(x: bubbleX, y: bubbleY, width: bubbleSize.width, height: bubbleSize.height)
        bubble.tailTarget = CGPoint(x: imageRect.midX, y: imageRect.midY)
    }

    private func calculateBubblePosition(bubbleSize: NSSize, imageRect: CGRect) -> (CGFloat, CGFloat) {
        let tailOffset: CGFloat = 12
        var bubbleX: CGFloat
        var bubbleY: CGFloat

        switch direction {
        case .bottom:
            bubbleX = imageRect.minX - bubbleSize.width + tailOffset
            bubbleY = imageRect.maxY - bubbleSize.height * 0.5
            bubbleX = max(0, bubbleX)
            bubbleY = min(bounds.height - bubbleSize.height, bubbleY)

        case .left:
            bubbleX = imageRect.maxX - bubbleSize.width / 2
            bubbleY = imageRect.maxY + tailOffset
            bubbleX = min(bounds.width - bubbleSize.width, max(0, bubbleX))
            bubbleY = min(bounds.height - bubbleSize.height, bubbleY)

        case .right:
            bubbleX = imageRect.minX - bubbleSize.width / 2
            bubbleY = imageRect.maxY + tailOffset
            bubbleX = min(bounds.width - bubbleSize.width, max(0, bubbleX))
            bubbleY = min(bounds.height - bubbleSize.height, bubbleY)
        }

        return (bubbleX, bubbleY)
    }

    override public func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override public func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
    }

    override public func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }
}

// MARK: - Pokkofy Window

/// 透明なオーバーレイウィンドウ
public class PokkofyWindow: NSWindow {
    public init(contentRect: NSRect, clickable: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = !clickable
        animationBehavior = .none
    }
}
