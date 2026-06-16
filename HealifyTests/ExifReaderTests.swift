import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Healify

@Suite struct ExifReaderTests {
    @Test func readsExifDateTimeOriginal() throws {
        let image = TestSupport.makeImage(width: 10, height: 10)
        let cg = try #require(image.cgImage)
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let props: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2025:01:02 03:04:05"]
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))

        let date = try #require(ExifReader.captureDate(from: data as Data))
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(c.year == 2025)
        #expect(c.month == 1)
        #expect(c.day == 2)
        #expect(c.hour == 3)
        #expect(c.minute == 4)
    }

    @Test func returnsNilWithoutCaptureMetadata() {
        let image = TestSupport.makeImage(width: 10, height: 10)
        let data = image.jpegData(compressionQuality: 0.8) ?? Data()
        #expect(ExifReader.captureDate(from: data) == nil)
    }
}
