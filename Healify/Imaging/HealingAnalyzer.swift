import Foundation
import CoreImage
import Vision
import UIKit

/// On-device image features extracted from a single wound photo.
struct PhotoFeatures {
    /// Inflammation index in 0–1: the red channel's share of total luminance
    /// within the frame. Inflamed tissue skews red, so a falling value across a
    /// series is a healing signal.
    let rednessIndex: Double
    /// Archived `VNFeaturePrintObservation` describing the image's overall
    /// appearance, used to measure visual divergence between photos.
    let featurePrint: Data?
}

/// Runs entirely on the device — no network, no third-party services. Combines
/// a Core Image color metric with a Vision feature print.
///
/// IMPORTANT: this is a heuristic wellness aid, not a medical diagnosis. The
/// score reflects visual inflammation and change over time, nothing more, and
/// the UI says so.
enum HealingAnalyzer {
    /// Bump when the algorithm changes so cached scores get recomputed.
    static let version = 1

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    // MARK: Feature extraction

    static func features(for imageData: Data) -> PhotoFeatures {
        let redness = rednessIndex(for: imageData)
        let print = featurePrint(for: imageData)
        return PhotoFeatures(rednessIndex: redness, featurePrint: print)
    }

    /// Average red share across the frame using a single Core Image area-average
    /// pass (cheap, GPU-backed).
    private static func rednessIndex(for imageData: Data) -> Double {
        guard let ciImage = CIImage(data: imageData) else { return 0 }
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extent)
              ]),
              let output = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let r = Double(bitmap[0]), g = Double(bitmap[1]), b = Double(bitmap[2])
        let total = r + g + b
        guard total > 0 else { return 0 }
        return r / total
    }

    private static func featurePrint(for imageData: Data) -> Data? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(data: imageData, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else { return nil }
            return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        } catch {
            return nil
        }
    }

    /// Visual distance (0 = identical) between two cached feature prints.
    static func distance(_ a: Data?, _ b: Data?) -> Float? {
        guard let a, let b,
              let obsA = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: a),
              let obsB = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: b)
        else { return nil }
        var dist = Float(0)
        do {
            try obsA.computeDistance(&dist, to: obsB)
            return dist
        } catch {
            return nil
        }
    }
}
