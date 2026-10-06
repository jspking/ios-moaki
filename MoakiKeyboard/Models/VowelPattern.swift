import Foundation

struct VowelPattern {
    let vowel: Jungseong
    let directions: [GestureDirection]

    init(_ vowel: Jungseong, _ directions: GestureDirection...) {
        self.vowel = vowel
        self.directions = directions
    }

    /// Length-agnostic patterns. Every diagonal is normalized onto a vertical
    /// axis before matching (↖↗→↑, ↙↘→↓), so no pattern here uses one.
    static let allPatterns: [VowelPattern] = [
        // Basic vowels
        VowelPattern(.ㅗ, .up),                           // ↑ (↖ ↗도 정규화로 처리됨)
        VowelPattern(.ㅜ, .down),                         // ↓ (↙ ↘도 정규화로 처리됨)
        VowelPattern(.ㅏ, .right),                        // →
        VowelPattern(.ㅓ, .left),                         // ←

        // Y-vowels (triple direction)
        VowelPattern(.ㅛ, .up, .down, .up),               // ↑↓↑
        VowelPattern(.ㅠ, .down, .up, .down),             // ↓↑↓
        VowelPattern(.ㅑ, .right, .left, .right),         // →←→
        VowelPattern(.ㅕ, .left, .right, .left),          // ←→←

        // Complex vowels (diphthongs)
        VowelPattern(.ㅘ, .up, .right),                   // ↑→
        VowelPattern(.ㅙ, .up, .right, .left),            // ↑→←
        VowelPattern(.ㅝ, .down, .left),                  // ↓←
        VowelPattern(.ㅞ, .down, .left, .right),          // ↓←→
        VowelPattern(.ㅚ, .up, .down),                    // ↑↓
        VowelPattern(.ㅟ, .down, .up),                    // ↓↑

        // Ae/E vowels
        VowelPattern(.ㅐ, .right, .left),                 // →←
        VowelPattern(.ㅒ, .right, .left, .right, .left),  // →←→←
        VowelPattern(.ㅔ, .left, .right),                 // ←→
        VowelPattern(.ㅖ, .left, .right, .left, .right),  // ←→←→
    ]

    /// Patterns that need a deliberately long first stroke. They are matched
    /// before `allPatterns` and only when the whole gesture is consumed, so a
    /// long stroke that continues into some other shape (long →← for ㅐ, long
    /// ↑→ for ㅘ) falls back to the length-agnostic table instead of being
    /// forced into ㅡ or ㅣ.
    ///
    /// A long stroke means the same vowel whichever way it is drawn: ㅡ along
    /// either horizontal direction, ㅣ along either vertical one. ㅢ follows the
    /// same rule on both of its strokes, so all four turns produce it.
    static let longFirstStrokePatterns: [VowelPattern] = [
        VowelPattern(.ㅡ, .right),                        // 긴 →
        VowelPattern(.ㅡ, .left),                         // 긴 ←
        VowelPattern(.ㅣ, .up),                           // 긴 ↑
        VowelPattern(.ㅣ, .down),                         // 긴 ↓

        // ㅢ = ㅡ + ㅣ: a long horizontal stroke, then a vertical turn.
        VowelPattern(.ㅢ, .right, .up),                   // 긴 → 다음 ↑
        VowelPattern(.ㅢ, .right, .down),                 // 긴 → 다음 ↓
        VowelPattern(.ㅢ, .left, .up),                    // 긴 ← 다음 ↑
        VowelPattern(.ㅢ, .left, .down),                  // 긴 ← 다음 ↓
    ]

    // Build a trie for efficient pattern matching
    static let patternTrie: PatternTrie = trie(for: allPatterns)

    static let longFirstStrokeTrie: PatternTrie = trie(for: longFirstStrokePatterns)

    private static func trie(for patterns: [VowelPattern]) -> PatternTrie {
        let trie = PatternTrie()
        for pattern in patterns {
            trie.insert(pattern)
        }
        return trie
    }
}

// Trie for efficient pattern matching
class PatternTrie {
    class Node {
        var children: [GestureDirection: Node] = [:]
        var vowel: Jungseong?
        var isPartialMatch: Bool = false // True if this is a prefix of a longer pattern
    }

    let root = Node()

    func insert(_ pattern: VowelPattern) {
        var current = root
        for (index, direction) in pattern.directions.enumerated() {
            if current.children[direction] == nil {
                current.children[direction] = Node()
            }
            current = current.children[direction]!

            // Mark intermediate nodes as partial matches
            if index < pattern.directions.count - 1 {
                current.isPartialMatch = true
            }
        }
        current.vowel = pattern.vowel
    }

    struct MatchResult {
        let vowel: Jungseong?
        let consumedCount: Int
        let hasLongerMatch: Bool
    }

    func match(_ directions: [GestureDirection]) -> MatchResult {
        var current = root
        var lastMatch: (vowel: Jungseong, count: Int)?
        var hasLongerMatch = false

        for (index, direction) in directions.enumerated() {
            guard let next = current.children[direction] else {
                break
            }
            current = next

            if let vowel = current.vowel {
                lastMatch = (vowel, index + 1)
            }

            if index == directions.count - 1 && !current.children.isEmpty {
                hasLongerMatch = true
            }
        }

        if let match = lastMatch {
            return MatchResult(vowel: match.vowel, consumedCount: match.count, hasLongerMatch: hasLongerMatch)
        }

        return MatchResult(vowel: nil, consumedCount: 0, hasLongerMatch: !current.children.isEmpty)
    }
}
