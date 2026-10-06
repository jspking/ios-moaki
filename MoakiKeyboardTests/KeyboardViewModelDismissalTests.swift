import CoreGraphics
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

@MainActor
final class KeyboardViewModelDismissalTests: XCTestCase {
    func testDismissalDoesNotInsertThePreviousCharacterAgain() {
        let viewModel = KeyboardViewModel()
        let delegate = DismissalSpyKeyboardDelegate()
        viewModel.delegate = delegate

        viewModel.inputConsonant(.ㅂ)
        viewModel.inputVowel(.ㅏ)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "바")

        viewModel.prepareForDismissal()
        viewModel.inputConsonant(.ㅈ)

        XCTAssertEqual(delegate.insertedTexts, [])
        XCTAssertEqual(delegate.composingUpdates.last?.previous, "")
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅈ")
    }

    func testDismissalClearsGestureState() {
        let viewModel = KeyboardViewModel()
        viewModel.gestureStarted(row: 1, column: 1, at: .zero)
        viewModel.gestureMoved(to: CGPoint(x: 0, y: -40))

        viewModel.prepareForDismissal()

        XCTAssertNil(viewModel.activeKey)
        XCTAssertNil(viewModel.previewVowel)
        XCTAssertNil(viewModel.gestureStartPoint)
        XCTAssertEqual(viewModel.gestureDirections, [])
        XCTAssertEqual(viewModel.composingText, "")
    }
}

@MainActor
private final class DismissalSpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var composingUpdates: [ComposingUpdate] = []

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() {}
    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }
    func triggerHapticFeedback() {}
}
