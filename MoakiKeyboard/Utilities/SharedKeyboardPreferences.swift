import Foundation

protocol KeyboardPreferencesBacking: AnyObject {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyboardPreferencesBacking {}

struct SharedKeyboardPreferences {
    static let appGroupIdentifier = "group.vkehfdl1.ios-moaki"
    static let deletionUnitKey = "backspaceDeletionUnit"

    private let store: KeyboardPreferencesBacking?

    init(suiteName: String = appGroupIdentifier) {
        self.store = UserDefaults(suiteName: suiteName)
    }

    init(store: KeyboardPreferencesBacking?) {
        self.store = store
    }

    var deletionUnit: DeletionUnit {
        get {
            guard let rawValue = store?.string(forKey: Self.deletionUnitKey),
                  let deletionUnit = DeletionUnit(rawValue: rawValue) else {
                return .compositionStep
            }
            return deletionUnit
        }
        nonmutating set {
            store?.set(newValue.rawValue, forKey: Self.deletionUnitKey)
        }
    }
}
