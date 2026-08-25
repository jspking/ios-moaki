import CoreGraphics
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class CursorMovementResolverTests: XCTestCase {
    func testHorizontalMovementUsesIncrementalThresholdsWithoutDuplicateSteps() {
        var resolver = CursorMovementResolver(horizontalStep: 14, verticalStep: 18)

        XCTAssertEqual(resolver.resolve(translation: CGSize(width: 13, height: 0)), .zero)
        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: 14, height: 0)),
            CursorMove(horizontalSteps: 1, verticalSteps: 0)
        )
        XCTAssertEqual(resolver.resolve(translation: CGSize(width: 14, height: 0)), .zero)
        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: 28, height: 0)),
            CursorMove(horizontalSteps: 1, verticalSteps: 0)
        )
    }

    func testDirectionReversalSettlesPendingMovement() {
        var resolver = CursorMovementResolver(horizontalStep: 14, verticalStep: 18)

        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: 20, height: 0)),
            CursorMove(horizontalSteps: 1, verticalSteps: 0)
        )
        XCTAssertEqual(
            resolver.resolve(translation: .zero),
            CursorMove(horizontalSteps: -1, verticalSteps: 0)
        )
    }

    func testDiagonalMovementResolvesBothAxes() {
        var resolver = CursorMovementResolver(horizontalStep: 14, verticalStep: 18)

        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: -28, height: 36)),
            CursorMove(horizontalSteps: -2, verticalSteps: 2)
        )
    }

    func testMovementPerUpdateIsCappedAndExcessIsDiscarded() {
        var resolver = CursorMovementResolver(
            horizontalStep: 14,
            verticalStep: 18,
            maximumStepsPerUpdate: 4
        )

        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: 140, height: 180)),
            CursorMove(horizontalSteps: 4, verticalSteps: 4)
        )
        XCTAssertEqual(
            resolver.resolve(translation: CGSize(width: 140, height: 180)),
            .zero
        )
    }

    func testExplicitNewlineMovesUpToSameLogicalColumn() {
        let resolver = CursorMovementResolver()

        XCTAssertEqual(
            resolver.verticalOffset(
                direction: .up,
                contextBefore: "abcd\nxy",
                contextAfter: ""
            ),
            -5
        )
    }

    func testExplicitNewlineMovesDownToSameLogicalColumn() {
        let resolver = CursorMovementResolver()

        XCTAssertEqual(
            resolver.verticalOffset(
                direction: .down,
                contextBefore: "ab",
                contextAfter: "cd\nwxyz"
            ),
            5
        )
    }

    func testShortAdjacentLinesClampToTheirLastValidColumn() {
        let resolver = CursorMovementResolver()

        XCTAssertEqual(
            resolver.verticalOffset(
                direction: .up,
                contextBefore: "ab\n12345",
                contextAfter: ""
            ),
            -6
        )
        XCTAssertEqual(
            resolver.verticalOffset(
                direction: .down,
                contextBefore: "12345",
                contextAfter: "\nab"
            ),
            3
        )
    }

    func testMissingLogicalLineUsesConfiguredFallbackDirection() {
        let resolver = CursorMovementResolver(verticalFallbackStride: 17)

        XCTAssertEqual(
            resolver.verticalOffset(direction: .up, contextBefore: "abc", contextAfter: nil),
            -17
        )
        XCTAssertEqual(
            resolver.verticalOffset(direction: .down, contextBefore: nil, contextAfter: "abc"),
            17
        )
    }

    func testDocumentEdgesDoNotRequestMovementPastBoundary() {
        let resolver = CursorMovementResolver(verticalFallbackStride: 17)

        XCTAssertEqual(
            resolver.verticalOffset(direction: .up, contextBefore: "", contextAfter: nil),
            0
        )
        XCTAssertEqual(
            resolver.verticalOffset(direction: .down, contextBefore: nil, contextAfter: ""),
            0
        )
    }

    func testLogicalColumnCountsExtendedGraphemeClusters() {
        let resolver = CursorMovementResolver()

        XCTAssertEqual(
            resolver.verticalOffset(
                direction: .up,
                contextBefore: "가👨‍👩‍👧‍👦\n나",
                contextAfter: ""
            ),
            -3
        )
    }
}
