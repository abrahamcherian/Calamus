import AppKit

/// HTML escaping and unescaping of text.
enum HTMLCoding {
    enum Mode: Int {
        case escape = 0          // only & < >
        case escapeQuotes = 1    // & < > and both kinds of quote
        case unescape = 2
    }

    static let menuItems: [(title: String, mode: Mode)] = [
        ("HTML Escape  ( & < > )", .escape),
        ("HTML Escape, also quotes  ( & < > \" ' )", .escapeQuotes),
        ("HTML Unescape", .unescape)
    ]

    /// The submenu used in the Edit menu and the right-click menu.
    static func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "HTML Escape / Unescape")
        for (index, entry) in menuItems.enumerated() {
            let item = NSMenuItem(title: entry.title, action: #selector(EditorViewController.htmlCoding(_:)), keyEquivalent: "")
            item.tag = entry.mode.rawValue
            menu.addItem(item)
            if index == 1 { menu.addItem(.separator()) }
        }
        return menu
    }

    static func convert(_ text: String, mode: Mode) -> String {
        switch mode {
        case .escape: return escape(text, quotes: false)
        case .escapeQuotes: return escape(text, quotes: true)
        case .unescape: return unescape(text)
        }
    }

    /// Replaces & < > (and, if asked, " and ') by their entities. "&" goes first so nothing is escaped twice.
    static func escape(_ text: String, quotes: Bool) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"" where quotes: result += "&quot;"
            case "'" where quotes: result += "&#39;"
            default: result.append(ch)
            }
        }
        return result
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}", "hellip": "\u{2026}",
        "mdash": "\u{2014}", "ndash": "\u{2013}", "lsquo": "\u{2018}", "rsquo": "\u{2019}",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "sbquo": "\u{201A}", "bdquo": "\u{201E}",
        "bull": "\u{2022}", "middot": "\u{00B7}", "laquo": "\u{00AB}", "raquo": "\u{00BB}",
        "euro": "\u{20AC}", "pound": "\u{00A3}", "yen": "\u{00A5}", "cent": "\u{00A2}",
        "sect": "\u{00A7}", "para": "\u{00B6}", "deg": "\u{00B0}", "plusmn": "\u{00B1}",
        "times": "\u{00D7}", "divide": "\u{00F7}", "frac12": "\u{00BD}", "frac14": "\u{00BC}",
        "frac34": "\u{00BE}", "larr": "\u{2190}", "rarr": "\u{2192}", "uarr": "\u{2191}", "darr": "\u{2193}",
        "hearts": "\u{2665}", "iexcl": "\u{00A1}", "iquest": "\u{00BF}", "micro": "\u{00B5}",
        "Aacute": "\u{00C1}", "aacute": "\u{00E1}", "Agrave": "\u{00C0}", "agrave": "\u{00E0}",
        "Acirc": "\u{00C2}", "acirc": "\u{00E2}", "Auml": "\u{00C4}", "auml": "\u{00E4}",
        "Aring": "\u{00C5}", "aring": "\u{00E5}", "AElig": "\u{00C6}", "aelig": "\u{00E6}",
        "Ccedil": "\u{00C7}", "ccedil": "\u{00E7}", "Eacute": "\u{00C9}", "eacute": "\u{00E9}",
        "Egrave": "\u{00C8}", "egrave": "\u{00E8}", "Ecirc": "\u{00CA}", "ecirc": "\u{00EA}",
        "Euml": "\u{00CB}", "euml": "\u{00EB}", "Iacute": "\u{00CD}", "iacute": "\u{00ED}",
        "Icirc": "\u{00CE}", "icirc": "\u{00EE}", "Iuml": "\u{00CF}", "iuml": "\u{00EF}",
        "Ntilde": "\u{00D1}", "ntilde": "\u{00F1}", "Oacute": "\u{00D3}", "oacute": "\u{00F3}",
        "Ocirc": "\u{00D4}", "ocirc": "\u{00F4}", "Ouml": "\u{00D6}", "ouml": "\u{00F6}",
        "Oslash": "\u{00D8}", "oslash": "\u{00F8}", "Uacute": "\u{00DA}", "uacute": "\u{00FA}",
        "Ucirc": "\u{00DB}", "ucirc": "\u{00FB}", "Uuml": "\u{00DC}", "uuml": "\u{00FC}",
        "szlig": "\u{00DF}", "yacute": "\u{00FD}", "yuml": "\u{00FF}"
    ]

    /// Turns &amp; &lt; &gt; &quot; &#39; &#x1F600; and other common entities back into characters.
    /// Entities are converted in one pass, so `&amp;lt;` becomes `&lt;` (not `<`). Unknown ones are left alone.
    static func unescape(_ text: String) -> String {
        guard text.contains("&"), let regex = try? NSRegularExpression(pattern: "&(#[0-9]{1,7}|#[xX][0-9A-Fa-f]{1,6}|[A-Za-z][A-Za-z0-9]{1,31});") else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let body = ns.substring(with: match.range(at: 1))
            var replacement: String?
            if body.hasPrefix("#") {
                let digits = body.dropFirst()
                let value: UInt32?
                if digits.hasPrefix("x") || digits.hasPrefix("X") {
                    value = UInt32(digits.dropFirst(), radix: 16)
                } else {
                    value = UInt32(digits, radix: 10)
                }
                if let value = value, let scalar = Unicode.Scalar(value) { replacement = String(Character(scalar)) }
            } else {
                replacement = named[body]
            }
            result += replacement ?? ns.substring(with: match.range)
            last = NSMaxRange(match.range)
        }
        result += ns.substring(from: last)
        return result
    }
}
