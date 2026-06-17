import Foundation
import UIKit

/// Stores wound photos as files in `Application Support/WoundImages` and hands
/// back the filenames the SwiftData models reference, keeping image bytes out of
/// the database. An in-memory thumbnail cache keeps scrolling smooth.
enum ImageStore {
    private static let directoryName = "WoundImages"
    private static let thumbnailCache = NSCache<NSString, UIImage>()
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

    /// Persists raw image data (preserving EXIF) and returns the new filename.
    @discardableResult
    static func saveOriginalData(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: url(for: filename), options: .atomic)
        return filename
    }

    /// Persists a `UIImage` as JPEG (for camera captures).
    @discardableResult
    static func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            throw ImageStoreError.encodingFailed
        }
        return try saveOriginalData(data)
    }

    static func loadImage(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: filename).path)
    }

    static func loadData(_ filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    /// Downsampled thumbnail for grid/list display, cached by filename + size.
    static func thumbnail(_ filename: String, maxPixel: CGFloat = 600) -> UIImage? {
        let key = "\(filename)@\(Int(maxPixel))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let image = downsample(url: url(for: filename), maxPixel: maxPixel) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Memory-efficient ImageIO downsampling — avoids fully decoding large photos
    /// just to show a thumbnail.
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
