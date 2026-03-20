import Cocoa

class ViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

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
}

extension ViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let doc = view.window?.windowController?.document as? PlainTextDocument else { return }
        doc.text = textView.string
        doc.updateChangeCount(.changeDone)
    }
}
