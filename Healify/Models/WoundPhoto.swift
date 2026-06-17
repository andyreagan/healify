import Foundation
import SwiftData

/// One photo in a wound's journal. Image bytes live on disk (see `ImageStore`);
/// the model keeps the filename, metadata, and cached analysis results.
@Model
final class WoundPhoto {
    @Attribute(.unique) var id: UUID
    var imageFilename: String
    /// When the photo was taken: seeded from EXIF, user-adjustable to fix the
    /// timeline for imported photos.
    var captureDate: Date
    /// True once the user has overridden the capture date (differs from EXIF).
    var captureDateAdjusted: Bool
    /// Original EXIF date read on import, kept so "reset to original" works.
    var exifCaptureDate: Date?
    var addedAt: Date
    var caption: String

    // Cached on-device analysis (nil until scoring runs).
    /// 0–100 healing progress vs. the baseline photo. Higher = more healed.
    var healingScore: Double?
    var rednessIndex: Double?
    var featurePrint: Data?
    /// Analyzer version that produced the cache, so results can be invalidated.
    var analysisVersion: Int?

    var wound: Wound?

    init(
        id: UUID = UUID(),
        imageFilename: String,
        captureDate: Date,
        exifCaptureDate: Date? = nil,
        captureDateAdjusted: Bool = false,
        addedAt: Date = .now,
        caption: String = ""
    ) {
        self.id = id
        self.imageFilename = imageFilename
        self.captureDate = captureDate
        self.exifCaptureDate = exifCaptureDate
        self.captureDateAdjusted = captureDateAdjusted
        self.addedAt = addedAt
        self.caption = caption
    }
}

extension WoundPhoto {
    var hasAnalysis: Bool { healingScore != nil }
}
