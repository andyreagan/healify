import Foundation
import SwiftData
import UIKit
@testable import Healify

/// Shared helpers for the test suites.
enum TestSupport {
    /// Keeps test containers alive for the whole test run. A `ModelContext` does
    /// not appear to retain its `ModelContainer` strongly, so returning
    /// `container.mainContext` from a function let the container deallocate and
    /// caused use-after-free crashes on CI. Holding a reference here fixes that.
    @MainActor private static var retainedContainers: [ModelContainer] = []

    /// A fresh in-memory SwiftData context using the app's versioned schema.
    @MainActor
    static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: HealifySchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        retainedContainers.append(container)
        return container.mainContext
    }

    /// A solid-color image at exact pixel dimensions (scale 1) for deterministic
    /// pixel assertions.
    static func makeImage(width: Int, height: Int, color: UIColor = .red) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    static func day(_ offset: Int, from date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Date {
        date.addingTimeInterval(Double(offset) * 86_400)
    }
}
