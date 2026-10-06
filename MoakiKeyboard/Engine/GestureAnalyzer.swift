import Foundation
import CoreGraphics

/// One stroke of a key gesture: the direction the finger travelled and how far
/// it actually went. `length` is the straight-line distance from where the
/// stroke began to the farthest point it reached, so a deliberate long drag can
/// be told apart from a short flick in the same direction.
struct GestureStroke: Equatable {
    let direction: GestureDirection
    let length: CGFloat
}

class GestureAnalyzer {
    private struct DirectionSegment {
        var direction: GestureDirection
        /// Distance measured at the moment the direction was recognized.
        /// The jitter heuristics are tuned against this value, so it stays
        /// separate from the stroke span below.
        var magnitude: CGFloat
        var startPoint: CGPoint
        /// Farthest point reached while this stroke was active.
        var farthestPoint: CGPoint

        var length: CGFloat {
            GestureAnalyzer.distance(from: startPoint, to: farthestPoint)
        }
    }

    private var touchPoints: [CGPoint] = []
    private var directions: [GestureDirection] = []
    private var directionMagnitudes: [CGFloat] = []
    private var strokeStartPoints: [CGPoint] = []
    private var strokeFarthestPoints: [CGPoint] = []
    private var lastDirectionChangePoint: CGPoint?

    private var threshold: CGFloat
    private var reversalThreshold: CGFloat
    private var directionChangeThreshold: CGFloat

    init(threshold: CGFloat = KeyboardMetrics.gestureThreshold,
         reversalThreshold: CGFloat = KeyboardMetrics.reversalThreshold,
         directionChangeThreshold: CGFloat = KeyboardMetrics.directionChangeThreshold) {
        self.threshold = threshold
        self.reversalThreshold = reversalThreshold
        self.directionChangeThreshold = directionChangeThreshold
    }

    /// Rescale every threshold from the single user-facing base length, keeping
    /// the ratios the defaults were tuned with.
    func configure(baseLength: CGFloat) {
        threshold = baseLength
        reversalThreshold = baseLength * SharedKeyboardPreferences.reversalThresholdRatio
        directionChangeThreshold = baseLength * SharedKeyboardPreferences.directionChangeThresholdRatio
    }

    func reset() {
        touchPoints.removeAll()
        directions.removeAll()
        directionMagnitudes.removeAll()
        strokeStartPoints.removeAll()
        strokeFarthestPoints.removeAll()
        lastDirectionChangePoint = nil
    }

    func addPoint(_ point: CGPoint) {
        touchPoints.append(point)
        analyzeLatestMovement()
    }

    func getDirections() -> [GestureDirection] {
        return directions
    }

    /// In-progress strokes, for live gesture feedback. Unlike `finalizeStrokes()`
    /// this skips jitter cleanup, matching how `getDirections()` behaves.
    func getStrokes() -> [GestureStroke] {
        currentSegments().map { GestureStroke(direction: $0.direction, length: $0.length) }
    }

    func getStartPoint() -> CGPoint? {
        return touchPoints.first
    }

    private func analyzeLatestMovement() {
        guard touchPoints.count >= 2 else { return }

        let referencePoint = lastDirectionChangePoint ?? touchPoints.first!
        let currentPoint = touchPoints.last!

        let vector = CGVector(
            dx: currentPoint.x - referencePoint.x,
            dy: currentPoint.y - referencePoint.y
        )

        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)

        // Try detecting direction with standard threshold first
        var newDirection = GestureDirection.from(vector: vector, threshold: threshold)

        // If standard threshold fails, try lower reversal threshold for opposite directions
        if newDirection == nil, let lastDirection = directions.last, magnitude >= reversalThreshold {
            if let candidate = GestureDirection.from(vector: vector, threshold: reversalThreshold),
               candidate.isOpposite(to: lastDirection) {
                newDirection = candidate
            }
        }

        guard let newDirection else {
            extendCurrentStroke(to: currentPoint)
            return
        }

        // Check if this is a new direction or continuation
        if let lastDirection = directions.last {
            // Only add if direction changed
            if newDirection != lastDirection {
                // Make sure we've moved enough from the last direction change
                if magnitude >= directionChangeThreshold || (newDirection.isOpposite(to: lastDirection) && magnitude >= reversalThreshold) {
                    beginStroke(newDirection, magnitude: magnitude, from: referencePoint, to: currentPoint)
                } else {
                    extendCurrentStroke(to: currentPoint)
                }
            } else {
                // Same direction continuing: this is where a long stroke grows.
                extendCurrentStroke(to: currentPoint)
            }
        } else {
            // First direction
            beginStroke(newDirection, magnitude: magnitude, from: referencePoint, to: currentPoint)
        }
    }

    private func beginStroke(_ direction: GestureDirection,
                             magnitude: CGFloat,
                             from startPoint: CGPoint,
                             to currentPoint: CGPoint) {
        directions.append(direction)
        directionMagnitudes.append(magnitude)
        strokeStartPoints.append(startPoint)
        strokeFarthestPoints.append(currentPoint)
        lastDirectionChangePoint = currentPoint
    }

    /// Grow the active stroke's span. Uses the farthest point rather than the
    /// latest one so a stroke's length does not shrink while the finger turns
    /// back for the next stroke.
    private func extendCurrentStroke(to point: CGPoint) {
        guard let index = strokeStartPoints.indices.last else { return }

        let startPoint = strokeStartPoints[index]
        let travelled = Self.distance(from: startPoint, to: point)
        let recorded = Self.distance(from: startPoint, to: strokeFarthestPoints[index])

        if travelled > recorded {
            strokeFarthestPoints[index] = point
        }
    }

    private func currentSegments() -> [DirectionSegment] {
        directions.indices.map { index in
            DirectionSegment(
                direction: directions[index],
                magnitude: directionMagnitudes[index],
                startPoint: strokeStartPoints[index],
                farthestPoint: strokeFarthestPoints[index]
            )
        }
    }

    func finalizeGesture() -> [GestureDirection] {
        finalizeStrokes().map { $0.direction }
    }

    func finalizeStrokes() -> [GestureStroke] {
        normalizeSegments(currentSegments())
            .map { GestureStroke(direction: $0.direction, length: $0.length) }
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
                // Merged strokes span from the first start to the last extent.
                result[result.count - 1].farthestPoint = segment.farthestPoint
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
                // The jitter split one real stroke in two; span the whole thing
                // so a long drag is not mistaken for a short one.
                result[index - 1].farthestPoint = next.farthestPoint
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

    fileprivate static func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
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
