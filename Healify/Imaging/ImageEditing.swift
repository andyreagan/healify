import UIKit

/// Pixel-accurate rotate/crop helpers used by the photo editor.
enum ImageEditing {
    /// Redraws an image so its pixels match the `.up` orientation, making
    /// subsequent pixel crops predictable.
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Rotates by quarter turns (positive = clockwise).
    static func rotated(_ image: UIImage, quartersClockwise: Int) -> UIImage {
        let q = ((quartersClockwise % 4) + 4) % 4
        let base = normalized(image)
        guard q != 0 else { return base }

        let radians = CGFloat(q) * .pi / 2
        let swaps = q % 2 == 1
        let newSize = swaps ? CGSize(width: base.size.height, height: base.size.width) : base.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            c.rotate(by: radians)
            base.draw(in: CGRect(x: -base.size.width / 2, y: -base.size.height / 2,
                                 width: base.size.width, height: base.size.height))
        }
    }

    /// Crops to a normalized rect (0–1, origin top-left, in display space).
    static func cropped(_ image: UIImage, to rect: CGRect) -> UIImage {
        let base = normalized(image)
        guard let cg = base.cgImage else { return base }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let pixels = CGRect(x: rect.minX * w, y: rect.minY * h,
                            width: rect.width * w, height: rect.height * h).integral
        guard pixels.width >= 1, pixels.height >= 1, let out = cg.cropping(to: pixels) else { return base }
        return UIImage(cgImage: out, scale: base.scale, orientation: .up)
    }
}
