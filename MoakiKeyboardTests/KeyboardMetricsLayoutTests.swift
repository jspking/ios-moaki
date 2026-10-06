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
        let vowelWidth = KeyboardMetrics.keyWidth(for: 6, row: 3, centerKeyWidth: centerWidth)
        let rowWidth = leftWidth
            + centerWidth * 4
            + backspaceWidth
            + vowelWidth
            + KeyboardMetrics.keySpacing * 6

        XCTAssertEqual(backspaceWidth, KeyboardMetrics.rightSymbolKeyWidth)
        XCTAssertEqual(KeyboardMetrics.keyContent(at: 3, column: 5, isSymbolMode: false), .backspace)
        XCTAssertEqual(KeyboardMetrics.keyContent(at: 3, column: 6, isSymbolMode: false), .vowelGesture)

        XCTAssertEqual(
            rowWidth,
            totalWidth - KeyboardMetrics.keySpacing * 2,
            accuracy: 0.001
        )
    }

    func testSymbolModeKeepsExpandedBackspace() {
        let centerWidth = KeyboardMetrics.centerKeyWidth(for: 375)
        XCTAssertEqual(KeyboardMetrics.columnCount(for: 3, isSymbolMode: true), 6)
        XCTAssertEqual(
            KeyboardMetrics.keyWidth(for: 5, row: 3, centerKeyWidth: centerWidth, isSymbolMode: true),
            KeyboardMetrics.rightSymbolKeyWidth + centerWidth + KeyboardMetrics.keySpacing
        )
    }

    // MARK: - Gesture Length Consistency

    /// The gesture length setting rescales the direction thresholds from the
    /// base value. These ratios live in SharedKeyboardPreferences because the
    /// app target does not compile KeyboardMetrics, so pin them here.
    func testGestureThresholdRatiosMatchKeyboardMetrics() {
        XCTAssertEqual(
            SharedKeyboardPreferences.defaultBaseGestureLength,
            KeyboardMetrics.gestureThreshold
        )
        XCTAssertEqual(
            KeyboardMetrics.gestureThreshold * SharedKeyboardPreferences.reversalThresholdRatio,
            KeyboardMetrics.reversalThreshold
        )
        XCTAssertEqual(
            KeyboardMetrics.gestureThreshold * SharedKeyboardPreferences.directionChangeThresholdRatio,
            KeyboardMetrics.directionChangeThreshold
        )
    }
}
