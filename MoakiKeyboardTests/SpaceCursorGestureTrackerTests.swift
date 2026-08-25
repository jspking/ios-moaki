import CoreGraphics
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class SpaceCursorGestureTrackerTests: XCTestCase {
    func testShortTapIsTheOnlyGestureThatInsertsSpace() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        XCTAssertEqual(tracker.touchDown(), .none)
        XCTAssertEqual(tracker.touchEnded(), .insertSpace)
        XCTAssertEqual(tracker.state, .idle)
    }

    func testCrossingDragThresholdSuppressesSpaceEvenAfterReturningToStart() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        _ = tracker.touchDown()
        XCTAssertEqual(tracker.dragChanged(translation: CGSize(width: 8, height: 0)), .none)
        XCTAssertEqual(tracker.dragChanged(translation: .zero), .none)

        XCTAssertEqual(tracker.touchEnded(), .none)
    }

    func testLongPressWithoutMovementNeverInsertsSpace() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        _ = tracker.touchDown()
        let generation = tracker.generation

        XCTAssertEqual(tracker.longPressFired(generation: generation), .cursorModeBegan)
        XCTAssertEqual(tracker.touchEnded(), .cursorModeEnded)
        XCTAssertEqual(tracker.state, .idle)
    }

    func testCursorModeForwardsTwoDimensionalTranslation() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        _ = tracker.touchDown()
        _ = tracker.longPressFired(generation: tracker.generation)

        let translation = CGSize(width: -28, height: 36)
        XCTAssertEqual(tracker.dragChanged(translation: translation), .moveCursor(translation))
    }

    func testLateTimerFromPreviousGestureCannotActivateNextGesture() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        _ = tracker.touchDown()
        let expiredGeneration = tracker.generation
        _ = tracker.touchEnded()
        _ = tracker.touchDown()

        XCTAssertEqual(tracker.longPressFired(generation: expiredGeneration), .none)
        XCTAssertEqual(tracker.state, .pressing)
    }

    func testCancellationEndsCursorModeAndInvalidatesTimerGeneration() {
        var tracker = SpaceCursorGestureTracker(dragThreshold: 8)

        _ = tracker.touchDown()
        let expiredGeneration = tracker.generation
        _ = tracker.longPressFired(generation: expiredGeneration)

        XCTAssertEqual(tracker.cancelled(), .cursorModeEnded)
        XCTAssertEqual(tracker.state, .idle)
        XCTAssertEqual(tracker.longPressFired(generation: expiredGeneration), .none)
    }
}
