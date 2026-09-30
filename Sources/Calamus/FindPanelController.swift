import AppKit

/// Find / Replace panel with Normal, Extended and Regular-expression modes.
final class FindPanelController: NSWindowController {
    static let shared = FindPanelController()

    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let matchCaseBox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    private let wholeWordBox = NSButton(checkboxWithTitle: "Whole word", target: nil, action: nil)
    private let wrapBox = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
    private let regexBox = NSButton(checkboxWithTitle: "Regular expression", target: nil, action: nil)
    private let extendedBox = NSButton(checkboxWithTitle: "Extended (\\n \\t \\0 \\x…)", target: nil, action: nil)
    private let dotAllBox = NSButton(checkboxWithTitle: ". matches newline", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    private init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 290),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "Find & Replace"
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private func buildUI(in panel: NSPanel) {
        matchCaseBox.state = .off
        wrapBox.state = .on

        findField.placeholderString = "Text to find"
        findField.target = self
        findField.action = #selector(findNext)
        replaceField.placeholderString = "Replacement text"
        for box in [matchCaseBox, wholeWordBox, wrapBox, regexBox, extendedBox, dotAllBox] {
            box.target = self
            box.action = #selector(optionsChanged)
        }

        let findRow = makeRow("Find what:", findField)
        let replaceRow = makeRow("Replace with:", replaceField)

        let optionsA = NSStackView(views: [matchCaseBox, wholeWordBox, wrapBox])
        let optionsB = NSStackView(views: [regexBox, extendedBox, dotAllBox])
        for s in [optionsA, optionsB] {
            s.orientation = .horizontal
            s.spacing = 14
        }

        let findNextButton = makeButton("Find Next", #selector(findNext))
        findNextButton.keyEquivalent = "\r"
        let buttonsA = NSStackView(views: [findNextButton,
                                           makeButton("Find Previous", #selector(findPrevious)),
                                           makeButton("Count", #selector(countMatches))])
        let buttonsB = NSStackView(views: [makeButton("Replace", #selector(replaceOne)),
                                           makeButton("Replace All", #selector(replaceAll))])
        for s in [buttonsA, buttonsB] {
            s.orientation = .horizontal
            s.spacing = 8
        }

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)

        let stack = NSStackView(views: [findRow, replaceRow, optionsA, optionsB, buttonsA, buttonsB, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        panel.contentView = content
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            findRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            replaceRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func makeRow(_ title: String, _ field: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 92).isActive = true
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func makeButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    // MARK: - Showing

    func show(focusReplace: Bool = false) {
        if let editor = EditorContext.current {
            let selected = editor.textView.selectedRange()
            if selected.length > 0 && selected.length < 500 {
                let text = (editor.textView.string as NSString).substring(with: selected)
                if !text.contains("\n") { findField.stringValue = text }
            }
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(focusReplace ? replaceField : findField)
    }

    func useSelectionForFind() {
        guard let editor = EditorContext.current else { return }
        let sel = editor.textView.selectedRange()
        guard sel.length > 0 else { return }
        findField.stringValue = (editor.textView.string as NSString).substring(with: sel)
    }

    var hasQuery: Bool { !findField.stringValue.isEmpty }

    // MARK: - Options

    private var options: FindOptions {
        FindOptions(matchCase: matchCaseBox.state == .on,
                    wholeWord: wholeWordBox.state == .on,
                    useRegex: regexBox.state == .on,
                    extended: extendedBox.state == .on,
                    dotMatchesNewline: dotAllBox.state == .on,
                    wrap: wrapBox.state == .on)
    }

    @objc private func optionsChanged() {
        // Extended and regex modes are mutually exclusive search-mode radio buttons.
        if regexBox.state == .on { extendedBox.state = .off }
        dotAllBox.isEnabled = regexBox.state == .on
        extendedBox.isEnabled = regexBox.state == .off
    }

    private func status(_ message: String) {
        statusLabel.stringValue = message
    }

    private func currentRegex() -> (NSRegularExpression, NSTextView)? {
        guard let editor = EditorContext.current else {
            status("No document is open.")
            return nil
        }
        guard hasQuery else {
            status("Enter the text to find.")
            return nil
        }
        do {
            let regex = try FindEngine.makeRegex(findField.stringValue, options)
            return (regex, editor.textView)
        } catch {
            status("Invalid regular expression.")
            return nil
        }
    }

    // MARK: - Actions

    @objc func findNext() { _ = find(forward: true) }
    @objc func findPrevious() { _ = find(forward: false) }

    /// Also used by the Find Next / Find Previous menu commands.
    @discardableResult
    func find(forward: Bool) -> Bool {
        guard let (regex, tv) = currentRegex() else { return false }
        let text = tv.string
        let length = (text as NSString).length
        let selection = tv.selectedRange()
        let matchOptions: NSRegularExpression.MatchingOptions = [.withTransparentBounds, .withoutAnchoringBounds]

        func firstMatch(in range: NSRange) -> NSRange? {
            var result: NSRange?
            regex.enumerateMatches(in: text, options: matchOptions, range: range) { match, _, stop in
                if let m = match, m.range.length > 0 {
                    result = m.range
                    stop.pointee = true
                }
            }
            return result
        }

        func lastMatch(in range: NSRange) -> NSRange? {
            var result: NSRange?
            regex.enumerateMatches(in: text, options: matchOptions, range: range) { match, _, _ in
                if let m = match, m.range.length > 0 { result = m.range }
            }
            return result
        }

        var found: NSRange?
        var wrapped = false
        if forward {
            let start = min(NSMaxRange(selection), length)
            found = firstMatch(in: NSRange(location: start, length: length - start))
            if found == nil && options.wrap {
                found = firstMatch(in: NSRange(location: 0, length: length))
                wrapped = found != nil
            }
        } else {
            found = lastMatch(in: NSRange(location: 0, length: min(selection.location, length)))
            if found == nil && options.wrap {
                found = lastMatch(in: NSRange(location: 0, length: length))
                wrapped = found != nil
            }
        }

        guard let range = found else {
            status("Not found.")
            NSSound.beep()
            return false
        }
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        tv.showFindIndicator(for: range)
        status(wrapped ? "Found (wrapped around)." : "Found.")
        return true
    }

    @objc private func countMatches() {
        guard let (regex, tv) = currentRegex() else { return }
        let text = tv.string
        let n = regex.numberOfMatches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
        status("\(n) match\(n == 1 ? "" : "es") in this document.")
    }

    @objc private func replaceOne() {
        guard let (regex, tv) = currentRegex() else { return }
        let selection = tv.selectedRange()
        let text = tv.string
        // Only replace if the current selection is itself a match (otherwise just move to the next one).
        if selection.length > 0,
           let m = regex.firstMatch(in: text, options: [.anchored, .withTransparentBounds, .withoutAnchoringBounds], range: selection),
           m.range == selection {
            let template = FindEngine.replacementTemplate(replaceField.stringValue, options)
            let replacement = regex.replacementString(for: m, in: text, offset: 0, template: template)
            if tv.shouldChangeText(in: selection, replacementString: replacement) {
                tv.textStorage?.replaceCharacters(in: selection, with: replacement)
                tv.didChangeText()
                tv.setSelectedRange(NSRange(location: selection.location + (replacement as NSString).length, length: 0))
            }
        }
        _ = find(forward: true)
    }

    @objc private func replaceAll() {
        guard let (regex, tv) = currentRegex() else { return }
        let text = tv.string
        let full = NSRange(location: 0, length: (text as NSString).length)
        let count = regex.numberOfMatches(in: text, options: [], range: full)
        guard count > 0 else {
            status("Not found.")
            NSSound.beep()
            return
        }
        let template = FindEngine.replacementTemplate(replaceField.stringValue, options)
        let result = regex.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template)
        let oldCaret = tv.selectedRange().location
        if tv.shouldChangeText(in: full, replacementString: result) {
            tv.textStorage?.replaceCharacters(in: full, with: result)
            tv.didChangeText()
            tv.setSelectedRange(NSRange(location: min(oldCaret, (result as NSString).length), length: 0))
        }
        status("Replaced \(count) occurrence\(count == 1 ? "" : "s").")
    }
}
