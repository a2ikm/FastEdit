import Cocoa

// Custom NSTextView subclass supporting multi-cursor editing
// and rectangular selection.
class EditorTextView: NSTextView {

    // MARK: - Multi-Cursor State

    // Additional cursor locations beyond the primary selection.
    // Each value is a character index in the text storage.
    var insertionLocations: [Int] = [] {
        didSet { updateInsertionIndicators() }
    }

    // Origins for selection ranges (used when extending selections).
    var selectionOrigins: [Int] = []

    // Visual indicators for additional cursors.
    var insertionIndicators: [NSTextInsertionIndicator] = []

    // True while the user is performing a rectangular selection via Option+drag.
    private(set) var isPerformingRectangularSelection: Bool = false

    // The point where mouseDown occurred, used as the anchor for rectangular selection.
    private var mouseDownPoint: NSPoint = .zero

    // Whether the text view has multiple insertion points active.
    var hasMultipleInsertions: Bool {
        !insertionLocations.isEmpty
    }

    // MARK: - Mouse Events for Rectangular Selection

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            isPerformingRectangularSelection = true
            mouseDownPoint = convert(event.locationInWindow, from: nil)
        } else {
            // Normal click cancels multi-cursor mode
            if hasMultipleInsertions {
                insertionLocations = []
                selectionOrigins = []
            }
            isPerformingRectangularSelection = false
        }
        super.mouseDown(with: event)
        isPerformingRectangularSelection = false
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        if isPerformingRectangularSelection, let layoutManager, let textContainer {
            let locations = computeInsertionLocations(
                from: mouseDownPoint,
                candidates: ranges,
                affinity: affinity,
                layoutManager: layoutManager,
                textContainer: textContainer
            )

            if !locations.isEmpty {
                // Set primary selection to first location only
                let primaryRange = NSRange(location: locations[0], length: 0)
                super.setSelectedRanges([NSValue(range: primaryRange)], affinity: affinity, stillSelecting: stillSelectingFlag)
                insertionLocations = Array(locations.dropFirst())
                return
            }
        }

        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    // Compute insertion locations for rectangular selection.
    // Given the mouse-down anchor point and the current drag position
    // (encoded as candidate ranges from NSTextView), calculate the
    // corresponding column position on each line in the range.
    private func computeInsertionLocations(
        from anchorPoint: NSPoint,
        candidates: [NSValue],
        affinity: NSSelectionAffinity,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> [Int] {
        guard !candidates.isEmpty else { return [] }

        let nsString = string as NSString
        let textLength = nsString.length
        guard textLength > 0 else { return [] }

        // Determine the anchor X position in text container coordinates
        let containerOrigin = textContainerOrigin
        let anchorX = anchorPoint.x - containerOrigin.x

        // Get the range of text covered by all candidates
        let union = candidates.reduce(candidates[0].rangeValue) { result, val in
            NSUnionRange(result, val.rangeValue)
        }

        // Find the line range for each line in the union
        var locations: [Int] = []
        var lineStart = union.location
        let unionEnd = NSMaxRange(union)

        while lineStart <= unionEnd && lineStart <= textLength {
            let lineRange: NSRange
            if lineStart < textLength {
                lineRange = nsString.lineRange(for: NSRange(location: lineStart, length: 0))
            } else {
                // Handle position at the very end of text
                lineRange = NSRange(location: textLength, length: 0)
            }

            // Find the character index at the anchor's X position on this line
            let location = characterIndex(atXPosition: anchorX, inLineStartingAt: lineStart, layoutManager: layoutManager, textContainer: textContainer)
            locations.append(location)

            // Move to the next line
            if lineRange.length == 0 {
                break
            }
            lineStart = NSMaxRange(lineRange)
        }

        return locations
    }

    // Find the character index closest to the given X position within a line.
    private func characterIndex(
        atXPosition xPos: CGFloat,
        inLineStartingAt lineStart: Int,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> Int {
        let nsString = string as NSString
        let textLength = nsString.length

        guard lineStart < textLength else { return textLength }

        let lineRange = nsString.lineRange(for: NSRange(location: lineStart, length: 0))
        // Exclude the trailing newline from the search range
        let contentEnd = max(lineRange.location, NSMaxRange(lineRange) - (nsString.substring(with: lineRange).hasSuffix("\n") ? 1 : 0))
        let searchRange = NSRange(location: lineRange.location, length: contentEnd - lineRange.location)

        if searchRange.length == 0 {
            return lineRange.location
        }

        // Use fractional glyph position to find the closest character
        let glyphRange = layoutManager.glyphRange(forCharacterRange: searchRange, actualCharacterRange: nil)
        var closestIndex = lineRange.location
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for glyphIndex in glyphRange.location..<NSMaxRange(glyphRange) {
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            // Check left edge of this glyph
            let leftDist = abs(rect.origin.x - xPos)
            if leftDist < closestDistance {
                closestDistance = leftDist
                closestIndex = charIndex
            }

            // Check right edge (which means placing cursor after this character)
            let rightDist = abs(rect.maxX - xPos)
            if rightDist < closestDistance {
                closestDistance = rightDist
                closestIndex = charIndex + 1
            }
        }

        return min(closestIndex, contentEnd)
    }

    // MARK: - Key Event Handling

    override func keyDown(with event: NSEvent) {
        // Ctrl+Shift+Up/Down for column selection
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) && flags.contains(.shift) {
            switch event.keyCode {
            case 126: // Up arrow
                selectColumnUp(nil)
                return
            case 125: // Down arrow
                selectColumnDown(nil)
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    // MARK: - Multi-Cursor Text Editing

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard hasMultipleInsertions else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let insertString = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        let insertLength = (insertString as NSString).length

        // Collect all insertion points: primary + additional
        var allLocations = [selectedRange().location] + insertionLocations
        allLocations.sort()

        // Replace in reverse order to preserve earlier indices
        guard let textStorage = textStorage else { return }

        undoManager?.beginUndoGrouping()

        var newLocations: [Int] = []
        var offset = 0

        for location in allLocations {
            let adjustedLocation = location + offset
            let range = NSRange(location: adjustedLocation, length: 0)

            if shouldChangeText(in: range, replacementString: insertString) {
                textStorage.replaceCharacters(in: range, with: insertString)
                didChangeText()
            }

            newLocations.append(adjustedLocation + insertLength)
            offset += insertLength
        }

        undoManager?.endUndoGrouping()

        // Update cursor positions
        if !newLocations.isEmpty {
            let primary = newLocations[0]
            super.setSelectedRanges([NSValue(range: NSRange(location: primary, length: 0))], affinity: .downstream, stillSelecting: false)
            insertionLocations = Array(newLocations.dropFirst())
        }
    }

    override func deleteBackward(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.deleteBackward(sender)
            return
        }
        multipleDelete(forward: false)
    }

    override func deleteForward(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.deleteForward(sender)
            return
        }
        multipleDelete(forward: true)
    }

    // Delete one character at each cursor position.
    private func multipleDelete(forward: Bool) {
        guard let textStorage = textStorage else { return }
        let nsString = string as NSString
        let textLength = nsString.length

        var allLocations = [selectedRange().location] + insertionLocations
        allLocations.sort()

        // Compute delete ranges
        var deleteRanges: [NSRange] = []
        for location in allLocations {
            if forward {
                if location < textLength {
                    deleteRanges.append(NSRange(location: location, length: 1))
                }
            } else {
                if location > 0 {
                    deleteRanges.append(NSRange(location: location - 1, length: 1))
                }
            }
        }

        guard !deleteRanges.isEmpty else { return }

        undoManager?.beginUndoGrouping()

        var newLocations: [Int] = []
        var offset = 0

        for range in deleteRanges {
            let adjustedRange = NSRange(location: range.location + offset, length: range.length)
            let replacement = ""

            if shouldChangeText(in: adjustedRange, replacementString: replacement) {
                textStorage.replaceCharacters(in: adjustedRange, with: replacement)
                didChangeText()
            }

            let newLocation = forward ? adjustedRange.location : adjustedRange.location
            newLocations.append(newLocation)
            offset -= range.length
        }

        undoManager?.endUndoGrouping()

        if !newLocations.isEmpty {
            let primary = newLocations[0]
            super.setSelectedRanges([NSValue(range: NSRange(location: primary, length: 0))], affinity: .downstream, stillSelecting: false)
            insertionLocations = Array(newLocations.dropFirst())
        }
    }

    // MARK: - Multi-Cursor Movement

    override func moveLeft(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.moveLeft(sender)
            return
        }
        moveCursors { max(0, $0 - 1) }
    }

    override func moveRight(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.moveRight(sender)
            return
        }
        let textLength = (string as NSString).length
        moveCursors { min(textLength, $0 + 1) }
    }

    override func moveUp(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.moveUp(sender)
            return
        }
        moveCursorsVertically(direction: .up)
    }

    override func moveDown(_ sender: Any?) {
        guard hasMultipleInsertions else {
            super.moveDown(sender)
            return
        }
        moveCursorsVertically(direction: .down)
    }

    // Apply a transform function to all cursor locations.
    private func moveCursors(using transform: (Int) -> Int) {
        var allLocations = [selectedRange().location] + insertionLocations
        allLocations = allLocations.map(transform)

        // Remove duplicates while preserving order
        var seen = Set<Int>()
        allLocations = allLocations.filter { seen.insert($0).inserted }

        if allLocations.count <= 1 {
            // All cursors collapsed into one or zero
            insertionLocations = []
            if let loc = allLocations.first {
                super.setSelectedRanges([NSValue(range: NSRange(location: loc, length: 0))], affinity: .downstream, stillSelecting: false)
            }
        } else {
            let primary = allLocations[0]
            super.setSelectedRanges([NSValue(range: NSRange(location: primary, length: 0))], affinity: .downstream, stillSelecting: false)
            insertionLocations = Array(allLocations.dropFirst())
        }
    }

    private enum VerticalDirection {
        case up, down
    }

    private func moveCursorsVertically(direction: VerticalDirection) {
        guard let layoutManager, let textContainer else { return }

        let containerOrigin = textContainerOrigin
        let allLocations = [selectedRange().location] + insertionLocations

        var newLocations: [Int] = []
        for location in allLocations {
            let safeLocation = min(location, (string as NSString).length)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: max(0, safeLocation > 0 ? safeLocation - 1 : 0))
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            // Get X position of current cursor
            let xPos: CGFloat
            if safeLocation < (string as NSString).length {
                let charGlyph = layoutManager.glyphIndexForCharacter(at: safeLocation)
                let charLoc = layoutManager.location(forGlyphAt: charGlyph)
                xPos = lineRect.origin.x + charLoc.x
            } else if (string as NSString).length > 0 {
                let lastGlyph = layoutManager.glyphIndexForCharacter(at: (string as NSString).length - 1)
                let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: textContainer)
                xPos = rect.maxX
            } else {
                xPos = 0
            }

            // Find the target Y position on the adjacent line
            let targetY: CGFloat
            switch direction {
            case .up:
                targetY = lineRect.origin.y - 1
            case .down:
                targetY = lineRect.maxY + 1
            }

            let targetPoint = NSPoint(x: xPos + containerOrigin.x, y: targetY + containerOrigin.y)
            let newIndex = characterIndexForInsertion(at: targetPoint)

            // Clamp to valid range
            let clampedIndex = max(0, min(newIndex, (string as NSString).length))
            newLocations.append(clampedIndex)
        }

        // Remove duplicates while preserving order
        var seen = Set<Int>()
        newLocations = newLocations.filter { seen.insert($0).inserted }

        if newLocations.count <= 1 {
            insertionLocations = []
            if let loc = newLocations.first {
                super.setSelectedRanges([NSValue(range: NSRange(location: loc, length: 0))], affinity: .downstream, stillSelecting: false)
            }
        } else {
            let primary = newLocations[0]
            super.setSelectedRanges([NSValue(range: NSRange(location: primary, length: 0))], affinity: .downstream, stillSelecting: false)
            insertionLocations = Array(newLocations.dropFirst())
        }
    }

    // MARK: - Select Column Up/Down (Ctrl+Shift+Up/Down)

    @IBAction func selectColumnUp(_ sender: Any?) {
        addCursorToAdjacentLine(direction: .up)
    }

    @IBAction func selectColumnDown(_ sender: Any?) {
        addCursorToAdjacentLine(direction: .down)
    }

    // Add a cursor on the line above or below the current topmost/bottommost cursor.
    private func addCursorToAdjacentLine(direction: VerticalDirection) {
        guard let layoutManager, let textContainer else { return }

        let containerOrigin = textContainerOrigin
        var allLocations = [selectedRange().location] + insertionLocations
        allLocations.sort()

        // Pick the edge cursor based on direction
        let edgeLocation: Int
        switch direction {
        case .up:
            edgeLocation = allLocations.first ?? selectedRange().location
        case .down:
            edgeLocation = allLocations.last ?? selectedRange().location
        }

        let nsString = string as NSString
        let textLength = nsString.length
        let safeLocation = min(edgeLocation, textLength)

        // Get the line fragment for the edge cursor
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: max(0, safeLocation > 0 ? safeLocation - 1 : 0))
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

        // Get X position
        let xPos: CGFloat
        if safeLocation < textLength {
            let charGlyph = layoutManager.glyphIndexForCharacter(at: safeLocation)
            let charLoc = layoutManager.location(forGlyphAt: charGlyph)
            xPos = lineRect.origin.x + charLoc.x
        } else if textLength > 0 {
            let lastGlyph = layoutManager.glyphIndexForCharacter(at: textLength - 1)
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: textContainer)
            xPos = rect.maxX
        } else {
            return
        }

        // Find target position on adjacent line
        let targetY: CGFloat
        switch direction {
        case .up:
            targetY = lineRect.origin.y - 1
            guard targetY >= 0 else { return }
        case .down:
            targetY = lineRect.maxY + 1
        }

        let targetPoint = NSPoint(x: xPos + containerOrigin.x, y: targetY + containerOrigin.y)
        let newIndex = characterIndexForInsertion(at: targetPoint)
        let clampedIndex = max(0, min(newIndex, textLength))

        // Don't add if already present
        if allLocations.contains(clampedIndex) { return }

        // Add the new cursor
        allLocations.append(clampedIndex)
        allLocations.sort()

        let primary = allLocations[0]
        super.setSelectedRanges([NSValue(range: NSRange(location: primary, length: 0))], affinity: .downstream, stillSelecting: false)
        insertionLocations = Array(allLocations.dropFirst())
    }

    // MARK: - Escape to Cancel Multi-Cursor

    override func cancelOperation(_ sender: Any?) {
        if hasMultipleInsertions {
            insertionLocations = []
            selectionOrigins = []
            return
        }
        super.cancelOperation(sender)
    }

    // MARK: - Insertion Indicator Display

    // Create or update NSTextInsertionIndicator views to show
    // additional cursors at each location in insertionLocations.
    func updateInsertionIndicators() {
        // Remove excess indicators
        while insertionIndicators.count > insertionLocations.count {
            let indicator = insertionIndicators.removeLast()
            indicator.removeFromSuperview()
        }

        // Add new indicators if needed
        while insertionIndicators.count < insertionLocations.count {
            let indicator = NSTextInsertionIndicator(frame: .zero)
            addSubview(indicator)
            insertionIndicators.append(indicator)
        }

        guard let layoutManager, let textContainer else { return }

        let nsString = string as NSString
        let textLength = nsString.length
        let containerOrigin = textContainerOrigin

        // Position each indicator
        for (i, location) in insertionLocations.enumerated() {
            let indicator = insertionIndicators[i]
            let safeLocation = min(location, textLength)

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: max(0, safeLocation - (safeLocation == textLength && textLength > 0 ? 1 : 0)))
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let cursorRect: NSRect
            if safeLocation < textLength {
                let charGlyphIndex = layoutManager.glyphIndexForCharacter(at: safeLocation)
                let charLocation = layoutManager.location(forGlyphAt: charGlyphIndex)
                cursorRect = NSRect(
                    x: lineRect.origin.x + charLocation.x + containerOrigin.x,
                    y: lineRect.origin.y + containerOrigin.y,
                    width: 1,
                    height: lineRect.height
                )
            } else {
                // At end of text: position after last character
                if textLength > 0 {
                    let lastGlyph = layoutManager.glyphIndexForCharacter(at: textLength - 1)
                    let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: textContainer)
                    cursorRect = NSRect(
                        x: boundingRect.maxX + containerOrigin.x,
                        y: boundingRect.origin.y + containerOrigin.y,
                        width: 1,
                        height: boundingRect.height
                    )
                } else {
                    cursorRect = NSRect(
                        x: containerOrigin.x,
                        y: containerOrigin.y,
                        width: 1,
                        height: lineRect.height
                    )
                }
            }

            indicator.frame = cursorRect
            indicator.displayMode = window?.isKeyWindow == true ? .automatic : .hidden
        }
    }

    // Update indicator display mode when window key state changes.
    func invalidateInsertionIndicatorDisplayMode() {
        let mode: NSTextInsertionIndicator.DisplayMode = window?.isKeyWindow == true ? .automatic : .hidden
        for indicator in insertionIndicators {
            indicator.displayMode = mode
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        invalidateInsertionIndicatorDisplayMode()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { invalidateInsertionIndicatorDisplayMode() }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { invalidateInsertionIndicatorDisplayMode() }
        return result
    }
}
