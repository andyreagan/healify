import Testing
import UIKit
@testable import Healify

@Suite struct ImageEditingTests {
    @Test func rotateQuarterSwapsDimensions() {
        let image = TestSupport.makeImage(width: 100, height: 60)
        let rotated = ImageEditing.rotated(image, quartersClockwise: 1)
        #expect(rotated.size == CGSize(width: 60, height: 100))
    }

    @Test func rotateTwiceKeepsDimensions() {
        let image = TestSupport.makeImage(width: 100, height: 60)
        let rotated = ImageEditing.rotated(image, quartersClockwise: 2)
        #expect(rotated.size == CGSize(width: 100, height: 60))
    }

    @Test func rotateIsModuloFour() {
        let image = TestSupport.makeImage(width: 100, height: 60)
        #expect(ImageEditing.rotated(image, quartersClockwise: 4).size == image.size)
        #expect(ImageEditing.rotated(image, quartersClockwise: -1).size == CGSize(width: 60, height: 100))
    }

    @Test func cropTakesNormalizedRegion() {
        let image = TestSupport.makeImage(width: 200, height: 100)
        let cropped = ImageEditing.cropped(image, to: CGRect(x: 0, y: 0, width: 0.5, height: 1.0))
        let cg = cropped.cgImage
        #expect(cg != nil)
        // Left half → ~100 x 100 pixels.
        #expect(abs((cg?.width ?? 0) - 100) <= 1)
        #expect(abs((cg?.height ?? 0) - 100) <= 1)
    }
}
