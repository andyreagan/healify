#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Developer-only sample data, gated behind launch env vars so it never affects
/// normal use:
///   SIMCTL_CHILD_HEALIFY_SEED=1        seed sample wounds (only if store empty)
///   SIMCTL_CHILD_HEALIFY_OPEN_FIRST=1  deep-link straight into the first wound
enum DebugSeed {
    private static func flag(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key] == "1" || UserDefaults.standard.bool(forKey: key)
    }
    static var shouldSeed: Bool { flag("HEALIFY_SEED") }
    static var shouldOpenFirst: Bool { flag("HEALIFY_OPEN_FIRST") }

    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard shouldSeed else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Wound>())) ?? 0
        guard existing == 0 else { return }

        let knee = Wound(name: "Knee scrape", bodyRegion: BodyRegion(part: .shin, side: .left, view: .front),
                         kind: .abrasion, createdAt: day(-12))
        context.insert(knee)

        let n1 = JournalNote(timestamp: day(-12), text: "Cleaned and dressed. Stings.", painLevel: 5, symptoms: [.redness, .swelling])
        n1.wound = knee
        let n2 = JournalNote(timestamp: day(-8), text: "Doctor says keep covered; ~2 weeks to close.",
                             painLevel: 3, isClinicianGuidance: true, expectedHealingDays: 14)
        n2.wound = knee
        knee.notes.append(contentsOf: [n1, n2])

        // Three photos with fading redness and *different aspect ratios*
        // (portrait, landscape, square) to verify uniform timeline sizing.
        let sizes = [CGSize(width: 300, height: 520), CGSize(width: 520, height: 300), CGSize(width: 400, height: 400)]
        for (i, redness) in [0.95, 0.6, 0.3].enumerated() {
            let image = makeWoundImage(redness: redness, size: sizes[i])
            if let name = try? ImageStore.saveImage(image) {
                let p = WoundPhoto(imageFilename: name, captureDate: day(-12 + i * 5))
                p.caption = i == 0 ? "Right after it happened" : ""
                p.wound = knee
                knee.photos.append(p)
                context.insert(p)
            }
        }

        let elbow = Wound(name: "Elbow graze", bodyRegion: BodyRegion(part: .forearm, side: .right, view: .front),
                          kind: .abrasion, createdAt: day(-3))
        context.insert(elbow)

        // Pre-compute on-device analysis so the AI UI is populated for review.
        analyze(knee)

        try? context.save()
    }

    /// Runs the real analyzer + scorer over a wound's photos (used by seed so the
    /// AI screens have data without manual steps).
    @MainActor
    private static func analyze(_ wound: Wound) {
        let photos = wound.photosByDate
        for photo in photos {
            guard let data = ImageStore.loadData(photo.imageFilename) else { continue }
            let f = HealingAnalyzer.features(for: data)
            photo.rednessIndex = f.rednessIndex
            photo.featurePrint = f.featurePrint
            photo.analysisVersion = HealingAnalyzer.version
        }
        let samples = photos.map { HealingScoring.Sample(id: $0.id, redness: $0.rednessIndex ?? 0, featurePrint: $0.featurePrint) }
        let scores = HealingScoring.scores(for: samples)
        for photo in photos { photo.healingScore = scores[photo.id] }
    }

    /// Round-trips the current store through export → import (fresh in-memory
    /// store) and prints the result. Run with SIMCTL_CHILD_HEALIFY_SELFTEST=1
    /// and `simctl launch --console`.
    @MainActor
    static func selfTestBackupIfRequested(_ context: ModelContext) {
        guard flag("HEALIFY_SELFTEST") else { return }
        do {
            let url = try DataExport.makeBackup(context)
            let bytes = (try? Data(contentsOf: url))?.count ?? 0

            let schema = Schema(versionedSchema: HealifySchemaV1.self)
            let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let dest = try ModelContainer(for: schema, configurations: cfg).mainContext
            let summary = try DataImport.restore(from: url, into: dest)

            let src = (try? context.fetch(FetchDescriptor<Wound>())) ?? []
            let dst = (try? dest.fetch(FetchDescriptor<Wound>())) ?? []
            func counts(_ w: [Wound]) -> String { "W\(w.count) P\(w.reduce(0){$0+$1.photos.count}) N\(w.reduce(0){$0+$1.notes.count})" }
            print("SELFTEST backup: file=\(bytes)B  src(\(counts(src)))  dst(\(counts(dst)))  added(W\(summary.woundsAdded) P\(summary.photosAdded) N\(summary.notesAdded))")
            if let f = dst.flatMap({ $0.photos }).first?.imageFilename {
                print("SELFTEST image restored: \(ImageStore.loadData(f)?.count ?? 0)B")
            }
            // Re-import the same file: everything should be skipped (idempotent).
            let again = try DataImport.restore(from: url, into: dest)
            print("SELFTEST reimport: added W\(again.woundsAdded) skipped W\(again.woundsSkipped) (expect added 0)")
        } catch {
            print("SELFTEST backup FAILED: \(error)")
        }
    }

    private static func day(_ offset: Int) -> Date { Date().addingTimeInterval(Double(offset) * 86_400) }

    /// A synthetic skin-tone tile with a reddish "wound" blob whose intensity is
    /// driven by `redness` (1 = angry, 0 = calm).
    private static func makeWoundImage(redness: Double, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.86, green: 0.70, blue: 0.60, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let dim = min(size.width, size.height) * 0.4
            let blob = CGRect(x: (size.width - dim) / 2, y: (size.height - dim) / 2, width: dim, height: dim)
            let r = 0.55 + 0.40 * redness
            let g = 0.30 - 0.10 * redness
            let b = 0.28 - 0.10 * redness
            UIColor(red: r, green: max(0, g), blue: max(0, b), alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: blob)
        }
    }
}
#endif
