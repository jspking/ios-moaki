import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class HangulComposerDeletionTests: XCTestCase {
    func testEveryCompoundVowelReturnsToItsPreviousCompositionStep() {
        let cases: [(input: Character, expected: Character)] = [
            ("과", "고"),
            ("괘", "과"),
            ("괴", "고"),
            ("궈", "구"),
            ("궤", "궈"),
            ("귀", "구"),
            ("긔", "그")
        ]

        for testCase in cases {
            let composer = HangulComposer()

            XCTAssertTrue(composer.resumeComposing(testCase.input))
            _ = composer.deleteBackward()

            XCTAssertEqual(
                composer.currentComposingCharacter,
                testCase.expected,
                "Expected \(testCase.input) to return to \(testCase.expected)"
            )
        }
    }

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
