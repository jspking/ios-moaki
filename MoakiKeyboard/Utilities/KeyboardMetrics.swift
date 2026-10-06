import Foundation
import CoreGraphics

/// Content type for each key in the keyboard grid
enum KeyContent: Equatable {
    case consonant(Choseong)
    case symbol(String)
    case backspace
    case vowelGesture
}

enum KeyboardMetrics {
    // Grid layout
    static let gridColumns = 7  // Expanded from 5 to 7
    static let gridRows = 4

    // Key sizing
    static let keySpacing: CGFloat = 4
    static let keyCornerRadius: CGFloat = 8

    // Both edges use the same width for symbols and the vowel gesture key.
    static let rightSymbolKeyWidth: CGFloat = 44

    // Width ratio for action keys (backspace/return) relative to total width
    static let actionKeyWidthRatio: CGFloat = 0.20

    // Function row
    static let functionRowHeight: CGFloat = 44

    // Gesture thresholds
    static let gestureThreshold: CGFloat = 20        // Minimum distance to register direction
    // Every basic vowel owns the same angular window around its own axis, so
    // ㅗ and ㅜ drift the same amount to either side as ㅏ and ㅓ already do.
    static let cardinalHalfAngle: CGFloat = 30
    static let reversalThreshold: CGFloat = 10       // Lower threshold for opposite direction reversals
    // How far a stroke has to double back before it counts as a reversal and
    // earns the lower threshold above. Judging this by angle rather than by
    // exact opposite buckets keeps a slightly skewed return stroke from
    // suddenly needing three times the distance.
    static let reversalMinimumAngle: CGFloat = 135
    // Require a more deliberate orthogonal turn than the initial stroke.
    // This prevents the natural hook at the end of an upward swipe from
    // promoting ㅗ (↑) to ㅘ (↑→).
    static let directionChangeThreshold: CGFloat = 30
    static let gestureTimeout: TimeInterval = 0.5    // Max time between direction changes

    // The gesture length setting exposes only the base value and rescales the
    // other two thresholds. The ratios and user-facing limits live in
    // SharedKeyboardPreferences, which both targets compile.

    // Space cursor gesture tuning values
    static let spaceDragThreshold: CGFloat = 8
    static let spaceLongPressDuration: TimeInterval = 0.35
    static let cursorHorizontalStep: CGFloat = 14
    static let cursorVerticalStep: CGFloat = 18
    static let cursorVerticalFallbackStride = 20
    static let cursorMaximumStepsPerUpdate = 4

    // Calculate action key width (backspace/return) based on total width
    static func actionKeyWidth(for totalWidth: CGFloat) -> CGFloat {
        return totalWidth * actionKeyWidthRatio
    }

    // Calculate center key width based on available space
    // Two fixed-width edge keys and five equally sized center keys.
    static func centerKeyWidth(for totalWidth: CGFloat) -> CGFloat {
        let spacing = keySpacing * 8  // 8 gaps for 7 columns + edges
        let availableWidth = totalWidth - spacing - rightSymbolKeyWidth * 2
        return availableWidth / 5
    }

    // Calculate key height based on available space
    static func keyHeight(for totalHeight: CGFloat) -> CGFloat {
        let availableHeight = totalHeight - functionRowHeight - keySpacing * CGFloat(gridRows + 2)
        return availableHeight / CGFloat(gridRows)
    }

    // Get key width for specific column and row
    static func keyWidth(for column: Int, row: Int, centerKeyWidth: CGFloat, isSymbolMode: Bool = false) -> CGFloat {
        if row == 3 && column == 5 {
            return isSymbolMode
                ? rightSymbolKeyWidth + centerKeyWidth + keySpacing
                : centerKeyWidth
        }

        if column == 0 || column == 6 {
            return rightSymbolKeyWidth
        }

        return centerKeyWidth
    }

    // Get number of columns for a row in the active layout.
    static func columnCount(for row: Int, isSymbolMode: Bool) -> Int {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count else { return 0 }
        return layout[row].count
    }

    // Calculate key size based on available width (legacy method for compatibility)
    static func keySize(for totalWidth: CGFloat, totalHeight: CGFloat) -> CGSize {
        let keyWidth = centerKeyWidth(for: totalWidth)
        let keyHeightValue = keyHeight(for: totalHeight)
        return CGSize(width: keyWidth, height: keyHeightValue)
    }

    // Korean mode layout: seven columns on every row.
    // Left column: special symbols, Center: consonants, Right column: symbols
    // Row 3: consonant-width backspace followed by the edge-width vowel key.
    static let koreanLayout: [[KeyContent]] = [
        [.symbol("~"), .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("!")],
        [.symbol("^"), .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .symbol("?")],
        [.symbol(";"), .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .symbol(".")],
        [.symbol("*"), .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspace, .vowelGesture],
    ]

    // Symbol mode layout.
    // Seven columns on rows 0-2; the last row keeps an expanded backspace.
    // Digits are centered:
    // row 0: 1 2 3
    // row 1: 4 5 6
    // row 2: 7 8 9
    // row 3: * 0 #
    static let symbolLayout: [[KeyContent]] = [
        [.symbol("~"), .symbol("!"), .symbol("1"), .symbol("2"), .symbol("3"), .symbol("@"), .symbol("$")],
        [.symbol("%"), .symbol("^"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("&"), .symbol("(")],
        [.symbol("="), .symbol("-"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("+"), .symbol(")")],
        [.symbol("/"), .symbol("?"), .symbol("*"), .symbol("0"), .symbol("#"), .backspace],
    ]

    // Long press number mapping for Korean mode
    // Only basic consonants (row 1-2) have number mappings
    // ㅂㅈㄷㄱㅅ → 1 2 3 4 5
    // ㅁㄴㅇㄹㅎ → 6 7 8 9 0
    static let longPressNumbers: [[String?]] = [
        [nil, nil, nil, nil, nil, nil, nil],  // row 0 (쌍자음 - no numbers)
        [nil, "1", "2", "3", "4", "5", nil],  // row 1 (ㅂㅈㄷㄱㅅ)
        [nil, "6", "7", "8", "9", "0", nil],  // row 2 (ㅁㄴㅇㄹㅎ)
        [nil, nil, nil, nil, nil, nil, nil],
    ]

    // Get key content at grid position for given mode
    static func keyContent(at row: Int, column: Int, isSymbolMode: Bool) -> KeyContent? {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count,
              column >= 0 && column < layout[row].count else {
            return nil
        }
        return layout[row][column]
    }

    // Get consonant at grid position (for Korean mode only)
    static func consonant(at row: Int, column: Int) -> Choseong? {
        guard let content = keyContent(at: row, column: column, isSymbolMode: false) else {
            return nil
        }
        if case .consonant(let choseong) = content {
            return choseong
        }
        return nil
    }

    // Get long press number for position
    static func longPressNumber(at row: Int, column: Int) -> String? {
        guard row >= 0 && row < longPressNumbers.count,
              column >= 0 && column < longPressNumbers[row].count else {
            return nil
        }
        return longPressNumbers[row][column]
    }
}
