import Foundation
import CoreGraphics

enum GestureDirection: String, CaseIterable {
    case up        // ↑
    case down      // ↓
    case left      // ←
    case right     // →
    case upLeft    // ↖
    case upRight   // ↗
    case downLeft  // ↙
    case downRight // ↘

    static func from(vector: CGVector, threshold: CGFloat = 20) -> GestureDirection? {
        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard magnitude >= threshold else { return nil }

        let angle = atan2(-vector.dy, vector.dx) // Negative dy because iOS y-axis is inverted
        let degrees = angle * 180 / .pi

        // Normalize to 0-360
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees

        // Keep a wider tolerance for vertical vowels on the screen-right side.
        // A vertical stroke may drift up to 20 degrees to the right and still
        // resolve as ㅗ/ㅜ, while deliberate 45-degree strokes remain ㅣ/ㅡ.
        switch normalizedDegrees {
        case 330...360, 0..<30:
            return .right
        case 30..<70:
            return .upRight
        case 70..<120:
            return .up
        case 120..<150:
            return .upLeft
        case 150..<210:
            return .left
        case 210..<240:
            return .downLeft
        case 240..<290:
            return .down
        case 290..<330:
            return .downRight
        default:
            return .right
        }
    }

    var symbol: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }

    var isCardinal: Bool {
        switch self {
        case .up, .down, .left, .right: return true
        default: return false
        }
    }

    var isDiagonal: Bool {
        !isCardinal
    }

    /// Check if two directions are exactly opposite (e.g., up↔down, left↔right)
    func isOpposite(to other: GestureDirection) -> Bool {
        switch (self, other) {
        case (.up, .down), (.down, .up),
             (.left, .right), (.right, .left),
             (.upLeft, .downRight), (.downRight, .upLeft),
             (.upRight, .downLeft), (.downLeft, .upRight):
            return true
        default:
            return false
        }
    }

    /// Check if two directions are adjacent (e.g., up and upRight are adjacent)
    func isAdjacentTo(_ other: GestureDirection) -> Bool {
        let adjacencyMap: [GestureDirection: Set<GestureDirection>] = [
            .up: [.upLeft, .upRight],
            .down: [.downLeft, .downRight],
            .left: [.upLeft, .downLeft],
            .right: [.upRight, .downRight],
            .upLeft: [.up, .left],
            .upRight: [.up, .right],
            .downLeft: [.down, .left],
            .downRight: [.down, .right]
        ]
        return adjacencyMap[self]?.contains(other) ?? false
    }
}
