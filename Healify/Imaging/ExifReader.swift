import Foundation
import ImageIO

/// Reads the original capture timestamp embedded in an image's metadata.
///
/// We prefer the EXIF *DateTimeOriginal* (when the shutter fired) and fall back
/// to the TIFF *DateTime*. This is what lets imported library photos land on
/// the correct day in the healing timeline instead of "now".
enum ExifReader {
    /// EXIF/TIFF dates are stored as "yyyy:MM:dd HH:mm:ss" in the photo's local
    /// time with no zone, so we parse in the current calendar.
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return captureDate(from: source)
    }

    static func captureDate(fromFile url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return captureDate(from: source)
    }

    private static func captureDate(from source: CGImageSource) -> Date? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
           let date = formatter.date(from: original) {
            return date
        }

        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateTime = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = formatter.date(from: dateTime) {
            return date
        }

        return nil
    }
}
