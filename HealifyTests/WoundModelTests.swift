import Testing
import Foundation
import SwiftData
@testable import Healify

@MainActor
@Suite struct WoundModelTests {
    @Test func photosAreSortedByCaptureDate() throws {
        let ctx = try TestSupport.makeContext()
        let w = Wound(name: "W")
        ctx.insert(w)
        for offset in [5, 1, 3] {
            let p = WoundPhoto(imageFilename: "\(offset).jpg", captureDate: TestSupport.day(offset))
            p.wound = w; w.photos.append(p); ctx.insert(p)
        }
        let dates = w.photosByDate.map(\.captureDate)
        #expect(dates == dates.sorted())
        #expect(w.baselinePhoto?.captureDate == TestSupport.day(1))
        #expect(w.latestPhoto?.captureDate == TestSupport.day(5))
    }

    @Test func deletingWoundRemovesPhotosAndNotes() throws {
        let ctx = try TestSupport.makeContext()
        let w = Wound(name: "W")
        ctx.insert(w)
        let p = WoundPhoto(imageFilename: "a.jpg", captureDate: .now)
        p.wound = w; w.photos.append(p); ctx.insert(p)
        let n = JournalNote(text: "hi"); n.wound = w; w.notes.append(n); ctx.insert(n)
        try ctx.save()

        Persistence.delete(w, from: ctx)
        try ctx.save()

        #expect(try ctx.fetchCount(FetchDescriptor<Wound>()) == 0)
        #expect(try ctx.fetchCount(FetchDescriptor<WoundPhoto>()) == 0)
        #expect(try ctx.fetchCount(FetchDescriptor<JournalNote>()) == 0)
    }

    @Test func locationDescriptionCombinesRegionAndDetail() {
        let region = BodyRegion(part: .forearm, side: .right, view: .front)
        #expect(Wound(name: "W", bodyLocation: "2cm scar", bodyRegion: region).locationDescription == "Right forearm · 2cm scar")
        #expect(Wound(name: "W", bodyLocation: "", bodyRegion: region).locationDescription == "Right forearm")
        #expect(Wound(name: "W", bodyLocation: "just here", bodyRegion: nil).locationDescription == "just here")
        #expect(Wound(name: "W").locationDescription == "")
    }

    @Test func latestScoreFollowsLatestPhoto() throws {
        let ctx = try TestSupport.makeContext()
        let w = Wound(name: "W")
        ctx.insert(w)
        let older = WoundPhoto(imageFilename: "o.jpg", captureDate: TestSupport.day(0)); older.healingScore = 20
        let newer = WoundPhoto(imageFilename: "n.jpg", captureDate: TestSupport.day(5)); newer.healingScore = 70
        for p in [older, newer] { p.wound = w; w.photos.append(p); ctx.insert(p) }
        #expect(w.latestScore == 70)
    }
}
