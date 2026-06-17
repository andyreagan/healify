import SwiftUI

enum Format {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func dayTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// "Day 3" style label relative to a wound's first photo/creation.
    static func dayNumber(_ date: Date, since start: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: date).day ?? 0
        return "Day \(max(0, days))"
    }
}

extension Double {
    /// 0–100 healing score → traffic-light color.
    var scoreColor: Color {
        switch self {
        case ..<25: return .red
        case ..<50: return .orange
        case ..<75: return .yellow
        default: return .green
        }
    }
}

extension Int {
    /// Pain 0–10 → color (green calm → red severe).
    var painColor: Color {
        switch self {
        case ..<3: return .green
        case ..<6: return .yellow
        case ..<8: return .orange
        default: return .red
        }
    }
}
