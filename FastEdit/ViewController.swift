import Cocoa

class ViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    private var isLineWrapping: Bool = true
    private var findBarViewController: FindBarViewController?
    private var scrollViewTopConstraint: NSLayoutConstraint?
    private var savedSelectedTextAttributes: [NSAttributedString.Key: Any]?
    private var currentMatches: [NSTextCheckingResult] = []
    private var currentHighlightIndex: Int?
    private var _suppressSearchOnTextChange = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let doc = view.window?.windowController?.document as? PlainTextDocument else { return }
        textView.string = doc.text
    }

    private func setupTextView() {
        textView.isRichText = false
        textView.font = NSFont(name: "Osaka-Mono", size: 14)
            ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
    }

    // MARK: - Font Size

    private static let defaultFontSize: CGFloat = 14

    @IBAction func makeFontBigger(_ sender: Any?) {
        changeFontSize(by: 1)
    }

    @IBAction func makeFontSmaller(_ sender: Any?) {
        changeFontSize(by: -1)
    }

    @IBAction func resetFontSize(_ sender: Any?) {
        guard let currentFont = textView.font else { return }
        textView.font = NSFont(descriptor: currentFont.fontDescriptor, size: Self.defaultFontSize)
    }

    private func changeFontSize(by delta: CGFloat) {
        guard let currentFont = textView.font else { return }
        let newSize = max(1, currentFont.pointSize + delta)
        textView.font = NSFont(descriptor: currentFont.fontDescriptor, size: newSize)
    }

    // MARK: - Line Wrapping

    @IBAction func toggleLineWrapping(_ sender: Any?) {
        isLineWrapping.toggle()
        applyLineWrapping()
    }

    private func applyLineWrapping() {
        guard let scrollView = textView.enclosingScrollView,
              let textContainer = textView.textContainer else { return }

        if isLineWrapping {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.isHorizontallyResizable = false
            scrollView.hasHorizontalScroller = false
        } else {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.isHorizontallyResizable = true
            scrollView.hasHorizontalScroller = true
        }

        textView.needsDisplay = true
        textView.invalidateIntrinsicContentSize()
    }

    // MARK: - Find Bar

    @IBAction func findAction(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        switch menuItem.tag {
        case 1: // Find… (Cmd+F)
            showFindBar(replaceMode: false)
        case 12: // Find and Replace… (Cmd+Option+F)
            showFindBar(replaceMode: true)
        case 7: // Use Selection for Find (Cmd+E)
            if let findBar = findBarViewController {
                let selectedRange = textView.selectedRange()
                if selectedRange.length > 0 {
                    let selectedText = (textView.string as NSString).substring(with: selectedRange)
                    findBar.setSearchText(selectedText)
                }
            }
        default:
            break
        }
    }

    private func showFindBar(replaceMode: Bool) {
        if findBarViewController == nil {
            let vc = FindBarViewController()
            vc.delegate = self
            addChild(vc)

            let findBarView = vc.view
            findBarView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(findBarView)

            guard let scrollView = textView.enclosingScrollView else { return }

            // Find and deactivate the existing scroll view top constraint
            for constraint in view.constraints {
                if constraint.firstItem === scrollView && constraint.firstAttribute == .top
                    && constraint.secondItem === view && constraint.secondAttribute == .top
                {
                    scrollViewTopConstraint = constraint
                    constraint.isActive = false
                    break
                }
            }

            NSLayoutConstraint.activate([
                findBarView.topAnchor.constraint(equalTo: view.topAnchor),
                findBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                findBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: findBarView.bottomAnchor),
            ])

            // Disable native selection rendering; we draw it ourselves via temporary attributes
            savedSelectedTextAttributes = textView.selectedTextAttributes
            textView.selectedTextAttributes = [:]

            findBarViewController = vc
        }

        if replaceMode {
            findBarViewController?.showFindAndReplace()
        } else {
            findBarViewController?.showFind()
        }

        view.window?.makeFirstResponder(findBarViewController?.searchField)
    }

    private func hideFindBar() {
        guard let vc = findBarViewController else { return }

        clearHighlights()

        // Restore original selection attributes
        if let saved = savedSelectedTextAttributes {
            textView.selectedTextAttributes = saved
            savedSelectedTextAttributes = nil
        }

        let findBarView = vc.view
        guard let scrollView = textView.enclosingScrollView else { return }

        // Remove find bar constraints involving the scroll view
        for constraint in view.constraints {
            if constraint.firstItem === scrollView && constraint.firstAttribute == .top
                && constraint.secondItem === findBarView && constraint.secondAttribute == .bottom
            {
                constraint.isActive = false
                break
            }
        }

        findBarView.removeFromSuperview()
        vc.dismiss()
        vc.removeFromParent()

        // Restore scroll view top constraint
        scrollViewTopConstraint?.isActive = true
        scrollViewTopConstraint = nil

        findBarViewController = nil
        view.window?.makeFirstResponder(textView)
    }

    private func clearHighlights() {
        guard let layoutManager = textView.layoutManager else { return }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        currentMatches = []
        currentHighlightIndex = nil
    }

    /// Applies all three highlight layers via temporary attributes.
    /// Order (low to high priority): selection → matches → current target.
    /// Later calls to addTemporaryAttribute overwrite earlier ones on overlapping ranges.
    private func updateAllHighlights() {
        guard let layoutManager = textView.layoutManager else { return }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        // 1. Selection (lowest priority) — semi-transparent gray
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            let selectionColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: selectionColor, forCharacterRange: selectedRange)
        }

        // 2. Matches (middle priority) — yellow
        let matchColor = NSColor.findHighlightColor
        for match in currentMatches {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: matchColor, forCharacterRange: match.range)
        }

        // 3. Current target (highest priority) — orange
        if let index = currentHighlightIndex, index < currentMatches.count {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.orange, forCharacterRange: currentMatches[index].range)
        }
    }
}

extension ViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleLineWrapping(_:)) {
            menuItem.title = isLineWrapping ? "Unwrap Lines" : "Wrap Lines"
            return true
        }
        if menuItem.action == #selector(findAction(_:)) {
            return true
        }
        return true
    }
}

extension ViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let doc = view.window?.windowController?.document as? PlainTextDocument else { return }
        doc.text = textView.string
        doc.updateChangeCount(.changeDone)
        if !findBarSuppressSearchOnTextChange {
            findBarViewController?.performSearch()
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        if findBarViewController != nil {
            updateAllHighlights()
        }
    }
}

// MARK: - FindBarDelegate

extension ViewController: FindBarDelegate {
    var findBarTextView: NSTextView { textView }
    var findBarSuppressSearchOnTextChange: Bool {
        get { _suppressSearchOnTextChange }
        set { _suppressSearchOnTextChange = newValue }
    }

    func findBarDidRequestClose() {
        hideFindBar()
    }

    func findBarDidUpdateMatches(_ matches: [NSTextCheckingResult], currentIndex: Int?) {
        currentMatches = matches
        currentHighlightIndex = currentIndex
        updateAllHighlights()
    }
}
