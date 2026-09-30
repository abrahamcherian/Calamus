import AppKit

/// The options sheet for one Format > Text Formatting command: change the options, watch the preview
/// update, then Apply to the selection (or to the whole document when nothing is selected).
final class TextFormatSheet: NSObject, NSTextFieldDelegate {
    private let tool: TextFormatTool
    private let source: String
    private let scopeNote: String
    private let panel: NSPanel
    private var controls: [String: NSControl] = [:]
    private let previewView: NSTextView
    private let previewScroll: NSScrollView
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    private let applyButton = NSButton(title: "Apply", target: nil, action: nil)
    private var output = ""
    /// Fixes the order of a "Random (shuffle)" sort, so what the preview shows is what gets applied.
    private let seed = String(UInt64.random(in: 1...UInt64.max))
    private weak var parentWindow: NSWindow?

    var onApply: ((String) -> Void)?
    var onFinish: (() -> Void)?

    init(tool: TextFormatTool, source: String, scopeNote: String) {
        self.tool = tool
        self.source = source
        self.scopeNote = scopeNote
        let scroll = NSTextView.scrollableTextView()
        previewScroll = scroll
        previewView = (scroll.documentView as? NSTextView) ?? NSTextView()
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
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
        summaryLabel.preferredMaxLayoutWidth = 520

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
                input.delegate = self
                var isNumber = false
                if case .number = field.kind { isNumber = true }
                input.widthAnchor.constraint(equalToConstant: isNumber ? 100 : 200).isActive = true
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

        previewView.isEditable = false
        previewView.isSelectable = true
        previewView.isRichText = false
        previewView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewView.textContainerInset = NSSize(width: 6, height: 6)
        previewView.isHorizontallyResizable = true
        previewView.textContainer?.widthTracksTextView = false
        previewView.textContainer?.containerSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
        previewScroll.hasVerticalScroller = true
        previewScroll.hasHorizontalScroller = true
        previewScroll.borderType = .bezelBorder
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        previewScroll.widthAnchor.constraint(equalToConstant: 520).isActive = true
        previewScroll.heightAnchor.constraint(equalToConstant: 150).isActive = true

        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.preferredMaxLayoutWidth = 520

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.keyEquivalent = "\u{1b}"
        applyButton.target = self
        applyButton.action = #selector(applyPressed)
        applyButton.keyEquivalent = "\r"
        for button in [cancel, applyButton] { button.bezelStyle = .rounded }
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let buttonRow = NSStackView(views: [spacer, cancel, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.widthAnchor.constraint(equalToConstant: 520).isActive = true

        let previewTitle = NSTextField(labelWithString: "Preview")
        previewTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        previewTitle.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, summaryLabel, grid, previewTitle, previewScroll, noteLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(14, after: summaryLabel)
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
        panel.setContentSize(NSSize(width: 560, height: stack.fittingSize.height))
    }

    // MARK: - Showing

    func present(on window: NSWindow) {
        parentWindow = window
        regenerate()
        window.beginSheet(panel) { [weak self] response in
            guard let self = self else { return }
            if response == .OK { self.onApply?(self.tool.transform(self.source, GeneratorValues(raw: self.currentValues().merging(["_seed": self.seed]) { $1 }))) }
            self.onFinish?()
        }
    }

    // MARK: - Preview

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

    /// The first part of the text (whole lines only), so the preview stays quick on big files.
    private func previewSource() -> (text: String, cut: Bool) {
        let limit = 4000
        guard source.count > limit else { return (source, false) }
        var text = String(source.prefix(limit))
        if let lastBreak = text.lastIndex(of: "\n") { text = String(text[..<lastBreak]) }
        return (text, true)
    }

    private func regenerate() {
        let values = currentValues()
        let preview = previewSource()
        let result = tool.transform(preview.text, GeneratorValues(raw: values.merging(["_seed": seed]) { $1 }))
        previewView.string = result
        applyButton.isEnabled = !source.isEmpty
        noteLabel.stringValue = scopeNote + (preview.cut ? " The preview shows the beginning only." : "")
        tool.remember(values)
        output = result
    }

    func controlTextDidChange(_ obj: Notification) { regenerate() }
    @objc private func optionChanged() { regenerate() }

    @objc private func applyPressed() {
        parentWindow?.endSheet(panel, returnCode: .OK)
    }

    @objc private func cancelPressed() {
        parentWindow?.endSheet(panel, returnCode: .cancel)
    }
}
