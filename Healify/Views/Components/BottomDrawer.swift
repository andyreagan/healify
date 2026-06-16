import SwiftUI

/// A lightweight Maps-style draggable bottom drawer that lives *inside* the view
/// hierarchy (not a system sheet), so NavigationLinks in its content push on the
/// same NavigationStack. Snaps between a collapsed peek and an expanded panel.
struct BottomDrawer<Content: View>: View {
    @Binding var expanded: Bool
    /// Peek height when collapsed.
    var minHeight: CGFloat = 130
    /// Fraction of the container height when expanded.
    var maxFraction: CGFloat = 0.86
    @ViewBuilder var content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height * maxFraction
            let target = expanded ? maxHeight : minHeight
            let height = min(maxHeight, max(minHeight, target - dragTranslation))

            VStack(spacing: 0) {
                handle
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geo.size.width, height: height, alignment: .top)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expanded)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var handle: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    // Up = expand, down = collapse (with a small velocity assist).
                    let projected = value.translation.height + value.predictedEndTranslation.height * 0.2
                    if projected < -40 { expanded = true }
                    else if projected > 40 { expanded = false }
                }
        )
        .onTapGesture { expanded.toggle() }
    }
}
