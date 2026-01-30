import Foundation
import Testing

@testable import PyokotifyCore

@Suite("Direction Tests")
struct DirectionTests {
    @Test("bottom の回転角度は 0")
    func bottomRotation() {
        #expect(PeekDirection.bottom.rotationDegrees == 0)
    }

    @Test("left の回転角度は -90（時計回り）")
    func leftRotation() {
        #expect(PeekDirection.left.rotationDegrees == -90)
    }

    @Test("right の回転角度は 90（反時計回り）")
    func rightRotation() {
        #expect(PeekDirection.right.rotationDegrees == 90)
    }

    @Test("全ての方向が CaseIterable に含まれる")
    func allCases() {
        let cases = PeekDirection.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.bottom))
        #expect(cases.contains(.left))
        #expect(cases.contains(.right))
    }

    @Test("random() は有効な方向を返す")
    func randomDirection() {
        for _ in 0..<100 {
            let direction = PeekDirection.random()
            #expect(PeekDirection.allCases.contains(direction))
        }
    }

    @Test("rawValue が正しい")
    func rawValues() {
        #expect(PeekDirection.bottom.rawValue == "bottom")
        #expect(PeekDirection.left.rawValue == "left")
        #expect(PeekDirection.right.rawValue == "right")
    }
}
