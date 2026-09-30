import AppKit

/// The content of one tab: text view + line numbers + status bar.
final class EditorViewController: NSViewController, NSTextViewDelegate, NSMenuItemValidation {
    private(set) weak var doc: TextDocument?

    private let scrollView = NSScrollView()
    private(set) var textView: EditorTextView!
    private var ruler: LineNumberRulerView!
    private let lineIndex = LineIndex()

    private(set) var language: Language = .plain
    private var languageOverridden = false
    private var theme: Theme = .light
    private var highlightWork: DispatchWorkItem?
    private var randomSheet: RandomGeneratorSheet?
    private var formatSheet: TextFormatSheet?
    private var uuidCountClamp: CountFieldClamp?
    private var voiceRange: NSRange?
    private var voiceCommittedWords: [String] = []
    private var voicePendingWord: String = ""
    private var voiceHasInsertedWord = false
    private var previewScrollView: NSScrollView!
    private var previewTextView: NSTextView!
    private(set) var isPreviewingMarkdown = false
    private var lastTypedAt: Date?
    private static let largeFileThreshold = 400_000

    // Split view: a second pane showing a DIFFERENT, already-open tab side by side with this
    // one (its own NSLayoutManager/NSTextContainer/NSTextView, attached to that OTHER
    // document's NSTextStorage) - for Window > Split Horizontally/Vertically and the matching
    // items in the right-click menu. nil when not split.
    private let splitView = NSSplitView()
    private var splitScrollView: NSScrollView?
    private var splitTextView: EditorTextView?
    private var splitRuler: LineNumberRulerView?
    /// The OTHER document's own editor, when this window's split pane is showing it. Its own
    /// undo manager, dirty tracking, journal mode and line numbering all still apply - typing
    /// in the split pane is exactly like typing into that document's own primary pane.
    private weak var splitDocumentEditor: EditorViewController?
    /// True while a second pane is showing.
    var isSplit: Bool { splitScrollView != nil }

    /// Other windows' split panes currently showing THIS document (their EditorTextView +
    /// LineNumberRulerView pair). Kept in sync by `applyPreferences()`/`highlightNow()`/the
    /// NSTextViewDelegate callbacks below, alongside this document's own `textView`. A window
    /// registers itself here in `beginSplit(with:vertical:)` and unregisters in `removeSplit()`.
    private var externalMirrors: [(textView: EditorTextView, ruler: LineNumberRulerView)] = []
    /// Set while this document is being shown in ANOTHER window's split pane, so it knows who
    /// to tell (`removeSplitIfMirroring`) if it's about to close.
    private weak var mirroredBy: EditorViewController?

    private let statusBar = NSView()
    private let statusLeft = NSTextField(labelWithString: "")
    private let eolLabel = NSTextField(labelWithString: "")
    private let encodingLabel = NSTextField(labelWithString: "")
    private let languageButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let voiceButton = NSButton(title: "", target: nil, action: nil)
    private let readButton = NSButton(title: "", target: nil, action: nil)

    // MARK: - Lifecycle

    init(document: TextDocument) {
        self.doc = document
        super.init(nibName: nil, bundle: nil)
        document.editor = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = AppearanceAwareView(frame: NSRect(x: 0, y: 0, width: 960, height: 680))
        container.onAppearanceChange = { [weak self] in self?.applyPreferences() }
        view = container

        buildTextView()
        buildPreviewView()
        buildStatusBar()

        // scrollView lives inside splitView from the start (as its only arranged subview) so
        // that opening a split later is just adding a second arranged subview - nothing about
        // scrollView's own constraints or position needs to change at that point.
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(splitView)
        container.addSubview(previewScrollView)
        container.addSubview(statusBar)
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: container.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            previewScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            previewScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            previewScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            previewScrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange),
                                               name: .preferencesChanged, object: nil)
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        reloadContent()
    }

    /// Lets the desktop show through the editor when the background opacity is below 100%.
    private func applyWindowTransparency() {
        guard let window = view.window else { return }
        let translucent = Preferences.shared.windowOpacity < 100 || Preferences.shared.textOpacity < 100
        window.isOpaque = !translucent
        // Classic always-visible scroll bars leave strips at the right and bottom edges that cannot be
        // tinted, so they showed the desktop completely. Overlay scroll bars sit on top of the text instead.
        scrollView.scrollerStyle = translucent ? .overlay : NSScroller.preferredScrollerStyle
        scrollView.autohidesScrollers = translucent
        window.backgroundColor = translucent ? .clear : .windowBackgroundColor
        window.hasShadow = true
        window.invalidateShadow()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyWindowTransparency()
        (scrollView.contentView as? TranslucentClipView)?.refreshBackground()
        view.window?.makeFirstResponder(textView)
        refreshTabTitle()
        refreshVoiceButtonState()
        refreshReadButtonState()
    }

    // MARK: - View construction

    private func buildTextView() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 960, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let tv = EditorTextView(frame: NSRect(x: 0, y: 0, width: 960, height: 656), textContainer: container)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.allowsUndo = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFontPanel = false
        tv.usesFindBar = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.delegate = self
        tv.onBeforeTyping = { [weak self] in self?.journalWillType() }
        textView = tv

        scrollView.contentView = TranslucentClipView()
        scrollView.documentView = tv
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false          // the clip view paints the background
        scrollView.contentView.drawsBackground = false

        ruler = LineNumberRulerView(textView: tv, lineIndex: lineIndex)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = Preferences.shared.showLineNumbers
    }

    /// A read-only sibling to `scrollView` for View > Markdown Preview. Kept entirely separate
    /// from `textView`'s storage so previewing never touches the text that gets saved to disk.
    /// Always a plain white page with black text - the standard look for a Markdown preview -
    /// regardless of whatever editor theme (dark, Monokai, etc.) is currently active.
    private func buildPreviewView() {
        let scroll = NSTextView.scrollableTextView()
        let tv = (scroll.documentView as? NSTextView) ?? NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = true
        tv.backgroundColor = .white
        tv.textColor = .black
        tv.textContainerInset = NSSize(width: 14, height: 12)
        scroll.drawsBackground = true
        scroll.backgroundColor = .white
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.isHidden = true
        previewScrollView = scroll
        previewTextView = tv
    }

    /// Re-renders the Markdown preview from the current text. Fixed white/black colors (see
    /// `buildPreviewView`), independent of the editor's theme.
    private func renderMarkdownPreview() {
        let rendered = MarkdownPreview.render(textView.string, baseFont: Preferences.shared.editorFont,
                                              textColor: .black, accentColor: NSColor(hex: 0x999999))
        previewTextView.textStorage?.setAttributedString(rendered)
        previewTextView.backgroundColor = .white
    }

    private func buildStatusBar() {
        statusBar.wantsLayer = true

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let statusFont = NSFont.systemFont(ofSize: 11)
        for label in [statusLeft, eolLabel, encodingLabel] {
            label.font = statusFont
            label.lineBreakMode = .byTruncatingTail
        }
        statusLeft.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(250), for: .horizontal)

        languageButton.controlSize = .small
        languageButton.font = statusFont
        languageButton.addItems(withTitles: Language.all.map { $0.name })
        languageButton.target = self
        languageButton.action = #selector(setLanguage(_:))

        voiceButton.bezelStyle = .inline
        voiceButton.controlSize = .small
        voiceButton.font = statusFont
        voiceButton.target = self
        voiceButton.action = #selector(toggleVoiceToText(_:))
        refreshVoiceButtonState()

        readButton.bezelStyle = .inline
        readButton.controlSize = .small
        readButton.font = statusFont
        readButton.target = self
        readButton.action = #selector(toggleReadAloud(_:))
        refreshReadButtonState()

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let stack = NSStackView(views: [statusLeft, spacer, voiceButton, readButton, eolLabel, encodingLabel, languageButton])
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        statusBar.addSubview(stack)
        statusBar.addSubview(separator)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: statusBar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: statusBar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor),
            separator.topAnchor.constraint(equalTo: statusBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor)
        ])
    }

    // MARK: - Content

    /// The current text (from the text view when the window exists, otherwise the document's copy).
    var currentText: String {
        isViewLoaded ? textView.string : (doc?.text ?? "")
    }

    func reloadContent() {
        guard isViewLoaded, let doc = doc else { return }
        if isPreviewingMarkdown {
            isPreviewingMarkdown = false
            scrollView.isHidden = false
            previewScrollView.isHidden = true
        }
        textView.string = doc.text
        lineIndex.rebuild(textView.string as NSString)
        if !languageOverridden { language = Language.detect(url: doc.fileURL) }
        applyPreferences()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        doc.undoManager?.removeAllActions()
        refreshStatus()
        refreshTabTitle()
    }

    func documentURLChanged() {
        guard isViewLoaded else { return }
        if !languageOverridden {
            language = Language.detect(url: doc?.fileURL)
            scheduleHighlight(immediate: true)
        }
        refreshStatus()
        refreshTabTitle()
        // Covers Save As on the already-frontmost window, which doesn't trigger a fresh
        // "window became key" notification the way opening or switching to a tab does.
        if view.window?.isKeyWindow == true { LastDocument.noteActive(url: doc?.fileURL) }
    }

    /// Adds a pin to this tab's label when its file is pinned (Window > Pin Tab). Only the
    /// tab strip's own title is touched — the window's title bar and Save panel are unaffected.
    func refreshTabTitle() {
        guard let window = view.window else { return }
        let base = window.title
        window.tab.title = PinnedTabs.shared.isPinned(window) ? "\u{1F4CC} " + base : base
    }

    // MARK: - Preferences

    @objc private func preferencesDidChange() {
        applyPreferences()
    }

    func applyPreferences() {
        guard isViewLoaded else { return }
        let prefs = Preferences.shared
        let dark = view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        theme = prefs.resolvedTheme(darkAppearance: dark)
        let font = prefs.editorFont

        textView.font = font
        textView.textColor = theme.foreground
        let alpha = CGFloat(prefs.windowOpacity) / 100        // gutter, status bar, window
        let textAlpha = CGFloat(prefs.textOpacity) / 100      // the writing area
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.insertionPointColor = theme.foreground
        textView.selectedTextAttributes = [.backgroundColor: theme.selection]
        textView.currentLineColor = prefs.highlightCurrentLine ? theme.currentLine : nil
        (scrollView.contentView as? TranslucentClipView)?.fillColor = theme.background.withAlphaComponent(textAlpha)
        applyWindowTransparency()

        let style = NSMutableParagraphStyle()
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        style.defaultTabInterval = spaceWidth * CGFloat(prefs.tabWidth)
        style.tabStops = []
        textView.defaultParagraphStyle = style
        textView.typingAttributes[.paragraphStyle] = style
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: storage.length))
        }

        applyWordWrap(prefs.wordWrap)
        textView.layoutManager?.showsInvisibleCharacters = prefs.showInvisibles
        textView.layoutManager?.showsControlCharacters = prefs.showInvisibles

        scrollView.rulersVisible = prefs.showLineNumbers
        ruler.gutterColor = theme.gutterBackground.withAlphaComponent(alpha)
        ruler.numberColor = theme.gutterForeground
        ruler.activeNumberColor = theme.foreground
        ruler.numberFont = NSFont.monospacedDigitSystemFont(ofSize: max(9, CGFloat(prefs.fontSize) - 2), weight: .regular)
        ruler.contentChanged()

        statusBar.layer?.backgroundColor = theme.gutterBackground.withAlphaComponent(alpha).cgColor
        for label in [statusLeft, eolLabel, encodingLabel] { label.textColor = theme.gutterForeground }

        // Mirror everything above onto any OTHER window's split pane currently showing THIS
        // document (see `externalMirrors`), so a pane stays visually identical to this
        // document's own primary pane no matter which window displays it. (This window's own
        // split pane, if it has one, is a DIFFERENT document entirely and styles itself the
        // same way when ITS OWN applyPreferences() runs.)
        for mirror in externalMirrors {
            styleMirrorTextView(mirror.textView, ruler: mirror.ruler, font: font, theme: theme,
                                style: style, prefs: prefs, alpha: alpha, textAlpha: textAlpha)
        }

        scheduleHighlight(immediate: true)
        textView.needsDisplay = true

        previewTextView?.textContainerInset = NSSize(width: 14, height: 12)
        if isPreviewingMarkdown {
            renderMarkdownPreview()
        }
    }

    /// Applies this document's current font/theme/paragraph-style settings to one mirror text
    /// view + ruler pair living in another window's split pane. Used by the loop in
    /// `applyPreferences()` above, and (via that same call) right after a new mirror pane is
    /// created in `beginSplit(with:vertical:)`.
    private func styleMirrorTextView(_ tv: EditorTextView, ruler mirrorRuler: LineNumberRulerView,
                                     font: NSFont, theme: Theme, style: NSParagraphStyle,
                                     prefs: Preferences, alpha: CGFloat, textAlpha: CGFloat) {
        tv.font = font
        tv.textColor = theme.foreground
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.insertionPointColor = theme.foreground
        tv.selectedTextAttributes = [.backgroundColor: theme.selection]
        tv.currentLineColor = prefs.highlightCurrentLine ? theme.currentLine : nil
        (tv.enclosingScrollView?.contentView as? TranslucentClipView)?.fillColor = theme.background.withAlphaComponent(textAlpha)
        tv.defaultParagraphStyle = style
        tv.typingAttributes[.paragraphStyle] = style
        tv.layoutManager?.showsInvisibleCharacters = prefs.showInvisibles
        tv.layoutManager?.showsControlCharacters = prefs.showInvisibles
        tv.enclosingScrollView?.rulersVisible = prefs.showLineNumbers
        mirrorRuler.gutterColor = theme.gutterBackground.withAlphaComponent(alpha)
        mirrorRuler.numberColor = theme.gutterForeground
        mirrorRuler.activeNumberColor = theme.foreground
        mirrorRuler.numberFont = NSFont.monospacedDigitSystemFont(ofSize: max(9, CGFloat(prefs.fontSize) - 2), weight: .regular)
        mirrorRuler.contentChanged()
        tv.needsDisplay = true
    }

    private func applyWordWrap(_ wrap: Bool) {
        applyWordWrap(wrap, to: textView, in: scrollView)
        // Any OTHER window currently mirroring THIS document (see `externalMirrors`) gets the
        // same treatment - this window's OWN split pane, if it has one, shows a different
        // document now and is wrapped by that document's own applyPreferences() instead.
        for mirror in externalMirrors {
            if let mirrorScroll = mirror.textView.enclosingScrollView {
                applyWordWrap(wrap, to: mirror.textView, in: mirrorScroll)
            }
        }
    }

    private func applyWordWrap(_ wrap: Bool, to textView: EditorTextView, in scrollView: NSScrollView) {
        guard let container = textView.textContainer else { return }
        if wrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: scrollView.contentSize.width,
                                             height: CGFloat.greatestFiniteMagnitude)
            var frame = textView.frame
            frame.size.width = scrollView.contentSize.width
            textView.frame = frame
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                             height: CGFloat.greatestFiniteMagnitude)
        }
    }

    // MARK: - Highlighting

    private func scheduleHighlight(immediate: Bool = false) {
        highlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.highlightNow() }
        highlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (immediate ? 0 : 0.12), execute: work)
    }

    private func highlightNow() {
        guard isViewLoaded,
              let lm = textView.layoutManager,
              let storage = textView.textStorage,
              textView.textContainer != nil else { return }
        let length = storage.length
        var range = NSRange(location: 0, length: length)
        if length > EditorViewController.largeFileThreshold {
            // Big files: only color what is on screen (plus a margin) - in this pane, and in
            // any OTHER window currently mirroring this document in its own split pane (see
            // `externalMirrors`), since each can be scrolled to a completely different part of
            // the file. (This window's OWN split pane, if it has one, shows a different
            // document entirely now, so it plays no part in this document's highlighting.)
            func visibleChars(_ tv: NSTextView) -> NSRange? {
                guard let lm = tv.layoutManager, let container = tv.textContainer else { return nil }
                let glyphs = lm.glyphRange(forBoundingRect: tv.visibleRect, in: container)
                return lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            }
            var start = length
            var end = 0
            var visibleIn: [EditorTextView] = [textView]
            visibleIn.append(contentsOf: externalMirrors.map { $0.textView })
            for tv in visibleIn {
                guard let chars = visibleChars(tv) else { continue }
                start = min(start, max(0, chars.location - 20_000))
                end = max(end, min(length, NSMaxRange(chars) + 20_000))
            }
            range = (storage.string as NSString).lineRange(for: NSRange(location: start, length: max(0, end - start)))
        }
        SyntaxHighlighter.apply(language: language, theme: theme, layoutManager: lm, storage: storage, range: range)
    }

    @objc private func scrolled() {
        ruler.setNeedsDisplay(ruler.bounds)
        if Preferences.shared.textOpacity < 100 { textView.setNeedsDisplay(textView.visibleRect) }
        if (textView.textStorage?.length ?? 0) > EditorViewController.largeFileThreshold { scheduleHighlight() }
    }

    // MARK: - Status bar

    /// Always this window's own document, regardless of which pane has keyboard focus - a
    /// split pane now shows a different document entirely, which already has its own status
    /// bar in its own window/tab. (Read Aloud is the one thing that still follows focus - see
    /// `activeTextView`.)
    func refreshStatus() {
        guard isViewLoaded else { return }
        let ns = textView.string as NSString
        let sel = textView.selectedRange()
        let line = lineIndex.lineNumber(at: sel.location)
        let column = sel.location - lineIndex.lineStart(ofLine: line) + 1
        var left = "Ln \(line), Col \(column)"
        if sel.length > 0 { left += "   Sel \(sel.length)" }
        left += "   Length \(ns.length)   Lines \(lineIndex.count)"
        statusLeft.stringValue = left
        eolLabel.stringValue = doc?.lineEnding.shortLabel ?? "LF"
        encodingLabel.stringValue = doc?.encodingChoice.label ?? "UTF-8"
        languageButton.selectItem(withTitle: language.name)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        lineIndex.rebuild(textView.string as NSString)
        ruler.contentChanged()
        // Keep this document's own line numbers up to date in any OTHER window mirroring it
        // (see `externalMirrors`) too - including when the edit was typed directly into that
        // mirror pane, since its delegate is this same editor (see `beginSplit(with:vertical:)`).
        for mirror in externalMirrors { mirror.ruler.contentChanged() }
        refreshStatus()
        scheduleHighlight()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        refreshStatus()
        textView.needsDisplay = true
        ruler.needsDisplay = true
        if let changed = notification.object as? NSTextView,
           let mirror = externalMirrors.first(where: { $0.textView === changed }) {
            mirror.textView.needsDisplay = true
            mirror.ruler.needsDisplay = true
        }
    }

    func undoManager(for view: NSTextView) -> UndoManager? {
        doc?.undoManager
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            // Auto-indent: copy the leading whitespace of the current line.
            let ns = textView.string as NSString
            let sel = textView.selectedRange()
            let lineStart = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
            var indent = ""
            var i = lineStart
            while i < sel.location {
                let c = ns.character(at: i)
                if c == 32 { indent += " " } else if c == 9 { indent += "\t" } else { break }
                i += 1
            }
            textView.insertText("\n" + indent, replacementRange: sel)
            return true
        case #selector(NSResponder.insertTab(_:)):
            let sel = textView.selectedRange()
            if sel.length > 0, (textView.string as NSString).substring(with: sel).contains(where: { $0.isNewline }) {
                indentSelection(nil)
                return true
            }
            return false
        case #selector(NSResponder.insertBacktab(_:)):
            unindentSelection(nil)
            return true
        default:
            return false
        }
    }

    // MARK: - Editing helpers

    func apply(_ edit: TextEdit) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        if tv.shouldChangeText(in: edit.range, replacementString: edit.replacement) {
            storage.replaceCharacters(in: edit.range, with: edit.replacement)
            // NSTextStorage's own replaceCharacters(in:with:) only inherits attributes from an
            // adjacent character, so inserting into an empty document (nothing to inherit from -
            // e.g. Voice to Text as the very first thing typed into a brand-new Untitled tab)
            // left the new text in AppKit's bare fallback (black, system font) instead of the
            // editor's actual font/color/spacing. Reasserting the current typing attributes here
            // matches what happens when the same text is typed by hand.
            let insertedRange = NSRange(location: edit.range.location, length: (edit.replacement as NSString).length)
            if NSMaxRange(insertedRange) <= storage.length {
                storage.addAttributes(tv.typingAttributes, range: insertedRange)
            }
            tv.didChangeText()
        }
        let length = storage.length
        let location = min(edit.selection.location, length)
        let selection = NSRange(location: location, length: min(edit.selection.length, length - location))
        tv.setSelectedRange(selection)
        tv.scrollRangeToVisible(selection)
    }

    private func run(_ operation: (NSString, NSRange) -> TextEdit?) {
        guard isViewLoaded else { return }
        let ns = textView.string as NSString
        guard let edit = operation(ns, textView.selectedRange()) else {
            NSSound.beep()
            return
        }
        apply(edit)
    }

    /// Selects a range and scrolls it into view (used by Find and Find in Files).
    func reveal(range: NSRange) {
        guard isViewLoaded else { return }
        let length = (textView.string as NSString).length
        guard NSMaxRange(range) <= length else { return }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        if range.length > 0 { textView.showFindIndicator(for: range) }
        textView.window?.makeFirstResponder(textView)
    }

    func goTo(line number: Int) {
        let line = max(1, min(number, lineIndex.count))
        reveal(range: NSRange(location: lineIndex.lineStart(ofLine: line), length: 0))
    }

    // MARK: - Edit menu actions

    @objc func duplicateLine(_ sender: Any?) { run { LineOps.duplicateLines($0, $1) } }
    @objc func deleteLine(_ sender: Any?) { run { LineOps.deleteLines($0, $1) } }
    @objc func moveLineUp(_ sender: Any?) { run { LineOps.moveLinesUp($0, $1) } }
    @objc func moveLineDown(_ sender: Any?) { run { LineOps.moveLinesDown($0, $1) } }
    @objc func joinLines(_ sender: Any?) { run { LineOps.joinLines($0, $1) } }
    @objc func sortLinesAscending(_ sender: Any?) {
        run { LineOps.sortLines($0, $1, ascending: true, ignoreCase: false) }
    }
    @objc func sortLinesDescending(_ sender: Any?) {
        run { LineOps.sortLines($0, $1, ascending: false, ignoreCase: false) }
    }
    @objc func removeDuplicateLines(_ sender: Any?) { run { LineOps.removeDuplicateLines($0, $1) } }
    @objc func trimTrailingWhitespace(_ sender: Any?) { run { LineOps.trimTrailingWhitespace($0, $1) } }
    @objc func uppercaseSelection(_ sender: Any?) { changeCase(upper: true) }
    @objc func lowercaseSelection(_ sender: Any?) { changeCase(upper: false) }

    /// Changes the case of the selection, or of the word at the cursor when nothing is selected.
    private func changeCase(upper: Bool) {
        guard isViewLoaded else { return }
        let ns = textView.string as NSString
        var range = textView.selectedRange()
        if range.length == 0 { range = wordRange(at: range.location) }
        guard range.length > 0, let edit = LineOps.changeCase(ns, range, upper: upper) else {
            NSSound.beep()
            return
        }
        apply(edit)
    }

    /// The word around (or just before) a caret position; empty if there is no word there.
    private func wordRange(at location: Int) -> NSRange {
        let ns = textView.string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        func isBlank(_ index: Int) -> Bool {
            guard let scalar = Unicode.Scalar(ns.character(at: index)) else { return false }
            return CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        var probe = min(location, ns.length - 1)
        if probe > 0 && isBlank(probe) && !isBlank(probe - 1) { probe -= 1 } // caret right after a word
        let range = textView.selectionRange(forProposedRange: NSRange(location: probe, length: 0),
                                            granularity: .selectByWord)
        let word = ns.substring(with: range)
        if word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return NSRange(location: 0, length: 0) }
        return range
    }

    // MARK: - Insert menu (lines, UUIDs, lorem ipsum, file info, banners, special characters)

    /// Inserts text at the cursor (replacing any selection).
    private func insertInline(_ text: String) {
        textView.insertText(text, replacementRange: textView.selectedRange())
    }

    /// Inserts text so that it sits on its own line(s), adding line breaks around it when needed.
    private func insertBlock(_ block: String) {
        let ns = textView.string as NSString
        let selection = textView.selectedRange()
        var prefix = ""
        var suffix = "\n"
        if selection.location > 0 {
            let before = ns.character(at: selection.location - 1)
            if before != 10 && before != 13 { prefix = "\n" }
        }
        let end = NSMaxRange(selection)
        if end < ns.length {
            let after = ns.character(at: end)
            if after == 10 || after == 13 { suffix = "" }
        }
        textView.insertText(prefix + block + suffix, replacementRange: selection)
    }

    /// Handles the Insert menu items that carry an id: horizontal lines, UUIDs, lorem ipsum, file info.
    @objc func insertSnippet(_ sender: Any?) {
        guard isViewLoaded, let item = sender as? NSMenuItem, let id = item.representedObject as? String else {
            NSSound.beep()
            return
        }
        if id.hasPrefix("line.") {
            guard let line = InsertSnippets.horizontalLine(id: id, width: Preferences.shared.insertLineWidth) else { return }
            insertBlock(line)
        } else if id.hasPrefix("uuid.") {
            if let value = UUIDGenerator.canonical(forID: id) {
                insertInline(UUIDGenerator.styled(value, format: Preferences.shared.uuidFormat))
            }
        } else if id.hasPrefix("lorem.") {
            if let text = InsertSnippets.lorem(id: id) { insertInline(text) }
        } else if id.hasPrefix("file.") {
            guard let url = doc?.fileURL else {
                presentAlert("Save the file first", "This file doesn't have a name or location yet. Save it, then try again.")
                return
            }
            switch id {
            case "file.name": insertInline(url.lastPathComponent)
            case "file.basename": insertInline(url.deletingPathExtension().lastPathComponent)
            case "file.path": insertInline(url.path)
            case "file.folder": insertInline(url.deletingLastPathComponent().path)
            default: break
            }
        }
    }

    /// Version 3 / 5 UUIDs are made from a namespace and a name, so ask for both.
    @objc func insertNameBasedUUID(_ sender: Any?) {
        guard isViewLoaded, let window = view.window, let item = sender as? NSMenuItem,
              let version = item.representedObject as? Int else { return }
        let selection = textView.selectedRange()
        var suggestion = ""
        if selection.length > 0 && selection.length < 200 {
            let picked = (textView.string as NSString).substring(with: selection)
            if !picked.contains("\n") { suggestion = picked }
        }

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: UUIDGenerator.Namespace.allCases.map { $0.label })
        let field = NSTextField(frame: .zero)
        field.stringValue = suggestion
        field.placeholderString = "Name, for example example.com"
        let stack = NSStackView(views: [popup, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        popup.widthAnchor.constraint(equalToConstant: 320).isActive = true
        field.widthAnchor.constraint(equalToConstant: 320).isActive = true
        stack.setFrameSize(stack.fittingSize)

        let alert = NSAlert()
        alert.messageText = "Version \(version) UUID"
        alert.informativeText = "The same namespace and name always give the same UUID."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self = self else { return }
            let name = field.stringValue
            guard !name.isEmpty else { return }
            let namespace = UUIDGenerator.Namespace.allCases[max(0, popup.indexOfSelectedItem)]
            let bytes = version == 3 ? UUIDGenerator.version3(namespace: namespace, name: name)
                                     : UUIDGenerator.version5(namespace: namespace, name: name)
            self.insertInline(UUIDGenerator.styled(UUIDGenerator.text(bytes), format: Preferences.shared.uuidFormat))
        }
    }

    /// Insert > UUID > Generate Multiple: makes several UUIDs of one kind at once and inserts them,
    /// one per line, using the current UUID format (same choices as the single-UUID menu items).
    @objc func insertMultipleUUIDs(_ sender: Any?) {
        guard isViewLoaded, let window = view.window else { return }

        let kinds: [(id: String, label: String)] = [
            ("uuid.v4", "Version 4 \u{2013} random"),
            ("uuid.v7", "Version 7 \u{2013} time-ordered (Unix time + random)"),
            ("uuid.v1", "Version 1 \u{2013} time and node"),
            ("uuid.v6", "Version 6 \u{2013} time-ordered (reordered version 1)"),
            ("uuid.v8", "Version 8 \u{2013} custom (random bits)"),
            ("uuid.nil", "Nil UUID (all zeros)"),
            ("uuid.max", "Max UUID (all F)")
        ]

        let versionLabel = NSTextField(labelWithString: "UUID version:")
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: kinds.map { $0.label })

        let maxCount = UUIDGenerator.maxMultipleCount
        let countLabel = NSTextField(labelWithString: "How many (max \(maxCount)):")
        let field = NSTextField(frame: .zero)
        field.stringValue = "10"
        let clamp = CountFieldClamp(maximum: maxCount)
        uuidCountClamp = clamp
        field.delegate = clamp

        let stack = NSStackView(views: [versionLabel, popup, countLabel, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        popup.widthAnchor.constraint(equalToConstant: 320).isActive = true
        field.widthAnchor.constraint(equalToConstant: 320).isActive = true
        stack.setFrameSize(stack.fittingSize)

        let alert = NSAlert()
        alert.messageText = "Generate Multiple UUIDs"
        alert.informativeText = "Inserts each UUID on its own line, using the current UUID format."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            self.uuidCountClamp = nil
            guard response == .alertFirstButtonReturn else { return }
            let id = kinds[max(0, popup.indexOfSelectedItem)].id
            let requested = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10
            let count = min(max(requested, 1), maxCount)
            let format = Preferences.shared.uuidFormat
            let lines = UUIDGenerator.multiple(forID: id, count: count).map { UUIDGenerator.styled($0, format: format) }
            guard !lines.isEmpty else { return }
            self.insertBlock(lines.joined(separator: "\n"))
        }
    }

    /// Opens the options sheet for a Random Generator tool and inserts the result at the cursor.
    @objc func showRandomGenerator(_ sender: Any?) {
        guard isViewLoaded, let window = view.window, let item = sender as? NSMenuItem,
              let name = item.representedObject as? String, let tool = RandomTool(rawValue: name) else { return }
        let sheet = RandomGeneratorSheet(tool: tool)
        randomSheet = sheet
        sheet.onInsert = { [weak self] text in self?.insertInline(text) }
        sheet.onFinish = { [weak self] in self?.randomSheet = nil }
        sheet.present(on: window)
    }

    // MARK: - URL encode / decode

    /// Edit > URL Encode / Decode: converts the selection, or the URL-like text (no spaces) around the cursor.
    @objc func urlCoding(_ sender: Any?) {
        guard isViewLoaded, let item = sender as? NSMenuItem, let mode = URLCoding.Mode(rawValue: item.tag) else { return }
        let ns = textView.string as NSString
        var range = textView.selectedRange()
        if range.length == 0 {
            func isSpace(_ c: unichar) -> Bool {
                guard let scalar = Unicode.Scalar(c) else { return false }
                return CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
            var start = min(range.location, ns.length)
            var end = start
            while start > 0 && !isSpace(ns.character(at: start - 1)) { start -= 1 }
            while end < ns.length && !isSpace(ns.character(at: end)) { end += 1 }
            range = NSRange(location: start, length: end - start)
        }
        guard range.length > 0 else {
            NSSound.beep()
            return
        }
        let original = ns.substring(with: range)
        guard let converted = URLCoding.convert(original, mode: mode) else {
            NSSound.beep()          // the %XX codes do not form valid text
            return
        }
        guard converted != original else { return }
        apply(TextEdit(range: range, replacement: converted,
                       selection: NSRange(location: range.location, length: (converted as NSString).length)))
    }

    // MARK: - HTML escape / unescape

    /// Edit > HTML Escape / Unescape: converts the selection, or the whole document when nothing is selected.
    @objc func htmlCoding(_ sender: Any?) {
        guard isViewLoaded, let item = sender as? NSMenuItem, let mode = HTMLCoding.Mode(rawValue: item.tag) else { return }
        let ns = textView.string as NSString
        var range = textView.selectedRange()
        if range.length == 0 { range = NSRange(location: 0, length: ns.length) }
        guard range.length > 0 else {
            NSSound.beep()
            return
        }
        let original = ns.substring(with: range)
        let converted = HTMLCoding.convert(original, mode: mode)
        guard converted != original else { return }
        apply(TextEdit(range: range, replacement: converted,
                       selection: NSRange(location: range.location, length: (converted as NSString).length)))
    }

    // MARK: - Journal mode

    /// In Journal mode, the first typing after a pause (or after opening the file) adds a banner with the
    /// current date and time at the end of the file and moves the cursor to a fresh line below it.
    private func journalWillType() {
        guard isViewLoaded, Preferences.shared.journalMode, language.name == Language.plain.name else { return }
        let now = Date()
        defer { lastTypedAt = now }
        let idle = Preferences.shared.journalIdleMinutes
        if let last = lastTypedAt, idle == 0 || now.timeIntervalSince(last) < Double(idle) * 60 { return }
        addJournalEntry(at: now)
    }

    /// Format > Add Journal Entry Now: adds a dated banner at the end and puts the cursor below it.
    @objc func addJournalEntryNow(_ sender: Any?) {
        guard isViewLoaded else { return }
        addJournalEntry(at: Date())
        lastTypedAt = Date()
        view.window?.makeFirstResponder(textView)
    }

    private func addJournalEntry(at date: Date) {
        guard let storage = textView.textStorage else { return }
        let ns = textView.string as NSString
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        let banner = InsertSnippets.banner(text: formatter.string(from: date), style: .plain,
                                           width: Preferences.shared.insertLineWidth)
        var entry = ""
        if ns.length > 0 {
            if ns.character(at: ns.length - 1) != 10 { entry += "\n" }
            entry += "\n"                       // a blank line between entries
        }
        entry += banner + "\n"
        let end = NSRange(location: ns.length, length: 0)
        // Insert like typed text so it gets the editor's font, color and spacing.
        textView.insertText(entry, replacementRange: end)
        let inserted = NSRange(location: end.location, length: (entry as NSString).length)
        if NSMaxRange(inserted) <= storage.length {
            storage.addAttributes(textView.typingAttributes, range: inserted)
        }
        let caret = NSRange(location: storage.length, length: 0)
        textView.setSelectedRange(caret)
        textView.scrollRangeToVisible(caret)
    }

    /// Format > Text Formatting: opens the options sheet for one command and rewrites the selected
    /// lines (or the whole document when nothing is selected).
    @objc func showTextFormatting(_ sender: Any?) {
        guard isViewLoaded, let window = view.window, let item = sender as? NSMenuItem,
              let name = item.representedObject as? String, let tool = TextFormatTool(rawValue: name) else { return }
        let ns = textView.string as NSString
        let selection = textView.selectedRange()
        let range: NSRange
        let scope: String
        if selection.length > 0 {
            range = ns.lineRange(for: selection)
            scope = "Applies to the selected lines."
        } else {
            range = NSRange(location: 0, length: ns.length)
            scope = "Nothing is selected, so this applies to the whole document."
        }
        let source = ns.substring(with: range)
        let sheet = TextFormatSheet(tool: tool, source: source, scopeNote: scope)
        formatSheet = sheet
        sheet.onApply = { [weak self] result in
            guard let self = self, result != source else { return }
            let length = (result as NSString).length
            self.apply(TextEdit(range: range, replacement: result, selection: NSRange(location: range.location, length: length)))
        }
        sheet.onFinish = { [weak self] in self?.formatSheet = nil }
        sheet.present(on: window)
    }

    @objc func insertSpecialCharacter(_ sender: Any?) {
        guard isViewLoaded, let item = sender as? NSMenuItem, let text = item.representedObject as? String else {
            NSSound.beep()
            return
        }
        insertInline(text)
    }

    private func bannerStyle() -> InsertSnippets.BannerStyle {
        if let prefix = language.lineComment { return .line(prefix) }
        switch language.name {
        case "HTML / XML": return .block(open: "<!--", close: "-->")
        case "CSS": return .block(open: "/*", close: "*/")
        default: return .plain
        }
    }

    /// Asks for a title and inserts a boxed heading in the comment style of the current language.
    @objc func insertCommentBanner(_ sender: Any?) {
        guard isViewLoaded, let window = view.window else { return }
        let selection = textView.selectedRange()
        var suggestion = ""
        if selection.length > 0 && selection.length < 200 {
            let picked = (textView.string as NSString).substring(with: selection)
            if !picked.contains("\n") { suggestion = picked }
        }
        let alert = NSAlert()
        alert.messageText = "Comment Banner"
        alert.informativeText = "Type the heading for the banner. It is written as a comment for \(language.name)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = suggestion
        field.placeholderString = "Section title"
        alert.accessoryView = field
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self = self else { return }
            let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let banner = InsertSnippets.banner(text: title, style: self.bannerStyle(), width: Preferences.shared.insertLineWidth)
            self.insertBlock(banner)
        }
    }

    // MARK: - Insert date / time

    /// Inserts the current time (format chosen by the menu item) at the cursor, replacing any selection.
    @objc func insertTime(_ sender: Any?) {
        guard isViewLoaded, let item = sender as? NSMenuItem, let id = item.representedObject as? String,
              let format = TimeFormats.format(withID: id) else {
            NSSound.beep()
            return
        }
        var target = textView.selectedRange()
        if item.tag == TimeMenu.contextTag, let location = textView.pendingInsertLocation {
            // From the right-click menu with nothing selected: insert where the click was.
            target = NSRange(location: min(location, (textView.string as NSString).length), length: 0)
            textView.setSelectedRange(target)
        }
        textView.pendingInsertLocation = nil
        textView.insertText(format.string(for: Date()), replacementRange: target)
    }

    // MARK: - Word count

    @objc func showWordCountDocument(_ sender: Any?) {
        guard isViewLoaded else { return }
        presentWordCount(title: "Word Count – Whole Document", text: textView.string)
    }

    @objc func showWordCountSelection(_ sender: Any?) {
        guard isViewLoaded else { return }
        let selection = textView.selectedRange()
        guard selection.length > 0 else {
            presentAlert("No text selected", "Select some text first, then choose Word Count – Selected Text.")
            return
        }
        presentWordCount(title: "Word Count – Selected Text",
                         text: (textView.string as NSString).substring(with: selection))
    }

    private func presentWordCount(title: String, text: String) {
        guard let window = view.window else {
            NSSound.beep()
            return
        }
        let summary = TextStats(text).summary
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = summary
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(title + "\n" + summary, forType: .string)
            }
        }
    }
    @objc func indentSelection(_ sender: Any?) { run { LineOps.indent($0, $1) } }
    @objc func unindentSelection(_ sender: Any?) {
        run { LineOps.unindent($0, $1, width: Preferences.shared.tabWidth) }
    }

    /// ⌘/ : comments or uncomments the selected lines (or the cursor's line) the way the current language does.
    @objc func toggleLineComment(_ sender: Any?) {
        let style = language.commentSyntax
        run { LineOps.toggleComment($0, $1, prefix: style.line, suffix: style.lineEnd) }
    }

    /// ⌥⌘/ : wraps the selection in a block comment, or removes the block comment around it.
    /// Languages without block comments (plain text, shell, YAML, ...) use line comments instead.
    @objc func toggleBlockComment(_ sender: Any?) {
        // From the right-click menu with nothing selected, the word under the pointer was selected only
        // to make the other commands work: comment the whole line instead of that one word.
        if (sender as? NSMenuItem)?.representedObject as? String == "context",
           textView.rightClickSelectedWord {
            textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0))
            textView.rightClickSelectedWord = false
        }
        let style = language.commentSyntax
        guard let open = style.blockOpen, let close = style.blockClose else {
            toggleLineComment(sender)
            return
        }
        run { LineOps.toggleBlockComment($0, $1, open: open, close: close) }
    }

    @objc func goToLine(_ sender: Any?) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter a line number from 1 to \(lineIndex.count)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let number = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) else { return }
            self?.goTo(line: number)
        }
    }

    // MARK: - JSON tools

    private func jsonIndent(for sender: Any?) -> String {
        let tag = (sender as? NSMenuItem)?.tag ?? -1
        switch tag {
        case 100: return "\t"
        case 2, 4: return String(repeating: " ", count: tag)
        default: return String(repeating: " ", count: Preferences.shared.tabWidth)
        }
    }

    /// Selected text if there is a selection, otherwise the whole document.
    private func jsonTarget() -> (text: String, range: NSRange, isWholeDocument: Bool) {
        let ns = textView.string as NSString
        let sel = textView.selectedRange()
        if sel.length > 0 { return (ns.substring(with: sel), sel, false) }
        return (ns as String, NSRange(location: 0, length: ns.length), true)
    }

    private func presentAlert(_ title: String, _ message: String, style: NSAlert.Style = .informational) {
        guard let window = view.window else {
            NSSound.beep()
            return
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

    private func reportJSONError(_ error: JSONFormatter.ParseError, in target: (text: String, range: NSRange, isWholeDocument: Bool)) {
        let length = (textView.string as NSString).length
        let absolute = min(length, target.range.location + error.offset)
        let line = lineIndex.lineNumber(at: absolute)
        let column = absolute - lineIndex.lineStart(ofLine: line) + 1
        reveal(range: NSRange(location: absolute, length: 0))
        presentAlert("Invalid JSON", "\(error.message)\n\nLine \(line), column \(column)", style: .warning)
    }

    private func runJSON(minify: Bool, sortKeys: Bool, indent: String) {
        guard isViewLoaded else { return }
        let target = jsonTarget()
        if target.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSSound.beep()
            return
        }
        do {
            let node = try JSONFormatter.parse(target.text)
            var output = minify ? JSONFormatter.minified(node) : JSONFormatter.pretty(node, indent: indent, sortKeys: sortKeys)
            if target.isWholeDocument && !minify { output += "\n" }
            let newLength = (output as NSString).length
            let selection = target.isWholeDocument
                ? NSRange(location: 0, length: 0)
                : NSRange(location: target.range.location, length: newLength)
            apply(TextEdit(range: target.range, replacement: output, selection: selection))
            if target.isWholeDocument && language == Language.plain && !languageOverridden {
                language = Language.json
                scheduleHighlight(immediate: true)
                refreshStatus()
            }
        } catch let error as JSONFormatter.ParseError {
            reportJSONError(error, in: target)
        } catch {
            NSSound.beep()
        }
    }

    @objc func formatJSON(_ sender: Any?) {
        runJSON(minify: false, sortKeys: false, indent: jsonIndent(for: sender))
    }

    @objc func formatJSONSortingKeys(_ sender: Any?) {
        runJSON(minify: false, sortKeys: true, indent: jsonIndent(for: sender))
    }

    @objc func minifyJSON(_ sender: Any?) {
        runJSON(minify: true, sortKeys: false, indent: "")
    }

    @objc func validateJSON(_ sender: Any?) {
        guard isViewLoaded else { return }
        let target = jsonTarget()
        if target.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSSound.beep()
            return
        }
        do {
            let node = try JSONFormatter.parse(target.text)
            let s = JSONFormatter.stats(node)
            let scope = target.isWholeDocument ? "The document" : "The selection"
            presentAlert("Valid JSON",
                         "\(scope) is valid JSON.\n\nObjects: \(s.objects)\nArrays: \(s.arrays)\nValues: \(s.values)\nNesting depth: \(s.maxDepth)")
        } catch let error as JSONFormatter.ParseError {
            reportJSONError(error, in: target)
        } catch {
            NSSound.beep()
        }
    }

    // MARK: - Format menu actions

    @objc func setLanguage(_ sender: Any?) {
        var name: String?
        if let item = sender as? NSMenuItem {
            name = item.representedObject as? String
        } else if let popup = sender as? NSPopUpButton {
            name = popup.titleOfSelectedItem
        }
        guard let chosen = name, let lang = Language.all.first(where: { $0.name == chosen }) else { return }
        language = lang
        languageOverridden = true
        scheduleHighlight(immediate: true)
        refreshStatus()
    }

    // MARK: - Voice to Text

    /// Starts or stops dictation - a toggle, driven by the Edit menu item or the status bar's
    /// microphone button. While running, it keeps listening on its own (Apple's recognizer ends
    /// and restarts a "segment" every time it detects a pause) until this is called again to
    /// stop it. Words are inserted one at a time as they're recognized and never edited or
    /// removed afterwards - see `applyVoiceUpdate` for why - so what's already on the page never
    /// flickers or gets replaced while more speech comes in.
    @objc func toggleVoiceToText(_ sender: Any?) {
        guard isViewLoaded else { return }
        if VoiceTranscriber.shared.isRunning {
            VoiceTranscriber.shared.stop()
            return
        }
        let insertAt = textView.selectedRange()
        voiceRange = NSRange(location: insertAt.location, length: 0)
        voiceCommittedWords = []
        voicePendingWord = ""
        voiceHasInsertedWord = false
        VoiceTranscriber.shared.onUpdate = { [weak self] text in
            self?.applyVoiceUpdate(text)
        }
        VoiceTranscriber.shared.onSegmentEnd = { [weak self] in
            self?.flushPendingVoiceWord()
            self?.voiceCommittedWords = []
            self?.voicePendingWord = ""
        }
        VoiceTranscriber.shared.onStop = { [weak self] in
            self?.flushPendingVoiceWord()
            self?.voiceRange = nil
            self?.voiceCommittedWords = []
            self?.voicePendingWord = ""
            self?.refreshVoiceButtonState()
        }
        VoiceTranscriber.shared.start { [weak self] errorMessage in
            guard let self = self else { return }
            if let message = errorMessage {
                self.voiceRange = nil
                self.presentAlert("Voice to Text", message, style: .warning)
            }
            self.refreshVoiceButtonState()
        }
        refreshVoiceButtonState()
    }

    /// Called with the current segment's transcript-so-far every time the recognizer refines
    /// its guess. Every word but the last is treated as confirmed and inserted immediately; the
    /// last word is held back (in `voicePendingWord`) since it may still change as more audio
    /// arrives, and only gets written once a further word follows it (proving it's settled) or
    /// the segment/session ends (`flushPendingVoiceWord`). Words already written are never
    /// touched again - only new ones are appended - so earlier text can't be yanked out from
    /// under whatever the cursor has moved on to.
    private func applyVoiceUpdate(_ text: String) {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return }
        let confirmed = Array(words.dropLast())
        voicePendingWord = words.last ?? ""
        guard confirmed.count > voiceCommittedWords.count else { return }
        insertVoiceWords(Array(confirmed[voiceCommittedWords.count...]))
        voiceCommittedWords = confirmed
    }

    /// Writes out whatever word is still being held back as "might still change" - called when
    /// a segment ends or dictation stops, since at that point recognition for it is done.
    private func flushPendingVoiceWord() {
        guard !voicePendingWord.isEmpty else { return }
        insertVoiceWords([voicePendingWord])
        voiceCommittedWords.append(voicePendingWord)
        voicePendingWord = ""
    }

    /// Inserts (never replaces) one or more confirmed words at the running voice cursor, adding
    /// a single leading space first if this isn't the very first word of the dictation session.
    private func insertVoiceWords(_ words: [String]) {
        guard !words.isEmpty, let range = voiceRange, isViewLoaded else { return }
        let joined = words.joined(separator: " ")
        let toInsert = voiceHasInsertedWord ? " " + joined : joined
        let insertedLength = (toInsert as NSString).length
        apply(TextEdit(range: range, replacement: toInsert,
                       selection: NSRange(location: range.location + insertedLength, length: 0)))
        voiceRange = NSRange(location: range.location + insertedLength, length: 0)
        voiceHasInsertedWord = true
    }

    /// Keeps the status bar's microphone button in sync with whether this tab is the one
    /// currently listening. The Edit menu item is refreshed separately, via `validateMenuItem`.
    private func refreshVoiceButtonState() {
        let listening = VoiceTranscriber.shared.isRunning && voiceRange != nil
        voiceButton.title = listening ? "\u{1F534} Stop" : "\u{1F3A4} Voice"
        voiceButton.contentTintColor = listening ? .systemRed : nil
    }

    // MARK: - Read Aloud

    /// Starts or stops reading text aloud - the status bar's speaker button, or Edit > Read
    /// Aloud. Reads the current selection if there is one; otherwise reads from the cursor to
    /// the end of the document. Uses the voice and rate set in Preferences > Voice.
    @objc func toggleReadAloud(_ sender: Any?) {
        guard isViewLoaded else { return }
        if TextReader.shared.isSpeaking {
            TextReader.shared.stop()
            refreshReadButtonState()
            return
        }
        let full = activeTextView.string as NSString
        let selection = activeTextView.selectedRange()
        let textToRead: String
        if selection.length > 0 {
            textToRead = full.substring(with: selection)
        } else {
            let start = min(selection.location, full.length)
            textToRead = full.substring(from: start)
        }
        guard !textToRead.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presentAlert("Read Aloud", "There's no text to read from the cursor position. Select some text, or place the cursor before some text, and try again.", style: .informational)
            return
        }
        TextReader.shared.onFinish = { [weak self] in
            self?.refreshReadButtonState()
        }
        TextReader.shared.speak(textToRead)
        refreshReadButtonState()
    }

    /// Keeps the status bar's speaker button in sync with whether reading is in progress. The
    /// Edit menu item is refreshed separately, via `validateMenuItem`.
    private func refreshReadButtonState() {
        let speaking = TextReader.shared.isSpeaking
        readButton.title = speaking ? "\u{1F7E5} Stop" : "\u{1F50A} Read"
        readButton.contentTintColor = speaking ? .systemRed : nil
    }

    // MARK: - Split View

    /// Whichever pane's text view most recently had the cursor - the main one, or the split
    /// pane if it currently has keyboard focus. Read Aloud uses this so it reads from whichever
    /// half of a split view you're actually working in; falls back to the main pane when
    /// there's no split, or focus is elsewhere. (The status bar does NOT follow this - see the
    /// note on `refreshStatus()` - since the split pane belongs to a different document now,
    /// with its own status bar in its own window.)
    private var activeTextView: EditorTextView {
        if let split = splitTextView, view.window?.firstResponder === split { return split }
        return textView
    }

    /// Window > Split Horizontally/Vertically and the right-click "Tab" submenu's matching
    /// items call this. Split View shows two DIFFERENT open tabs side by side, not two views
    /// onto the same document - since a document-level command like Insert Date/Time can't
    /// tell which pane you mean, each pane stays exactly itself, with its own undo, saving and
    /// dirty tracking. Picks which other open tab fills the new pane; `vertical` sets the
    /// divider (true: side-by-side left/right, "Split Vertically"; false: stacked top/bottom,
    /// "Split Horizontally").
    private func presentSplitTabPicker(vertical: Bool) {
        let candidates = otherOpenDocuments()
        guard !candidates.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Open another tab first"
            alert.informativeText = "Split View shows two different tabs side by side. Open a second file (or use File > New), then try again."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if candidates.count == 1 {
            beginSplit(with: candidates[0], vertical: vertical)
            return
        }
        guard let chosen = pickDocument(from: candidates, title: "Split with which tab?") else { return }
        beginSplit(with: chosen, vertical: vertical)
    }

    /// Every other currently open tab, excluding this one and any tab already showing in some
    /// other window's split pane (so a tab is never mirrored into two places at once).
    private func otherOpenDocuments() -> [TextDocument] {
        NSDocumentController.shared.documents.compactMap { $0 as? TextDocument }
            .filter {
                $0 !== doc && $0.editor !== self && $0.editor?.mirroredBy == nil
                    && $0.editor?.isViewLoaded == true
            }
    }

    /// A small confirm/Cancel prompt with a popup listing `documents` by their tab title.
    /// Returns the chosen document, or nil if cancelled.
    private func pickDocument(from documents: [TextDocument], title: String, confirmTitle: String = "Split") -> TextDocument? {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 24), pullsDown: false)
        popup.addItems(withTitles: documents.map { $0.displayName ?? "Untitled" })

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = popup
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let index = max(0, popup.indexOfSelectedItem)
        guard documents.indices.contains(index) else { return nil }
        return documents[index]
    }

    /// Opens a second pane inside this window showing `document` - a different, already-open
    /// tab - side by side with this one. The pane is a real NSLayoutManager/NSTextContainer
    /// attached directly to `document`'s own NSTextStorage (not a copy), so it's the exact same
    /// file, live: its delegate is `document`'s own editor (not this one), so typing here is
    /// routed through that document's own undo manager, dirty tracking, journal mode and line
    /// numbering, exactly as if it had been typed into that document's own primary pane.
    func beginSplit(with document: TextDocument, vertical: Bool) {
        guard isViewLoaded, !isSplit, let otherEditor = document.editor, otherEditor !== self,
              otherEditor.isViewLoaded, let storage = otherEditor.textView.textStorage else { return }

        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 960, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = EditorTextView(frame: textView.frame, textContainer: textContainer)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.allowsUndo = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFontPanel = false
        tv.usesFindBar = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.textContainerInset = textView.textContainerInset
        tv.delegate = otherEditor
        tv.onBeforeTyping = { [weak otherEditor] in otherEditor?.journalWillType() }

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentView = TranslucentClipView()
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(splitScrolled),
                                               name: NSView.boundsDidChangeNotification, object: scroll.contentView)

        let rulerView = LineNumberRulerView(textView: tv, lineIndex: otherEditor.lineIndex)
        scroll.verticalRulerView = rulerView
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = Preferences.shared.showLineNumbers

        splitTextView = tv
        splitRuler = rulerView
        splitScrollView = scroll
        splitDocumentEditor = otherEditor
        otherEditor.externalMirrors.append((textView: tv, ruler: rulerView))
        otherEditor.mirroredBy = self

        splitView.isVertical = vertical
        splitView.addArrangedSubview(scroll)
        // Styles the new pane (font, theme, invisibles, rulers, ...) using `document`'s own
        // settings, and re-highlights it - see the `externalMirrors` loop in applyPreferences().
        otherEditor.applyPreferences()
        view.window?.makeFirstResponder(tv)

        // NSSplitView's Auto Layout support installs constraints that keep both arranged
        // subviews pinned edge-to-edge-to-divider, but nothing in there actually demands an
        // even split - with no other size-defining constraint on either subview, the layout
        // solver is free to satisfy that arrangement by giving the newly added pane (almost)
        // no space at all. Forcing the divider to the midpoint here removes that ambiguity
        // outright, regardless of which direction was picked first.
        centerSplitDivider()
    }

    /// Window > Change Split Tab...: swaps which other open tab the split pane is showing,
    /// reusing the same pane (so its orientation is kept) instead of closing and reopening it.
    @objc func changeSplitTab(_ sender: Any?) {
        guard isViewLoaded, isSplit, let tv = splitTextView, let scroll = splitScrollView,
              let oldEditor = splitDocumentEditor else { return }
        let candidates = otherOpenDocuments()
        guard !candidates.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No other tabs open"
            alert.informativeText = "Open another file first, then try again."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        guard let newDocument = pickDocument(from: candidates, title: "Show which tab in this pane?", confirmTitle: "Change"),
              let newEditor = newDocument.editor, newEditor !== oldEditor, newEditor.isViewLoaded,
              let newStorage = newEditor.textView.textStorage else { return }

        if let lm = tv.layoutManager { oldEditor.textView.textStorage?.removeLayoutManager(lm) }
        oldEditor.externalMirrors.removeAll { $0.textView === tv }
        if oldEditor.mirroredBy === self { oldEditor.mirroredBy = nil }

        if let lm = tv.layoutManager { newStorage.addLayoutManager(lm) }
        // LineNumberRulerView's line index is fixed at init, so switching documents means a
        // fresh ruler (styled again below via applyPreferences()) rather than mutating this one.
        let newRuler = LineNumberRulerView(textView: tv, lineIndex: newEditor.lineIndex)
        scroll.verticalRulerView = newRuler
        splitRuler = newRuler
        tv.delegate = newEditor
        tv.onBeforeTyping = { [weak newEditor] in newEditor?.journalWillType() }
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        tv.scrollRangeToVisible(NSRange(location: 0, length: 0))

        splitDocumentEditor = newEditor
        newEditor.externalMirrors.append((textView: tv, ruler: newRuler))
        newEditor.mirroredBy = self
        newEditor.applyPreferences()
    }

    /// Puts the split divider at the midpoint of whichever dimension it runs along, so a fresh
    /// or re-oriented split always starts as an even 50/50 division instead of leaving it up to
    /// Auto Layout to pick an (unconstrained, and sometimes near-zero) size for the new pane.
    private func centerSplitDivider() {
        guard splitScrollView != nil else { return }
        splitView.layoutSubtreeIfNeeded()
        let total = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 0 else { return }
        let half = (total - splitView.dividerThickness) / 2
        splitView.setPosition(half, ofDividerAt: 0)
    }

    /// Removes the second pane, if any, going back to a single editor view. If it was showing
    /// another document, that document's own bookkeeping (`externalMirrors`/`mirroredBy`) is
    /// cleaned up too, so it stops being asked to keep styling/highlighting a pane that no
    /// longer exists.
    func removeSplit() {
        guard let scroll = splitScrollView, let tv = splitTextView else { return }
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        splitView.removeArrangedSubview(scroll)
        scroll.removeFromSuperview()
        if let otherEditor = splitDocumentEditor {
            if let lm = tv.layoutManager { otherEditor.textView.textStorage?.removeLayoutManager(lm) }
            otherEditor.externalMirrors.removeAll { $0.textView === tv }
            if otherEditor.mirroredBy === self { otherEditor.mirroredBy = nil }
        }
        splitScrollView = nil
        splitTextView = nil
        splitRuler = nil
        splitDocumentEditor = nil
        if view.window?.firstResponder === tv { view.window?.makeFirstResponder(textView) }
    }

    /// Called by `documentWillClose()` on a document that's currently mirrored in this window's
    /// split pane, so the pane is removed cleanly instead of being left pointing at text
    /// storage that's about to go away.
    func removeSplitIfMirroring(_ editor: EditorViewController) {
        guard splitDocumentEditor === editor else { return }
        removeSplit()
    }

    /// Called by `TextDocument.close()` just before this document closes, so any split-pane
    /// relationship involving it is torn down instead of left dangling: if another window is
    /// showing this document in its split pane, that pane is removed; if this window has its
    /// own split pane open on a different document, that's removed too.
    func documentWillClose() {
        mirroredBy?.removeSplitIfMirroring(self)
        if splitDocumentEditor != nil { removeSplit() }
    }

    @objc func splitHorizontally(_ sender: Any?) {
        guard isViewLoaded else { return }
        if isSplit, !splitView.isVertical { removeSplit(); return }
        if isSplit { splitView.isVertical = false; centerSplitDivider(); return }
        presentSplitTabPicker(vertical: false)
    }

    @objc func splitVertically(_ sender: Any?) {
        guard isViewLoaded else { return }
        if isSplit, splitView.isVertical { removeSplit(); return }
        if isSplit { splitView.isVertical = true; centerSplitDivider(); return }
        presentSplitTabPicker(vertical: true)
    }

    /// Called when the split pane's own clip view scrolls - keeps its own gutter and (for large
    /// files, in the OTHER document it's showing) the highlighted range in sync, the same way
    /// `scrolled()` does for the main pane.
    @objc private func splitScrolled() {
        guard let tv = splitTextView, let rulerView = splitRuler, let otherEditor = splitDocumentEditor else { return }
        rulerView.setNeedsDisplay(rulerView.bounds)
        if Preferences.shared.textOpacity < 100 { tv.setNeedsDisplay(tv.visibleRect) }
        if (otherEditor.textView.textStorage?.length ?? 0) > EditorViewController.largeFileThreshold {
            otherEditor.scheduleHighlight()
        }
    }

    // MARK: - Markdown Preview

    /// Swaps the editable text view for a read-only rendered view, or back. The document's text
    /// storage is never touched by this — the preview is built into a separate text view, so
    /// there's no risk of a rendered/highlighted string ever being saved to disk.
    @objc func toggleMarkdownPreview(_ sender: Any?) {
        guard isViewLoaded else { return }
        isPreviewingMarkdown.toggle()
        if isPreviewingMarkdown {
            renderMarkdownPreview()
            scrollView.isHidden = true
            previewScrollView.isHidden = false
        } else {
            scrollView.isHidden = false
            previewScrollView.isHidden = true
            view.window?.makeFirstResponder(textView)
        }
    }

    // MARK: - Open in Default Browser

    /// View > Open in Default Browser: hands the current HTML/XML file to macOS's default
    /// browser via NSWorkspace, the same app you'd get double-clicking the file in Finder.
    @objc func openInBrowser(_ sender: Any?) {
        guard isViewLoaded else { return }
        if let doc = doc, let url = doc.fileURL {
            guard doc.isDocumentEdited else {
                NSWorkspace.shared.open(url)
                return
            }
            // There's a saved file, but it doesn't match what's on screen - ask before showing
            // the browser a possibly-stale version.
            let alert = NSAlert()
            alert.messageText = "Save \(url.lastPathComponent) before opening in your browser?"
            alert.informativeText = "The file has changes that aren't saved yet, so the browser would show an older version."
            alert.addButton(withTitle: "Save and Open")
            alert.addButton(withTitle: "Open Saved Version")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                doc.save(to: url, ofType: doc.fileType ?? "public.plain-text", for: .saveOperation) { error in
                    if let error = error {
                        NSApp.presentError(error)
                    } else {
                        NSWorkspace.shared.open(url)
                    }
                }
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(url)
            default:
                break
            }
            return
        }
        // Never been saved - there's no file on disk to hand the browser, so write what's on
        // screen to a throwaway temporary copy instead. This copy is a snapshot: it won't update
        // itself if you keep editing, unlike a saved file (which the browser just re-reads live).
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CalamusPreview", isDirectory: true)
        let base = (doc?.displayName ?? "Untitled").replacingOccurrences(of: "/", with: "-")
        let file = directory.appendingPathComponent("\(base)-\(UUID().uuidString.prefix(8)).html")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try textView.string.write(to: file, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(file)
        } catch {
            NSApp.presentError(error)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setLanguage(_:)), menuItem.representedObject is String {
            menuItem.state = (menuItem.representedObject as? String) == language.name ? .on : .off
        }
        if menuItem.action == #selector(showWordCountSelection(_:)) { return textView.selectedRange().length > 0 }
        if menuItem.action == #selector(insertSnippet(_:)),
           let id = menuItem.representedObject as? String, id.hasPrefix("file.") {
            return doc?.fileURL != nil
        }
        if menuItem.action == #selector(toggleVoiceToText(_:)) {
            let running = VoiceTranscriber.shared.isRunning && voiceRange != nil
            menuItem.title = running ? "Stop Voice to Text" : "Start Voice to Text"
            menuItem.state = running ? .on : .off
        }
        if menuItem.action == #selector(toggleReadAloud(_:)) {
            let speaking = TextReader.shared.isSpeaking
            menuItem.title = speaking ? "Stop Reading Aloud" : "Read Aloud"
            menuItem.state = speaking ? .on : .off
        }
        if menuItem.action == #selector(splitHorizontally(_:)) {
            let active = isSplit && !splitView.isVertical
            menuItem.title = active ? "Remove Split" : (isSplit ? "Split Horizontally" : "Split Horizontally…")
            menuItem.state = active ? .on : .off
        }
        if menuItem.action == #selector(splitVertically(_:)) {
            let active = isSplit && splitView.isVertical
            menuItem.title = active ? "Remove Split" : (isSplit ? "Split Vertically" : "Split Vertically…")
            menuItem.state = active ? .on : .off
        }
        if menuItem.action == #selector(changeSplitTab(_:)) {
            return isSplit
        }
        if menuItem.action == #selector(toggleMarkdownPreview(_:)) {
            menuItem.state = isPreviewingMarkdown ? .on : .off
            return language == Language.markdown
        }
        if menuItem.action == #selector(openInBrowser(_:)) {
            return language == Language.html
        }
        return true
    }

    deinit {
        if voiceRange != nil { VoiceTranscriber.shared.stop() }
    }
}

/// Keeps a "how many" text field from holding more than `maximum` as the person types, the same
/// way RandomGeneratorSheet's own count field behaves: clamped live while typing, and fixed up
/// (falling back to 1 for anything that isn't a number) when the field loses focus.
private final class CountFieldClamp: NSObject, NSTextFieldDelegate {
    let maximum: Int
    init(maximum: Int) { self.maximum = maximum }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let value = Int(field.stringValue.trimmingCharacters(in: .whitespaces)),
              value > maximum else { return }
        field.stringValue = String(maximum)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        guard let value = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) else {
            field.stringValue = "1"
            return
        }
        field.stringValue = String(min(maximum, max(1, value)))
    }
}
