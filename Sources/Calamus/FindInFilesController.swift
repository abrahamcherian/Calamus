import AppKit

struct FileMatch {
    let url: URL
    let line: Int
    let column: Int
    let preview: String
    let range: NSRange
}

/// "Find in Files": searches a folder (optionally recursive) and lists every hit.
final class FindInFilesController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = FindInFilesController()

    private let findField = NSTextField()
    private let filterField = NSTextField()
    private let directoryField = NSTextField()
    private let matchCaseBox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    private let wholeWordBox = NSButton(checkboxWithTitle: "Whole word", target: nil, action: nil)
    private let regexBox = NSButton(checkboxWithTitle: "Regular expression", target: nil, action: nil)
    private let subfoldersBox = NSButton(checkboxWithTitle: "In all subfolders", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()

    private var results: [FileMatch] = []
    private var rootPath = ""
    private var searchToken = 0

    private init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "Find in Files"
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 560, height: 360)
        super.init(window: panel)
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private func buildUI(in panel: NSPanel) {
        findField.placeholderString = "Text to find"
        findField.target = self
        findField.action = #selector(search)
        filterField.stringValue = "*"
        filterField.placeholderString = "e.g. *.swift; *.md"
        directoryField.placeholderString = "Folder to search"
        subfoldersBox.state = .on

        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseDirectory))
        chooseButton.bezelStyle = .rounded
        directoryField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let directoryRow = NSStackView(views: [label("In folder:"), directoryField, chooseButton])
        directoryRow.orientation = .horizontal
        directoryRow.spacing = 8

        let findRow = row("Find what:", findField)
        let filterRow = row("Filters:", filterField)

        let options = NSStackView(views: [matchCaseBox, wholeWordBox, regexBox, subfoldersBox])
        options.orientation = .horizontal
        options.spacing = 14

        let searchButton = NSButton(title: "Find All", target: self, action: #selector(search))
        searchButton.bezelStyle = .rounded
        searchButton.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [searchButton, statusLabel])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)

        for (id, title, width) in [("file", "File", 300.0), ("line", "Line", 60.0), ("text", "Text", 400.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = CGFloat(width)
            column.minWidth = 40
            tableView.addTableColumn(column)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelected)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        let stack = NSStackView(views: [findRow, filterRow, directoryRow, options, buttonRow, scroll])
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
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            findRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            filterRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            directoryRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func label(_ title: String) -> NSTextField {
        let l = NSTextField(labelWithString: title)
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 80).isActive = true
        l.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return l
    }

    private func row(_ title: String, _ field: NSTextField) -> NSStackView {
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let r = NSStackView(views: [label(title), field])
        r.orientation = .horizontal
        r.spacing = 8
        return r
    }

    // MARK: - Showing

    func show() {
        if let editor = EditorContext.current {
            let sel = editor.textView.selectedRange()
            if sel.length > 0 && sel.length < 200 {
                let text = (editor.textView.string as NSString).substring(with: sel)
                if !text.contains("\n") { findField.stringValue = text }
            }
        }
        if directoryField.stringValue.isEmpty {
            let folder = EditorContext.current?.doc?.fileURL?.deletingLastPathComponent().path
                ?? NSHomeDirectory()
            directoryField.stringValue = folder
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findField)
    }

    @objc private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url { self?.directoryField.stringValue = url.path }
        }
    }

    // MARK: - Searching

    @objc private func search() {
        let query = findField.stringValue
        guard !query.isEmpty else {
            statusLabel.stringValue = "Enter the text to find."
            return
        }
        let expanded = (directoryField.stringValue as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            statusLabel.stringValue = "Choose an existing folder."
            return
        }
        let options = FindOptions(matchCase: matchCaseBox.state == .on,
                                  wholeWord: wholeWordBox.state == .on,
                                  useRegex: regexBox.state == .on)
        let regex: NSRegularExpression
        do {
            regex = try FindEngine.makeRegex(query, options)
        } catch {
            statusLabel.stringValue = "Invalid regular expression."
            return
        }

        let filters = filterField.stringValue
            .split(whereSeparator: { $0 == ";" || $0 == "," || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "*" && $0 != "*.*" }
            .map { NSPredicate(format: "SELF LIKE[c] %@", $0) }
        let recursive = subfoldersBox.state == .on
        let root = URL(fileURLWithPath: expanded)

        searchToken += 1
        let token = searchToken
        results = []
        rootPath = root.path
        tableView.reloadData()
        statusLabel.stringValue = "Searching…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var found: [FileMatch] = []
            var filesSearched = 0
            var truncated = false

            let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
            var enumOptions: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            if !recursive { enumOptions.insert(.skipsSubdirectoryDescendants) }
            let skipDirectories: Set<String> = ["node_modules", "build", "DerivedData", "Pods"]

            if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: enumOptions) {
                for case let url as URL in enumerator {
                    if self?.searchToken != token { return }
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    if values?.isDirectory == true {
                        if skipDirectories.contains(url.lastPathComponent) { enumerator.skipDescendants() }
                        continue
                    }
                    guard values?.isRegularFile == true else { continue }
                    if let size = values?.fileSize, size > 20_000_000 { continue }
                    let name = url.lastPathComponent
                    if !filters.isEmpty && !filters.contains(where: { $0.evaluate(with: name) }) { continue }
                    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
                    if data.prefix(8000).contains(0) { continue } // binary file
                    filesSearched += 1

                    let text = TextEncodingChoice.decode(data).text
                    let ns = text as NSString
                    let index = LineIndex()
                    index.rebuild(ns)
                    regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, stop in
                        guard let m = match, m.range.length > 0 else { return }
                        let line = index.lineNumber(at: m.range.location)
                        let lineStart = index.lineStart(ofLine: line)
                        let lineRange = ns.lineRange(for: NSRange(location: m.range.location, length: 0))
                        var preview = ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                        if preview.count > 200 { preview = String(preview.prefix(200)) + "…" }
                        found.append(FileMatch(url: url, line: line, column: m.range.location - lineStart + 1,
                                               preview: preview, range: m.range))
                        if found.count >= 10_000 {
                            truncated = true
                            stop.pointee = true
                        }
                    }
                    if truncated { break }
                }
            }

            DispatchQueue.main.async {
                guard let self = self, self.searchToken == token else { return }
                self.results = found
                self.tableView.reloadData()
                let files = Set(found.map { $0.url }).count
                var message = "\(found.count) match\(found.count == 1 ? "" : "es") in \(files) file\(files == 1 ? "" : "s") (\(filesSearched) searched)"
                if truncated { message += " — showing the first 10,000" }
                self.statusLabel.stringValue = message
            }
        }
    }

    // MARK: - Results table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard results.indices.contains(row) else { return nil }
        let match = results[row]
        switch tableColumn?.identifier.rawValue {
        case "file":
            let prefix = rootPath + "/"
            return match.url.path.hasPrefix(prefix) ? String(match.url.path.dropFirst(prefix.count)) : match.url.path
        case "line": return "\(match.line):\(match.column)"
        case "text": return match.preview
        default: return nil
        }
    }

    @objc private func openSelected() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard results.indices.contains(row) else { return }
        let match = results[row]
        NSDocumentController.shared.openDocument(withContentsOf: match.url, display: true) { document, _, error in
            if let error = error {
                NSApp.presentError(error)
                return
            }
            guard let doc = document as? TextDocument else { return }
            DispatchQueue.main.async { doc.editor?.reveal(range: match.range) }
        }
    }
}
