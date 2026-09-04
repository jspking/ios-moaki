import Foundation

enum DeletionUnit: String, CaseIterable, Identifiable {
    case compositionStep
    case character

    var id: String { rawValue }
}
