import Testing
@testable import Healify

@Suite struct BodyRegionTests {
    @Test func frontLimbReadsSideThenPart() {
        let r = BodyRegion(part: .forearm, side: .right, view: .front)
        #expect(r.displayName == "Right forearm")
    }

    @Test func backLimbReadsBackOfSidePart() {
        let r = BodyRegion(part: .hand, side: .left, view: .back)
        #expect(r.displayName == "Back of left hand")
    }

    @Test func torsoPartsImplyFrontBackWithoutPrefix() {
        #expect(BodyRegion(part: .chest, side: .center, view: .front).displayName == "Chest")
        #expect(BodyRegion(part: .upperBack, side: .center, view: .back).displayName == "Upper back")
    }

    @Test func multiWordPartKeepsSpacing() {
        let r = BodyRegion(part: .upperArm, side: .left, view: .front)
        #expect(r.displayName == "Left upper arm")
    }

    @Test func identityIsViewSidePart() {
        let r = BodyRegion(part: .shin, side: .left, view: .front)
        #expect(r.id == "front.left.shin")
    }

    @Test func equalityMatchesAllComponents() {
        let a = BodyRegion(part: .foot, side: .right, view: .front)
        let b = BodyRegion(part: .foot, side: .right, view: .front)
        let c = BodyRegion(part: .foot, side: .right, view: .back)
        #expect(a == b)
        #expect(a != c)
    }
}
