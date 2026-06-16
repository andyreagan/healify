import Foundation
import SwiftData

/// One photo in a wound's journal.
///
/// The image bytes live on disk (see `ImageStore`); the model only keeps the
/// filename plus metadata and any cached analysis results so SwiftData stays
/// lean.
@Model
final class WoundPhoto {
    @Attribute(.unique) var id: UUID

    /// Filename within the image store directory (e.g. "<uuid>.jpg").
    var imageFilename: String

    /// The moment the photo was taken. Seeded from EXIF when available, but the
    /// user can adjust it — backdating an imported photo fixes the timeline.
    var captureDate: Date

    /// True once the user has manually overridden the capture date, so the UI
    /// can show that it differs from the embedded EXIF timestamp.
    var captureDateAdjusted: Bool

    /// The original EXIF capture date we read on import, kept so "reset to
    /// original" works after an adjustment.
    var exifCaptureDate: Date?

    /// When the row was created in the app.
    var addedAt: Date

    var caption: String

    // MARK: Cached on-device analysis (nil until AI scoring runs)

    /// 0–100 healing progress vs. the baseline photo. Higher = more healed.
    var healingScore: Double?

    /// Inflammation/redness index for this photo (see `HealingAnalyzer`).
    var rednessIndex: Double?

    /// Vision feature-print bytes, cached so we don't recompute on every pass.
    var featurePrint: Data?

    /// App version of the analyzer that produced the cached values, so results
    /// can be invalidated if the algorithm changes.
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
