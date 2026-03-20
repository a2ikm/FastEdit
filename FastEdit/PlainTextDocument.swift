import AppKit

class PlainTextDocument: NSDocument {

    nonisolated(unsafe) var text: String = ""

    nonisolated override class var autosavesInPlace: Bool { false }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let wc = storyboard.instantiateController(
            withIdentifier: "DocumentWindowController"
        ) as! NSWindowController
        wc.window?.tabbingMode = .disallowed
        addWindowController(wc)
    }

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr)
        }
        text = str
    }

    nonisolated override func data(ofType typeName: String) throws -> Data {
        guard let data = text.data(using: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr)
        }
        return data
    }

    override func canClose(
        withDelegate delegate: Any,
        shouldClose shouldCloseSelector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard isDocumentEdited else {
            // 変更なし — そのまま閉じる
            notifyShouldClose(true, delegate: delegate, selector: shouldCloseSelector, contextInfo: contextInfo)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?"
        alert.addButton(withTitle: "Save")           // 1st button — Enter
        alert.addButton(withTitle: "Don't Save")      // 2nd button — Space
        alert.buttons[1].keyEquivalent = " "

        guard let window = windowControllers.first?.window else {
            notifyShouldClose(false, delegate: delegate, selector: shouldCloseSelector, contextInfo: contextInfo)
            return
        }

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                self.save(withDelegate: delegate, didSave: shouldCloseSelector, contextInfo: contextInfo)
            } else {
                self.notifyShouldClose(true, delegate: delegate, selector: shouldCloseSelector, contextInfo: contextInfo)
            }
        }
    }

    private func notifyShouldClose(
        _ shouldClose: Bool,
        delegate: Any,
        selector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let selector = selector else { return }
        // NSDocument の shouldClose コールバック規約:
        // - (void)document:(NSDocument *)doc shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo
        let obj = delegate as AnyObject
        typealias Signature = @convention(c) (AnyObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        let method = unsafeBitCast(obj.method(for: selector), to: Signature.self)
        method(obj, selector, self, shouldClose, contextInfo)
    }
}
