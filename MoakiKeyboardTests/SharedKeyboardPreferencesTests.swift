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

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
