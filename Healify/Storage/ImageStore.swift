import Foundation
import UIKit

/// Stores wound photos as files on disk and hands back the filenames that the
/// SwiftData models reference. Keeping image bytes out of the database keeps
/// queries fast and the store file small.
///
/// Files live in `Application Support/WoundImages`, which is backed up but not
/// user-visible. A small in-memory thumbnail cache keeps scrolling smooth.
enum ImageStore {
    private static let directoryName = "WoundImages"
    private static let thumbnailCache = NSCache<NSString, UIImage>()

    /// Compression used when persisting full images.
    private static let jpegQuality: CGFloat = 0.9

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    // MARK: Writing

    /// Persists raw image data (preserving EXIF) and returns the generated
    /// filename. Prefer this for imported photos so metadata survives.
    @discardableResult
    static func saveOriginalData(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: url(for: filename), options: .atomic)
        return filename
    }

    /// Persists a `UIImage` as JPEG. Used for camera captures where we already
    /// have a `UIImage`.
    @discardableResult
    static func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            throw ImageStoreError.encodingFailed
        }
        return try saveOriginalData(data)
    }

    // MARK: Reading

    static func loadImage(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: filename).path)
    }

    static func loadData(_ filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    /// Returns a downsampled thumbnail suitable for grid/list display, cached
    /// by filename + pixel size.
    static func thumbnail(_ filename: String, maxPixel: CGFloat = 600) -> UIImage? {
        let key = "\(filename)@\(Int(maxPixel))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let image = downsample(url: url(for: filename), maxPixel: maxPixel) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    // MARK: Deleting

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    // MARK: Helpers

    /// Memory-efficient downsampling via ImageIO so large camera photos don't
    /// get fully decoded just to show a thumbnail.
    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

enum ImageStoreError: Error {
    case encodingFailed
}
