import Foundation

/// The bundled "Read Me" note (Resources/ReadMe.txt). Shown automatically when Calamus
/// starts with nothing else to open, and any time from Help > Read Me.
enum AppReadMe {
    static var text: String {
        if let url = Bundle.main.url(forResource: "ReadMe", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return contents
        }
        return fallback
    }

    private static let fallback = """
    Calamus
    A free, open-source text and code editor for macOS.

    This app costs nothing, has no subscription, and shows no ads.

    Support: support@abrahamcherian.in
    """
}
