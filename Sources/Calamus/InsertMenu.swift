import AppKit

/// Builds the menu-bar "Insert" menu: date and time, horizontal lines, UUIDs, lorem ipsum, file info,
/// comment banners and special characters.
enum InsertMenuBuilder {
    private static func parentItem(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func snippetItem(_ title: String, id: String, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(EditorViewController.insertSnippet(_:)), keyEquivalent: key)
        item.representedObject = id
        if !key.isEmpty { item.keyEquivalentModifierMask = [.command, .option] }
        return item
    }

    static func makeInsertMenu() -> NSMenu {
        let menu = NSMenu(title: "Insert")
        menu.addItem(parentItem("Date and Time", TimeMenu.makeMenu(title: "Date and Time", shortcuts: true, contextual: false)))
        menu.addItem(.separator())
        menu.addItem(parentItem("Horizontal Line", makeLineMenu()))
        menu.addItem(parentItem("UUID", makeUUIDMenu()))
        menu.addItem(parentItem("Random Generator", makeRandomMenu()))
        menu.addItem(parentItem("Lorem Ipsum", makeLoremMenu()))
        menu.addItem(parentItem("File Info", makeFileInfoMenu()))
        menu.addItem(.separator())
        let banner = NSMenuItem(title: "Comment Banner…", action: #selector(EditorViewController.insertCommentBanner(_:)), keyEquivalent: "b")
        banner.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(banner)
        menu.addItem(parentItem("Special Characters", makeSpecialMenu()))
        return menu
    }

    // MARK: - Submenus

    private static func makeLineMenu() -> NSMenu {
        let menu = NSMenu(title: "Horizontal Line")
        for style in InsertSnippets.lineStyles {
            let sample = String(repeating: style.character, count: 12)
            let key = style.id == "line.dash" ? "l" : ""
            menu.addItem(snippetItem("\(sample)   \(style.label)", id: style.id, key: key))
        }
        menu.addItem(.separator())
        menu.addItem(snippetItem("---   Markdown rule", id: "line.markdown"))
        menu.addItem(.separator())

        let widths = NSMenu(title: "Line Width")
        for width in InsertSnippets.lineWidths {
            let item = NSMenuItem(title: "\(width) characters", action: #selector(AppDelegate.setInsertLineWidth(_:)), keyEquivalent: "")
            item.tag = width
            widths.addItem(item)
        }
        menu.addItem(parentItem("Line Width", widths))
        return menu
    }

    private static func makeRandomMenu() -> NSMenu {
        let menu = NSMenu(title: "Random Generator")
        for tool in RandomTool.allCases {
            let item = NSMenuItem(title: tool.title + "\u{2026}", action: #selector(EditorViewController.showRandomGenerator(_:)), keyEquivalent: "")
            item.representedObject = tool.rawValue
            item.toolTip = tool.summary
            menu.addItem(item)
        }
        return menu
    }

    private static func makeUUIDMenu() -> NSMenu {
        let menu = NSMenu(title: "UUID")
        menu.addItem(snippetItem("Version 4 \u{2013} random", id: "uuid.v4", key: "u"))
        menu.addItem(snippetItem("Version 7 \u{2013} time-ordered (Unix time + random)", id: "uuid.v7"))
        menu.addItem(snippetItem("Version 1 \u{2013} time and node", id: "uuid.v1"))
        menu.addItem(snippetItem("Version 6 \u{2013} time-ordered (reordered version 1)", id: "uuid.v6"))
        menu.addItem(snippetItem("Version 8 \u{2013} custom (random bits)", id: "uuid.v8"))
        menu.addItem(.separator())
        for (version, label) in [(3, "Version 3 \u{2013} name-based (MD5)\u{2026}"), (5, "Version 5 \u{2013} name-based (SHA-1)\u{2026}")] {
            let item = NSMenuItem(title: label, action: #selector(EditorViewController.insertNameBasedUUID(_:)), keyEquivalent: "")
            item.representedObject = version
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(snippetItem("Nil UUID (all zeros)", id: "uuid.nil"))
        menu.addItem(snippetItem("Max UUID (all F)", id: "uuid.max"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Generate Multiple\u{2026}",
                                 action: #selector(EditorViewController.insertMultipleUUIDs(_:)), keyEquivalent: ""))
        menu.addItem(.separator())

        let formats = NSMenu(title: "Format")
        let options: [(String, String)] = [("lower", "lowercase"), ("upper", "UPPERCASE"),
                                           ("compact", "Without dashes"), ("braces", "In braces { }")]
        for (id, label) in options {
            let item = NSMenuItem(title: label, action: #selector(AppDelegate.setUUIDFormat(_:)), keyEquivalent: "")
            item.representedObject = id
            formats.addItem(item)
        }
        menu.addItem(parentItem("Format", formats))
        return menu
    }

    private static func makeLoremMenu() -> NSMenu {
        let menu = NSMenu(title: "Lorem Ipsum")
        menu.addItem(snippetItem("10 words", id: "lorem.words"))
        menu.addItem(snippetItem("1 sentence", id: "lorem.sentence"))
        menu.addItem(.separator())
        menu.addItem(snippetItem("1 paragraph", id: "lorem.p1"))
        menu.addItem(snippetItem("3 paragraphs", id: "lorem.p3"))
        menu.addItem(snippetItem("5 paragraphs", id: "lorem.p5"))
        return menu
    }

    private static func makeFileInfoMenu() -> NSMenu {
        let menu = NSMenu(title: "File Info")
        menu.addItem(snippetItem("File name", id: "file.name"))
        menu.addItem(snippetItem("File name without extension", id: "file.basename"))
        menu.addItem(snippetItem("Full path", id: "file.path"))
        menu.addItem(snippetItem("Folder path", id: "file.folder"))
        return menu
    }

    /// Shows invisible characters (tab, non-breaking and zero-width space) as visible symbols in the menu.
    private static func displayGlyph(for text: String) -> String {
        switch text {
        case "\t": return "\u{21E5}"
        case "\u{00A0}", "\u{200B}": return "\u{2423}"
        default: return text
        }
    }

    private static func makeSpecialMenu() -> NSMenu {
        let menu = NSMenu(title: "Special Characters")
        for group in InsertSnippets.specialGroups {
            let submenu = NSMenu(title: group.title)
            for entry in group.items {
                let shown = displayGlyph(for: entry.text)
                let item = NSMenuItem(title: "\(shown)   \(entry.name)",
                                      action: #selector(EditorViewController.insertSpecialCharacter(_:)), keyEquivalent: "")
                item.representedObject = entry.text
                submenu.addItem(item)
            }
            menu.addItem(parentItem(group.title, submenu))
        }
        return menu
    }
}
