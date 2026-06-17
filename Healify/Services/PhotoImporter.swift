import Foundation
import SwiftData
import UIKit

/// Turns raw photos into persisted `WoundPhoto` rows, writing the image to disk.
enum PhotoImporter {
    /// Import raw image data (e.g. PhotosPicker), using its EXIF capture date.
    @discardableResult
    @MainActor
    static func importData(_ data: Data, into wound: Wound, context: ModelContext) -> WoundPhoto? {
        guard let filename = try? ImageStore.saveOriginalData(data) else { return nil }
        let exifDate = ExifReader.captureDate(from: data)
        let photo = WoundPhoto(
            imageFilename: filename,
            captureDate: exifDate ?? .now,
            exifCaptureDate: exifDate
        )
        photo.wound = wound
        wound.photos.append(photo)
        context.insert(photo)
        return photo
    }

    /// Import a freshly captured camera image. No EXIF, so capture date is now.
    @discardableResult
    @MainActor
    static func importCameraImage(_ image: UIImage, into wound: Wound, context: ModelContext) -> WoundPhoto? {
        guard let filename = try? ImageStore.saveImage(image) else { return nil }
        let photo = WoundPhoto(
            imageFilename: filename,
            captureDate: .now,
            exifCaptureDate: nil
        )
        photo.wound = wound
        wound.photos.append(photo)
        context.insert(photo)
        return photo
    }
}
