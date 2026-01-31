import AppKit
import Foundation

// MARK: - Peek Direction

/// Character appearance direction
public enum PeekDirection: String, CaseIterable, Sendable {
    case bottom = "bottom"
    case left = "left"
    case right = "right"

    public static func random() -> PeekDirection {
        allCases.randomElement() ?? .bottom
    }

    /// Image rotation angle (degrees) - counterclockwise is positive
    public var rotationDegrees: CGFloat {
        switch self {
        case .bottom: return 0  // No rotation (head up)
        case .left: return -90  // Head right (appearing from left) - 90° clockwise
        case .right: return 90  // Head left (appearing from right) - 90° counterclockwise
        }
    }
}

// MARK: - Image Rotation

extension NSImage {
    /// Return image rotated by specified degrees
    public func rotated(byDegrees degrees: CGFloat) -> NSImage {
        if degrees == 0 { return self }

        var newSize = size

        // Swap width and height for 90°/-90° rotation
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
