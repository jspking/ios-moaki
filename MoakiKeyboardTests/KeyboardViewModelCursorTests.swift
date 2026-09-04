import CoreGraphics
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

@MainActor
final class KeyboardViewModelCursorTests: XCTestCase {
    func testCursorModeCommitsHangulBeforeMovementAndNextInputStartsFresh() {
        let viewModel = KeyboardViewModel()
        let delegate = CursorSpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        viewModel.beginCursorMovement()
        viewModel.moveCursor(translation: CGSize(width: 14, height: 0))
        viewModel.inputConsonant(.ㄴ)

        XCTAssertEqual(delegate.cursorOffsets, [1])
        XCTAssertEqual(delegate.composingUpdates.last, .init(previous: "", current: "ㄴ"))
    }

    func testEachVerticalStepReadsFreshDocumentContext() {
        let viewModel = KeyboardViewModel()
        let delegate = CursorSpyKeyboardDelegate()
        delegate.contextsBefore = ["abcd\nxy", "abc\nxy"]
        delegate.contextsAfter = ["", ""]
        viewModel.delegate = delegate

        viewModel.beginCursorMovement()
        viewModel.moveCursor(translation: CGSize(width: 0, height: -36))

        XCTAssertEqual(delegate.beforeReadCount, 2)
        XCTAssertEqual(delegate.afterReadCount, 2)
        XCTAssertEqual(delegate.cursorOffsets, [-5, -4])
    }

    func testDiagonalUpdateAppliesHorizontalAndVerticalMovement() {
        let viewModel = KeyboardViewModel()
        let delegate = CursorSpyKeyboardDelegate()
        delegate.contextsBefore = ["ab"]
        delegate.contextsAfter = ["cd\nwxyz"]
        viewModel.delegate = delegate

        viewModel.beginCursorMovement()
        viewModel.moveCursor(translation: CGSize(width: 14, height: 18))

        XCTAssertEqual(delegate.cursorOffsets, [1, 5])
    }

    func testEndingCursorModeClearsMovementRemainders() {
        let viewModel = KeyboardViewModel()
        let delegate = CursorSpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.beginCursorMovement()
        viewModel.moveCursor(translation: CGSize(width: 14, height: 0))
        viewModel.endCursorMovement()
        viewModel.beginCursorMovement()
        viewModel.moveCursor(translation: CGSize(width: 14, height: 0))

        XCTAssertEqual(delegate.cursorOffsets, [1, 1])
    }
}

private final class CursorSpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var composingUpdates: [ComposingUpdate] = []
    var cursorOffsets: [Int] = []
    var contextsBefore: [String?] = []
    var contextsAfter: [String?] = []
    private(set) var beforeReadCount = 0
    private(set) var afterReadCount = 0

    var documentContextBeforeInput: String? {
        defer { beforeReadCount += 1 }
        return contextsBefore.indices.contains(beforeReadCount) ? contextsBefore[beforeReadCount] : nil
    }

    var documentContextAfterInput: String? {
        defer { afterReadCount += 1 }
        return contextsAfter.indices.contains(afterReadCount) ? contextsAfter[afterReadCount] : nil
    }

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {}

    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }

    func triggerHapticFeedback() {}

    func moveCursor(byCharacterOffset offset: Int) {
        cursorOffsets.append(offset)
    }
}
