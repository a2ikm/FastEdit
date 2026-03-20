import Testing
import Foundation
@testable import FastEdit

struct SelectionAdjustmentTests {
    // MARK: - Replacement before selection

    @Test func replacementBeforeSelection_sameLength() {
        // "aaaBBBccc" → replace "aaa" (0..<3) with "xxx" (len 3)
        // Selection "BBB" at 3..<6 → stays at 3..<6
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 3
        )
        #expect(result == NSRange(location: 3, length: 3))
    }

    @Test func replacementBeforeSelection_longer() {
        // "aaaBBBccc" → replace "aaa" (0..<3) with "xxxxx" (len 5)
        // Selection "BBB" at 3..<6 → shifts to 5..<8
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 5
        )
        #expect(result == NSRange(location: 5, length: 3))
    }

    @Test func replacementBeforeSelection_shorter() {
        // "aaaBBBccc" → replace "aaa" (0..<3) with "x" (len 1)
        // Selection "BBB" at 3..<6 → shifts to 1..<4
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 1
        )
        #expect(result == NSRange(location: 1, length: 3))
    }

    @Test func replacementBeforeSelection_delete() {
        // "aaaBBBccc" → delete "aaa" (0..<3)
        // Selection "BBB" at 3..<6 → shifts to 0..<3
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 0
        )
        #expect(result == NSRange(location: 0, length: 3))
    }

    // MARK: - Replacement after selection

    @Test func replacementAfterSelection() {
        // "aaaBBBccc" → replace "ccc" (6..<9) with "xxxxx"
        // Selection "BBB" at 3..<6 → no change
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 6, length: 3),
            replacementLength: 5
        )
        #expect(result == NSRange(location: 3, length: 3))
    }

    // MARK: - Replacement overlapping selection

    @Test func replacementOverlapsSelection_longer() {
        // "aaaBBBccc" → replace "aBBBc" (2..<7) with "xxxxxxx" (len 7)
        // Selection "BBB" at 3..<6 → length adjusts: 3 + (7-5) = 5
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 2, length: 5),
            replacementLength: 7
        )
        #expect(result == NSRange(location: 3, length: 5))
    }

    @Test func replacementOverlapsSelection_shorter() {
        // "aaaBBBccc" → replace "aBBBc" (2..<7) with "x" (len 1)
        // Selection "BBB" at 3..<6 → length adjusts: max(0, 3 + (1-5)) = 0
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 2, length: 5),
            replacementLength: 1
        )
        #expect(result == NSRange(location: 3, length: 0))
    }

    // MARK: - Replacement immediately adjacent to selection

    @Test func replacementImmediatelyBeforeSelection() {
        // "aaaBBB" → replace "aaa" (0..<3) with "x" (len 1)
        // Selection "BBB" starts right at end of replacement range
        // replacedEnd (3) <= selection.location (3) → shift
        let result = adjustedSelection(
            NSRange(location: 3, length: 3),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 1
        )
        #expect(result == NSRange(location: 1, length: 3))
    }

    // MARK: - Empty selection (insertion point)

    @Test func emptySelectionAfterReplacement() {
        // Cursor at position 5, replace range 0..<3 with "x" (len 1)
        // Cursor shifts to 3
        let result = adjustedSelection(
            NSRange(location: 5, length: 0),
            afterReplacingRange: NSRange(location: 0, length: 3),
            replacementLength: 1
        )
        #expect(result == NSRange(location: 3, length: 0))
    }

    // MARK: - Multiple sequential adjustments (simulating replaceAll in reverse)

    @Test func multipleReplacementsInReverse() {
        // "foo bar foo baz foo" → replace all "foo" with "x"
        // Matches at: 0..<3, 8..<11, 16..<19
        // Selection at 4..<7 ("bar")
        // Reverse iteration: match at 16, then 8, then 0

        var sel = NSRange(location: 4, length: 3)

        // Replace match at 16..<19 (after selection — no change)
        sel = adjustedSelection(sel, afterReplacingRange: NSRange(location: 16, length: 3), replacementLength: 1)
        #expect(sel == NSRange(location: 4, length: 3))

        // Replace match at 8..<11 (after selection — no change)
        sel = adjustedSelection(sel, afterReplacingRange: NSRange(location: 8, length: 3), replacementLength: 1)
        #expect(sel == NSRange(location: 4, length: 3))

        // Replace match at 0..<3 (before selection — shift by -2)
        sel = adjustedSelection(sel, afterReplacingRange: NSRange(location: 0, length: 3), replacementLength: 1)
        #expect(sel == NSRange(location: 2, length: 3))
    }

    // MARK: - Edge case: location would go negative

    @Test func locationClampedToZero() {
        // Selection at 1, replace 0..<5 with "" (delete)
        // delta = -5, overlaps → length adjustment: max(0, 2 + (-5)) = 0
        // location stays at 1 (overlap case adjusts length not location)
        let result = adjustedSelection(
            NSRange(location: 1, length: 2),
            afterReplacingRange: NSRange(location: 0, length: 5),
            replacementLength: 0
        )
        #expect(result == NSRange(location: 1, length: 0))
    }
}
