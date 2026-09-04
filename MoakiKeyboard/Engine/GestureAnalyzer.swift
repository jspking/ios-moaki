import Foundation
import CoreGraphics

class GestureAnalyzer {
    private struct DirectionSegment {
        var direction: GestureDirection
        var magnitude: CGFloat
    }

    private var touchPoints: [CGPoint] = []
    private var directions: [GestureDirection] = []
    private var directionMagnitudes: [CGFloat] = []
    private var lastDirectionChangePoint: CGPoint?
    /// Angle-only reading of the opening stroke, kept so the stroke can be
    /// re-judged as it lengthens without mistaking a turn for growth.
    private var openingStrokeBearing: GestureDirection?
    /// Longest the opening stroke has been so far, so a finger coming back
    /// towards the start is never mistaken for the stroke still growing.
    private var openingStrokeLength: CGFloat = 0

    private let threshold: CGFloat
    private let reversalThreshold: CGFloat
    private let directionChangeThreshold: CGFloat
    private let diagonalThreshold: CGFloat

    init(threshold: CGFloat = KeyboardMetrics.gestureThreshold,
         reversalThreshold: CGFloat = KeyboardMetrics.reversalThreshold,
         directionChangeThreshold: CGFloat = KeyboardMetrics.directionChangeThreshold,
         diagonalThreshold: CGFloat = KeyboardMetrics.diagonalThreshold) {
        self.threshold = threshold
        self.reversalThreshold = reversalThreshold
        self.directionChangeThreshold = directionChangeThreshold
        self.diagonalThreshold = diagonalThreshold
    }

    func reset() {
        touchPoints.removeAll()
        directions.removeAll()
        directionMagnitudes.removeAll()
        lastDirectionChangePoint = nil
        openingStrokeBearing = nil
        openingStrokeLength = 0
    }

    func addPoint(_ point: CGPoint) {
        touchPoints.append(point)
        analyzeLatestMovement()
    }

    func getDirections() -> [GestureDirection] {
        return directions
    }

    func getStartPoint() -> CGPoint? {
        return touchPoints.first
    }

    private func analyzeLatestMovement() {
        guard touchPoints.count >= 2 else { return }

        let currentPoint = touchPoints.last!

        guard let lastDirection = directions.last else {
            recordOpeningStroke(endingAt: currentPoint)
            return
        }

        let isOpeningStrokeGrowing = reviseOpeningStroke(endingAt: currentPoint)

        let referencePoint = lastDirectionChangePoint ?? touchPoints.first!
        let vector = CGVector(
            dx: currentPoint.x - referencePoint.x,
            dy: currentPoint.y - referencePoint.y
        )
        let magnitude = GestureDirection.magnitude(of: vector)

        // Try detecting direction with standard threshold first
        var newDirection = GestureDirection.from(vector: vector, threshold: threshold)

        // If standard threshold fails, try lower reversal threshold for opposite directions
        if newDirection == nil, magnitude >= reversalThreshold {
            if let candidate = GestureDirection.from(vector: vector, threshold: reversalThreshold),
               candidate.isOpposite(to: lastDirection) {
                newDirection = candidate
            }
        }

        guard let newDirection else { return }

        // Nothing has turned yet, so keep the turn reference near the finger.
        // Left behind at the point where the opening stroke was first
        // recognised, a later turn gets measured across the whole remaining
        // stroke and reads as a diagonal rather than the turn it is.
        //
        // The recent movement has to agree with the opening bearing as well.
        // The middle stroke of ㅙ(↑→←) and ㅞ(↓←→) arrives while the path from
        // the origin still points the way it started, and it must not be
        // mistaken for the opening stroke simply carrying on.
        if isOpeningStrokeGrowing && newDirection == openingStrokeBearing {
            lastDirectionChangePoint = currentPoint
            return
        }

        // Only add if direction changed
        if newDirection != lastDirection {
            // Make sure we've moved enough from the last direction change
            if magnitude >= directionChangeThreshold || (newDirection.isOpposite(to: lastDirection) && magnitude >= reversalThreshold) {
                directions.append(newDirection)
                directionMagnitudes.append(magnitude)
                lastDirectionChangePoint = currentPoint
            }
        }
    }

    /// The opening stroke is judged by angle and length together, so a drag that
    /// sits in a diagonal wedge starts out as the nearest basic vowel and only
    /// becomes ㅣ/ㅡ once it is long enough.
    private func recordOpeningStroke(endingAt currentPoint: CGPoint) {
        let vector = strokeVector(endingAt: currentPoint)
        guard let direction = GestureDirection.from(vector: vector,
                                                    threshold: threshold,
                                                    diagonalThreshold: diagonalThreshold) else {
            return
        }

        directions.append(direction)
        directionMagnitudes.append(GestureDirection.magnitude(of: vector))
        openingStrokeBearing = GestureDirection.from(vector: vector, threshold: threshold)
        openingStrokeLength = GestureDirection.magnitude(of: vector)
        lastDirectionChangePoint = currentPoint
    }

    /// While the opening stroke is the only one recorded it stays revisable,
    /// because the finger may still cross `diagonalThreshold` and turn ㅗ into ㅣ.
    /// Measuring from the touch origin every sample keeps the verdict current
    /// right up to the moment the finger lifts.
    ///
    /// The stroke only counts as still growing while it points the same way it
    /// started and keeps getting longer. A turn such as ㅘ(↑→) swings the angle
    /// away from that bearing, and a reversal such as ㅚ(↑↓) shortens the stroke,
    /// so both fall through to the direction-change logic.
    private func reviseOpeningStroke(endingAt currentPoint: CGPoint) -> Bool {
        guard directions.count == 1, let bearing = openingStrokeBearing else { return false }

        let vector = strokeVector(endingAt: currentPoint)
        let length = GestureDirection.magnitude(of: vector)

        guard length > openingStrokeLength,
              GestureDirection.from(vector: vector, threshold: threshold) == bearing,
              let revised = GestureDirection.from(vector: vector,
                                                  threshold: threshold,
                                                  diagonalThreshold: diagonalThreshold) else {
            return false
        }

        directions[0] = revised
        directionMagnitudes[0] = length
        openingStrokeLength = length
        return true
    }

    private func strokeVector(endingAt currentPoint: CGPoint) -> CGVector {
        let startPoint = touchPoints.first ?? currentPoint
        return CGVector(dx: currentPoint.x - startPoint.x, dy: currentPoint.y - startPoint.y)
    }

    func finalizeGesture() -> [GestureDirection] {
        let segments = zip(directions, directionMagnitudes).map {
            DirectionSegment(direction: $0.0, magnitude: $0.1)
        }
        return normalizeSegments(segments).map { $0.direction }
    }

    /// Keep intentional turns for 3-stroke gestures (important for ㅙ/ㅞ),
    /// while removing duplicate and jitter-only segments.
    private func normalizeSegments(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var collapsed = collapseConsecutiveDuplicates(segments)
        collapsed = collapseTinyOscillations(collapsed)
        collapsed = trimTinyLeadingAndTrailingNoise(collapsed)
        return collapsed
    }

    private func collapseConsecutiveDuplicates(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [DirectionSegment] = [segments[0]]
        for segment in segments.dropFirst() {
            if segment.direction == result.last?.direction {
                if segment.magnitude > (result.last?.magnitude ?? 0) {
                    result[result.count - 1].magnitude = segment.magnitude
                }
                continue
            }
            result.append(segment)
        }
        return result
    }

    private func collapseTinyOscillations(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count >= 3 else { return segments }

        var result = segments
        var index = 1

        let jitterMagnitudeCap = max(reversalThreshold, directionChangeThreshold * 0.8)
        let jitterRatio: CGFloat = 0.75

        while index < result.count - 1 {
            let previous = result[index - 1]
            let current = result[index]
            let next = result[index + 1]

            let returnsToPrevious = previous.direction == next.direction
            let isAdjacentJitter = current.direction.isAdjacentTo(previous.direction)
            let isTinySegment = current.magnitude <= jitterMagnitudeCap ||
                current.magnitude <= min(previous.magnitude, next.magnitude) * jitterRatio

            if returnsToPrevious && isAdjacentJitter && isTinySegment {
                result[index - 1].magnitude = max(previous.magnitude, next.magnitude)
                result.remove(at: index + 1)
                result.remove(at: index)
                if index > 1 {
                    index -= 1
                }
                continue
            }

            index += 1
        }

        return result
    }

    private func trimTinyLeadingAndTrailingNoise(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count > 1 else { return segments }

        var result = segments
        let edgeNoiseCap = max(reversalThreshold, directionChangeThreshold * 0.8)

        if let first = result.first, let second = result.dropFirst().first {
            if first.magnitude <= edgeNoiseCap && first.direction.isAdjacentTo(second.direction) {
                result.removeFirst()
            }
        }

        if result.count > 1, let last = result.last, let previous = result.dropLast().last {
            if last.magnitude <= edgeNoiseCap && last.direction.isAdjacentTo(previous.direction) {
                result.removeLast()
            }
        }

        return result
    }
}

// Extension to help with gesture visualization
extension GestureAnalyzer {
    var directionString: String {
        directions.map { $0.symbol }.joined()
    }

    var hasGesture: Bool {
        !directions.isEmpty
    }
}
