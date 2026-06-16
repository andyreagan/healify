import Foundation
import SwiftData
import UIKit

/// Centralizes turning raw photos into persisted `WoundPhoto` rows: writes the
/// image to disk and seeds the capture date from EXIF when possible.
enum PhotoImporter {
    /// Import from raw image data (e.g. PhotosPicker), preserving EXIF and using
    /// its original capture date for the timeline.
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

    /// Import a freshly captured camera image. No EXIF, so the capture date is
    /// now (the user can still adjust it later).
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
