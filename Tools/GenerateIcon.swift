// Generates the Healify app icon (1024×1024) with Core Graphics — no design
// tools needed. Xcode thins this single source into all required sizes.
//
// Usage:
//   xcrun swift Tools/GenerateIcon.swift \
//     Healify/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Tweak the colors / bandage geometry below and re-run to iterate.

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let W = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard CommandLine.arguments.count > 1 else { fputs("usage: GenerateIcon.swift <out.png>\n", stderr); exit(2) }
guard let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// Background: diagonal green gradient (brand accent family).
let grad = CGGradient(colorsSpace: cs,
    colors: [color(0.40, 0.80, 0.62), color(0.16, 0.56, 0.43)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(W)),
                       end: CGPoint(x: CGFloat(W), y: 0), options: [])

// Soft glow top-left for depth.
let glow = CGGradient(colorsSpace: cs,
    colors: [color(1, 1, 1, 0.18), color(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 720), startRadius: 0,
                       endCenter: CGPoint(x: 330, y: 720), endRadius: 620, options: [])

// Bandage, centered, rotated -45°.
ctx.translateBy(x: 512, y: 512)
ctx.rotate(by: -.pi / 4)

func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

// Drop shadow under the strip.
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 46, color: color(0, 0.12, 0.08, 0.35))
ctx.addPath(roundRect(-330, -118, 660, 236, 118))
ctx.setFillColor(color(0.99, 0.99, 0.97))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Central absorbent pad (light green tint).
ctx.addPath(roundRect(-116, -118, 232, 236, 26))
ctx.setFillColor(color(0.86, 0.94, 0.89))
ctx.fillPath()

// Perforation dots on each wing.
ctx.setFillColor(color(0.55, 0.78, 0.66, 0.55))
for cx in [-258.0, -188.0, 188.0, 258.0] {
    for cy in [-72.0, 0.0, 72.0] {
        ctx.addEllipse(in: CGRect(x: cx - 17, y: cy - 17, width: 34, height: 34))
    }
}
ctx.fillPath()

guard let image = ctx.makeImage() else { exit(1) }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outURL.path)")
