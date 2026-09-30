import AppKit

/// Keeps the Insert menu's titles showing the current time each time the menu opens.
final class TimeMenuUpdater: NSObject, NSMenuDelegate {
    static let shared = TimeMenuUpdater()

    func menuNeedsUpdate(_ menu: NSMenu) {
        let now = Date()
        for item in menu.items {
            guard let id = item.representedObject as? String else { continue }
            if id == "header.local" {
                item.title = "Local time (\(TimeFormats.localZoneDescription(for: now)))"
            } else if id == "header.utc" {
                item.title = "UTC time"
            } else if let format = TimeFormats.format(withID: id) {
                item.title = "\(format.string(for: now))   ·   \(format.label)"
            }
        }
    }
}

/// Builds the "insert the current time" menu used by the menu bar and the right-click menu.
enum TimeMenu {
    /// Tag marking items that come from the right-click menu (they insert where you clicked).
    static let contextTag = 7

    static func makeMenu(title: String = "Insert Date/Time", shortcuts: Bool, contextual: Bool) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.delegate = TimeMenuUpdater.shared
        menu.autoenablesItems = true

        let shortcutDigits = shortcuts ? TimeFormats.shortcutDigits() : [:]

        func header(_ id: String, _ text: String) -> NSMenuItem {
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.representedObject = id
            item.isEnabled = false
            return item
        }

        func entry(_ format: TimeFormat) -> NSMenuItem {
            let item = NSMenuItem(title: format.label, action: #selector(EditorViewController.insertTime(_:)), keyEquivalent: "")
            item.representedObject = format.id
            if contextual { item.tag = TimeMenu.contextTag }
            if shortcuts, let digit = shortcutDigits[format.id] {
                item.keyEquivalent = digit
                item.keyEquivalentModifierMask = [.command, .option]
            }
            return item
        }

        menu.addItem(header("header.local", "Local time"))
        for format in TimeFormats.local { menu.addItem(entry(format)) }
        menu.addItem(.separator())
        menu.addItem(header("header.utc", "UTC time"))
        for format in TimeFormats.utc { menu.addItem(entry(format)) }

        TimeMenuUpdater.shared.menuNeedsUpdate(menu)
        return menu
    }
}
