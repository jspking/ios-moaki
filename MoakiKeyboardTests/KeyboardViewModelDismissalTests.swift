import CoreGraphics
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

@MainActor
final class KeyboardViewModelDismissalTests: XCTestCase {

    private var viewModel: KeyboardViewModel!
    private var delegate: DismissalSpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = DismissalSpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// A composing syllable is already real text in the document, because
    /// extensions cannot use marked text. If the composer keeps holding it
    /// after the keyboard goes away, the next key press commits it a second
    /// time and the letter appears twice.
    func testDismissalStopsTheComposingSyllableFromBeingInsertedTwice() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero) // ㅂ
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅂ")
        XCTAssertEqual(delegate.insertedTexts, [])

        viewModel.prepareForDismissal()

        viewModel.gestureStarted(row: 1, column: 2, at: .zero) // ㅈ
        viewModel.gestureEnded(row: 1, column: 2)

        XCTAssertEqual(delegate.insertedTexts, [], "ㅂ is already in the document")
        XCTAssertEqual(delegate.composingUpdates.last?.previous, "")
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅈ")
    }

    func testDismissalAlsoClearsGestureState() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero)
        viewModel.gestureMoved(to: CGPoint(x: 0, y: -40))

        viewModel.prepareForDismissal()

        XCTAssertNil(viewModel.activeKey)
        XCTAssertNil(viewModel.previewVowel)
    }
}

private final class DismissalSpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var composingUpdates: [ComposingUpdate] = []

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {}

    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }

    func triggerHapticFeedback() {}
}
