import XCTest

@testable import MoakiKeyboardCore

final class KeyboardMetricsLayoutTests: XCTestCase {
    func testRightEdgeSymbolUsesFullSizeTouchTarget() {
        let centerWidth = KeyboardMetrics.centerKeyWidth(for: 375)

        XCTAssertEqual(
            KeyboardMetrics.keyWidth(for: 6, row: 0, centerKeyWidth: centerWidth),
            44
        )
        XCTAssertGreaterThan(centerWidth, 44)
    }

    func testSevenColumnRowsStillFitAvailableKeyboardWidth() {
        let totalWidth: CGFloat = 375
        let centerWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        let leftWidth = KeyboardMetrics.keyWidth(for: 0, row: 0, centerKeyWidth: centerWidth)
        let rightWidth = KeyboardMetrics.keyWidth(for: 6, row: 0, centerKeyWidth: centerWidth)
        let rowWidth = leftWidth
            + centerWidth * 5
            + rightWidth
            + KeyboardMetrics.keySpacing * 6

        XCTAssertEqual(
            rowWidth,
            totalWidth - KeyboardMetrics.keySpacing * 2,
            accuracy: 0.001
        )
    }

    func testBackspaceRowMatchesSevenColumnRowWidth() {
        let totalWidth: CGFloat = 375
        let centerWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        let leftWidth = KeyboardMetrics.keyWidth(for: 0, row: 3, centerKeyWidth: centerWidth)
        let backspaceWidth = KeyboardMetrics.keyWidth(for: 5, row: 3, centerKeyWidth: centerWidth)
        let rowWidth = leftWidth
            + centerWidth * 4
            + backspaceWidth
            + KeyboardMetrics.keySpacing * 5

        XCTAssertEqual(
            rowWidth,
            totalWidth - KeyboardMetrics.keySpacing * 2,
            accuracy: 0.001
        )
    }
}
