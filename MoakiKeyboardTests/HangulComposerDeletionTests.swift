import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class HangulComposerDeletionTests: XCTestCase {
    func testResumedDoubleFinalDeletesByCompositionStep() {
        let composer = HangulComposer()

        XCTAssertTrue(composer.resumeComposing("값"))

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "갑")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "가")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testResumedCompoundVowelDeletesByGestureStep() {
        let composer = HangulComposer()

        XCTAssertTrue(composer.resumeComposing("괘"))

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "과")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "고")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testResumeRejectsNonHangulGrapheme() {
        let composer = HangulComposer()

        XCTAssertFalse(composer.resumeComposing("👨‍👩‍👧‍👦"))
        XCTAssertEqual(composer.state, .empty)
    }

    func testResumeRejectsHangulWithCombiningMark() throws {
        let composer = HangulComposer()
        let decoratedHangul = try XCTUnwrap("가\u{301}".first)

        XCTAssertFalse(composer.resumeComposing(decoratedHangul))
        XCTAssertEqual(composer.state, .empty)
    }
}
