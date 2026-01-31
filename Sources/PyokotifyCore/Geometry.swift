import Foundation

// MARK: - Geometry Utilities

/// Geometry calculation utilities
public enum Geometry {
    /// Calculate the point on the edge of a rectangle at a given angle from center
    /// - Parameters:
    ///   - rect: The target rectangle
    ///   - angle: Angle from center (radians)
    /// - Returns: Point on the rectangle edge
    public static func pointOnRectEdge(rect: CGRect, angle: CGFloat) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let cosA = cos(angle)
        let sinA = sin(angle)

        // Calculate intersection with each edge and return the closest
        var t: CGFloat = .greatestFiniteMagnitude

        if cosA > 0 {
            t = min(t, (rect.maxX - center.x) / cosA)
        } else if cosA < 0 {
            t = min(t, (rect.minX - center.x) / cosA)
        }

        if sinA > 0 {
            t = min(t, (rect.maxY - center.y) / sinA)
        } else if sinA < 0 {
            t = min(t, (rect.minY - center.y) / sinA)
        }

        return CGPoint(
            x: center.x + cosA * t,
            y: center.y + sinA * t
        )
    }

    /// Calculate the drawing rect for an image (replicates scaleProportionallyUpOrDown behavior)
    /// - Parameters:
    ///   - imageSize: Original image size
    ///   - viewSize: View size
    /// - Returns: The rect where the image will be drawn
    public static func calculateImageRect(imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var drawSize: CGSize
        if imageAspect > viewAspect {
            // Image is wider -> fit to width
            drawSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // Image is taller -> fit to height
            drawSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }

        // Center the image
        let x = (viewSize.width - drawSize.width) / 2
        let y = (viewSize.height - drawSize.height) / 2

        return CGRect(x: x, y: y, width: drawSize.width, height: drawSize.height)
    }

    /// Calculate the vertices of the tail triangle
    /// - Parameters:
    ///   - bubbleRect: The speech bubble rectangle
    ///   - targetPoint: The target point where the tail points to
    ///   - tailLength: Length of the tail
    ///   - tailWidth: Width of the tail base
    ///   - insetAmount: Inset offset for the tail base
    /// - Returns: Tuple of (tip, left base, right base), or nil
    public static func calculateTailPoints(
        bubbleRect: CGRect,
        targetPoint: CGPoint,
        tailLength: CGFloat,
        tailWidth: CGFloat,
        insetAmount: CGFloat
    ) -> (tip: CGPoint, left: CGPoint, right: CGPoint)? {
        let bubbleCenter = CGPoint(x: bubbleRect.midX, y: bubbleRect.midY)
        let dx = targetPoint.x - bubbleCenter.x
        let dy = targetPoint.y - bubbleCenter.y
        let angle = atan2(dy, dx)

        // Point on edge
        let edgePoint = pointOnRectEdge(rect: bubbleRect, angle: angle)

        // Offset tail base inward
        let tailBase = CGPoint(
            x: edgePoint.x - cos(angle) * insetAmount,
            y: edgePoint.y - sin(angle) * insetAmount
        )

        // Tip
        let tip = CGPoint(
            x: edgePoint.x + cos(angle) * tailLength,
            y: edgePoint.y + sin(angle) * tailLength
        )

        // Left and right base points
        let perpAngle = angle + .pi / 2
        let left = CGPoint(
            x: tailBase.x + cos(perpAngle) * tailWidth,
            y: tailBase.y + sin(perpAngle) * tailWidth
        )
        let right = CGPoint(
            x: tailBase.x - cos(perpAngle) * tailWidth,
            y: tailBase.y - sin(perpAngle) * tailWidth
        )

        return (tip, left, right)
    }
}
