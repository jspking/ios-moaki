import CoreGraphics
import XCTest

@testable import MoakiKeyboardCore

@MainActor
final class KeyboardViewModelVowelKeyTests: XCTestCase {
    func testShortSwipesInsertStandaloneVowelsWithoutConsonants() {
        let cases: [(CGPoint, String)] = [
            (CGPoint(x: 40, y: 0), "ㅏ"),
            (CGPoint(x: -40, y: 0), "ㅓ"),
            (CGPoint(x: 0, y: -40), "ㅗ"),
            (CGPoint(x: 0, y: 40), "ㅜ")
        ]
        for (point, expected) in cases {
            let model = KeyboardViewModel()
            let delegate = VowelKeyDelegate()
            model.delegate = delegate
            swipe(model, to: point)
            XCTAssertEqual(delegate.insertedTexts, [expected])
            XCTAssertEqual(delegate.currentComposingText, "")
            XCTAssertEqual(delegate.deleteCount, 0)
        }
    }

    func testTapWithoutSwipeDoesNotInsertOrDelete() {
        let model = KeyboardViewModel()
        let delegate = VowelKeyDelegate()
        model.delegate = delegate
        swipe(model, to: .zero)
        XCTAssertEqual(delegate.insertedTexts, [])
        XCTAssertEqual(delegate.deleteCount, 0)
    }

    func testLongSwipeUsesConfiguredLengthAndPreviewsVowel() {
        let model = KeyboardViewModel()
        let delegate = VowelKeyDelegate()
        model.delegate = delegate
        model.applyGestureLengths(baseLength: 20, longStrokeLength: 90)
        swipe(model, to: CGPoint(x: 80, y: 0))
        XCTAssertEqual(delegate.insertedTexts, ["ㅏ"])

        model.gestureStarted(row: 3, column: 5, at: .zero)
        model.gestureMoved(to: CGPoint(x: 90, y: 0))
        XCTAssertEqual(model.previewVowel, .ㅡ)
        model.gestureEnded(row: 3, column: 5)
        XCTAssertEqual(delegate.insertedTexts, ["ㅏ", "ㅡ"])

        swipe(model, to: CGPoint(x: 0, y: -90))
        XCTAssertEqual(delegate.insertedTexts, ["ㅏ", "ㅡ", "ㅣ"])
    }

    func testVowelKeyCanCompleteAnExistingConsonant() {
        let model = KeyboardViewModel()
        let delegate = VowelKeyDelegate()
        model.delegate = delegate
        model.inputConsonant(.ㄱ)
        swipe(model, to: CGPoint(x: 40, y: 0))
        XCTAssertEqual(delegate.currentComposingText, "가")
        XCTAssertEqual(delegate.insertedTexts, [])
    }

    private func swipe(_ model: KeyboardViewModel, to point: CGPoint) {
        model.gestureStarted(row: 3, column: 5, at: .zero)
        model.gestureMoved(to: point)
        model.gestureEnded(row: 3, column: 5)
    }
}

@MainActor
private final class VowelKeyDelegate: KeyboardViewModelDelegate {
    var insertedTexts: [String] = []
    var currentComposingText = ""
    var deleteCount = 0

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() { deleteCount += 1 }
    func updateComposingText(from previous: String, to current: String) {
        currentComposingText = current
    }
    func triggerHapticFeedback() {}
}
