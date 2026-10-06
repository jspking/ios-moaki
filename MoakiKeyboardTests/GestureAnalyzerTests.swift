import XCTest
#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class GestureAnalyzerTests: XCTestCase {

    // MARK: - Reversal Threshold Tests

    func testReversalDetectedAtLowerThreshold() {
        // With reversalThreshold=10, opposite direction change should be detected at 10px
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px (above threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up (iOS y-axis: lower y = up)

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Now reverse down by only 12px from direction change point (above reversal=10, below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down], "Opposite reversal should be detected at reversal threshold (10px)")
    }

    func testNonReversalRequiresFullThreshold() {
        // Non-opposite direction changes should still require the full threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Try to move right by only 12px (non-opposite direction, below threshold=20)
        analyzer.addPoint(CGPoint(x: 112, y: 75))  // 12px right from direction change point

        XCTAssertEqual(analyzer.getDirections(), [.up], "Non-opposite direction change should require full threshold")
    }

    func testTripleReversalForYoVowel() {
        // Simulate ㅛ gesture: up → down → up with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Second direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down])

        // Third direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 12px up from y=87

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.up, .down, .up], "Triple reversal should produce ㅛ pattern (↑↓↑)")
    }

    func testTripleReversalForYuVowel() {
        // Simulate ㅠ gesture: down → up → down with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: down 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 25px down

        XCTAssertEqual(analyzer.getDirections(), [.down])

        // Second direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 113))  // 12px up from y=125

        XCTAssertEqual(analyzer.getDirections(), [.down, .up])

        // Third direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 12px down from y=113

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.down, .up, .down], "Triple reversal should produce ㅠ pattern (↓↑↓)")
    }

    func testFirstDirectionAlwaysRequiresFullThreshold() {
        // First direction should always need the full threshold, never reversal threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Move only 12px (above reversal=10 but below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 88))  // 12px up

        XCTAssertEqual(analyzer.getDirections(), [], "First direction should require full threshold")
    }

    // MARK: - Deliberate Turn Threshold Tests

    func testDefaultTurnThresholdIgnoresShortRightHookAfterUp() {
        let analyzer = GestureAnalyzer()

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // ↑ 25px
        analyzer.addPoint(CGPoint(x: 125, y: 75))  // → 25px, below turn threshold

        XCTAssertEqual(analyzer.finalizeGesture(), [.up])
    }

    func testDefaultTurnThresholdKeepsClearRightTurnAfterUp() {
        let analyzer = GestureAnalyzer()

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // ↑ 25px
        analyzer.addPoint(CGPoint(x: 131, y: 75))  // → 31px, deliberate turn

        XCTAssertEqual(analyzer.finalizeGesture(), [.up, .right])
    }

    // MARK: - Opening Stroke Length Tests

    /// The complaint behind this rule: a vertical drag that leans to the right
    /// used to tip over into ㅣ. It now stays ㅗ however far the finger travels.
    func testVerticalStrokeLeaningRightStaysUpAtAnyLength() {
        for length in [CGFloat(30), 60, 90, 140] {
            let analyzer = GestureAnalyzer()
            feed(analyzer, degrees: 65, length: length)
            XCTAssertEqual(analyzer.finalizeGesture(), [.up], "\(length)pt")
        }
    }

    func testLongVerticalStrokeIsNeverPromotedToADiagonal() {
        let analyzer = GestureAnalyzer()
        feed(analyzer, degrees: 90, length: 140)
        XCTAssertEqual(analyzer.finalizeGesture(), [.up])
    }

    func testOpeningDiagonalStaysBasicUntilItPassesTheDiagonalThreshold() {
        let analyzer = GestureAnalyzer()
        feed(analyzer, degrees: 45, length: KeyboardMetrics.diagonalThreshold - 5)
        XCTAssertEqual(analyzer.finalizeGesture(), [.up])
    }

    func testOpeningDiagonalIsRejudgedAsTheFingerKeepsTravelling() {
        let analyzer = GestureAnalyzer()
        feed(analyzer, degrees: 45, length: 30)
        XCTAssertEqual(analyzer.getDirections(), [.up], "short diagonal starts out as ㅗ")

        feed(analyzer, degrees: 45, length: 60, from: 30)
        XCTAssertEqual(analyzer.finalizeGesture(), [.upRight], "and is revised once it is long enough")
    }

    func testLongDownRightStrokeBecomesTheDiagonalForEu() {
        let analyzer = GestureAnalyzer()
        feed(analyzer, degrees: 315, length: 90)
        XCTAssertEqual(analyzer.finalizeGesture(), [.downRight])
    }

    /// Revising the opening stroke must not eat a genuine turn, or ㅘ would
    /// collapse into a single stroke.
    func testTurnAfterTheOpeningStrokeSurvivesTheRevision() {
        let analyzer = GestureAnalyzer()
        analyzer.addPoint(CGPoint(x: 100, y: 200))
        analyzer.addPoint(CGPoint(x: 100, y: 140))   // ↑ 60px, past the diagonal threshold
        analyzer.addPoint(CGPoint(x: 145, y: 140))   // → 45px, deliberate turn

        XCTAssertEqual(analyzer.finalizeGesture(), [.up, .right])
    }

    // MARK: - Finalize Gesture Normalization Tests

    func testFinalizeKeepsMeaningfulMiddleDiagonalForThreeStrokeTurn() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 126))   // ↓
        analyzer.addPoint(CGPoint(x: 122, y: 148))   // ↘
        analyzer.addPoint(CGPoint(x: 96, y: 148))    // ←

        XCTAssertEqual(analyzer.getDirections(), [.down, .downRight, .left])
        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    func testFinalizeCollapsesTinyDiagonalJitterWhenPathReturnsToSameDirection() {
        let analyzer = GestureAnalyzer(threshold: 8, reversalThreshold: 6, directionChangeThreshold: 8)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))    // ↑
        analyzer.addPoint(CGPoint(x: 109, y: 61))    // small ↗ jitter
        analyzer.addPoint(CGPoint(x: 109, y: 35))    // back to ↑, clearly longer than the jitter

        XCTAssertEqual(analyzer.getDirections(), [.up, .upRight, .up])
        XCTAssertEqual(analyzer.finalizeGesture(), [.up])
    }

    func testFinalizeKeepsDownRightLeftSequenceForWePattern() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 128))   // ↓
        analyzer.addPoint(CGPoint(x: 124, y: 152))   // ↘
        analyzer.addPoint(CGPoint(x: 98, y: 152))    // ←

        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    // MARK: - isOpposite Tests

    func testIsOpposite() {
        XCTAssertTrue(GestureDirection.up.isOpposite(to: .down))
        XCTAssertTrue(GestureDirection.down.isOpposite(to: .up))
        XCTAssertTrue(GestureDirection.left.isOpposite(to: .right))
        XCTAssertTrue(GestureDirection.right.isOpposite(to: .left))
        XCTAssertTrue(GestureDirection.upLeft.isOpposite(to: .downRight))
        XCTAssertTrue(GestureDirection.downRight.isOpposite(to: .upLeft))
        XCTAssertTrue(GestureDirection.upRight.isOpposite(to: .downLeft))
        XCTAssertTrue(GestureDirection.downLeft.isOpposite(to: .upRight))
    }

    func testIsNotOpposite() {
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .right))
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.downRight.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.left.isOpposite(to: .downLeft))
    }

    // MARK: - Reversal Detection Tests

    func testReversalIsJudgedByAngleNotByExactOppositeBuckets() {
        XCTAssertTrue(GestureDirection.up.isReversal(of: .down))
        XCTAssertTrue(GestureDirection.right.isReversal(of: .left))
        XCTAssertTrue(GestureDirection.right.isReversal(of: .upLeft), "135° apart still doubles back")
        XCTAssertTrue(GestureDirection.up.isReversal(of: .downRight))
        XCTAssertTrue(GestureDirection.down.isReversal(of: .upLeft))
    }

    func testPerpendicularAndAdjacentTurnsAreNotReversals() {
        XCTAssertFalse(GestureDirection.up.isReversal(of: .left))
        XCTAssertFalse(GestureDirection.up.isReversal(of: .right))
        XCTAssertFalse(GestureDirection.up.isReversal(of: .upRight))
        XCTAssertFalse(GestureDirection.right.isReversal(of: .downRight))
    }

    /// A return stroke that comes back a little off the outgoing line used to
    /// fall out of the opposite-bucket test and need the full turn distance.
    func testSkewedReturnStrokeKeepsTheLowerReversalThreshold() {
        let analyzer = GestureAnalyzer()
        analyzer.addPoint(CGPoint(x: 150, y: 250))
        analyzer.addPoint(CGPoint(x: 210, y: 250))   // → 60px
        analyzer.addPoint(CGPoint(x: 189, y: 264))   // 215°, 25px: under the turn threshold

        XCTAssertEqual(analyzer.getDirections(), [.right, .downLeft])
    }

    // MARK: - Helpers

    /// Feed a straight drag sampled every few points, the way a finger reports.
    private func feed(_ analyzer: GestureAnalyzer,
                      degrees: CGFloat,
                      length: CGFloat,
                      from startLength: CGFloat = 0,
                      origin: CGPoint = CGPoint(x: 150, y: 250),
                      step: CGFloat = 4) {
        let radians = degrees * .pi / 180
        if startLength == 0 {
            analyzer.addPoint(origin)
        }
        var travelled = startLength
        while travelled < length {
            travelled = min(travelled + step, length)
            analyzer.addPoint(CGPoint(
                x: origin.x + cos(radians) * travelled,
                y: origin.y - sin(radians) * travelled
            ))
        }
    }
}
