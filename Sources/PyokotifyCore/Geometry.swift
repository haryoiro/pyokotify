import Foundation

// MARK: - Geometry Utilities

/// 幾何計算ユーティリティ
public enum Geometry {

    // MARK: - 矩形の縁上の点

    public static func pointOnRectEdge(rect: CGRect, angle: CGFloat) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let cosA = cos(angle)
        let sinA = sin(angle)

        // 各辺との交点を計算し、最も近いものを返す
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

    // MARK: - 画像描画領域

    /// NSImageView の scaleProportionallyUpOrDown と同じ計算
    public static func calculateImageRect(imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var drawSize: CGSize
        if imageAspect > viewAspect {
            // 画像の方が横長 → 幅に合わせる
            drawSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // 画像の方が縦長 → 高さに合わせる
            drawSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }

        // 中央に配置
        let x = (viewSize.width - drawSize.width) / 2
        let y = (viewSize.height - drawSize.height) / 2

        return CGRect(x: x, y: y, width: drawSize.width, height: drawSize.height)
    }

    // MARK: - 吹き出しのしっぽ

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

        // 縁上の点
        let edgePoint = pointOnRectEdge(rect: bubbleRect, angle: angle)

        // 根元を内側にオフセット
        let tailBase = CGPoint(
            x: edgePoint.x - cos(angle) * insetAmount,
            y: edgePoint.y - sin(angle) * insetAmount
        )

        // 先端
        let tip = CGPoint(
            x: edgePoint.x + cos(angle) * tailLength,
            y: edgePoint.y + sin(angle) * tailLength
        )

        // 根元の左右
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
