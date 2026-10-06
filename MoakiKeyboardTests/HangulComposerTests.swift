import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif
#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class HangulComposerTests: XCTestCase {

    var composer: HangulComposer!

    override func setUp() {
        super.setUp()
        composer = HangulComposer()
    }

    override func tearDown() {
        composer = nil
        super.tearDown()
    }

    // MARK: - Basic Composition Tests

    func testInitialState() {
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertEqual(composer.displayText, "")
    }

    func testSingleChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testChoseongJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testCompleteSyllable() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "간")
    }

    func testSequentialSyllables() {
        // 안녕
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "안")

        _ = composer.inputJungseong(.ㅕ)
        XCTAssertEqual(composer.composedText, "아")
        XCTAssertEqual(composer.currentComposingCharacter, "녀")

        _ = composer.inputChoseong(.ㅇ)
        XCTAssertEqual(composer.currentComposingCharacter, "녕")
    }

    // MARK: - Double Jongseong Tests

    func testDoubleJongseong() {
        // 값
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")
    }

    func testDoubleJongseongSplit() {
        // 읽다 -> 읽 + 다
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㄹ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "읽")

        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.composedText, "일")
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    // MARK: - Delete Tests

    func testDeleteChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    func testDeleteJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testDeleteJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testDeleteDoubleJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "갑")
    }

    // MARK: - Edge Cases

    func testDoubleConsonantCannotBeJongseong() {
        // ㄸ, ㅃ, ㅉ cannot be jongseong
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄸ)

        XCTAssertEqual(composer.composedText, "가")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄸ")
    }

    func testVowelWithoutConsonant() {
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.composedText, "ㅏ")
        XCTAssertEqual(composer.state, .empty)
    }

    // MARK: - Unicode Composition Tests

    func testUnicodeValues() {
        // 가 = 0xAC00
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xAC00)

        // 힣 = 0xD7A3 (last syllable)
        composer.reset()
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㅎ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xD7A3)
    }

    // MARK: - Complex Input Sequences

    func testHelloWorld() {
        // 안녕하세요
        // 안녕 needs ㄴ twice: ㅇㅏㄴ closes 안, then ㄴㅕㅇ opens 녕.
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputChoseong(.ㅇ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅔ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅛ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "안녕하세요")
    }

    /// Typed without an explicit commit between syllables, so this also covers
    /// the composer closing a syllable when the next choseong arrives.
    func testThankYou() {
        // 감사합니다 = ㄱㅏㅁ / ㅅㅏ / ㅎㅏㅂ / ㄴㅣ / ㄷㅏ
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅁ)

        XCTAssertEqual(composer.currentComposingCharacter, "감")

        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅏ)

        XCTAssertEqual(composer.composedText, "감")

        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)

        XCTAssertEqual(composer.composedText, "감사")

        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅣ)

        XCTAssertEqual(composer.composedText, "감사합")

        _ = composer.inputChoseong(.ㄷ)
        _ = composer.inputJungseong(.ㅏ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "감사합니다")
    }
}
