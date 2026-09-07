import Foundation
import CoreGraphics

protocol KeyboardPreferencesBacking: AnyObject {
    func string(forKey defaultName: String) -> String?
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyboardPreferencesBacking {}

struct SharedKeyboardPreferences {
    static let appGroupIdentifier = "group.vkehfdl1.ios-moaki"
    static let deletionUnitKey = "backspaceDeletionUnit"
    static let baseGestureLengthKey = "baseGestureLength"
    static let longStrokeLengthKey = "longStrokeLength"

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

    /// Distance at which a drag starts counting as a direction stroke. Drives
    /// every gesture threshold, so this is the "ㅏ ㅓ ㅗ ㅜ sensitivity" knob.
    var baseGestureLength: CGFloat {
        get {
            let stored = storedLength(forKey: Self.baseGestureLengthKey)
                ?? KeyboardMetrics.defaultBaseGestureLength
            return stored.clamped(to: KeyboardMetrics.baseGestureLengthRange)
        }
        nonmutating set {
            store?.set(
                Double(newValue.clamped(to: KeyboardMetrics.baseGestureLengthRange)),
                forKey: Self.baseGestureLengthKey
            )
        }
    }

    /// Distance at which a first stroke means ㅡ/ㅣ instead of ㅏ/ㅗ. Always kept
    /// clear of `baseGestureLength`; if the two met, short strokes would become
    /// impossible to enter.
    var longStrokeLength: CGFloat {
        get {
            let stored = storedLength(forKey: Self.longStrokeLengthKey)
                ?? KeyboardMetrics.defaultLongStrokeLength
            return Self.clampLongStrokeLength(stored, baseGestureLength: baseGestureLength)
        }
        nonmutating set {
            let clamped = Self.clampLongStrokeLength(
                newValue,
                baseGestureLength: baseGestureLength
            )
            store?.set(Double(clamped), forKey: Self.longStrokeLengthKey)
        }
    }

    func resetGestureLengths() {
        baseGestureLength = KeyboardMetrics.defaultBaseGestureLength
        longStrokeLength = KeyboardMetrics.defaultLongStrokeLength
    }

    static func clampLongStrokeLength(_ value: CGFloat, baseGestureLength: CGFloat) -> CGFloat {
        let floorValue = max(
            KeyboardMetrics.longStrokeLengthRange.lowerBound,
            baseGestureLength + KeyboardMetrics.minimumLongStrokeMargin
        )
        return value.clamped(to: floorValue...KeyboardMetrics.longStrokeLengthRange.upperBound)
    }

    /// `object(forKey:)` rather than `double(forKey:)` so an unset value stays
    /// distinguishable from a stored zero.
    private func storedLength(forKey key: String) -> CGFloat? {
        guard let value = store?.object(forKey: key) as? NSNumber else { return nil }
        return CGFloat(value.doubleValue)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
