import AppKit
import AVFoundation
import Speech

/// File > Preferences…: one place for the app's default values (Insert menu and Random Generator
/// defaults, plus a reset to factory settings). Font, size and colors stay in Font & Colors (⌘,).
final class AppPreferencesWindowController: NSWindowController, NSTextFieldDelegate {
    static let shared = AppPreferencesWindowController()

    private let tabView = NSTabView()
    private let opacitySlider = NSSlider(value: Double(Preferences.defaultWindowTransparency), minValue: 0, maxValue: 90,
                                         target: nil, action: nil)
    private let opacityLabel = NSTextField(labelWithString: "")
    private let textSlider = NSSlider(value: Double(Preferences.defaultTextTransparency), minValue: 0, maxValue: 90,
                                      target: nil, action: nil)
    private let textLabel = NSTextField(labelWithString: "")
    private let keepTransparencyBox = NSButton(checkboxWithTitle: "Keep my transparency settings when the app restarts (otherwise both start at the defaults)",
                                               target: nil, action: nil)
    private let journalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let widthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let uuidPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let voiceLocalePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let onDeviceBox = NSButton(checkboxWithTitle: "Prefer on-device recognition when available (more private and works offline; off allows Apple's server-based recognizer, which supports more languages)",
                                       target: nil, action: nil)
    private let micStatusLabel = NSTextField(labelWithString: "")
    private let speechStatusLabel = NSTextField(labelWithString: "")
    private let readVoicePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let readRateSlider = NSSlider(value: Preferences.defaultReadAloudRate, minValue: 100, maxValue: 300,
                                          target: nil, action: nil)
    private let readRateLabel = NSTextField(labelWithString: "")
    private let toolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let formHolder = NSStackView()
    private let rememberBox = NSButton(checkboxWithTitle: "Start each tool with the values I used last time (instead of my defaults)",
                                       target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private var controls: [String: NSControl] = [:]
    private var isBuilding = false

    private let uuidOptions: [(id: String, label: String)] = [
        ("lower", "Lowercase, with dashes"), ("upper", "UPPERCASE, with dashes"),
        ("compact", "Without dashes"), ("braces", "In braces { }")
    ]

    // Built once in buildUI(): the languages Speech Recognition supports, and the voices
    // installed for speech synthesis. Index 0 in each popup is always "System Default" (index
    // -1 in these arrays, i.e. not present here).
    private var voiceLocaleOptions: [(id: String, label: String)] = []
    private var readAloudVoiceOptions: [(id: String, label: String)] = []

    private var currentTool: RandomTool {
        let index = max(0, toolPopup.indexOfSelectedItem)
        return RandomTool.allCases[min(index, RandomTool.allCases.count - 1)]
    }

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI(in: window)
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange),
                                               name: .preferencesChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        syncInsertTab()
        syncVoiceTab()
        rebuildRandomForm()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout helpers

    private func horizontal(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func page(_ views: [NSView]) -> NSView {
        let container = NSView()
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    private func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 11)
        label.preferredMaxLayoutWidth = 520
        return label
    }

    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        return label
    }

    private func labeled(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 10
        return row
    }

    // MARK: - Building the window

    private func buildUI(in window: NSWindow) {
        // General
        let openFonts = NSButton(title: "Open Font & Colors…", target: self, action: #selector(openFontsAndColors))
        openFonts.bezelStyle = .rounded
        let resetAll = NSButton(title: "Reset All Settings to Factory Defaults…", target: self, action: #selector(resetEverything))
        resetAll.bezelStyle = .rounded
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.isContinuous = true
        opacitySlider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        opacityLabel.alignment = .right
        opacityLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let opacityReset = NSButton(title: "Reset", target: self, action: #selector(opacityReset))
        opacityReset.bezelStyle = .rounded
        let opacityRow = NSStackView(views: [opacitySlider, opacityLabel, opacityReset])
        opacityRow.orientation = .horizontal
        opacityRow.spacing = 10

        textSlider.target = self
        textSlider.action = #selector(textTransparencyChanged)
        textSlider.isContinuous = true
        textSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        textLabel.alignment = .right
        textLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let textReset = NSButton(title: "Reset", target: self, action: #selector(textTransparencyReset))
        textReset.bezelStyle = .rounded
        let textRow = NSStackView(views: [textSlider, textLabel, textReset])
        textRow.orientation = .horizontal
        textRow.spacing = 10

        keepTransparencyBox.target = self
        keepTransparencyBox.action = #selector(keepTransparencyChanged)

        let idleChoices: [(String, Int)] = [("5 minutes", 5), ("15 minutes", 15), ("30 minutes", 30), ("1 hour", 60),
                                            ("4 hours", 240), ("Only when the file is opened", 0)]
        for (title, minutes) in idleChoices {
            journalPopup.addItem(withTitle: title)
            journalPopup.lastItem?.tag = minutes
        }
        journalPopup.target = self
        journalPopup.action = #selector(journalIdleChanged)

        let general = page([
            heading("Journal mode (Format menu)"),
            labeled("New entry after:", journalPopup),
            note("When Journal mode is on, typing in a plain text file adds a banner with the date and time at the end of the file and starts you on a fresh line below it. A new banner is added when you type again after this much time without typing."),
            heading("Window background"),
            labeled("Window:", opacityRow),
            labeled("Text background:", textRow),
            note("Transparency in percent: 0% is fully solid, higher lets the desktop show through (text stays fully visible). Window controls the line-number gutter and status bar; Text background controls the area you type in. Defaults: \(Preferences.defaultWindowTransparency)% and \(Preferences.defaultTextTransparency)%, applied every time the app starts."),
            keepTransparencyBox,
            heading("Editor look"),
            note("Font, font size, theme, background and text colors, tab width and the view options are edited in Font & Colors (⌘,). Factory defaults: JetBrains Mono, size 18, Licorice (black) background and #CC9933 text."),
            openFonts,
            heading("Start over"),
            note("Puts every setting in Calamus (fonts, colors, Insert menu choices, Random Generator defaults) back to how it was on first launch."),
            resetAll
        ])

        // Insert
        widthPopup.addItems(withTitles: InsertSnippets.lineWidths.map { "\($0) characters" })
        for (index, width) in InsertSnippets.lineWidths.enumerated() { widthPopup.item(at: index)?.tag = width }
        widthPopup.target = self
        widthPopup.action = #selector(insertWidthChanged)
        uuidPopup.addItems(withTitles: uuidOptions.map { $0.label })
        uuidPopup.target = self
        uuidPopup.action = #selector(uuidFormatChanged)
        let insert = page([
            heading("Insert menu defaults"),
            labeled("Line width:", widthPopup),
            labeled("UUID format:", uuidPopup),
            note("Line width is used by Insert > Horizontal Line and Comment Banner. The UUID format is used by every Insert > UUID version. Changes apply immediately (the same choices are also in the Insert menu).")
        ])

        // Voice (Voice to Text and Read Aloud)
        buildVoiceOptions()
        voiceLocalePopup.target = self
        voiceLocalePopup.action = #selector(voiceLocaleChanged)
        onDeviceBox.target = self
        onDeviceBox.action = #selector(onDeviceChanged)
        let openMicButton = NSButton(title: "Open Microphone Privacy Settings…", target: self, action: #selector(openMicPrivacy))
        openMicButton.bezelStyle = .rounded
        let openSpeechButton = NSButton(title: "Open Speech Recognition Privacy Settings…", target: self, action: #selector(openSpeechPrivacy))
        openSpeechButton.bezelStyle = .rounded
        micStatusLabel.font = NSFont.systemFont(ofSize: 11)
        micStatusLabel.textColor = .secondaryLabelColor
        speechStatusLabel.font = NSFont.systemFont(ofSize: 11)
        speechStatusLabel.textColor = .secondaryLabelColor

        readVoicePopup.target = self
        readVoicePopup.action = #selector(readVoiceChanged)
        readRateSlider.target = self
        readRateSlider.action = #selector(readRateChanged)
        readRateSlider.isContinuous = true
        readRateSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        readRateLabel.alignment = .right
        readRateLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let readRateRow = horizontal([readRateSlider, readRateLabel])
        let testVoiceButton = NSButton(title: "Test Voice", target: self, action: #selector(testReadVoice))
        testVoiceButton.bezelStyle = .rounded

        let voice = page([
            heading("Voice to Text (Edit menu, \u{21e7}\u{2318}V)"),
            labeled("Language:", voiceLocalePopup),
            onDeviceBox,
            labeled("Microphone:", horizontal([micStatusLabel, openMicButton])),
            labeled("Speech Recognition:", horizontal([speechStatusLabel, openSpeechButton])),
            note("\"System Default\" follows whatever language macOS is currently set to. Changes apply the next time you start Voice to Text (\u{21e7}\u{2318}V)."),
            heading("Read Aloud (Edit menu, \u{21e7}\u{2318}R)"),
            labeled("Voice:", readVoicePopup),
            labeled("Rate:", readRateRow),
            testVoiceButton,
            note("Reads the selected text, or from the cursor to the end of the document if nothing is selected. More voices can be installed in System Settings \u{2192} Accessibility \u{2192} Spoken Content \u{2192} System Voice \u{2192} Manage Voices…")
        ])

        // Random Generator
        toolPopup.addItems(withTitles: RandomTool.allCases.map { $0.title })
        toolPopup.target = self
        toolPopup.action = #selector(toolChanged)
        formHolder.orientation = .vertical
        formHolder.alignment = .leading
        formHolder.spacing = 8
        rememberBox.target = self
        rememberBox.action = #selector(rememberChanged)
        let restore = NSButton(title: "Restore Built-in Defaults for This Tool", target: self, action: #selector(restoreToolDefaults))
        restore.bezelStyle = .rounded
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        let random = page([
            heading("Random Generator defaults"),
            labeled("Tool:", toolPopup),
            formHolder,
            rememberBox,
            restore,
            statusLabel,
            note("What you set here is what each tool's options sheet starts with. Changes are saved as you make them. \"How many\" can be 1 to \(RandomGenerators.maxCount).")
        ])

        for (label, view) in [("General", general), ("Insert", insert), ("Voice", voice), ("Random Generator", random)] {
            let item = NSTabViewItem(identifier: label)
            item.label = label
            item.view = view
            tabView.addTabViewItem(item)
        }
        window.contentView = tabView
    }

    // MARK: - Insert tab

    private func syncInsertTab() {
        let prefs = Preferences.shared
        if let index = InsertSnippets.lineWidths.firstIndex(of: prefs.insertLineWidth) {
            widthPopup.selectItem(at: index)
        }
        if let index = uuidOptions.firstIndex(where: { $0.id == prefs.uuidFormat }) {
            uuidPopup.selectItem(at: index)
        }
        rememberBox.state = UserDefaults.standard.bool(forKey: "randomRemembersLast") ? .on : .off
        journalPopup.selectItem(withTag: prefs.journalIdleMinutes)
        opacitySlider.integerValue = prefs.windowTransparency
        opacityLabel.stringValue = "\(prefs.windowTransparency)%"
        keepTransparencyBox.state = prefs.keepTransparencyAcrossLaunches ? .on : .off
        textSlider.integerValue = prefs.textTransparency
        textLabel.stringValue = "\(prefs.textTransparency)%"
    }

    @objc private func opacityChanged() {
        let value = opacitySlider.integerValue
        opacityLabel.stringValue = "\(value)%"
        if Preferences.shared.windowTransparency != value { Preferences.shared.windowTransparency = value }
    }

    @objc private func journalIdleChanged() {
        Preferences.shared.journalIdleMinutes = journalPopup.selectedItem?.tag ?? 30
    }

    @objc private func keepTransparencyChanged() {
        Preferences.shared.keepTransparencyAcrossLaunches = (keepTransparencyBox.state == .on)
    }

    @objc private func textTransparencyChanged() {
        let value = textSlider.integerValue
        textLabel.stringValue = "\(value)%"
        if Preferences.shared.textTransparency != value { Preferences.shared.textTransparency = value }
    }

    @objc private func textTransparencyReset() {
        Preferences.shared.textTransparency = Preferences.defaultTextTransparency
    }

    @objc private func opacityReset() {
        Preferences.shared.windowTransparency = Preferences.defaultWindowTransparency
    }

    @objc private func preferencesDidChange() { syncInsertTab(); syncVoiceTab() }

    @objc private func insertWidthChanged() {
        let width = widthPopup.selectedItem?.tag ?? 80
        Preferences.shared.insertLineWidth = width
    }

    @objc private func uuidFormatChanged() {
        let index = max(0, uuidPopup.indexOfSelectedItem)
        Preferences.shared.uuidFormat = uuidOptions[min(index, uuidOptions.count - 1)].id
    }

    // MARK: - Voice tab

    /// Populates the language and voice popups once, from what's actually installed/supported
    /// on this Mac. Index 0 in each popup is "System Default"; `voiceLocaleOptions[i]` /
    /// `readAloudVoiceOptions[i]` correspond to popup index `i + 1`.
    private func buildVoiceOptions() {
        voiceLocalePopup.removeAllItems()
        voiceLocalePopup.addItem(withTitle: "System Default")
        let locales = SFSpeechRecognizer.supportedLocales().map { locale -> (id: String, label: String) in
            let label = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            return (locale.identifier, label)
        }.sorted { $0.label < $1.label }
        voiceLocaleOptions = locales
        voiceLocalePopup.addItems(withTitles: locales.map { $0.label })

        readVoicePopup.removeAllItems()
        readVoicePopup.addItem(withTitle: "System Default")
        let voices = NSSpeechSynthesizer.availableVoices.map { voiceID -> (id: String, label: String) in
            // NSSpeechSynthesizer.VoiceName isn't a plain String on this SDK (it's its own
            // RawRepresentable type), so every voice identifier is unwrapped via .rawValue here.
            let voiceRawID = voiceID.rawValue
            let attributes = NSSpeechSynthesizer.attributes(forVoice: voiceID)
            let name = (attributes[NSSpeechSynthesizer.VoiceAttributeKey.name] as? String) ?? voiceRawID
            if let localeID = attributes[NSSpeechSynthesizer.VoiceAttributeKey.localeIdentifier] as? String {
                return (voiceRawID, "\(name) (\(localeID))")
            }
            return (voiceRawID, name)
        }.sorted { $0.label < $1.label }
        readAloudVoiceOptions = voices
        readVoicePopup.addItems(withTitles: voices.map { $0.label })
    }

    private func syncVoiceTab() {
        let prefs = Preferences.shared
        if !prefs.voiceRecognitionLocale.isEmpty,
           let index = voiceLocaleOptions.firstIndex(where: { $0.id == prefs.voiceRecognitionLocale }) {
            voiceLocalePopup.selectItem(at: index + 1)
        } else {
            voiceLocalePopup.selectItem(at: 0)
        }
        onDeviceBox.state = prefs.voiceRequiresOnDeviceRecognition ? .on : .off
        micStatusLabel.stringValue = AppPreferencesWindowController.microphonePermissionDescription()
        speechStatusLabel.stringValue = AppPreferencesWindowController.speechPermissionDescription()

        if !prefs.readAloudVoiceIdentifier.isEmpty,
           let index = readAloudVoiceOptions.firstIndex(where: { $0.id == prefs.readAloudVoiceIdentifier }) {
            readVoicePopup.selectItem(at: index + 1)
        } else {
            readVoicePopup.selectItem(at: 0)
        }
        readRateSlider.doubleValue = prefs.readAloudRate
        readRateLabel.stringValue = "\(Int(prefs.readAloudRate)) wpm"
    }

    private static func microphonePermissionDescription() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return "Allowed"
        case .denied, .restricted: return "Not allowed"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    private static func speechPermissionDescription() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return "Allowed"
        case .denied, .restricted: return "Not allowed"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    @objc private func voiceLocaleChanged() {
        let index = voiceLocalePopup.indexOfSelectedItem
        Preferences.shared.voiceRecognitionLocale = index <= 0 ? "" : voiceLocaleOptions[min(index - 1, voiceLocaleOptions.count - 1)].id
    }

    @objc private func onDeviceChanged() {
        Preferences.shared.voiceRequiresOnDeviceRecognition = (onDeviceBox.state == .on)
    }

    @objc private func openMicPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSpeechPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func readVoiceChanged() {
        let index = readVoicePopup.indexOfSelectedItem
        Preferences.shared.readAloudVoiceIdentifier = index <= 0 ? "" : readAloudVoiceOptions[min(index - 1, readAloudVoiceOptions.count - 1)].id
    }

    @objc private func readRateChanged() {
        let value = readRateSlider.doubleValue
        readRateLabel.stringValue = "\(Int(value)) wpm"
        Preferences.shared.readAloudRate = value
    }

    @objc private func testReadVoice() {
        TextReader.shared.stop()
        TextReader.shared.speak("This is what Read Aloud sounds like with your current settings.")
    }

    // MARK: - Random Generator tab

    @objc private func toolChanged() { rebuildRandomForm() }

    private func rebuildRandomForm() {
        isBuilding = true
        defer { isBuilding = false }
        controls.removeAll()
        for view in formHolder.arrangedSubviews {
            formHolder.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        statusLabel.stringValue = ""
        let tool = currentTool
        let saved = tool.editableDefaults()
        var rows: [[NSView]] = []
        for field in tool.fields {
            switch field.kind {
            case .toggle:
                let box = NSButton(checkboxWithTitle: field.label, target: self, action: #selector(controlChanged))
                box.state = saved[field.id] == "1" ? .on : .off
                controls[field.id] = box
                rows.append([NSGridCell.emptyContentView, box])
            case .text, .number:
                let label = NSTextField(labelWithString: (field.id == "count" ? RandomTool.countLabel : field.label) + ":")
                label.alignment = .right
                let input = NSTextField()
                input.stringValue = saved[field.id] ?? field.defaultValue
                input.delegate = self
                var isNumber = false
                if case .number = field.kind { isNumber = true }
                input.widthAnchor.constraint(equalToConstant: isNumber ? 110 : 240).isActive = true
                controls[field.id] = input
                rows.append([label, input])
            case .choice(let options):
                let label = NSTextField(labelWithString: field.label + ":")
                label.alignment = .right
                let popup = NSPopUpButton(frame: .zero, pullsDown: false)
                popup.addItems(withTitles: options)
                if let value = saved[field.id], options.contains(value) { popup.selectItem(withTitle: value) }
                popup.target = self
                popup.action = #selector(controlChanged)
                controls[field.id] = popup
                rows.append([label, popup])
            }
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        formHolder.addArrangedSubview(grid)
    }

    private func currentFormValues() -> [String: String] {
        var values: [String: String] = [:]
        for field in currentTool.fields {
            guard let control = controls[field.id] else { continue }
            switch field.kind {
            case .toggle: values[field.id] = (control as? NSButton)?.state == .on ? "1" : "0"
            case .text, .number: values[field.id] = (control as? NSTextField)?.stringValue ?? field.defaultValue
            case .choice: values[field.id] = (control as? NSPopUpButton)?.titleOfSelectedItem ?? field.defaultValue
            }
        }
        return values
    }

    private func saveForm() {
        guard !isBuilding else { return }
        currentTool.saveEditableDefaults(currentFormValues())
        statusLabel.stringValue = "Saved."
    }

    @objc private func controlChanged() { saveForm() }

    func controlTextDidChange(_ obj: Notification) { saveForm() }

    func controlTextDidEndEditing(_ obj: Notification) {
        // Keep "How many" between 1 and the global maximum.
        if let field = obj.object as? NSTextField, field === controls["count"] {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            let value = Int(text) ?? 1
            field.stringValue = String(min(RandomGenerators.maxCount, max(1, value)))
        }
        saveForm()
    }

    @objc private func restoreToolDefaults() {
        currentTool.clearEditableDefaults()
        rebuildRandomForm()
        statusLabel.stringValue = "Built-in defaults restored for \(currentTool.title)."
    }

    @objc private func rememberChanged() {
        UserDefaults.standard.set(rememberBox.state == .on, forKey: "randomRemembersLast")
    }

    // MARK: - General tab

    @objc private func openFontsAndColors() {
        PreferencesWindowController.shared.show()
    }

    @objc private func resetEverything() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings to factory defaults?"
        alert.informativeText = "Font, colors, Insert menu choices, Voice settings and all Random Generator defaults will go back to how they were on first launch. Your documents are not affected."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        syncInsertTab()
        syncVoiceTab()
        rebuildRandomForm()
    }
}
