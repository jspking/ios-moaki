import Foundation
import CoreGraphics

class VowelResolver {
    private let patternTrie = VowelPattern.patternTrie
    private let longFirstStrokeTrie = VowelPattern.longFirstStrokeTrie

    private var longStrokeLength: CGFloat

    struct Resolution {
        let vowel: Jungseong?
        let hasMoreMatches: Bool
    }

    init(longStrokeLength: CGFloat = SharedKeyboardPreferences.defaultLongStrokeLength) {
        self.longStrokeLength = longStrokeLength
    }

    func configure(longStrokeLength: CGFloat) {
        self.longStrokeLength = longStrokeLength
    }

    func resolve(strokes: [GestureStroke]) -> Resolution {
        guard !strokes.isEmpty else {
            return Resolution(vowel: nil, hasMoreMatches: false)
        }

        let normalized = normalizeForMatching(strokes.map { $0.direction })

        if startsWithLongStroke(strokes),
           let resolution = resolveWithLongFirstStroke(normalized) {
            return resolution
        }

        let match = patternTrie.match(normalized)
        return Resolution(vowel: match.vowel, hasMoreMatches: match.hasLongerMatch)
    }

    /// Length-agnostic entry point. Every stroke is treated as short, so ㅡ, ㅣ
    /// and ㅢ are never produced.
    func resolve(directions: [GestureDirection]) -> Resolution {
        resolve(strokes: directions.map { GestureStroke(direction: $0, length: 0) })
    }

    // For real-time feedback during gesture
    func peekVowel(strokes: [GestureStroke]) -> Jungseong? {
        resolve(strokes: strokes).vowel
    }

    func peekVowel(directions: [GestureDirection]) -> Jungseong? {
        resolve(directions: directions).vowel
    }

    // Check if current directions could potentially match a vowel
    func hasPotentialMatch(strokes: [GestureStroke]) -> Bool {
        guard !strokes.isEmpty else { return false }
        let resolution = resolve(strokes: strokes)
        return resolution.vowel != nil || resolution.hasMoreMatches
    }

    func hasPotentialMatch(directions: [GestureDirection]) -> Bool {
        hasPotentialMatch(strokes: directions.map { GestureStroke(direction: $0, length: 0) })
    }

    private func startsWithLongStroke(_ strokes: [GestureStroke]) -> Bool {
        guard let first = strokes.first else { return false }
        return first.length >= longStrokeLength
    }

    /// A long-stroke pattern only wins when it accounts for the entire gesture.
    /// Otherwise the caller falls back to the length-agnostic table.
    private func resolveWithLongFirstStroke(_ normalized: [GestureDirection]) -> Resolution? {
        let match = longFirstStrokeTrie.match(normalized)
        guard let vowel = match.vowel, match.consumedCount == normalized.count else {
            return nil
        }
        return Resolution(vowel: vowel, hasMoreMatches: match.hasLongerMatch)
    }

    /// Normalization rules:
    /// 1. The first stroke's diagonals are canonicalized onto the vertical axis
    ///    (↖ ↗ → ↑, ↙ ↘ → ↓), so the tilt of a stroke never decides which vowel
    ///    it is — only its direction and length do.
    /// 2. From the second stroke onward, diagonals are mapped to a single cardinal axis.
    ///    A final diagonal that continues the previous vertical stroke stays vertical,
    ///    so natural finger drift does not become an unintended compound vowel.
    /// 3. Consecutive identical directions collapse into one stroke.
    private func normalizeForMatching(_ directions: [GestureDirection]) -> [GestureDirection] {
        guard !directions.isEmpty else { return [] }

        var normalized: [GestureDirection] = []
        normalized.reserveCapacity(directions.count)

        for (index, direction) in directions.enumerated() {
            let next: GestureDirection
            if index == 0 {
                next = normalizeFirstStroke(direction)
            } else {
                next = normalizeTrailingStroke(
                    direction,
                    previous: normalized.last,
                    hasFollowingStroke: index < directions.count - 1
                )
            }

            // Treat repeated same-direction segments as one stroke.
            if normalized.last != next {
                normalized.append(next)
            }
        }

        return normalized
    }

    private func normalizeFirstStroke(_ direction: GestureDirection) -> GestureDirection {
        switch direction {
        case .upLeft, .upRight:
            return .up
        case .downLeft, .downRight:
            return .down
        default:
            return direction
        }
    }

    private func normalizeTrailingStroke(_ direction: GestureDirection,
                                         previous: GestureDirection?,
                                         hasFollowingStroke: Bool) -> GestureDirection {
        guard direction.isDiagonal else { return direction }

        guard let (vertical, horizontal) = diagonalComponents(of: direction) else {
            return direction
        }

        guard let previous else {
            return vertical
        }

        // If the previous stroke is horizontal, keep the diagonal's horizontal intent.
        if previous == .left || previous == .right {
            return horizontal
        }

        // A terminal same-axis diagonal is usually natural drift while lifting the
        // finger. Keep it vertical unless another stroke confirms compound-vowel
        // intent (e.g. ↑↗← for ㅙ).
        if previous == vertical {
            return hasFollowingStroke ? horizontal : vertical
        }

        return vertical
    }

    private func diagonalComponents(of direction: GestureDirection) -> (vertical: GestureDirection, horizontal: GestureDirection)? {
        switch direction {
        case .upRight:
            return (.up, .right)
        case .upLeft:
            return (.up, .left)
        case .downRight:
            return (.down, .right)
        case .downLeft:
            return (.down, .left)
        default:
            return nil
        }
    }
}
