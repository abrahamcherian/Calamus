import AppKit

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension NSColor {
    var srgbComponents: (r: CGFloat, g: CGFloat, b: CGFloat) {
        guard let c = usingColorSpace(.sRGB) else { return (1, 1, 1) }
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }

    /// Perceived brightness from 0 (black) to 1 (white).
    var luminance: CGFloat {
        let c = srgbComponents
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    var hexValue: UInt32 {
        let c = srgbComponents
        return (UInt32((c.r * 255).rounded()) << 16) | (UInt32((c.g * 255).rounded()) << 8) | UInt32((c.b * 255).rounded())
    }
}

struct Theme {
    let name: String
    let isDark: Bool
    let background: NSColor
    let foreground: NSColor
    let selection: NSColor
    let currentLine: NSColor
    let gutterBackground: NSColor
    let gutterForeground: NSColor
    let tokens: [TokenKind: NSColor]

    func color(for kind: TokenKind) -> NSColor { tokens[kind] ?? foreground }

    static let light = Theme(
        name: "Light", isDark: false,
        background: NSColor(hex: 0xFFFFFF), foreground: NSColor(hex: 0x1F2328),
        selection: NSColor(hex: 0xB3D7FF), currentLine: NSColor(hex: 0xF2F5FA),
        gutterBackground: NSColor(hex: 0xF5F5F5), gutterForeground: NSColor(hex: 0x8A8F98),
        tokens: [
            .comment: NSColor(hex: 0x6A737D), .string: NSColor(hex: 0xC41A16), .number: NSColor(hex: 0x1C00CF),
            .keyword: NSColor(hex: 0xAD3DA4), .type: NSColor(hex: 0x3E8087), .tag: NSColor(hex: 0x0B4F79),
            .attribute: NSColor(hex: 0x836C28), .heading: NSColor(hex: 0x0B4F79), .special: NSColor(hex: 0x78492A)
        ])

    static let dark = Theme(
        name: "Dark", isDark: true,
        background: NSColor(hex: 0x1E1E1E), foreground: NSColor(hex: 0xD4D4D4),
        selection: NSColor(hex: 0x264F78), currentLine: NSColor(hex: 0x2A2D2E),
        gutterBackground: NSColor(hex: 0x252526), gutterForeground: NSColor(hex: 0x858585),
        tokens: [
            .comment: NSColor(hex: 0x6A9955), .string: NSColor(hex: 0xCE9178), .number: NSColor(hex: 0xB5CEA8),
            .keyword: NSColor(hex: 0xC586C0), .type: NSColor(hex: 0x4EC9B0), .tag: NSColor(hex: 0x569CD6),
            .attribute: NSColor(hex: 0x9CDCFE), .heading: NSColor(hex: 0x569CD6), .special: NSColor(hex: 0xDCDCAA)
        ])

    static let monokai = Theme(
        name: "Monokai", isDark: true,
        background: NSColor(hex: 0x272822), foreground: NSColor(hex: 0xF8F8F2),
        selection: NSColor(hex: 0x49483E), currentLine: NSColor(hex: 0x3E3D32),
        gutterBackground: NSColor(hex: 0x2D2E27), gutterForeground: NSColor(hex: 0x90908A),
        tokens: [
            .comment: NSColor(hex: 0x75715E), .string: NSColor(hex: 0xE6DB74), .number: NSColor(hex: 0xAE81FF),
            .keyword: NSColor(hex: 0xF92672), .type: NSColor(hex: 0x66D9EF), .tag: NSColor(hex: 0xF92672),
            .attribute: NSColor(hex: 0xA6E22E), .heading: NSColor(hex: 0xA6E22E), .special: NSColor(hex: 0xFD971F)
        ])

    static let solarizedLight = Theme(
        name: "Solarized Light", isDark: false,
        background: NSColor(hex: 0xFDF6E3), foreground: NSColor(hex: 0x586E75),
        selection: NSColor(hex: 0xD5DDD0), currentLine: NSColor(hex: 0xEEE8D5),
        gutterBackground: NSColor(hex: 0xEEE8D5), gutterForeground: NSColor(hex: 0x93A1A1),
        tokens: [
            .comment: NSColor(hex: 0x93A1A1), .string: NSColor(hex: 0x2AA198), .number: NSColor(hex: 0xD33682),
            .keyword: NSColor(hex: 0x859900), .type: NSColor(hex: 0xB58900), .tag: NSColor(hex: 0x268BD2),
            .attribute: NSColor(hex: 0xCB4B16), .heading: NSColor(hex: 0x268BD2), .special: NSColor(hex: 0xCB4B16)
        ])

    static let dracula = Theme(
        name: "Dracula", isDark: true,
        background: NSColor(hex: 0x282A36), foreground: NSColor(hex: 0xF8F8F2),
        selection: NSColor(hex: 0x44475A), currentLine: NSColor(hex: 0x323543),
        gutterBackground: NSColor(hex: 0x2B2D3A), gutterForeground: NSColor(hex: 0x6272A4),
        tokens: [
            .comment: NSColor(hex: 0x6272A4), .string: NSColor(hex: 0xF1FA8C), .number: NSColor(hex: 0xBD93F9),
            .keyword: NSColor(hex: 0xFF79C6), .type: NSColor(hex: 0x8BE9FD), .tag: NSColor(hex: 0xFF79C6),
            .attribute: NSColor(hex: 0x50FA7B), .heading: NSColor(hex: 0xBD93F9), .special: NSColor(hex: 0xFFB86C)
        ])

    static let nord = Theme(
        name: "Nord", isDark: true,
        background: NSColor(hex: 0x2E3440), foreground: NSColor(hex: 0xD8DEE9),
        selection: NSColor(hex: 0x434C5E), currentLine: NSColor(hex: 0x3B4252),
        gutterBackground: NSColor(hex: 0x2B303B), gutterForeground: NSColor(hex: 0x616E88),
        tokens: [
            .comment: NSColor(hex: 0x616E88), .string: NSColor(hex: 0xA3BE8C), .number: NSColor(hex: 0xB48EAD),
            .keyword: NSColor(hex: 0x81A1C1), .type: NSColor(hex: 0x8FBCBB), .tag: NSColor(hex: 0x81A1C1),
            .attribute: NSColor(hex: 0xD08770), .heading: NSColor(hex: 0x88C0D0), .special: NSColor(hex: 0xEBCB8B)
        ])

    static let sepia = Theme(
        name: "Sepia", isDark: false,
        background: NSColor(hex: 0xF4ECD8), foreground: NSColor(hex: 0x5B4636),
        selection: NSColor(hex: 0xE0D2B0), currentLine: NSColor(hex: 0xEBE1C8),
        gutterBackground: NSColor(hex: 0xEBE1C8), gutterForeground: NSColor(hex: 0xA39480),
        tokens: [
            .comment: NSColor(hex: 0x9C8B73), .string: NSColor(hex: 0x8A5A2B), .number: NSColor(hex: 0xB4552D),
            .keyword: NSColor(hex: 0x9C4A1A), .type: NSColor(hex: 0x4F7A5A), .tag: NSColor(hex: 0x7A4E2D),
            .attribute: NSColor(hex: 0x6B6B2E), .heading: NSColor(hex: 0x7A4E2D), .special: NSColor(hex: 0x8B5E3C)
        ])

    static let all: [Theme] = [light, dark, monokai, solarizedLight, dracula, nord, sepia]

    /// Applies the user's own background and/or text color on top of this theme. When the chosen
    /// background is much lighter or darker than the theme, the matching light/dark syntax palette
    /// is used so code stays readable.
    func customized(background: NSColor?, foreground: NSColor?) -> Theme {
        guard background != nil || foreground != nil else { return self }
        let bg = background ?? self.background
        let bgIsDark = bg.luminance < 0.5
        let base: Theme = (bgIsDark == isDark) ? self : (bgIsDark ? Theme.dark : Theme.light)
        let fg = foreground ?? base.foreground
        let toward: NSColor = bgIsDark ? .white : .black
        let accent = NSColor(hex: 0x3B82F6)
        return Theme(
            name: name, isDark: bgIsDark,
            background: bg,
            foreground: fg,
            selection: bg.blended(withFraction: bgIsDark ? 0.30 : 0.25, of: accent) ?? base.selection,
            currentLine: bg.blended(withFraction: 0.07, of: toward) ?? base.currentLine,
            gutterBackground: bg.blended(withFraction: 0.05, of: toward) ?? base.gutterBackground,
            gutterForeground: fg.blended(withFraction: 0.45, of: bg) ?? base.gutterForeground,
            tokens: base.tokens)
    }

    static func named(_ name: String) -> Theme? { all.first { $0.name == name } }
}

extension Notification.Name {
    static let preferencesChanged = Notification.Name("CalamusPreferencesChanged")
}

/// User-visible settings, stored in UserDefaults. Every change notifies all open editors.
final class Preferences {
    static let shared = Preferences()
    static let autoThemeName = "Auto"

    // Factory defaults for a fresh install (before the user changes anything).
    static let defaultFontFamily = "JetBrains Mono"
    static let defaultFontSize = 18.0
    static let defaultThemeName = "Dark"
    /// How see-through the editor background is, in percent (0 = solid, higher lets the desktop show through).
    static let defaultWindowTransparency = 5
    /// The same for the text area itself (the writing background), in percent.
    static let defaultTextTransparency = 5
    /// Licorice (the macOS crayon, pure black) background and CC9933 (gold/brown) text.
    static let defaultBackgroundHex: UInt32 = 0x000000
    static let defaultForegroundHex: UInt32 = 0xCC9933
    /// NSSpeechSynthesizer's own default speaking rate is close to this, in words per minute.
    static let defaultReadAloudRate = 180.0

    private let defaults = UserDefaults.standard

    private init() {
        // Transparency starts from its defaults at every launch unless "keep" is ticked in Preferences.
        if !defaults.bool(forKey: "keepTransparencyAcrossLaunches") {
            defaults.removeObject(forKey: "windowBackgroundTransparency")
            defaults.removeObject(forKey: "textBackgroundTransparency")
        }
        defaults.register(defaults: [
            "wordWrap": false,
            "showLineNumbers": true,
            "showInvisibles": false,
            "highlightCurrentLine": true,
            "fontSize": Preferences.defaultFontSize,
            "fontFamily": Preferences.defaultFontFamily,
            "menuUsesEditorFont": true,
            "journalMode": false,
            "journalIdleMinutes": 30,
            "windowBackgroundTransparency": Preferences.defaultWindowTransparency,
            "textBackgroundTransparency": Preferences.defaultTextTransparency,
            "themeName": Preferences.defaultThemeName,
            "tabWidth": 4,
            "insertLineWidth": 80,
            "uuidFormat": "lower",
            "voiceRecognitionLocale": "",
            "voiceRequiresOnDeviceRecognition": true,
            "readAloudVoiceIdentifier": "",
            "readAloudRate": Preferences.defaultReadAloudRate
        ])
    }

    private func changed() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }

    var wordWrap: Bool {
        get { defaults.bool(forKey: "wordWrap") }
        set { defaults.set(newValue, forKey: "wordWrap"); changed() }
    }

    var showLineNumbers: Bool {
        get { defaults.bool(forKey: "showLineNumbers") }
        set { defaults.set(newValue, forKey: "showLineNumbers"); changed() }
    }

    var showInvisibles: Bool {
        get { defaults.bool(forKey: "showInvisibles") }
        set { defaults.set(newValue, forKey: "showInvisibles"); changed() }
    }

    var highlightCurrentLine: Bool {
        get { defaults.bool(forKey: "highlightCurrentLine") }
        set { defaults.set(newValue, forKey: "highlightCurrentLine"); changed() }
    }

    var fontSize: Double {
        get { defaults.double(forKey: "fontSize") }
        set { defaults.set(min(72, max(6, newValue)), forKey: "fontSize"); changed() }
    }

    /// Whether the app's menus use the editor font (true) or the normal system font (false).
    var menuUsesEditorFont: Bool {
        get { defaults.bool(forKey: "menuUsesEditorFont") }
        set { defaults.set(newValue, forKey: "menuUsesEditorFont"); changed() }
    }

    /// Window background (gutter, status bar, window) transparency in percent, 0 (solid) ... 90.
    var windowTransparency: Int {
        get { min(90, max(0, defaults.integer(forKey: "windowBackgroundTransparency"))) }
        set { defaults.set(min(90, max(0, newValue)), forKey: "windowBackgroundTransparency"); changed() }
    }

    /// Text area background transparency in percent, 0 (solid) ... 90.
    var textTransparency: Int {
        get { min(90, max(0, defaults.integer(forKey: "textBackgroundTransparency"))) }
        set { defaults.set(min(90, max(0, newValue)), forKey: "textBackgroundTransparency"); changed() }
    }

    var textOpacity: Int { 100 - textTransparency }

    /// The matching opacity in percent (100 - transparency).
    var windowOpacity: Int { 100 - windowTransparency }

    /// When true, the transparency sliders keep their values between launches; otherwise both start at the defaults.
    var keepTransparencyAcrossLaunches: Bool {
        get { defaults.bool(forKey: "keepTransparencyAcrossLaunches") }
        set { defaults.set(newValue, forKey: "keepTransparencyAcrossLaunches") }
    }

    /// Journal mode: in plain text, typing after a pause first adds a dated banner at the end of the file.
    var journalMode: Bool {
        get { defaults.bool(forKey: "journalMode") }
        set { defaults.set(newValue, forKey: "journalMode"); changed() }
    }

    /// Minutes without typing after which the next typing starts a new journal entry (0 = only when the file is opened).
    var journalIdleMinutes: Int {
        get { max(0, defaults.integer(forKey: "journalIdleMinutes")) }
        set { defaults.set(max(0, newValue), forKey: "journalIdleMinutes") }
    }

    var themeName: String {
        get { defaults.string(forKey: "themeName") ?? Preferences.autoThemeName }
        set { defaults.set(newValue, forKey: "themeName"); changed() }
    }

    /// Width (in characters) of lines and banners made by the Insert menu.
    var insertLineWidth: Int {
        get { max(10, defaults.integer(forKey: "insertLineWidth")) }
        set { defaults.set(newValue, forKey: "insertLineWidth") }
    }

    /// How inserted UUIDs are written: "lower", "upper", "compact" (no dashes) or "braces".
    var uuidFormat: String {
        get { defaults.string(forKey: "uuidFormat") ?? "lower" }
        set { defaults.set(newValue, forKey: "uuidFormat") }
    }

    // MARK: - Voice to Text & Read Aloud (Preferences > Voice)

    /// Recognition language for Voice to Text, as a BCP-47 locale identifier (e.g. "en-US"), or
    /// "" to follow whatever language macOS is currently set to.
    var voiceRecognitionLocale: String {
        get { defaults.string(forKey: "voiceRecognitionLocale") ?? "" }
        set { defaults.set(newValue, forKey: "voiceRecognitionLocale") }
    }

    /// When true, dictation stays on-device when the chosen language supports it - more private
    /// and works offline, but Apple's on-device models cover fewer languages/accents than its
    /// server-based recognizer, which this turns off in favor of.
    var voiceRequiresOnDeviceRecognition: Bool {
        get { defaults.bool(forKey: "voiceRequiresOnDeviceRecognition") }
        set { defaults.set(newValue, forKey: "voiceRequiresOnDeviceRecognition") }
    }

    /// The voice for Read Aloud, stored as a plain string (NSSpeechSynthesizer.VoiceName's
    /// .rawValue) since NSSpeechSynthesizer.VoiceName itself isn't a plain String on this SDK
    /// and isn't a type UserDefaults can store directly. "" means whatever voice is set as the
    /// system default. Rewrap with NSSpeechSynthesizer.VoiceName(rawValue:) before handing it
    /// to NSSpeechSynthesizer/NSSpeechSynthesizer.attributes(forVoice:).
    var readAloudVoiceIdentifier: String {
        get { defaults.string(forKey: "readAloudVoiceIdentifier") ?? "" }
        set { defaults.set(newValue, forKey: "readAloudVoiceIdentifier") }
    }

    /// Read Aloud speaking rate, in words per minute.
    var readAloudRate: Double {
        get { defaults.double(forKey: "readAloudRate") }
        set { defaults.set(min(400, max(80, newValue)), forKey: "readAloudRate") }
    }

    var tabWidth: Int {
        get { max(1, defaults.integer(forKey: "tabWidth")) }
        set { defaults.set(newValue, forKey: "tabWidth"); changed() }
    }

    /// Whether the user has accepted the liability disclaimer shown once at first launch (see
    /// LegalDisclaimer.confirmAccepted()). Defaults to false (unset keys read as false), which is
    /// exactly what a fresh install or a factory reset should do - show the disclaimer again.
    var disclaimerAccepted: Bool {
        get { defaults.bool(forKey: "disclaimerAccepted") }
        set { defaults.set(newValue, forKey: "disclaimerAccepted") }
    }

    static let systemMonospacedName = "System Monospaced"

    /// Adopts a font chosen in the system Fonts panel (family and point size).
    func adopt(font: NSFont) {
        defaults.set(font.familyName ?? Preferences.systemMonospacedName, forKey: "fontFamily")
        defaults.set(min(72, max(6, Double(font.pointSize))), forKey: "fontSize")
        changed()
    }

    var fontFamily: String {
        get { defaults.string(forKey: "fontFamily") ?? Preferences.systemMonospacedName }
        set { defaults.set(newValue, forKey: "fontFamily"); changed() }
    }

    var editorFont: NSFont {
        let size = CGFloat(fontSize)
        if fontFamily != Preferences.systemMonospacedName,
           let font = NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Optional user overrides layered over the selected theme (nil = use the theme's color).
    var customBackground: NSColor? {
        get { color(forKey: "customBackground") }
        set { setColor(newValue, forKey: "customBackground") }
    }

    var customForeground: NSColor? {
        get { color(forKey: "customForeground") }
        set { setColor(newValue, forKey: "customForeground") }
    }

    private func color(forKey key: String) -> NSColor? {
        if let value = defaults.object(forKey: key) as? Int {
            return value >= 0 ? NSColor(hex: UInt32(value)) : nil
        }
        // Nothing saved: use the factory colors until the user changes or resets colors.
        if defaults.bool(forKey: "colorsTouched") { return nil }
        return NSColor(hex: key == "customBackground" ? Preferences.defaultBackgroundHex : Preferences.defaultForegroundHex)
    }

    private func setColor(_ color: NSColor?, forKey key: String) {
        defaults.set(true, forKey: "colorsTouched")
        if let color = color {
            defaults.set(Int(color.hexValue), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        changed()
    }

    func resetColors() {
        defaults.set(true, forKey: "colorsTouched")
        defaults.removeObject(forKey: "customBackground")
        defaults.removeObject(forKey: "customForeground")
        changed()
    }

    func resolvedTheme(darkAppearance: Bool) -> Theme {
        let base: Theme
        if themeName == Preferences.autoThemeName {
            base = darkAppearance ? .dark : .light
        } else {
            base = Theme.named(themeName) ?? .light
        }
        return base.customized(background: customBackground, foreground: customForeground)
    }

    /// The theme currently in effect, using the app's appearance for "Automatic".
    func currentTheme() -> Theme {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return resolvedTheme(darkAppearance: dark)
    }
}
