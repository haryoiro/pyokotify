import Foundation
import Testing

@testable import PyokotifyCore

@Suite("Geometry Tests")
struct GeometryTests {
    // MARK: - pointOnRectEdge Tests

    @Test("右方向（0度）で矩形の右端の点を返す")
    func pointOnRectEdgeRight() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: 0)

        #expect(point.x == 100)
        #expect(point.y == 50)
    }

    @Test("上方向（90度）で矩形の上端の点を返す")
    func pointOnRectEdgeTop() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: .pi / 2)

        #expect(abs(point.x - 50) < 0.001)
        #expect(abs(point.y - 100) < 0.001)
    }

    @Test("左方向（180度）で矩形の左端の点を返す")
    func pointOnRectEdgeLeft() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: .pi)

        #expect(abs(point.x - 0) < 0.001)
        #expect(abs(point.y - 50) < 0.001)
    }

    @Test("下方向（-90度）で矩形の下端の点を返す")
    func pointOnRectEdgeBottom() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: -.pi / 2)

        #expect(abs(point.x - 50) < 0.001)
        #expect(abs(point.y - 0) < 0.001)
    }

    @Test("斜め45度で矩形の角付近の点を返す")
    func pointOnRectEdgeDiagonal() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: .pi / 4)

        // 正方形の場合、45度は右上の角
        #expect(abs(point.x - 100) < 0.001)
        #expect(abs(point.y - 100) < 0.001)
    }

    @Test("オフセットのある矩形でも正しく計算")
    func pointOnRectEdgeWithOffset() {
        let rect = CGRect(x: 50, y: 50, width: 100, height: 100)
        let point = Geometry.pointOnRectEdge(rect: rect, angle: 0)

        #expect(point.x == 150)  // 50 + 100
        #expect(point.y == 100)  // 50 + 50
    }

    // MARK: - calculateImageRect Tests

    @Test("同じアスペクト比でビュー全体に収まる")
    func calculateImageRectSameAspect() {
        let imageSize = CGSize(width: 100, height: 100)
        let viewSize = CGSize(width: 200, height: 200)
        let rect = Geometry.calculateImageRect(imageSize: imageSize, viewSize: viewSize)

        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 200)
        #expect(rect.height == 200)
    }

    @Test("横長画像が幅に合わせてスケール")
    func calculateImageRectWideImage() {
        let imageSize = CGSize(width: 200, height: 100)
        let viewSize = CGSize(width: 100, height: 100)
        let rect = Geometry.calculateImageRect(imageSize: imageSize, viewSize: viewSize)

        #expect(rect.width == 100)
        #expect(rect.height == 50)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 25)  // 中央配置
    }

    @Test("縦長画像が高さに合わせてスケール")
    func calculateImageRectTallImage() {
        let imageSize = CGSize(width: 100, height: 200)
        let viewSize = CGSize(width: 100, height: 100)
        let rect = Geometry.calculateImageRect(imageSize: imageSize, viewSize: viewSize)

        #expect(rect.width == 50)
        #expect(rect.height == 100)
        #expect(rect.origin.x == 25)  // 中央配置
        #expect(rect.origin.y == 0)
    }

    @Test("画像サイズがゼロの場合はゼロを返す")
    func calculateImageRectZeroImage() {
        let imageSize = CGSize(width: 0, height: 100)
        let viewSize = CGSize(width: 100, height: 100)
        let rect = Geometry.calculateImageRect(imageSize: imageSize, viewSize: viewSize)

        #expect(rect == .zero)
    }

    @Test("ビューサイズがゼロの場合はゼロを返す")
    func calculateImageRectZeroView() {
        let imageSize = CGSize(width: 100, height: 100)
        let viewSize = CGSize(width: 0, height: 100)
        let rect = Geometry.calculateImageRect(imageSize: imageSize, viewSize: viewSize)

        #expect(rect == .zero)
    }

    // MARK: - calculateTailPoints Tests

    @Test("しっぽの点が正しく計算される")
    func calculateTailPointsBasic() {
        let bubbleRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let targetPoint = CGPoint(x: 200, y: 50)  // 右側のターゲット

        guard
            let points = Geometry.calculateTailPoints(
                bubbleRect: bubbleRect,
                targetPoint: targetPoint,
                tailLength: 15,
                tailWidth: 10,
                insetAmount: 12
            )
        else {
            Issue.record("Expected points but got nil")
            return
        }

        // 先端はターゲット方向に伸びている
        #expect(points.tip.x > 100)
        #expect(abs(points.tip.y - 50) < 1)

        // 根元の左右は上下に分かれている
        #expect(points.left.y > points.right.y)
    }

    @Test("上方向のターゲットでしっぽが上を向く")
    func calculateTailPointsUpward() {
        let bubbleRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let targetPoint = CGPoint(x: 50, y: 200)  // 上側のターゲット

        guard
            let points = Geometry.calculateTailPoints(
                bubbleRect: bubbleRect,
                targetPoint: targetPoint,
                tailLength: 15,
                tailWidth: 10,
                insetAmount: 12
            )
        else {
            Issue.record("Expected points but got nil")
            return
        }

        // 先端は上方向
        #expect(points.tip.y > 100)
        #expect(abs(points.tip.x - 50) < 1)
    }
}
