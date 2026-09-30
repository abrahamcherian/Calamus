import AppKit

/// Opens the Terminal app that comes with macOS, in the folder you are working in, and can run the
/// file you are editing there.
enum TerminalLauncher {
    private static let terminalApp = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")

    /// Folder of the current file, or your home folder when the file isn't saved yet.
    static func currentFolder() -> URL {
        EditorContext.current?.doc?.fileURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// Opens a new Terminal window in the given folder.
    static func open(in folder: URL) {
        NSWorkspace.shared.open([folder], withApplicationAt: terminalApp,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                DispatchQueue.main.async { NSApp.presentError(error) }
            }
        }
    }

    /// Lets you pick any folder and opens Terminal there.
    static func openInChosenFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Terminal"
        panel.message = "Choose the folder to open in Terminal"
        panel.directoryURL = currentFolder()
        if panel.runModal() == .OK, let folder = panel.url { open(in: folder) }
    }

    // MARK: - Run the current file

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// The shell command that runs a file of the given language, or nil if we don't know how.
    private static func command(for languageName: String, file: URL) -> String? {
        let path = shellQuote(file.path)
        let ext = file.pathExtension.lowercased()
        switch languageName {
        case "Python": return "python3 \(path)"
        case "Shell": return "bash \(path)"
        case "Swift": return "swift \(path)"
        case "Go": return "go run \(path)"
        case "Java": return "java \(path)"
        case "JavaScript / TypeScript":
            return ["js", "mjs", "cjs"].contains(ext) ? "node \(path)" : nil
        case "C / C++ / Obj-C":
            let out = "\"${TMPDIR:-/tmp}/calamus_run\""
            if ext == "c" { return "cc \(path) -o \(out) && \(out)" }
            if ["cpp", "cc", "cxx"].contains(ext) { return "c++ \(path) -o \(out) && \(out)" }
            return nil
        default:
            return nil
        }
    }

    private static func message(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Runs the file in the frontmost editor tab inside a Terminal window.
    static func runCurrentFile() {
        guard let editor = EditorContext.current, let doc = editor.doc, let url = doc.fileURL else {
            message("Save the file first", "Save this file, then choose Run Current File in Terminal.")
            return
        }
        guard let command = command(for: editor.language.name, file: url) else {
            message("Can't run this file",
                    "Calamus doesn't know how to run \(editor.language.name) files (\(url.lastPathComponent)). "
                    + "It can run Python, Shell, Swift, Go, Java, JavaScript (.js) and C/C++ files.")
            return
        }

        if doc.isDocumentEdited {
            let alert = NSAlert()
            alert.messageText = "Save \(url.lastPathComponent) before running?"
            alert.informativeText = "The file has changes that aren't saved yet."
            alert.addButton(withTitle: "Save and Run")
            alert.addButton(withTitle: "Run Saved Version")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                doc.save(to: url, ofType: doc.fileType ?? "public.plain-text", for: .saveOperation) { error in
                    if let error = error {
                        NSApp.presentError(error)
                    } else {
                        launch(command: command, in: url.deletingLastPathComponent())
                    }
                }
            case .alertSecondButtonReturn:
                launch(command: command, in: url.deletingLastPathComponent())
            default:
                break
            }
            return
        }
        launch(command: command, in: url.deletingLastPathComponent())
    }

    /// Writes a small .command script and opens it with Terminal, which runs it in a new window.
    private static func launch(command: String, in folder: URL) {
        let lines = [
            "#!/bin/zsh",
            "cd \(shellQuote(folder.path)) || exit 1",
            "clear",
            command,
            "status=$?",
            "echo",
            "echo \"[Finished with exit status $status - press Return to close]\"",
            "read -r REPLY",
            "exit $status"
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CalamusRun", isDirectory: true)
        let file = directory.appendingPathComponent("run-\(UUID().uuidString.prefix(8)).command")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        } catch {
            NSApp.presentError(error)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: terminalApp,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                DispatchQueue.main.async { NSApp.presentError(error) }
            }
        }
    }
}
