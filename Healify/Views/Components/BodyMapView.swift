import SwiftUI

/// A tappable region: anatomical region plus its drawn shape and position in a
/// normalized 0–1 canvas.
private struct BodySlot: Identifiable {
    enum Kind { case ellipse, capsule, roundedRect }
    let region: BodyRegion
    let center: CGPoint   // normalized 0–1
    let size: CGSize      // normalized 0–1
    let kind: Kind
    var id: String { region.id }
}

/// Builds figure geometry for a view + body shape; `BodyShape` nudges the
/// proportions so the silhouette loosely matches the person.
private enum BodyLayout {
    static func slots(view: BodyView, shape: BodyShape) -> [BodySlot] {
        let shoulderHalf: CGFloat = shape == .masculine ? 0.175 : shape == .feminine ? 0.150 : 0.162
        let waistHalf: CGFloat = shape == .feminine ? 0.110 : 0.118
        let hipHalf: CGFloat = shape == .feminine ? 0.165 : shape == .masculine ? 0.140 : 0.150

        let torsoUpper: BodyPart = view == .front ? .chest : .upperBack
        let torsoMid: BodyPart = view == .front ? .abdomen : .lowerBack
        let torsoLow: BodyPart = view == .front ? .pelvis : .buttocks

        var slots: [BodySlot] = []
        func add(_ part: BodyPart, _ side: BodySide, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ kind: BodySlot.Kind) {
            slots.append(BodySlot(region: BodyRegion(part: part, side: side, view: view),
                                  center: CGPoint(x: cx, y: cy), size: CGSize(width: w, height: h), kind: kind))
        }
        // Mirror a paired limb to both sides (anatomical right sits on viewer's left).
        func pair(_ part: BodyPart, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ kind: BodySlot.Kind) {
            add(part, .right, cx, cy, w, h, kind)
            add(part, .left, 1 - cx, cy, w, h, kind)
        }

        // Center column.
        add(.head, .center, 0.5, 0.065, 0.15, 0.10, .ellipse)
        add(.neck, .center, 0.5, 0.140, 0.07, 0.045, .roundedRect)
        add(torsoUpper, .center, 0.5, 0.250, shoulderHalf * 2, 0.155, .roundedRect)
        add(torsoMid, .center, 0.5, 0.385, waistHalf * 2 + 0.04, 0.125, .roundedRect)
        add(torsoLow, .center, 0.5, 0.480, hipHalf * 2, 0.095, .roundedRect)

        // Arms (right side coords; mirrored).
        let armX = 0.5 - shoulderHalf - 0.030
        pair(.upperArm, armX, 0.265, 0.075, 0.175, .capsule)
        pair(.forearm, armX - 0.022, 0.435, 0.066, 0.165, .capsule)
        pair(.hand, armX - 0.034, 0.555, 0.062, 0.065, .ellipse)

        // Legs.
        pair(.thigh, 0.5 - 0.078, 0.610, 0.108, 0.195, .capsule)
        pair(.shin, 0.5 - 0.082, 0.810, 0.082, 0.170, .capsule)
        pair(.foot, 0.5 - 0.086, 0.935, 0.088, 0.050, .ellipse)

        return slots
    }
}

/// A stylized, tappable anatomical figure. Used as the location picker (single
/// `selection`) and the home dashboard (multiple `markers`).
struct BodyMapView: View {
    var shape: BodyShape = .neutral
    @Binding var bodyView: BodyView
    /// Highlighted region (single-picker mode).
    var selection: BodyRegion?
    /// Highlighted regions (multi-select mode, e.g. bulk create).
    var selected: Set<BodyRegion> = []
    /// region → wound count (home mode).
    var markers: [BodyRegion: Int] = [:]
    var showsViewToggle: Bool = true
    var onTapRegion: ((BodyRegion) -> Void)?

    /// Aspect ratio (w:h) of the drawing area the normalized canvas maps into.
    private let figureAspect: CGFloat = 0.52

    var body: some View {
        VStack(spacing: 8) {
            if showsViewToggle {
                Picker("View", selection: $bodyView) {
                    ForEach(BodyView.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            GeometryReader { geo in
                let rect = figureRect(in: geo.size)
                ZStack(alignment: .topLeading) {
                    ForEach(BodyLayout.slots(view: bodyView, shape: shape)) { slot in
                        slotView(slot, in: rect)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            if !otherSideHint.isEmpty {
                Text(otherSideHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func slotView(_ slot: BodySlot, in rect: CGRect) -> some View {
        let w = slot.size.width * rect.width
        let h = slot.size.height * rect.height
        let x = rect.minX + slot.center.x * rect.width
        let y = rect.minY + slot.center.y * rect.height
        let count = markers[slot.region] ?? 0
        let isSelected = selection == slot.region || selected.contains(slot.region)

        shapeFor(slot.kind)
            .fill(fillColor(isSelected: isSelected, count: count))
            .overlay(shapeFor(slot.kind).stroke(Color(.systemGray3), lineWidth: 1))
            .frame(width: w, height: h)
            .overlay {
                if count > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: min(w, h) * 0.55, height: min(w, h) * 0.55)
                        .overlay {
                            if count > 1 {
                                Text("\(count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                }
            }
            .position(x: x, y: y)
            .contentShape(shapeFor(slot.kind).path(in: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)))
            .onTapGesture { onTapRegion?(slot.region) }
    }

    private func shapeFor(_ kind: BodySlot.Kind) -> AnyShape {
        switch kind {
        case .ellipse: return AnyShape(Ellipse())
        case .capsule: return AnyShape(Capsule())
        case .roundedRect: return AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func fillColor(isSelected: Bool, count: Int) -> Color {
        if isSelected { return .accentColor }
        if count > 0 { return .accentColor.opacity(0.22) }
        return Color(.systemGray5)
    }

    private func figureRect(in size: CGSize) -> CGRect {
        // Fit the figure's aspect into the available area, centered.
        var w = size.width
        var h = w / figureAspect
        if h > size.height {
            h = size.height
            w = h * figureAspect
        }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private var otherSideHint: String {
        let otherCount = markers.filter { $0.key.view != bodyView }.values.reduce(0, +)
        guard otherCount > 0 else { return "" }
        let other = bodyView == .front ? "back" : "front"
        return "\(otherCount) more on the \(other)"
    }
}

#Preview {
    @Previewable @State var view: BodyView = .front
    return BodyMapView(
        shape: .neutral,
        bodyView: $view,
        selection: BodyRegion(part: .forearm, side: .right, view: .front),
        markers: [BodyRegion(part: .shin, side: .left, view: .front): 2]
    )
    .padding()
}
