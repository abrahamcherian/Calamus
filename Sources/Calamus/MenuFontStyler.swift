import AppKit

/// Shows the app's menu items in the editor font (JetBrains Mono by default) when
/// "Use the editor font in menus" is on, and in the normal macOS system font when it is off.
/// (macOS always draws the menu-bar titles themselves and the shortcut symbols in the system font.)
final class MenuFontStyler: NSObject, NSMenuDelegate {
    static let shared = MenuFontStyler()
    static let menuFontSize: CGFloat = 13

    private var observing = false

    /// Call once after `NSApp.mainMenu` has been built.
    func install() {
        guard let main = NSApp.mainMenu else { return }
        attach(main)
        if !observing {
            observing = true
            NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange),
                                                   name: .preferencesChanged, object: nil)
        }
        refresh()
    }

    @objc private func preferencesDidChange() { refresh() }

    func refresh() {
        guard let main = NSApp.mainMenu else { return }
        apply(to: main, recursive: true)
    }

    private func attach(_ menu: NSMenu) {
        menu.delegate = self
        for item in menu.items {
            if let sub = item.submenu { attach(sub) }
        }
    }

    private var menuFont: NSFont? {
        guard Preferences.shared.menuUsesEditorFont else { return nil }
        let family = Preferences.shared.fontFamily
        let size = MenuFontStyler.menuFontSize
        if family != Preferences.systemMonospacedName,
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func apply(to menu: NSMenu, recursive: Bool) {
        let font = menuFont
        for item in menu.items {
            if !item.isSeparatorItem {
                if let font = font {
                    item.attributedTitle = NSAttributedString(string: item.title, attributes: [.font: font])
                } else if item.attributedTitle != nil {
                    let title = item.title
                    item.attributedTitle = nil
                    item.title = title
                }
            }
            if recursive, let sub = item.submenu { apply(to: sub, recursive: true) }
        }
    }

    // Titles that change (for example a toggled item or the window list) are restyled as each menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        apply(to: menu, recursive: false)
    }
}
