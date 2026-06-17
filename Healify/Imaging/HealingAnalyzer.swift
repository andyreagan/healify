import Foundation
import CoreImage
import Vision
import UIKit

/// On-device image features extracted from a single wound photo.
struct PhotoFeatures {
    /// Inflammation index 0–1: red channel's share of the frame. A falling value
    /// across a series is a healing signal.
    let rednessIndex: Double
    /// Archived `VNFeaturePrintObservation`, used to measure visual divergence.
    let featurePrint: Data?
}

/// On-device wound analysis: a Core Image color metric plus a Vision feature
/// print. A heuristic wellness aid, not a medical diagnosis.
enum HealingAnalyzer {
    /// Bump when the algorithm changes so cached scores get recomputed.
    static let version = 1

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func features(for imageData: Data) -> PhotoFeatures {
        PhotoFeatures(rednessIndex: rednessIndex(for: imageData), featurePrint: featurePrint(for: imageData))
    }

    /// Average red share across the frame via one Core Image area-average pass.
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
