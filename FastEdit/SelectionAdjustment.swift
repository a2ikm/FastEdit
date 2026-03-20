import Foundation

/// Adjusts a selection range after a text replacement has been performed.
///
/// - Parameters:
///   - selection: The original selection range before the replacement.
///   - replacedRange: The range of text that was replaced.
///   - replacementLength: The length of the replacement string.
/// - Returns: The adjusted selection range.
func adjustedSelection(
    _ selection: NSRange,
    afterReplacingRange replacedRange: NSRange,
    replacementLength: Int
) -> NSRange {
    let delta = replacementLength - replacedRange.length

    var result = selection

    let replacedEnd = replacedRange.location + replacedRange.length
    if replacedEnd <= selection.location {
        // Replacement is entirely before the selection — shift location
        result.location += delta
    } else if replacedRange.location < selection.location + selection.length {
        // Replacement overlaps the selection — adjust length
        result.length = max(0, result.length + delta)
    }
    // Replacement is entirely after the selection — no change

    result.location = max(0, result.location)
    return result
}
