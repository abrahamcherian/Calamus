import AppKit

/// "Font & Colors" settings window. Every change applies live to all open editors.
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sizeStepper = NSStepper()
    private let sizeLabel = NSTextField(labelWithString: "")
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let backgroundWell = NSColorWell()
    private let textWell = NSColorWell()
    private let tabPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let wrapBox = NSButton(checkboxWithTitle: "Word wrap", target: nil, action: nil)
    private let numbersBox = NSButton(checkboxWithTitle: "Show line numbers", target: nil, action: nil)
    private let invisiblesBox = NSButton(checkboxWithTitle: "Show whitespace and line endings", target: nil, action: nil)
    private let menuFontBox = NSButton(checkboxWithTitle: "Use the editor font in menus (uncheck for the system font)", target: nil, action: nil)
    private let currentLineBox = NSButton(checkboxWithTitle: "Highlight current line", target: nil, action: nil)

    private var fontFamilies: [String] = []
    private var isRefreshing = false

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Font & Colors"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI(in: window)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .preferencesChanged, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private static func monospacedFamilies() -> [String] {
        let manager = NSFontManager.shared
        return manager.availableFontFamilies.filter { family in
            manager.font(withFamily: family, traits: [], weight: 5, size: 12)?.isFixedPitch ?? false
        }.sorted()
    }

    private func buildUI(in window: NSWindow) {
        let bundled = BundledFonts.available
        let others = PreferencesWindowController.monospacedFamilies().filter { !bundled.contains($0) }
        fontFamilies = [Preferences.systemMonospacedName] + bundled + others
        fontPopup.addItems(withTitles: fontFamilies)
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged)

        sizeStepper.minValue = 6
        sizeStepper.maxValue = 72
        sizeStepper.increment = 1
        sizeStepper.valueWraps = false
        sizeStepper.target = self
        sizeStepper.action = #selector(sizeChanged)
        sizeLabel.alignment = .right
        sizeLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        let resetSize = NSButton(title: "Reset", target: self, action: #selector(resetSizePressed))
        resetSize.bezelStyle = .rounded

        themePopup.addItem(withTitle: "Automatic (follow system)")
        themePopup.addItems(withTitles: Theme.all.map { $0.name })
        themePopup.target = self
        themePopup.action = #selector(themeChanged)

        for well in [backgroundWell, textWell] {
            well.widthAnchor.constraint(equalToConstant: 48).isActive = true
            well.heightAnchor.constraint(equalToConstant: 26).isActive = true
            well.target = self
        }
        backgroundWell.action = #selector(backgroundChanged)
        textWell.action = #selector(textColorChanged)
        let resetColors = NSButton(title: "Reset to Theme Colors", target: self, action: #selector(resetColorsPressed))
        resetColors.bezelStyle = .rounded

        tabPopup.addItems(withTitles: ["2 spaces", "4 spaces", "8 spaces"])
        tabPopup.target = self
        tabPopup.action = #selector(tabWidthChanged)

        for box in [wrapBox, numbersBox, invisiblesBox, currentLineBox] {
            box.target = self
            box.action = #selector(togglesChanged)
        }

        menuFontBox.target = self
        menuFontBox.action = #selector(menuFontChanged)

        let hint = NSTextField(wrappingLabelWithString:
            "Changes apply immediately. Choosing a background color keeps your theme's syntax colors, "
            + "switching to a light or dark palette automatically so text stays readable.")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)

        let rows: [NSView] = [
            row("Font:", fontPopup),
            row("Size:", horizontal([sizeLabel, sizeStepper, resetSize])),
            separator(),
            row("Theme:", themePopup),
            row("Background:", backgroundWell),
            row("Text color:", textWell),
            row("", resetColors),
            separator(),
            row("Tab width:", tabPopup),
            row("", wrapBox),
            row("", numbersBox),
            row("", invisiblesBox),
            row("", currentLineBox),
            separator(),
            row("", menuFontBox),
            hint
        ]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        window.contentView = content
        content.addSubview(stack)
        var constraints = [
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20)
        ]
        for view in rows { constraints.append(view.widthAnchor.constraint(equalTo: stack.widthAnchor)) }
        NSLayoutConstraint.activate(constraints)
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 480, height: stack.fittingSize.height + 40))
    }

    private func horizontal(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.spacing = 8
        return s
    }

    private func row(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 92).isActive = true
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let r = NSStackView(views: [label, control, spacer])
        r.orientation = .horizontal
        r.spacing = 10
        r.alignment = .centerY
        return r
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    func show() {
        refresh()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Syncing controls with preferences

    @objc private func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }
        let prefs = Preferences.shared

        if let index = fontFamilies.firstIndex(of: prefs.fontFamily) {
            fontPopup.selectItem(at: index)
        } else {
            fontPopup.selectItem(at: 0)
        }
        sizeStepper.doubleValue = prefs.fontSize
        sizeLabel.stringValue = "\(Int(prefs.fontSize.rounded())) pt"

        if prefs.themeName == Preferences.autoThemeName {
            themePopup.selectItem(at: 0)
        } else if let index = Theme.all.firstIndex(where: { $0.name == prefs.themeName }) {
            themePopup.selectItem(at: index + 1)
        }

        let theme = prefs.currentTheme()
        backgroundWell.color = theme.background
        textWell.color = theme.foreground

        switch prefs.tabWidth {
        case 2: tabPopup.selectItem(at: 0)
        case 8: tabPopup.selectItem(at: 2)
        default: tabPopup.selectItem(at: 1)
        }
        wrapBox.state = prefs.wordWrap ? .on : .off
        numbersBox.state = prefs.showLineNumbers ? .on : .off
        invisiblesBox.state = prefs.showInvisibles ? .on : .off
        currentLineBox.state = prefs.highlightCurrentLine ? .on : .off
        menuFontBox.state = prefs.menuUsesEditorFont ? .on : .off
    }

    // MARK: - Actions

    @objc private func fontChanged() {
        guard !isRefreshing, let title = fontPopup.titleOfSelectedItem else { return }
        Preferences.shared.fontFamily = title
    }

    @objc private func sizeChanged() {
        guard !isRefreshing else { return }
        Preferences.shared.fontSize = sizeStepper.doubleValue
    }

    @objc private func resetSizePressed() {
        Preferences.shared.fontSize = Preferences.defaultFontSize
    }

    @objc private func themeChanged() {
        guard !isRefreshing else { return }
        let index = themePopup.indexOfSelectedItem
        Preferences.shared.themeName = index <= 0 ? Preferences.autoThemeName : Theme.all[index - 1].name
        // Picking a theme means "use that theme", so drop any color overrides from a previous session.
        Preferences.shared.resetColors()
    }

    @objc private func backgroundChanged() {
        guard !isRefreshing else { return }
        Preferences.shared.customBackground = backgroundWell.color
    }

    @objc private func textColorChanged() {
        guard !isRefreshing else { return }
        Preferences.shared.customForeground = textWell.color
    }

    @objc private func resetColorsPressed() {
        Preferences.shared.resetColors()
    }

    @objc private func tabWidthChanged() {
        guard !isRefreshing else { return }
        let widths = [2, 4, 8]
        let index = tabPopup.indexOfSelectedItem
        if widths.indices.contains(index) { Preferences.shared.tabWidth = widths[index] }
    }

    @objc private func togglesChanged() {
        guard !isRefreshing else { return }
        let prefs = Preferences.shared
        // Read every box first: each preference write refreshes all the boxes.
        let wrap = wrapBox.state == .on
        let numbers = numbersBox.state == .on
        let invisibles = invisiblesBox.state == .on
        let currentLine = currentLineBox.state == .on
        if prefs.wordWrap != wrap { prefs.wordWrap = wrap }
        if prefs.showLineNumbers != numbers { prefs.showLineNumbers = numbers }
        if prefs.showInvisibles != invisibles { prefs.showInvisibles = invisibles }
        if prefs.highlightCurrentLine != currentLine { prefs.highlightCurrentLine = currentLine }
    }

    /// Handled on its own: each preference change refreshes every checkbox, so writing all the
    /// preferences in one go would put the box you just clicked back to its old value.
    @objc private func menuFontChanged() {
        guard !isRefreshing else { return }
        Preferences.shared.menuUsesEditorFont = (menuFontBox.state == .on)
    }
}
