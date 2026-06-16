import SwiftUI

/// A circular progress ring for a 0–100 healing score.
struct ScoreRing: View {
    let score: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var caption: String? = "healed"

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, score / 100)))
                .stroke(score.scoreColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: score)
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        ScoreRing(score: 18)
        ScoreRing(score: 64, size: 80, lineWidth: 8)
        ScoreRing(score: 92)
    }
    .padding()
}
