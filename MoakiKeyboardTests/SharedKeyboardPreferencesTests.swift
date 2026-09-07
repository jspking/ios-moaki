import Foundation
import XCTest

#if SWIFT_PACKAGE
@testable import MoakiKeyboardCore
#else
@testable import MoakiKeyboard
#endif

final class SharedKeyboardPreferencesTests: XCTestCase {
    func testPersistsDeletionUnitInInjectedSuite() throws {
        let suiteName = "SharedKeyboardPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = SharedKeyboardPreferences(store: defaults)

        preferences.deletionUnit = .character

        XCTAssertEqual(SharedKeyboardPreferences(store: defaults).deletionUnit, .character)
    }

    func testUnknownValueFallsBackToCompositionStep() {
        let store = InMemoryPreferencesStore()
        store.set("future-value", forKey: SharedKeyboardPreferences.deletionUnitKey)

        XCTAssertEqual(
            SharedKeyboardPreferences(store: store).deletionUnit,
            .compositionStep
        )
    }

    // MARK: - Gesture Lengths

    func testGestureLengthDefaultsMatchCurrentTuning() {
        let preferences = SharedKeyboardPreferences(store: InMemoryPreferencesStore())

        XCTAssertEqual(preferences.baseGestureLength, SharedKeyboardPreferences.defaultBaseGestureLength)
        XCTAssertEqual(preferences.longStrokeLength, SharedKeyboardPreferences.defaultLongStrokeLength)
    }

    func testPersistsGestureLengths() throws {
        let suiteName = "SharedKeyboardPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = SharedKeyboardPreferences(store: defaults)

        preferences.baseGestureLength = 28
        preferences.longStrokeLength = 95

        let reloaded = SharedKeyboardPreferences(store: defaults)
        XCTAssertEqual(reloaded.baseGestureLength, 28)
        XCTAssertEqual(reloaded.longStrokeLength, 95)
    }

    func testGestureLengthsAreClampedToTheirRanges() {
        let preferences = SharedKeyboardPreferences(store: InMemoryPreferencesStore())

        preferences.baseGestureLength = 5
        XCTAssertEqual(preferences.baseGestureLength, SharedKeyboardPreferences.baseGestureLengthRange.lowerBound)

        preferences.baseGestureLength = 500
        XCTAssertEqual(preferences.baseGestureLength, SharedKeyboardPreferences.baseGestureLengthRange.upperBound)

        preferences.longStrokeLength = 5000
        XCTAssertEqual(preferences.longStrokeLength, SharedKeyboardPreferences.longStrokeLengthRange.upperBound)
    }

    func testLongStrokeLengthStaysClearOfBaseLength() {
        let preferences = SharedKeyboardPreferences(store: InMemoryPreferencesStore())

        preferences.baseGestureLength = 40
        preferences.longStrokeLength = 40

        XCTAssertEqual(
            preferences.longStrokeLength,
            40 + SharedKeyboardPreferences.minimumLongStrokeMargin
        )
    }

    func testRaisingBaseLengthPushesStoredLongStrokeUpOnRead() {
        let store = InMemoryPreferencesStore()
        let preferences = SharedKeyboardPreferences(store: store)

        preferences.longStrokeLength = 45
        preferences.baseGestureLength = 40

        // 45pt is now too close to the 40pt base, so reads report the floor.
        XCTAssertEqual(preferences.longStrokeLength, 50)
    }

    func testResetGestureLengthsRestoresDefaults() {
        let preferences = SharedKeyboardPreferences(store: InMemoryPreferencesStore())

        preferences.baseGestureLength = 35
        preferences.longStrokeLength = 130
        preferences.resetGestureLengths()

        XCTAssertEqual(preferences.baseGestureLength, SharedKeyboardPreferences.defaultBaseGestureLength)
        XCTAssertEqual(preferences.longStrokeLength, SharedKeyboardPreferences.defaultLongStrokeLength)
    }

    func testMissingStoreFallsBackToGestureLengthDefaults() {
        let preferences = SharedKeyboardPreferences(store: nil)

        preferences.baseGestureLength = 35
        XCTAssertEqual(preferences.baseGestureLength, SharedKeyboardPreferences.defaultBaseGestureLength)
        XCTAssertEqual(preferences.longStrokeLength, SharedKeyboardPreferences.defaultLongStrokeLength)
    }

    func testMissingStoreFallsBackWithoutCrashingOnWrite() {
        let preferences = SharedKeyboardPreferences(store: nil)

        XCTAssertEqual(preferences.deletionUnit, .compositionStep)
        preferences.deletionUnit = .character
        XCTAssertEqual(preferences.deletionUnit, .compositionStep)
    }
}

private final class InMemoryPreferencesStore: KeyboardPreferencesBacking {
    private var values: [String: Any] = [:]

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
