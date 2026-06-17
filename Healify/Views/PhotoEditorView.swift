import SwiftUI

/// Crop + rotate editor for a wound photo. Drag the corner handles to crop,
/// rotate in 90° steps; "Done" returns the edited image.
struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    var onComplete: (UIImage) -> Void

    @State private var working: UIImage
    /// Crop rect in normalized image space (0–1, origin top-left).
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var baseCrop: CGRect?

    private let handle: CGFloat = 28
    private let minSize: CGFloat = 0.12

    init(image: UIImage, onComplete: @escaping (UIImage) -> Void) {
        self.image = image
        self.onComplete = onComplete
        _working = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frame = fittedRect(working.size, in: geo.size)
                let cropRect = viewRect(crop, in: frame)
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: working)
                        .resizable()
                        .scaledToFit()

                    // Dim everything outside the crop window. Stays in the
                    // GeometryReader's coordinate space (no ignoresSafeArea) so
                    // the punched-out hole aligns with the crop rect.
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .mask {
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(x: cropRect.midX, y: cropRect.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        }
                        .allowsHitTesting(false)

                    // Crop border + move handle.
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(frame))

                    // Corner resize handles.
                    ForEach(Corner.allCases, id: \.self) { corner in
                        Circle()
                            .fill(Color.white)
                            .frame(width: handle, height: handle)
                            .position(corner.point(in: cropRect))
                            .gesture(cornerGesture(corner, frame))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black)
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 40) {
                    Button { rotate(-1) } label: { Label("Rotate left", systemImage: "rotate.left") }
                    Button { rotate(1) } label: { Label("Rotate right", systemImage: "rotate.right") }
                    Button { crop = CGRect(x: 0, y: 0, width: 1, height: 1) } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: done).bold() }
            }
        }
    }

    private func rotate(_ quarters: Int) {
        working = ImageEditing.rotated(working, quartersClockwise: quarters)
        crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func done() {
        onComplete(ImageEditing.cropped(working, to: crop))
        dismiss()
    }

    private func moveGesture(_ frame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if baseCrop == nil { baseCrop = crop }
                var r = baseCrop!
                r.origin.x = min(max(0, r.origin.x + value.translation.width / frame.width), 1 - r.width)
                r.origin.y = min(max(0, r.origin.y + value.translation.height / frame.height), 1 - r.height)
                crop = r
            }
            .onEnded { _ in baseCrop = nil }
    }

    private func cornerGesture(_ corner: Corner, _ frame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if baseCrop == nil { baseCrop = crop }
                let dx = value.translation.width / frame.width
                let dy = value.translation.height / frame.height
                crop = clamp(corner.resize(baseCrop!, dx: dx, dy: dy))
            }
            .onEnded { _ in baseCrop = nil }
    }

    private func clamp(_ r: CGRect) -> CGRect {
        var c = r
        // Keep within [0,1] and enforce a minimum size.
        c.origin.x = min(max(0, c.origin.x), 1 - minSize)
        c.origin.y = min(max(0, c.origin.y), 1 - minSize)
        c.size.width = min(max(minSize, c.size.width), 1 - c.origin.x)
        c.size.height = min(max(minSize, c.size.height), 1 - c.origin.y)
        return c
    }

    /// The rect an aspect-fit image occupies within a container.
    private func fittedRect(_ imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func viewRect(_ norm: CGRect, in frame: CGRect) -> CGRect {
        CGRect(x: frame.minX + norm.minX * frame.width,
               y: frame.minY + norm.minY * frame.height,
               width: norm.width * frame.width,
               height: norm.height * frame.height)
    }

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
            case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }

        /// Resizes a normalized crop by moving this corner by (dx, dy).
        func resize(_ r: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
            var c = r
            switch self {
            case .topLeft:
                c.origin.x += dx; c.origin.y += dy; c.size.width -= dx; c.size.height -= dy
            case .topRight:
                c.origin.y += dy; c.size.width += dx; c.size.height -= dy
            case .bottomLeft:
                c.origin.x += dx; c.size.width -= dx; c.size.height += dy
            case .bottomRight:
                c.size.width += dx; c.size.height += dy
            }
            return c
        }
    }
}
