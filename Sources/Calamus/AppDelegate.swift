import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        // The disclaimer must be accepted before anything else happens - if it's declined,
        // quit immediately without building menus, registering fonts, or opening any document.
        guard LegalDisclaimer.confirmAccepted() else {
            NSApp.terminate(nil)
            return
        }
        BundledFonts.register()
        // Create the document controller first so it reads the document types from Info.plist.
        _ = NSDocumentController.shared
        NSWindow.allowsAutomaticWindowTabbing = true
        buildMenus()
        // Tracks whichever document tab is frontmost, so the next launch can bring it back.
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)),
                                               name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    /// We open a Read Me tab or the last document ourselves instead (see
    /// applicationDidFinishLaunching), so suppress AppKit's automatic blank "Untitled" document at launch.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Deferred a tick so any file already being opened (double-click, Open Recent, a
        // relaunch after Login Items) has had a chance to register before we check.
        DispatchQueue.main.async { [weak self] in
            let reopenedPinned = PinnedTabs.shared.reopenAtLaunch()
            guard !reopenedPinned, NSDocumentController.shared.documents.isEmpty else { return }
            // A fresh launch (nothing remembered yet, or the remembered file is gone) shows the
            // Read Me note; every later launch brings back whichever document was open last.
            if !LastDocument.reopenAtLaunch() {
                self?.showReadMe(nil)
            }
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let editor = (window.windowController as? EditorWindowController)?.editor else { return }
        LastDocument.noteActive(url: editor.doc?.fileURL)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Makes sure a Voice to Text session in progress doesn't leave the microphone running,
    /// and that Read Aloud doesn't keep talking, after the app quits.
    func applicationWillTerminate(_ notification: Notification) {
        VoiceTranscriber.shared.stop()
        TextReader.shared.stop()
    }

    // MARK: - Menu construction

    private func item(_ title: String, _ action: Selector?, _ key: String = "",
                      _ modifiers: NSEvent.ModifierFlags = [.command], tag: Int = 0,
                      represented: Any? = nil) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { mi.keyEquivalentModifierMask = modifiers }
        mi.tag = tag
        mi.representedObject = represented
        return mi
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach { menu.addItem($0) }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    private func arrowKey(_ code: Int) -> String {
        guard let scalar = UnicodeScalar(UInt32(code)) else { return "" }
        return String(Character(scalar))
    }

    private func buildMenus() {
        let main = NSMenu()

        // App menu
        let appName = ProcessInfo.processInfo.processName
        let appMenu = submenu(appName, [
            item("About Calamus", #selector(showAbout(_:))),
            .separator(),
            item("Font & Colors…", #selector(showPreferences(_:)), ","),
            .separator(),
            item("Hide Calamus", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit Calamus", #selector(NSApplication.terminate(_:)), "q")
        ])
        main.addItem(appMenu)

        // File menu
        main.addItem(submenu("File", [
            item("New", #selector(NSDocumentController.newDocument(_:)), "n"),
            item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"),
            .separator(),
            item("Close", #selector(closeCurrentTab(_:)), "w"),
            item("Save", #selector(NSDocument.save(_:)), "s"),
            item("Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift]),
            item("Save All", #selector(saveAllDocuments(_:)), "s", [.command, .option]),
            item("Revert to Saved", #selector(NSDocument.revertToSaved(_:))),
            .separator(),
            item("Preferences…", #selector(showAppPreferences(_:)), ",", [.command, .option]),
            .separator(),
            item("Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift]),
            item("Print…", #selector(NSDocument.printDocument(_:)), "p")
        ]))

        // Edit menu
        let lineOps = submenu("Line Operations", [
            item("Duplicate Line", #selector(EditorViewController.duplicateLine(_:)), "d"),
            item("Delete Line", #selector(EditorViewController.deleteLine(_:)), "k", [.command, .shift]),
            item("Move Line Up", #selector(EditorViewController.moveLineUp(_:)), arrowKey(NSUpArrowFunctionKey), [.command, .option]),
            item("Move Line Down", #selector(EditorViewController.moveLineDown(_:)), arrowKey(NSDownArrowFunctionKey), [.command, .option]),
            item("Join Lines", #selector(EditorViewController.joinLines(_:)), "j"),
            .separator(),
            item("Sort Lines Ascending", #selector(EditorViewController.sortLinesAscending(_:))),
            item("Sort Lines Descending", #selector(EditorViewController.sortLinesDescending(_:))),
            item("Remove Duplicate Lines", #selector(EditorViewController.removeDuplicateLines(_:))),
            item("Trim Trailing Whitespace", #selector(EditorViewController.trimTrailingWhitespace(_:)))
        ])
        let htmlCodingItem = NSMenuItem(title: "HTML Escape / Unescape", action: nil, keyEquivalent: "")
        htmlCodingItem.submenu = HTMLCoding.makeMenu()
        let urlCodingItem = NSMenuItem(title: "URL Encode / Decode", action: nil, keyEquivalent: "")
        urlCodingItem.submenu = URLCoding.makeMenu()
        let caseMenu = submenu("Convert Case", [
            item("UPPERCASE", #selector(EditorViewController.uppercaseSelection(_:)), "u", [.command, .shift]),
            item("lowercase", #selector(EditorViewController.lowercaseSelection(_:)), "u", [.command, .control])
        ])
        main.addItem(submenu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Toggle Comment", #selector(EditorViewController.toggleLineComment(_:)), "/"),
            item("Toggle Block Comment", #selector(EditorViewController.toggleBlockComment(_:)), "/", [.command, .option]),
            item("Indent", #selector(EditorViewController.indentSelection(_:)), "]"),
            item("Unindent", #selector(EditorViewController.unindentSelection(_:)), "["),
            .separator(),
            lineOps,
            caseMenu,
            urlCodingItem,
            htmlCodingItem,
            .separator(),
            item("Word Count – Whole Document…", #selector(EditorViewController.showWordCountDocument(_:))),
            item("Word Count – Selected Text…", #selector(EditorViewController.showWordCountSelection(_:))),
            .separator(),
            item("Start Voice to Text", #selector(EditorViewController.toggleVoiceToText(_:)), "v", [.command, .shift]),
            item("Read Aloud", #selector(EditorViewController.toggleReadAloud(_:)), "r", [.command, .shift])
        ]))

        // Search menu
        main.addItem(submenu("Search", [
            item("Find…", #selector(showFindPanel(_:)), "f"),
            item("Find Next", #selector(findNextMatch(_:)), "g"),
            item("Find Previous", #selector(findPreviousMatch(_:)), "g", [.command, .shift]),
            item("Replace…", #selector(showReplacePanel(_:)), "f", [.command, .option]),
            item("Use Selection for Find", #selector(useSelectionForFind(_:)), "e"),
            .separator(),
            item("Find in Files…", #selector(showFindInFiles(_:)), "f", [.command, .shift]),
            .separator(),
            item("Go to Line…", #selector(EditorViewController.goToLine(_:)), "l")
        ]))

        // Insert menu: date and time, horizontal lines, UUIDs, lorem ipsum, file info, banners, symbols
        let insertParent = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertParent.submenu = InsertMenuBuilder.makeInsertMenu()
        main.addItem(insertParent)

        // View menu
        let themeItems = ([Preferences.autoThemeName] + Theme.all.map { $0.name }).map {
            item($0 == Preferences.autoThemeName ? "Automatic (follow system)" : $0,
                 #selector(selectTheme(_:)), represented: $0)
        }
        let tabItems = [2, 4, 8].map { item("\($0) spaces", #selector(setTabWidth(_:)), tag: $0) }
        main.addItem(submenu("View", [
            item("Word Wrap", #selector(toggleWordWrap(_:)), "w", [.command, .option]),
            item("Show Line Numbers", #selector(toggleLineNumbers(_:))),
            item("Show Whitespace and Line Endings", #selector(toggleInvisibles(_:)), "i", [.command, .option]),
            item("Highlight Current Line", #selector(toggleCurrentLine(_:))),
            item("Markdown Preview", #selector(EditorViewController.toggleMarkdownPreview(_:)), "m", [.command, .shift]),
            item("Open in Default Browser", #selector(EditorViewController.openInBrowser(_:)), "b", [.command, .shift]),
            .separator(),
            item("Increase Font Size", #selector(zoomIn(_:)), "="),
            item("Decrease Font Size", #selector(zoomOut(_:)), "-"),
            item("Reset Font Size", #selector(zoomReset(_:)), "0"),
            item("Font & Colors…", #selector(showPreferences(_:)), ",", [.command, .shift]),
            .separator(),
            submenu("Theme", themeItems),
            submenu("Tab Width", tabItems),
            .separator(),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
        ]))

        // Format menu
        let encodingItems = TextEncodingChoice.allCases.map {
            item($0.label, #selector(TextDocument.setEncoding(_:)), tag: $0.rawValue)
        }
        let lineEndingItems = LineEnding.allCases.map {
            item($0.label, #selector(TextDocument.setLineEnding(_:)), tag: $0.rawValue)
        }
        let languageItems = Language.all.map {
            item($0.name, #selector(EditorViewController.setLanguage(_:)), represented: $0.name)
        }
        let sizeItems = [9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 36, 48, 72].map {
            item("\($0)", #selector(setFontSize(_:)), tag: $0)
        }
        // JSON tools now live under Format > JSON
        let tabularizeJSONItem = NSMenuItem(title: "Convert to Table…", action: #selector(EditorViewController.showTextFormatting(_:)), keyEquivalent: "")
        tabularizeJSONItem.representedObject = TextFormatTool.tabularize.rawValue
        let jsonMenu = submenu("JSON", [
            item("Format JSON", #selector(EditorViewController.formatJSON(_:)), "j", [.command, .option], tag: -1),
            item("Format JSON and Sort Keys", #selector(EditorViewController.formatJSONSortingKeys(_:)), "j", [.command, .option, .shift], tag: -1),
            item("Minify JSON", #selector(EditorViewController.minifyJSON(_:)), "m", [.command, .option]),
            item("Validate JSON", #selector(EditorViewController.validateJSON(_:)), "v", [.command, .option]),
            .separator(),
            item("Format with 2 Spaces", #selector(EditorViewController.formatJSON(_:)), tag: 2),
            item("Format with 4 Spaces", #selector(EditorViewController.formatJSON(_:)), tag: 4),
            item("Format with Tabs", #selector(EditorViewController.formatJSON(_:)), tag: 100),
            .separator(),
            tabularizeJSONItem
        ])

        var textFormatItems: [NSMenuItem] = []
        for tool in TextFormatTool.allCases {
            if tool == .tabularize { textFormatItems.append(.separator()) }
            let mi = NSMenuItem(title: tool.title + "…", action: #selector(EditorViewController.showTextFormatting(_:)), keyEquivalent: "")
            mi.representedObject = tool.rawValue
            textFormatItems.append(mi)
        }

        main.addItem(submenu("Format", [
            item("Font…", #selector(showFontPanel(_:)), "t"),
            submenu("Font Size", sizeItems),
            .separator(),
            submenu("Save Encoding", encodingItems),
            submenu("Line Endings", lineEndingItems),
            submenu("Language", languageItems),
            .separator(),
            jsonMenu,
            submenu("Text Formatting", textFormatItems),
            .separator(),
            item("Journal Mode", #selector(toggleJournalMode(_:))),
            item("Add Journal Entry Now", #selector(EditorViewController.addJournalEntryNow(_:)))
        ]))

        // Terminal menu (uses the Terminal app that comes with macOS)
        main.addItem(submenu("Terminal", [
            item("Open Terminal Here", #selector(openTerminalHere(_:)), "`", [.control]),
            item("Open Terminal in Folder…", #selector(openTerminalInFolder(_:)), "t", [.command, .option]),
            .separator(),
            item("Run Current File in Terminal", #selector(runCurrentFile(_:)), "r")
        ]))

        // Window menu
        let windowMenu = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            .separator(),
            item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "\t", [.control, .shift]),
            item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "\t", [.control]),
            item("Move Tab to New Window", #selector(NSWindow.moveTabToNewWindow(_:))),
            item("Merge All Windows", #selector(NSWindow.mergeAllWindows(_:))),
            item("Duplicate Tab", #selector(duplicateTab(_:)), "d", [.command, .shift]),
            item("Pin Tab", #selector(togglePinTab(_:)), "p", [.command, .option]),
            .separator(),
            item("Close Tabs to the Right", #selector(closeTabsToRight(_:))),
            item("Close Tabs to the Left", #selector(closeTabsToLeft(_:))),
            .separator(),
            item("Split Horizontally", #selector(EditorViewController.splitHorizontally(_:)), "'", [.command, .shift]),
            item("Split Vertically", #selector(EditorViewController.splitVertically(_:)), "\\", [.command, .shift]),
            item("Change Split Tab…", #selector(EditorViewController.changeSplitTab(_:))),
            .separator(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        ])
        main.addItem(windowMenu)

        // Help menu
        let helpMenu = submenu("Help", [
            item("Read Me", #selector(showReadMe(_:)))
        ])
        main.addItem(helpMenu)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu.submenu
        NSApp.helpMenu = helpMenu.submenu
        MenuFontStyler.shared.install()
    }

    // MARK: - File actions

    @objc func saveAllDocuments(_ sender: Any?) {
        for document in NSDocumentController.shared.documents where document.isDocumentEdited {
            document.save(nil)
        }
    }

    // MARK: - About / Read Me

    /// Shows a widened alert instead of the system's standard About panel, whose credits area is
    /// a small scrolling text view - too cramped now that it also carries the full disclaimer
    /// (see LegalDisclaimer.swift). This version grows to fit everything with no scrolling.
    @objc func showAbout(_ sender: Any?) {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        LegalDisclaimer.showAbout(version: version, build: build)
    }

    /// Opens the bundled Read Me note as its own tab (not tied to any file on disk).
    @objc func showReadMe(_ sender: Any?) {
        let doc = TextDocument()
        doc.text = AppReadMe.text
        doc.explicitDisplayName = "Read Me"
        NSDocumentController.shared.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
    }

    // MARK: - Tabs (close guard, duplicate, pin)

    /// Same as the ordinary Close, except a pinned tab asks first (unpinning it, so a future
    /// relaunch doesn't try to reopen a file you've deliberately closed).
    @objc func closeCurrentTab(_ sender: Any?) {
        guard let window = NSApp.keyWindow else { return }
        closeTab(window)
    }

    /// Closes one tab, asking first if it's pinned - the same guard `closeCurrentTab` always
    /// used, pulled out so the bulk close-to-the-left/right commands can reuse it per tab
    /// instead of closing a pinned tab out from under you without asking.
    @discardableResult
    private func closeTab(_ window: NSWindow) -> Bool {
        if PinnedTabs.shared.isPinned(window) {
            let alert = NSAlert()
            alert.messageText = "\u{201C}\(window.title)\u{201D} is pinned"
            alert.informativeText = "Pinned tabs reopen automatically the next time you launch Calamus. Unpin it first, or unpin and close now."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Unpin and Close")
            alert.alertStyle = .informational
            guard alert.runModal() == .alertSecondButtonReturn else { return false }
            PinnedTabs.shared.setPinned(false, for: window)
        }
        window.performClose(nil)
        return true
    }

    /// Closes every tab after the current one in the tab bar (to the right, in a left-to-right
    /// layout). Each one that's pinned still asks first, exactly like closing it on its own.
    @objc func closeTabsToRight(_ sender: Any?) {
        closeTabs(after: true)
    }

    /// Closes every tab before the current one in the tab bar (to the left).
    @objc func closeTabsToLeft(_ sender: Any?) {
        closeTabs(after: false)
    }

    private func closeTabs(after: Bool) {
        guard let window = NSApp.keyWindow, let group = window.tabGroup else { return }
        // NSWindowTabGroup.windows is ordered leading-to-trailing edge of the tab bar, i.e. left to right.
        let windows = group.windows
        guard let index = windows.firstIndex(of: window) else { return }
        let targets = after ? Array(windows[(index + 1)...]) : Array(windows[..<index])
        for target in targets { closeTab(target) }
    }

    /// Whether there's at least one tab to close in that direction - used to gray out Close
    /// Tabs to the Right/Left when there's nothing there (e.g. only one tab open at all).
    private func tabsExist(after: Bool) -> Bool {
        guard let window = NSApp.keyWindow, let group = window.tabGroup else { return false }
        let windows = group.windows
        guard let index = windows.firstIndex(of: window) else { return false }
        return after ? index < windows.count - 1 : index > 0
    }

    /// Opens a second, independent tab with a copy of the current tab's text (not saved to any file).
    @objc func duplicateTab(_ sender: Any?) {
        guard let current = EditorContext.current else { return }
        let newDoc = TextDocument()
        newDoc.text = current.currentText
        NSDocumentController.shared.addDocument(newDoc)
        newDoc.makeWindowControllers()
        newDoc.showWindows()
        let langItem = NSMenuItem()
        langItem.representedObject = current.language.name
        newDoc.editor?.setLanguage(langItem)
    }

    @objc func togglePinTab(_ sender: Any?) {
        guard let window = NSApp.keyWindow, EditorContext.current?.doc?.fileURL != nil else { return }
        PinnedTabs.shared.togglePin(for: window)
    }

    // MARK: - Search actions

    @objc func showFindPanel(_ sender: Any?) { FindPanelController.shared.show() }
    @objc func showReplacePanel(_ sender: Any?) { FindPanelController.shared.show(focusReplace: true) }
    @objc func findNextMatch(_ sender: Any?) {
        if FindPanelController.shared.hasQuery { FindPanelController.shared.find(forward: true) }
        else { FindPanelController.shared.show() }
    }
    @objc func findPreviousMatch(_ sender: Any?) {
        if FindPanelController.shared.hasQuery { FindPanelController.shared.find(forward: false) }
        else { FindPanelController.shared.show() }
    }
    @objc func useSelectionForFind(_ sender: Any?) { FindPanelController.shared.useSelectionForFind() }
    @objc func showFindInFiles(_ sender: Any?) { FindInFilesController.shared.show() }

    // MARK: - Terminal actions

    @objc func openTerminalHere(_ sender: Any?) { TerminalLauncher.open(in: TerminalLauncher.currentFolder()) }
    @objc func openTerminalInFolder(_ sender: Any?) { TerminalLauncher.openInChosenFolder() }
    @objc func runCurrentFile(_ sender: Any?) { TerminalLauncher.runCurrentFile() }

    // MARK: - View actions

    @objc func setInsertLineWidth(_ sender: NSMenuItem) { Preferences.shared.insertLineWidth = sender.tag }
    @objc func setUUIDFormat(_ sender: NSMenuItem) {
        if let format = sender.representedObject as? String { Preferences.shared.uuidFormat = format }
    }

    @objc func toggleWordWrap(_ sender: Any?) { Preferences.shared.wordWrap.toggle() }
    @objc func toggleLineNumbers(_ sender: Any?) { Preferences.shared.showLineNumbers.toggle() }
    @objc func toggleInvisibles(_ sender: Any?) { Preferences.shared.showInvisibles.toggle() }
    @objc func toggleCurrentLine(_ sender: Any?) { Preferences.shared.highlightCurrentLine.toggle() }
    @objc func toggleJournalMode(_ sender: Any?) { Preferences.shared.journalMode.toggle() }
    @objc func zoomIn(_ sender: Any?) { Preferences.shared.fontSize += 1 }
    @objc func zoomOut(_ sender: Any?) { Preferences.shared.fontSize -= 1 }
    @objc func zoomReset(_ sender: Any?) { Preferences.shared.fontSize = Preferences.defaultFontSize }
    @objc func showFontPanel(_ sender: Any?) {
        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(Preferences.shared.editorFont, isMultiple: false)
        manager.orderFrontFontPanel(self)
    }

    /// Called by the system Fonts panel when a font or size is picked.
    @objc func changeFont(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        Preferences.shared.adopt(font: manager.convert(Preferences.shared.editorFont))
    }

    @objc func setFontSize(_ sender: NSMenuItem) { Preferences.shared.fontSize = Double(sender.tag) }

    @objc func showPreferences(_ sender: Any?) { PreferencesWindowController.shared.show() }
    @objc func showAppPreferences(_ sender: Any?) { AppPreferencesWindowController.shared.show() }

    @objc func selectTheme(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { Preferences.shared.themeName = name }
    }

    @objc func setTabWidth(_ sender: NSMenuItem) { Preferences.shared.tabWidth = sender.tag }

    // MARK: - Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let prefs = Preferences.shared
        switch menuItem.action {
        case #selector(runCurrentFile(_:)):
            return EditorContext.current?.doc?.fileURL != nil
        case #selector(setUUIDFormat(_:)):
            menuItem.state = (menuItem.representedObject as? String) == prefs.uuidFormat ? .on : .off
        case #selector(setInsertLineWidth(_:)):
            menuItem.state = menuItem.tag == prefs.insertLineWidth ? .on : .off
        case #selector(toggleJournalMode(_:)):
            menuItem.state = prefs.journalMode ? .on : .off
        case #selector(toggleWordWrap(_:)):
            menuItem.state = prefs.wordWrap ? .on : .off
        case #selector(toggleLineNumbers(_:)):
            menuItem.state = prefs.showLineNumbers ? .on : .off
        case #selector(toggleInvisibles(_:)):
            menuItem.state = prefs.showInvisibles ? .on : .off
        case #selector(toggleCurrentLine(_:)):
            menuItem.state = prefs.highlightCurrentLine ? .on : .off
        case #selector(selectTheme(_:)):
            menuItem.state = (menuItem.representedObject as? String) == prefs.themeName ? .on : .off
        case #selector(setFontSize(_:)):
            menuItem.state = menuItem.tag == Int(prefs.fontSize.rounded()) ? .on : .off
        case #selector(setTabWidth(_:)):
            menuItem.state = menuItem.tag == prefs.tabWidth ? .on : .off
        case #selector(showFindPanel(_:)), #selector(showReplacePanel(_:)), #selector(findNextMatch(_:)),
             #selector(findPreviousMatch(_:)), #selector(useSelectionForFind(_:)):
            return EditorContext.current != nil
        case #selector(saveAllDocuments(_:)):
            return NSDocumentController.shared.documents.contains { $0.isDocumentEdited }
        case #selector(duplicateTab(_:)):
            return EditorContext.current != nil
        case #selector(togglePinTab(_:)):
            let pinned = NSApp.keyWindow.map { PinnedTabs.shared.isPinned($0) } ?? false
            menuItem.title = pinned ? "Unpin Tab" : "Pin Tab"
            menuItem.state = pinned ? .on : .off
            return EditorContext.current?.doc?.fileURL != nil
        case #selector(closeTabsToRight(_:)):
            return tabsExist(after: true)
        case #selector(closeTabsToLeft(_:)):
            return tabsExist(after: false)
        default:
            break
        }
        return true
    }
}
