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

    /// Axis angle each direction is centred on, in the 0-360 space where
    /// right is 0, up is 90, left is 180 and down is 270.
    var axisDegrees: CGFloat {
        switch self {
        case .right: return 0
        case .upRight: return 45
        case .up: return 90
        case .upLeft: return 135
        case .left: return 180
        case .downLeft: return 225
        case .down: return 270
        case .downRight: return 315
        }
    }

    /// Vertical directions come first so a stroke that sits exactly between two
    /// axes resolves to ㅗ/ㅜ, the pair users most often miss.
    private static let cardinals: [GestureDirection] = [.up, .down, .right, .left]
    private static let diagonals: [GestureDirection] = [.upRight, .upLeft, .downLeft, .downRight]

    /// Classify a stroke by angle alone. Each cardinal axis owns a symmetric
    /// window of `KeyboardMetrics.cardinalHalfAngle` degrees on either side of
    /// it, and the diagonals own the wedges left in between.
    static func from(vector: CGVector, threshold: CGFloat = KeyboardMetrics.gestureThreshold) -> GestureDirection? {
        guard magnitude(of: vector) >= threshold else { return nil }
        return at(degrees: degrees(of: vector))
    }

    /// Classify a stroke by angle and length together.
    ///
    /// ㅣ(↗) and ㅡ(↘) are the only vowels a diagonal stands for, and they are
    /// reached by a deliberately long drag: a stroke that lands in a diagonal
    /// wedge but has not travelled `diagonalThreshold` yet resolves to whichever
    /// cardinal it is closest to. Left diagonals have no vowel of their own, so
    /// they always resolve to their nearest cardinal and length never matters
    /// for them.
    static func from(vector: CGVector,
                     threshold: CGFloat,
                     diagonalThreshold: CGFloat) -> GestureDirection? {
        guard let direction = from(vector: vector, threshold: threshold) else { return nil }
        guard direction.isDiagonal else { return direction }

        let isVowelBearingDiagonal = direction == .upRight || direction == .downRight
        if isVowelBearingDiagonal && magnitude(of: vector) >= diagonalThreshold - distanceSlack {
            return direction
        }
        return nearestCardinal(toDegrees: degrees(of: vector))
    }

    /// A stroke sampled from a touch path never lands exactly on a boundary, so
    /// comparisons are made with this slack. It keeps a stroke drawn on an axis
    /// boundary from flipping between two vowels run to run.
    private static let angleSlack: CGFloat = 0.5
    /// The same idea for the length gate, in points.
    private static let distanceSlack: CGFloat = 0.5

    /// The cardinal whose axis is closest to `degrees`, ties going to ㅗ/ㅜ.
    static func nearestCardinal(toDegrees degrees: CGFloat) -> GestureDirection {
        nearest(among: cardinals, toDegrees: degrees)
    }

    /// The direction owning `degrees` under the symmetric window rule.
    static func at(degrees: CGFloat) -> GestureDirection {
        let halfAngle = KeyboardMetrics.cardinalHalfAngle
        for cardinal in cardinals
        where angularDistance(cardinal.axisDegrees, degrees) <= halfAngle + angleSlack {
            return cardinal
        }
        return nearest(among: diagonals, toDegrees: degrees)
    }

    /// Closest axis among `candidates`, with ties resolved by their order.
    private static func nearest(among candidates: [GestureDirection], toDegrees degrees: CGFloat) -> GestureDirection {
        var best = candidates[0]
        var bestDistance = angularDistance(best.axisDegrees, degrees)

        for candidate in candidates.dropFirst() {
            let distance = angularDistance(candidate.axisDegrees, degrees)
            if distance < bestDistance - angleSlack {
                best = candidate
                bestDistance = distance
            }
        }

        return best
    }

    static func magnitude(of vector: CGVector) -> CGFloat {
        sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
    }

    /// Stroke angle in the 0-360 space. iOS y grows downwards, hence the sign flip.
    private static func degrees(of vector: CGVector) -> CGFloat {
        let radians = atan2(-vector.dy, vector.dx)
        let degrees = radians * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// Shortest angle between two bearings, always 0...180.
    private static func angularDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
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
