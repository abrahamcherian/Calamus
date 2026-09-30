import AppKit

/// One open file (one tab). Owns the bytes-level concerns: encoding, line endings, load and save.
/// The text itself lives in the editor's NSTextView while the window is open.
@objc(NPTextDocument)
final class TextDocument: NSDocument {
    var text: String = ""
    var encodingChoice: TextEncodingChoice = .utf8
    var lineEnding: LineEnding = .lf
    weak var editor: EditorViewController?

    override class var autosavesInPlace: Bool { false }

    override var fileURL: URL? {
        didSet { editor?.documentURLChanged() }
    }

    /// Overrides the tab/window title for a document that isn't backed by a file yet,
    /// such as the bundled Read Me note. Nil (the default) falls back to the usual
    /// "Untitled" naming.
    var explicitDisplayName: String?
    override var displayName: String! {
        get { explicitDisplayName ?? super.displayName }
        set { super.displayName = newValue }
    }

    // MARK: - Windows

    override func makeWindowControllers() {
        let editorVC = EditorViewController(document: self)
        let window = NSWindow(contentViewController: editorVC)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 960, height: 680))
        window.tabbingMode = .preferred
        window.tabbingIdentifier = EditorWindowController.tabIdentifier
        let controller = EditorWindowController(window: window)
        controller.shouldCascadeWindows = true
        addWindowController(controller)
    }

    // MARK: - Reading and writing

    override func read(from data: Data, ofType typeName: String) throws {
        let decoded = TextEncodingChoice.decode(data)
        text = decoded.text
        encodingChoice = decoded.encoding
        lineEnding = LineEnding.detect(decoded.text)
        editor?.reloadContent()
    }

    override func data(ofType typeName: String) throws -> Data {
        let current = editor?.currentText ?? text
        let normalized = LineEnding.convert(current, to: lineEnding)
        guard let data = encodingChoice.encode(normalized) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding, userInfo: [
                NSLocalizedDescriptionKey:
                    "This text can't be saved as \(encodingChoice.label) without losing characters. "
                    + "Choose a different encoding from Format \u{25B8} Encoding and try again."
            ])
        }
        return data
    }

    // MARK: - Closing

    /// Runs before the document actually closes, so if it's involved in a Split View pane -
    /// either being shown in another window's split pane, or hosting its own split pane on a
    /// different document - that relationship is torn down cleanly rather than left pointing at
    /// text storage or a window that's about to go away. See `EditorViewController.documentWillClose()`.
    override func close() {
        editor?.documentWillClose()
        super.close()
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        // Let people choose any file extension (.py, .json, ...) instead of forcing .txt.
        // (Set through key-value coding: the typed property is deprecated and its replacement needs a newer SDK.)
        savePanel.setValue(nil, forKey: "allowedFileTypes")
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = false
        return true
    }

    // MARK: - Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = NSPrintInfo(dictionary: printSettings)
        // NSPrintInfo.paperSize always reports the paper's portrait dimensions, even when Page
        // Setup has Orientation set to Landscape - it's up to whoever builds the print view to
        // swap them. Without this, the text wraps to the narrow portrait width no matter what
        // orientation was chosen, so the printed page reads as portrait either way.
        var paperSize = info.paperSize
        if info.orientation == .landscape {
            paperSize = NSSize(width: paperSize.height, height: paperSize.width)
        }
        let width = paperSize.width - info.leftMargin - info.rightMargin
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: max(100, width), height: 100))
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        view.textColor = .black
        view.backgroundColor = .white
        view.string = editor?.currentText ?? text
        view.sizeToFit()
        return NSPrintOperation(view: view, printInfo: info)
    }

    // MARK: - Format menu actions (found through the responder chain)

    @objc func setEncoding(_ sender: NSMenuItem) {
        guard let choice = TextEncodingChoice(rawValue: sender.tag) else { return }
        encodingChoice = choice
        updateChangeCount(.changeDone)
        editor?.refreshStatus()
    }

    @objc func setLineEnding(_ sender: NSMenuItem) {
        guard let choice = LineEnding(rawValue: sender.tag) else { return }
        lineEnding = choice
        updateChangeCount(.changeDone)
        editor?.refreshStatus()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setEncoding(_:)) {
            menuItem.state = (menuItem.tag == encodingChoice.rawValue) ? .on : .off
            return true
        }
        if menuItem.action == #selector(setLineEnding(_:)) {
            menuItem.state = (menuItem.tag == lineEnding.rawValue) ? .on : .off
            return true
        }
        return super.validateMenuItem(menuItem)
    }
}

/// Window controller for one editor tab.
final class EditorWindowController: NSWindowController {
    static let tabIdentifier = "CalamusEditorTab"

    var editor: EditorViewController? { contentViewController as? EditorViewController }

    /// New documents join the current window as a tab, using macOS's native tab bar.
    override func showWindow(_ sender: Any?) {
        if let w = window, !w.isVisible, w.tabbingIdentifier == EditorWindowController.tabIdentifier {
            let candidates: [NSWindow?] = [NSApp.keyWindow, NSApp.mainWindow]
            let host = candidates.compactMap { $0 }.first { $0 !== w && $0.windowController is EditorWindowController }
                ?? NSApp.windows.first { $0 !== w && $0.isVisible && $0.windowController is EditorWindowController }
            host?.addTabbedWindow(w, ordered: .above)
        }
        super.showWindow(sender)
    }

    /// Called by the "+" button in the tab bar.
    @objc override func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }
}

enum EditorContext {
    /// The editor in the frontmost document window (used by the Find panels).
    static var current: EditorViewController? {
        (NSApp.mainWindow?.windowController as? EditorWindowController)?.editor
    }
}
