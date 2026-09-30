import AppKit

/// The options sheet for one Random Generator tool: change the options, watch the preview update,
/// then Insert it at the cursor.
final class RandomGeneratorSheet: NSObject, NSTextFieldDelegate {
    private let tool: RandomTool
    private let panel: NSPanel
    private var controls: [String: NSControl] = [:]
    private let previewView: NSTextView
    private let previewScroll: NSScrollView
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    private let insertButton = NSButton(title: "Insert", target: nil, action: nil)
    private var output = ""
    private var limitNotice = ""
    private weak var parentWindow: NSWindow?

    var onInsert: ((String) -> Void)?
    var onFinish: (() -> Void)?

    init(tool: RandomTool) {
        self.tool = tool
        let scroll = NSTextView.scrollableTextView()
        previewScroll = scroll
        previewView = (scroll.documentView as? NSTextView) ?? NSTextView()
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
                        styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        buildUI()
    }

    // MARK: - Building the sheet

    private func buildUI() {
        let saved = tool.initialValues()

        let titleLabel = NSTextField(labelWithString: tool.title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        let summaryLabel = NSTextField(wrappingLabelWithString: tool.summary)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.preferredMaxLayoutWidth = 500

        // Option rows.
        var rows: [[NSView]] = []
        for field in tool.fields {
            switch field.kind {
            case .toggle:
                let box = NSButton(checkboxWithTitle: field.label, target: self, action: #selector(optionChanged))
                box.state = saved[field.id] == "1" ? .on : .off
                controls[field.id] = box
                rows.append([NSGridCell.emptyContentView, box])
            case .text, .number:
                let label = NSTextField(labelWithString: field.label + ":")
                label.alignment = .right
                let input = NSTextField()
                input.stringValue = saved[field.id] ?? field.defaultValue
                if field.id == "count" { input.stringValue = RandomGeneratorSheet.limitedCount(input.stringValue) }
                input.delegate = self
                input.widthAnchor.constraint(equalToConstant: field.kind.isNumber ? 110 : 260).isActive = true
                controls[field.id] = input
                rows.append([label, input])
            case .choice(let options):
                let label = NSTextField(labelWithString: field.label + ":")
                label.alignment = .right
                let popup = NSPopUpButton(frame: .zero, pullsDown: false)
                popup.addItems(withTitles: options)
                if let value = saved[field.id], options.contains(value) { popup.selectItem(withTitle: value) }
                popup.target = self
                popup.action = #selector(optionChanged)
                controls[field.id] = popup
                rows.append([label, popup])
            }
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing

        // Preview area.
        previewView.isEditable = false
        previewView.isSelectable = true
        previewView.isRichText = false
        previewView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewView.textContainerInset = NSSize(width: 6, height: 6)
        previewScroll.hasVerticalScroller = true
        previewScroll.borderType = .bezelBorder
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        previewScroll.widthAnchor.constraint(equalToConstant: 500).isActive = true
        previewScroll.heightAnchor.constraint(equalToConstant: 130).isActive = true

        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.preferredMaxLayoutWidth = 500

        // Buttons.
        let againButton = NSButton(title: "Generate Again", target: self, action: #selector(generateAgain))
        let copy = NSButton(title: "Copy", target: self, action: #selector(copyPressed))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.keyEquivalent = "\u{1b}"
        insertButton.target = self
        insertButton.action = #selector(insertPressed)
        insertButton.keyEquivalent = "\r"
        for button in [againButton, copy, cancel, insertButton] { button.bezelStyle = .rounded }
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let buttonRow = NSStackView(views: [againButton, copy, spacer, cancel, insertButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView(views: [titleLabel, summaryLabel, grid, previewScroll, noteLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        panel.contentView = content
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        content.layoutSubtreeIfNeeded()
        panel.setContentSize(NSSize(width: 540, height: stack.fittingSize.height))
    }

    // MARK: - Showing

    func present(on window: NSWindow) {
        parentWindow = window
        regenerate()
        window.beginSheet(panel) { [weak self] response in
            guard let self = self else { return }
            if response == .OK, !self.output.isEmpty { self.onInsert?(self.output) }
            self.onFinish?()
        }
    }

    // MARK: - Generating

    private func currentValues() -> [String: String] {
        var values: [String: String] = [:]
        for field in tool.fields {
            guard let control = controls[field.id] else { continue }
            switch field.kind {
            case .toggle: values[field.id] = (control as? NSButton)?.state == .on ? "1" : "0"
            case .text, .number: values[field.id] = (control as? NSTextField)?.stringValue ?? field.defaultValue
            case .choice: values[field.id] = (control as? NSPopUpButton)?.titleOfSelectedItem ?? field.defaultValue
            }
        }
        return values
    }

    private func regenerate() {
        let values = currentValues()
        let result = RandomGenerators.generate(tool, GeneratorValues(raw: values))
        output = result.text
        previewView.string = result.text
        noteLabel.stringValue = limitNotice.isEmpty ? result.note : limitNotice + " " + result.note
        insertButton.isEnabled = !result.text.isEmpty
        tool.remember(values)
    }

    /// Keeps "How many" between 1 and the global maximum.
    private static func limitedCount(_ text: String) -> String {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else { return text }
        return String(min(RandomGenerators.maxCount, max(1, value)))
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === controls["count"] {
            if let value = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), value > RandomGenerators.maxCount {
                field.stringValue = String(RandomGenerators.maxCount)
                limitNotice = "The most you can make at once is \(RandomGenerators.maxCount)."
            } else {
                limitNotice = ""
            }
        }
        regenerate()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === controls["count"] else { return }
        let fixed = RandomGeneratorSheet.limitedCount(field.stringValue)
        field.stringValue = Int(fixed) == nil ? "1" : fixed
        regenerate()
    }

    @objc private func optionChanged() { regenerate() }
    @objc private func generateAgain() { regenerate() }

    @objc private func copyPressed() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        noteLabel.stringValue = "Copied to the clipboard."
    }

    @objc private func insertPressed() {
        parentWindow?.endSheet(panel, returnCode: .OK)
    }

    @objc private func cancelPressed() {
        parentWindow?.endSheet(panel, returnCode: .cancel)
    }
}

private extension FieldKind {
    var isNumber: Bool {
        if case .number = self { return true }
        return false
    }
}
