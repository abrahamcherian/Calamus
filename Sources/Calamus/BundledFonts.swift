import AppKit
import CoreText

/// The free, open-source coding fonts that ship inside the app (Resources/Fonts).
/// They are registered for this app only; nothing is installed on the Mac.
enum BundledFonts {
    /// Family names as they appear in the font picker.
    static let families = ["Cascadia Code", "DejaVu Sans Mono", "Fira Code", "JetBrains Mono", "Source Code Pro"]

    /// Call once at launch, before any font is looked up.
    static func register() {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// The bundled families that actually loaded.
    static var available: [String] {
        let installed = Set(NSFontManager.shared.availableFontFamilies)
        return families.filter { installed.contains($0) }
    }
}
