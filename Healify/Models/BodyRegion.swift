import Foundation

/// A structured anatomical location for a wound, stored on `Wound` as Codable.
struct BodyRegion: Codable, Hashable, Identifiable {
    var part: BodyPart
    var side: BodySide
    var view: BodyView

    var id: String { "\(view.rawValue).\(side.rawValue).\(part.rawValue)" }

    /// e.g. "Right forearm", "Lower back", "Back of left hand".
    var displayName: String {
        switch part {
        case .chest, .abdomen, .pelvis, .upperBack, .lowerBack, .buttocks, .head, .neck:
            return part.label // torso parts already imply front/back
        default:
            let sided = side == .center ? part.label : "\(side.label) \(part.label.lowercasedFirst)"
            return view == .back ? "Back of \(sided.lowercasedFirst)" : sided.capitalizedFirst
        }
    }
}

enum BodySide: String, Codable, Hashable {
    case left, right, center
    var label: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .center: return ""
        }
    }
}

enum BodyView: String, Codable, Hashable, CaseIterable {
    case front, back
    var label: String { self == .front ? "Front" : "Back" }
}

enum BodyPart: String, Codable, Hashable, CaseIterable {
    case head, neck
    case chest, abdomen, pelvis      // front torso
    case upperBack, lowerBack, buttocks // back torso
    case upperArm, forearm, hand
    case thigh, shin, foot

    var label: String {
        switch self {
        case .head: return "Head"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .abdomen: return "Abdomen"
        case .pelvis: return "Pelvis"
        case .upperBack: return "Upper back"
        case .lowerBack: return "Lower back"
        case .buttocks: return "Buttocks"
        case .upperArm: return "Upper arm"
        case .forearm: return "Forearm"
        case .hand: return "Hand"
        case .thigh: return "Thigh"
        case .shin: return "Shin"
        case .foot: return "Foot"
        }
    }
}

extension String {
    var capitalizedFirst: String { isEmpty ? self : prefix(1).uppercased() + dropFirst() }
    var lowercasedFirst: String { isEmpty ? self : prefix(1).lowercased() + dropFirst() }
}
