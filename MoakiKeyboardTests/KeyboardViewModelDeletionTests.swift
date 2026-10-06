import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

@MainActor
final class KeyboardViewModelDeletionTests: XCTestCase {
    func testCompositionStepDeletesActiveDoubleFinalByInputStep() {
        let (viewModel, delegate) = makeSystem()

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㅂ)
        viewModel.inputConsonant(.ㅅ)

        XCTAssertEqual(delegate.text, "값")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "갑")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "가")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㄱ")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "")
    }

    func testCompositionStepDeletesActiveCompoundVowelByGestureStep() {
        let (viewModel, delegate) = makeSystem()

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅙ)

        XCTAssertEqual(delegate.text, "괘")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "과")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "고")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㄱ")
    }

    func testCompositionStepRestoresCommittedHangulFromDocumentContext() {
        let (viewModel, delegate) = makeSystem(text: "값")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "갑")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "가")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㄱ")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "")
    }

    func testCompositionStepRestoresCommittedCompoundVowel() {
        let (viewModel, delegate) = makeSystem(text: "과")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "고")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㄱ")
    }

    func testCharacterUnitDeletesActiveCompositionAtOnce() {
        let (viewModel, delegate) = makeSystem(deletionUnit: .character)

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㅂ)
        viewModel.inputConsonant(.ㅅ)
        XCTAssertEqual(delegate.text, "값")
        let deleteCountBeforeBackspace = delegate.systemDeleteCount

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "")
        XCTAssertEqual(delegate.systemDeleteCount, deleteCountBeforeBackspace + 1)
    }

    func testCharacterUnitDeletesCommittedGraphemeWithOneSystemCall() {
        let (viewModel, delegate) = makeSystem(text: "가👨‍👩‍👧‍👦", deletionUnit: .character)

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "가")
        XCTAssertEqual(delegate.systemDeleteCount, 1)
    }

    func testSelectionUsesOneSystemDeletionAndSkipsHangulRestoration() {
        let (viewModel, delegate) = makeSystem(text: "값abc")
        delegate.selectedText = "abc"

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "값")
        XCTAssertEqual(delegate.systemDeleteCount, 1)
    }

    func testSelectionTakesPriorityOverTrackedComposition() {
        let (viewModel, delegate) = makeSystem()
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        delegate.text.append("abc")
        delegate.selectedText = "abc"
        let deleteCountBeforeBackspace = delegate.systemDeleteCount

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "가")
        XCTAssertEqual(delegate.systemDeleteCount, deleteCountBeforeBackspace + 1)
        XCTAssertEqual(viewModel.composingText, "")
    }

    func testCompositionStepFallsBackToSystemDeletionForNonHangulGrapheme() {
        let (viewModel, delegate) = makeSystem(text: "가👨‍👩‍👧‍👦")

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "가")
        XCTAssertEqual(delegate.systemDeleteCount, 1)
    }

    func testMissingDocumentContextFallsBackToOneSystemDeletion() {
        let (viewModel, delegate) = makeSystem(text: "값")
        delegate.providesDocumentContext = false

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "")
        XCTAssertEqual(delegate.systemDeleteCount, 1)
    }

    func testMissingDocumentContextStillUsesTrackedComposition() {
        let (viewModel, delegate) = makeSystem()
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㅂ)
        viewModel.inputConsonant(.ㅅ)
        delegate.providesDocumentContext = false

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "갑")
    }

    func testChangedDocumentContextDropsStaleCompositionBeforeDeletion() {
        let (viewModel, delegate) = makeSystem()
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        delegate.text = "나"

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "ㄴ")
    }

    func testLongPressUsesSnapshotAndModeChangeStopsFurtherTicks() {
        let (viewModel, delegate) = makeSystem(text: "값")

        viewModel.beginBackspacePress()
        XCTAssertEqual(delegate.text, "갑")

        viewModel.repeatBackspaceIfNeeded()
        XCTAssertEqual(delegate.text, "가")

        viewModel.applyDeletionUnit(.character)
        viewModel.repeatBackspaceIfNeeded()

        XCTAssertEqual(delegate.text, "가")
        XCTAssertEqual(viewModel.deletionUnit, .character)
    }

    func testLongPressCharacterModeDeletesOneGraphemePerTick() {
        let (viewModel, delegate) = makeSystem(
            text: "가👨‍👩‍👧‍👦",
            deletionUnit: .character
        )

        viewModel.beginBackspacePress()
        XCTAssertEqual(delegate.text, "가")

        viewModel.repeatBackspaceIfNeeded()
        XCTAssertEqual(delegate.text, "")
        XCTAssertEqual(delegate.systemDeleteCount, 2)

        viewModel.endBackspacePress()
    }

    private func makeSystem(
        text: String = "",
        deletionUnit: DeletionUnit = .compositionStep
    ) -> (KeyboardViewModel, DeletionBufferDelegate) {
        let viewModel = KeyboardViewModel(
            deletionUnit: deletionUnit,
            backspaceRepeatInitialDelay: 60,
            backspaceRepeatInterval: 60
        )
        let delegate = DeletionBufferDelegate(text: text)
        viewModel.delegate = delegate
        return (viewModel, delegate)
    }
}

@MainActor
private final class DeletionBufferDelegate: KeyboardViewModelDelegate {
    var text: String
    var selectedText: String?
    var providesDocumentContext = true
    private(set) var systemDeleteCount = 0

    init(text: String) {
        self.text = text
    }

    var documentContextBeforeInput: String? {
        providesDocumentContext ? text : nil
    }

    var documentContextAfterInput: String? { "" }

    func insertText(_ text: String) {
        self.text.append(text)
    }

    func deleteBackward() {
        systemDeleteCount += 1

        if let selectedText, !selectedText.isEmpty, text.hasSuffix(selectedText) {
            text.removeLast(selectedText.count)
            self.selectedText = nil
            return
        }

        if !text.isEmpty {
            text.removeLast()
        }
    }

    func updateComposingText(from previous: String, to current: String) {
        for _ in previous where !text.isEmpty {
            text.removeLast()
            systemDeleteCount += 1
        }
        text.append(current)
    }

    func triggerHapticFeedback() {}
}
