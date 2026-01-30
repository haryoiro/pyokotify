import AppKit
import Foundation

// MARK: - Peek Direction

/// キャラクターの出現方向
public enum PeekDirection: String, CaseIterable, Sendable {
    case bottom = "bottom"
    case left = "left"
    case right = "right"

    public static func random() -> PeekDirection {
        allCases.randomElement() ?? .bottom
    }

    /// 画像の回転角度（度）- 反時計回りが正
    public var rotationDegrees: CGFloat {
        switch self {
        case .bottom: return 0  // そのまま（頭が上）
        case .left: return -90  // 頭が右（左から出てくる）- 時計回り90度
        case .right: return 90  // 頭が左（右から出てくる）- 反時計回り90度
        }
    }
}

// MARK: - Image Rotation

extension NSImage {
    /// 指定角度で回転した画像を返す
    public func rotated(byDegrees degrees: CGFloat) -> NSImage {
        if degrees == 0 { return self }

        var newSize = size

        // 90度/-90度回転の場合は幅と高さを入れ替え
        if abs(degrees) == 90 || abs(degrees) == 270 {
            newSize = NSSize(width: size.height, height: size.width)
        }

        let rotatedImage = NSImage(size: newSize)
        rotatedImage.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()

        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        rotatedImage.unlockFocus()
        return rotatedImage
    }
}
