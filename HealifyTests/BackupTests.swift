import Testing
import Foundation
import SwiftData
@testable import Healify

@MainActor
@Suite struct BackupTests {
    @Test func exportImportRoundTripPreservesEverything() throws {
        let ctx = try TestSupport.makeContext()

        let region = BodyRegion(part: .shin, side: .left, view: .front)
        let wound = Wound(name: "Knee", bodyLocation: "detail", bodyRegion: region, kind: .abrasion)
        ctx.insert(wound)

        let filename = try ImageStore.saveImage(TestSupport.makeImage(width: 20, height: 20, color: .blue))
        let photo = WoundPhoto(imageFilename: filename, captureDate: TestSupport.day(0))
        photo.healingScore = 42
        photo.wound = wound; wound.photos.append(photo); ctx.insert(photo)

        let note = JournalNote(text: "cleaned", painLevel: 3, symptoms: [.redness])
        note.wound = wound; wound.notes.append(note); ctx.insert(note)
        try ctx.save()

        // Export, then import into a fresh store.
        let url = try DataExport.makeBackup(ctx)
        let dest = try TestSupport.makeContext()
        let summary = try DataImport.restore(from: url, into: dest)

        #expect(summary.woundsAdded == 1)
        #expect(summary.photosAdded == 1)
        #expect(summary.notesAdded == 1)

        let restored = try #require(try dest.fetch(FetchDescriptor<Wound>()).first)
        #expect(restored.name == "Knee")
        #expect(restored.bodyRegion == region)
        #expect(restored.photos.count == 1)
        #expect(restored.notes.first?.painLevel == 3)

        // Image bytes were rewritten to disk under a fresh filename.
        let restoredFile = try #require(restored.photos.first?.imageFilename)
        #expect(restoredFile != filename)
        #expect(ImageStore.loadData(restoredFile) != nil)

        // Re-importing the same file is idempotent.
        let again = try DataImport.restore(from: url, into: dest)
        #expect(again.woundsAdded == 0)
        #expect(again.woundsSkipped == 1)

        ImageStore.delete(filename)
        ImageStore.delete(restoredFile)
    }
}
