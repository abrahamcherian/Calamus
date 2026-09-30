import AppKit

/// NSTextView that can paint a highlight behind the caret's line.
final class EditorTextView: NSTextView {
    /// Where the right-click happened (when nothing was selected), so Insert Date/Time can go there.
    var pendingInsertLocation: Int?
    /// True when the last right-click selected the word under the pointer because nothing was selected.
    var rightClickSelectedWord = false
    /// Called just before an ordinary typed character reaches the text (used by Journal mode).
    var onBeforeTyping: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if let hook = onBeforeTyping, EditorTextView.isTypedCharacter(event) { hook() }
        super.keyDown(with: event)
    }

    private static func isTypedCharacter(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !flags.isDisjoint(with: [.command, .control, .function]) { return false }
        guard let scalar = event.characters?.unicodeScalars.first else { return false }
        let value = scalar.value
        return value >= 0x20 && value != 0x7F && !(0xF700...0xF8FF).contains(value)
    }

    var currentLineColor: NSColor? {
        didSet { needsDisplay = true }
    }

    /// The text view draws no background of its own (the clip view behind it paints the possibly
    /// see-through background once); it only adds the current-line highlight under the text.
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        if let color = currentLineColor, selectedRange().length == 0, let line = currentLineRect() {
            color.setFill()
            NSRect(x: bounds.minX, y: line.minY, width: bounds.width, height: line.height).fill()
        }
        super.draw(dirtyRect)
    }

    /// Right-click menu: case conversion and word counts, above the standard editing items.
    override func menu(for event: NSEvent) -> NSMenu? {
        pendingInsertLocation = nil
        rightClickSelectedWord = false
        // With nothing selected, right-clicking a word selects it so the commands apply to that word.
        if selectedRange().length == 0 {
            let ns = string as NSString
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            pendingInsertLocation = min(index, ns.length) // "Insert Date/Time" goes where you clicked
            if ns.length > 0 && index < ns.length {
                let range = selectionRange(forProposedRange: NSRange(location: index, length: 0),
                                           granularity: .selectByWord)
                let word = ns.substring(with: range)
                if !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    setSelectedRange(range)
                    rightClickSelectedWord = true
                }
            }
        }
        guard let menu = super.menu(for: event) else { return nil }
        let timeItem = NSMenuItem(title: "Insert Date/Time", action: nil, keyEquivalent: "")
        timeItem.submenu = TimeMenu.makeMenu(shortcuts: false, contextual: true)
        let commentItem = NSMenuItem(title: "Toggle Comment", action: #selector(EditorViewController.toggleLineComment(_:)), keyEquivalent: "/")
        commentItem.keyEquivalentModifierMask = [.command]
        commentItem.representedObject = "context"
        let blockCommentItem = NSMenuItem(title: "Toggle Block Comment", action: #selector(EditorViewController.toggleBlockComment(_:)), keyEquivalent: "/")
        blockCommentItem.keyEquivalentModifierMask = [.command, .option]
        blockCommentItem.representedObject = "context"
        let tabularizeItem = NSMenuItem(title: "Tabularize Data…", action: #selector(EditorViewController.showTextFormatting(_:)), keyEquivalent: "")
        tabularizeItem.representedObject = TextFormatTool.tabularize.rawValue
        let htmlItem = NSMenuItem(title: "HTML Escape / Unescape", action: nil, keyEquivalent: "")
        htmlItem.submenu = HTMLCoding.makeMenu()
        let urlItem = NSMenuItem(title: "URL Encode / Decode", action: nil, keyEquivalent: "")
        urlItem.submenu = URLCoding.makeMenu()

        // macOS doesn't let an app add items to the native tab bar's own right-click menu (no
        // public API for that), so these tab-level commands - the closest equivalent to
        // "right-click a tab" - live here on the editor's own right-click menu instead, and on
        // the Window menu. All are nil-targeted and resolve through the responder chain, same
        // as the items above.
        let tabMenu = NSMenu(title: "Tab")
        tabMenu.addItem(NSMenuItem(title: "Close Tabs to the Right", action: #selector(AppDelegate.closeTabsToRight(_:)), keyEquivalent: ""))
        tabMenu.addItem(NSMenuItem(title: "Close Tabs to the Left", action: #selector(AppDelegate.closeTabsToLeft(_:)), keyEquivalent: ""))
        tabMenu.addItem(.separator())
        tabMenu.addItem(NSMenuItem(title: "Duplicate Tab", action: #selector(AppDelegate.duplicateTab(_:)), keyEquivalent: ""))
        tabMenu.addItem(NSMenuItem(title: "Pin Tab", action: #selector(AppDelegate.togglePinTab(_:)), keyEquivalent: ""))
        tabMenu.addItem(.separator())
        tabMenu.addItem(NSMenuItem(title: "Split Horizontally", action: #selector(EditorViewController.splitHorizontally(_:)), keyEquivalent: ""))
        tabMenu.addItem(NSMenuItem(title: "Split Vertically", action: #selector(EditorViewController.splitVertically(_:)), keyEquivalent: ""))
        tabMenu.addItem(NSMenuItem(title: "Change Split Tab…", action: #selector(EditorViewController.changeSplitTab(_:)), keyEquivalent: ""))
        let tabItem = NSMenuItem(title: "Tab", action: nil, keyEquivalent: "")
        tabItem.submenu = tabMenu

        let items: [NSMenuItem] = [
            NSMenuItem(title: "Change to UPPERCASE", action: #selector(EditorViewController.uppercaseSelection(_:)), keyEquivalent: ""),
            NSMenuItem(title: "Change to lowercase", action: #selector(EditorViewController.lowercaseSelection(_:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Word Count – Whole Document…", action: #selector(EditorViewController.showWordCountDocument(_:)), keyEquivalent: ""),
            NSMenuItem(title: "Word Count – Selected Text…", action: #selector(EditorViewController.showWordCountSelection(_:)), keyEquivalent: ""),
            .separator(),
            timeItem,
            .separator(),
            commentItem,
            blockCommentItem,
            .separator(),
            tabularizeItem,
            urlItem,
            htmlItem,
            .separator(),
            tabItem,
            .separator()
        ]
        for (position, item) in items.enumerated() { menu.insertItem(item, at: position) }
        return menu
    }

    private func currentLineRect() -> NSRect? {
        guard let lm = layoutManager else { return nil }
        let length = (string as NSString).length
        let location = selectedRange().location
        var rect: NSRect
        if location >= length {
            if lm.extraLineFragmentTextContainer != nil {
                rect = lm.extraLineFragmentRect
            } else if length > 0 && lm.numberOfGlyphs > 0 {
                rect = lm.lineFragmentRect(forGlyphAt: lm.numberOfGlyphs - 1, effectiveRange: nil)
            } else {
                return nil
            }
        } else {
            let glyph = lm.glyphIndexForCharacter(at: location)
            rect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        rect.origin.y += textContainerOrigin.y
        return rect
    }
}

/// Container view that reports light/dark appearance changes so "Auto" themes can follow the system.
final class AppearanceAwareView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

/// A plain view that only shows a background color (with its transparency) and ignores the mouse.
private final class TextBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Clip view whose background is a separate see-through view placed right behind it. AppKit resets the
/// layer color of its own clip views (which made the text area fully clear at launch), but leaves the
/// layer color of an ordinary view alone.
final class TranslucentClipView: NSClipView {
    private let backgroundView = TextBackgroundView()

    /// Background color including its transparency.
    var fillColor: NSColor = .clear {
        didSet {
            backgroundView.layer?.backgroundColor = fillColor.cgColor
            backgroundView.layer?.isOpaque = false
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        drawsBackground = false
    }

    override var isOpaque: Bool { false }

    /// Re-applies the color and position (called when a window or tab appears).
    func refreshBackground() {
        backgroundView.frame = frame
        backgroundView.layer?.backgroundColor = fillColor.cgColor
        if backgroundView.superview == nil, let parent = superview {
            parent.addSubview(backgroundView, positioned: .below, relativeTo: self)
        }
    }

    override var frame: NSRect {
        didSet { backgroundView.frame = frame }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        backgroundView.removeFromSuperview()
        guard let parent = superview else { return }
        backgroundView.frame = frame
        backgroundView.layer?.backgroundColor = fillColor.cgColor
        parent.addSubview(backgroundView, positioned: .below, relativeTo: self)
    }
}
