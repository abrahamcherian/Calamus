import AppKit

/// Remembers the most recently active saved document (whichever tab was frontmost), so that on
/// a later launch — with no file passed in and no pinned tabs to reopen — Calamus can bring
/// that document back instead of always showing the Read Me note. The very first launch (and any
/// launch where the remembered file has since been moved or deleted) has nothing usable to
/// restore, so it still falls through to the Read Me note.
enum LastDocument {
    private static let defaultsKey = "lastActiveDocumentPath"

    /// Records the file behind the document that just became active. Ignored for documents with
    /// no file yet (a fresh Untitled tab, the bundled Read Me note), since there's nothing on disk
    /// to reopen for those.
    static func noteActive(url: URL?) {
        guard let url = url else { return }
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
    }

    /// Opens the remembered document, if its file still exists on disk. Called once at launch,
    /// after pinned tabs have had their chance. Fire-and-forget, like `PinnedTabs.reopenAtLaunch()`.
    /// Returns true if it asked to reopen a file.
    @discardableResult
    static func reopenAtLaunch() -> Bool {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey),
              FileManager.default.fileExists(atPath: path) else { return false }
        NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path),
                                                   display: true, completionHandler: { _, _, _ in })
        return true
    }
}
