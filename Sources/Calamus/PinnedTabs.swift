import AppKit

/// Tracks which tabs are pinned, by file path, and persists the set across launches.
/// A pinned tab's file reopens automatically the next time Calamus starts, and its tab
/// is decorated with a pin so it's easy to spot. Only saved files can be pinned (there's
/// nothing on disk to reopen for an unsaved "Untitled" tab).
final class PinnedTabs {
    static let shared = PinnedTabs()

    private let defaultsKey = "pinnedTabPaths"
    private var paths: Set<String>

    private init() {
        paths = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    private func save() {
        UserDefaults.standard.set(Array(paths), forKey: defaultsKey)
    }

    func isPinned(_ url: URL?) -> Bool {
        guard let path = url?.path else { return false }
        return paths.contains(path)
    }

    func isPinned(_ window: NSWindow) -> Bool {
        isPinned(editorWindowController(for: window)?.editor?.doc?.fileURL)
    }

    /// Flips the pin state of the tab showing in `window`. Does nothing for an unsaved document.
    func togglePin(for window: NSWindow) {
        setPinned(!isPinned(window), for: window)
    }

    func setPinned(_ pinned: Bool, for window: NSWindow) {
        guard let editor = editorWindowController(for: window)?.editor, let url = editor.doc?.fileURL else { return }
        if pinned { paths.insert(url.path) } else { paths.remove(url.path) }
        save()
        editor.refreshTabTitle()
    }

    /// Opens every pinned file that still exists on disk. Called once at launch.
    /// Returns true if it reopened at least one file. Pins whose file has vanished are dropped.
    @discardableResult
    func reopenAtLaunch() -> Bool {
        let fm = FileManager.default
        let stillThere = paths.filter { fm.fileExists(atPath: $0) }
        if stillThere.count != paths.count {
            paths = stillThere
            save()
        }
        for path in stillThere.sorted() {
            NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path),
                                                       display: true, completionHandler: { _, _, _ in })
        }
        return !stillThere.isEmpty
    }

    private func editorWindowController(for window: NSWindow) -> EditorWindowController? {
        window.windowController as? EditorWindowController
    }
}
