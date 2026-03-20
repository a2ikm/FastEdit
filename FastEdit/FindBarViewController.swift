import AppKit

protocol FindBarDelegate: AnyObject {
    var findBarTextView: NSTextView { get }
    func findBarDidRequestClose()
    func findBarDidUpdateMatches(_ matches: [NSTextCheckingResult], currentIndex: Int?)
    func findBarDidReplace()
}

class FindBarViewController: NSViewController {
    // MARK: - UI Elements

    private(set) var searchField: NSTextField!
    private var replaceField: NSTextField!
    private var regexToggle: NSButton!
    private var caseToggle: NSButton!
    private var prevButton: NSButton!
    private var nextButton: NSButton!
    private var closeButton: NSButton!
    private var replaceButton: NSButton!
    private var replaceAllButton: NSButton!
    private var selectionToggle: NSButton!
    private var matchCountLabel: NSTextField!
    private var replaceRow: NSStackView!
    private var separator: NSBox!

    // MARK: - State

    weak var delegate: FindBarDelegate?
    private let engine = RegexSearchEngine()
    private var matches: [NSTextCheckingResult] = []
    private var currentMatchIndex: Int?
    private var frozenSelectionRange: NSRange?

    var isReplaceMode: Bool = false {
        didSet {
            replaceRow.isHidden = !isReplaceMode
        }
    }

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Search field
        searchField = NSTextField()
        searchField.placeholderString = "Search"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Match count label
        matchCountLabel = NSTextField(labelWithString: "")
        matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
        matchCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        matchCountLabel.textColor = .secondaryLabelColor
        matchCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        matchCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Toggle buttons
        regexToggle = makeToggleButton(title: ".*", toolTip: "Regular Expression")
        regexToggle.state = .on
        regexToggle.action = #selector(toggleChanged(_:))

        caseToggle = makeToggleButton(title: "Aa", toolTip: "Case Sensitive")
        caseToggle.state = .off
        caseToggle.action = #selector(toggleChanged(_:))

        selectionToggle = makeToggleButton(title: "⊏⊐", toolTip: "Find in Selection")
        selectionToggle.state = .off
        selectionToggle.action = #selector(selectionToggleChanged(_:))

        // Navigation buttons
        prevButton = makeButton(title: "<", toolTip: "Previous Match")
        prevButton.action = #selector(previousMatch)
        nextButton = makeButton(title: ">", toolTip: "Next Match")
        nextButton.action = #selector(nextMatch)

        // Close button
        closeButton = makeButton(title: "×", toolTip: "Close")
        closeButton.action = #selector(close)

        // Search row
        let searchRow = NSStackView(views: [
            searchField, matchCountLabel, caseToggle, selectionToggle, regexToggle, prevButton, nextButton, closeButton,
        ])
        searchRow.orientation = .horizontal
        searchRow.spacing = 4
        searchRow.translatesAutoresizingMaskIntoConstraints = false

        // Replace field
        replaceField = NSTextField()
        replaceField.placeholderString = "Replace"
        replaceField.translatesAutoresizingMaskIntoConstraints = false
        replaceField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Replace buttons
        replaceButton = makeButton(title: "Replace", toolTip: "Replace")
        replaceButton.action = #selector(replaceCurrent)
        replaceAllButton = makeButton(title: "All", toolTip: "Replace All")
        replaceAllButton.action = #selector(replaceAll)

        // Replace row
        replaceRow = NSStackView(views: [replaceField, replaceButton, replaceAllButton])
        replaceRow.orientation = .horizontal
        replaceRow.spacing = 4
        replaceRow.translatesAutoresizingMaskIntoConstraints = false
        replaceRow.isHidden = !isReplaceMode

        // Separator
        separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Main stack
        let mainStack = NSStackView(views: [searchRow, replaceRow, separator])
        mainStack.orientation = .vertical
        mainStack.spacing = 4
        mainStack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 2, right: 8)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
    }

    // MARK: - Public Methods

    func showFind() {
        isReplaceMode = false
    }

    func showFindAndReplace() {
        isReplaceMode = true
    }

    func dismiss() {
        matches = []
        currentMatchIndex = nil
        frozenSelectionRange = nil
    }

    func setSearchText(_ text: String) {
        searchField.stringValue = text
        performSearch()
    }

    @objc func performSearch() {
        guard let textView = delegate?.findBarTextView else { return }
        let text = textView.string

        let searchRange: NSRange
        if selectionToggle.state == .on, let frozen = frozenSelectionRange {
            // Clamp frozen range to current text length
            let textLength = (text as NSString).length
            let clampedLength = min(frozen.length, textLength - frozen.location)
            searchRange = NSRange(location: frozen.location, length: max(0, clampedLength))
        } else {
            searchRange = NSRange(location: 0, length: (text as NSString).length)
        }

        let options = currentSearchOptions()

        do {
            matches = try engine.findMatches(
                pattern: searchField.stringValue,
                in: text,
                range: searchRange,
                options: options
            )
            searchField.backgroundColor = nil
            updateMatchCountLabel()

            if matches.isEmpty {
                currentMatchIndex = nil
            } else {
                currentMatchIndex = 0
            }

            delegate?.findBarDidUpdateMatches(matches, currentIndex: currentMatchIndex)

            // Only move text view selection when search field is not focused
            let searchFieldFocused = searchField.currentEditor() != nil
            if !searchFieldFocused, let index = currentMatchIndex {
                selectMatch(at: index)
            }
        } catch {
            matches = []
            currentMatchIndex = nil
            searchField.backgroundColor = NSColor.systemRed.withAlphaComponent(0.15)
            updateMatchCountLabel()
            delegate?.findBarDidUpdateMatches([], currentIndex: nil)
        }
    }

    // MARK: - Actions

    @objc private func toggleChanged(_ sender: NSButton) {
        performSearch()
    }

    @objc func nextMatch() {
        guard !matches.isEmpty else { return }
        let index = ((currentMatchIndex ?? -1) + 1) % matches.count
        currentMatchIndex = index
        selectMatch(at: index)
        delegate?.findBarDidUpdateMatches(matches, currentIndex: currentMatchIndex)
    }

    @objc func previousMatch() {
        guard !matches.isEmpty else { return }
        let index = ((currentMatchIndex ?? 1) - 1 + matches.count) % matches.count
        currentMatchIndex = index
        selectMatch(at: index)
        delegate?.findBarDidUpdateMatches(matches, currentIndex: currentMatchIndex)
    }

    @objc private func close() {
        delegate?.findBarDidRequestClose()
    }

    @objc private func selectionToggleChanged(_ sender: NSButton) {
        if sender.state == .on {
            // Freeze the current selection range
            if let textView = delegate?.findBarTextView {
                let selectedRange = textView.selectedRange()
                if selectedRange.length > 0 {
                    frozenSelectionRange = selectedRange
                } else {
                    // No selection — turn off
                    sender.state = .off
                    frozenSelectionRange = nil
                }
            }
        } else {
            frozenSelectionRange = nil
        }
        performSearch()
    }

    @objc private func replaceCurrent() {
        guard let textView = delegate?.findBarTextView,
              let index = currentMatchIndex,
              index < matches.count
        else { return }

        let match = matches[index]
        let text = textView.string
        let template = replaceField.stringValue
        let options = currentSearchOptions()

        guard let replacement = try? engine.replacementString(
            for: match,
            in: text,
            pattern: searchField.stringValue,
            template: template,
            options: options
        ) else { return }

        // Use NSTextView's undo-aware replacement
        let matchRange = match.range
        if textView.shouldChangeText(in: matchRange, replacementString: replacement) {
            textView.replaceCharacters(in: matchRange, with: replacement)
            textView.didChangeText()
        }

        // Adjust frozen selection range if needed
        if let frozen = frozenSelectionRange {
            let delta = (replacement as NSString).length - matchRange.length
            frozenSelectionRange = NSRange(location: frozen.location, length: frozen.length + delta)
        }

        delegate?.findBarDidReplace()
        performSearch()
    }

    @objc private func replaceAll() {
        guard let textView = delegate?.findBarTextView, !matches.isEmpty else { return }

        let template = replaceField.stringValue
        let options = currentSearchOptions()

        // Group all replacements into a single undo operation
        textView.undoManager?.beginUndoGrouping()

        let pattern = searchField.stringValue

        // Replace in reverse order to preserve ranges
        for match in matches.reversed() {
            guard let replacement = try? engine.replacementString(
                for: match,
                in: textView.string,
                pattern: pattern,
                template: template,
                options: options
            ) else { continue }

            if textView.shouldChangeText(in: match.range, replacementString: replacement) {
                textView.replaceCharacters(in: match.range, with: replacement)
                textView.didChangeText()
            }
        }

        textView.undoManager?.endUndoGrouping()

        delegate?.findBarDidReplace()

        // Reset scope to whole text after replace all
        if selectionToggle.state == .on {
            selectionToggle.state = .off
            frozenSelectionRange = nil
        }

        performSearch()
    }

    // MARK: - Key Handling

    override func cancelOperation(_ sender: Any?) {
        delegate?.findBarDidRequestClose()
    }

    // MARK: - Private

    private func currentSearchOptions() -> SearchOptions {
        SearchOptions(
            isRegex: regexToggle.state == .on,
            isCaseSensitive: caseToggle.state == .on
        )
    }

    private func selectMatch(at index: Int) {
        guard let textView = delegate?.findBarTextView, index < matches.count else { return }
        let range = matches[index].range
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }

    private func updateMatchCountLabel() {
        let pattern = searchField.stringValue
        if pattern.isEmpty {
            matchCountLabel.stringValue = ""
        } else if matches.isEmpty {
            matchCountLabel.stringValue = "No matches"
        } else if let index = currentMatchIndex {
            matchCountLabel.stringValue = "\(index + 1) / \(matches.count)"
        } else {
            matchCountLabel.stringValue = "\(matches.count) matches"
        }
    }

    private func makeToggleButton(title: String, toolTip: String) -> NSButton {
        let button = NSButton()
        button.title = title
        button.toolTip = toolTip
        button.setButtonType(.pushOnPushOff)
        button.bezelStyle = .recessed
        button.refusesFirstResponder = true
        button.target = self
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func makeButton(title: String, toolTip: String) -> NSButton {
        let button = NSButton()
        button.title = title
        button.toolTip = toolTip
        button.bezelStyle = .recessed
        button.refusesFirstResponder = true
        button.target = self
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
}

// MARK: - NSTextFieldDelegate

extension FindBarViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === searchField {
            performSearch()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            delegate?.findBarDidRequestClose()
            return true
        }
        if commandSelector == #selector(insertNewline(_:)) {
            if control === searchField {
                nextMatch()
                return true
            }
        }
        return false
    }
}
