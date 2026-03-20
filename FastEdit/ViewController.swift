import Cocoa

class ViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    private var isLineWrapping: Bool = true

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
        textView.usesFindBar = true
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

}

extension ViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleLineWrapping(_:)) {
            menuItem.title = isLineWrapping ? "Unwrap Lines" : "Wrap Lines"
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
    }
}
