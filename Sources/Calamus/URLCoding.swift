import AppKit

/// URL (percent) encoding and decoding of text.
enum URLCoding {
    enum Mode: Int {
        case encodeAll = 0       // like JavaScript encodeURIComponent: everything but letters, digits and - _ . ~
        case encodeKeepURL = 1   // like encodeURI: also keeps : / ? # [ ] @ ! $ & ' ( ) * + , ; = and existing %XX
        case decode = 2
        case decodePlusAsSpace = 3   // form data: "+" means a space
    }

    private static let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    private static let urlCharacters = unreserved + ":/?#[]@!$&'()*+,;=%"

    static let menuItems: [(title: String, mode: Mode)] = [
        ("URL Encode (all special characters)", .encodeAll),
        ("URL Encode (keep : / ? & = # in a URL)", .encodeKeepURL),
        ("URL Decode", .decode),
        ("URL Decode (+ becomes a space)", .decodePlusAsSpace)
    ]

    /// The submenu used in the Edit menu and the right-click menu.
    static func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "URL Encode / Decode")
        for (index, entry) in menuItems.enumerated() {
            let item = NSMenuItem(title: entry.title, action: #selector(EditorViewController.urlCoding(_:)), keyEquivalent: "")
            item.tag = entry.mode.rawValue
            menu.addItem(item)
            if index == 1 { menu.addItem(.separator()) }
        }
        return menu
    }

    /// Converts `text` line by line (line breaks are kept as they are). Returns nil when a decode would not
    /// produce valid text.
    static func convert(_ text: String, mode: Mode) -> String? {
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            switch mode {
            case .encodeAll:
                lines.append(line.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: unreserved)) ?? line)
            case .encodeKeepURL:
                lines.append(line.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: urlCharacters)) ?? line)
            case .decode, .decodePlusAsSpace:
                guard let decoded = decode(line, plusAsSpace: mode == .decodePlusAsSpace) else { return nil }
                lines.append(decoded)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Decodes %XX sequences (UTF-8). A "%" that is not followed by two hex digits is kept as it is.
    static func decode(_ text: String, plusAsSpace: Bool) -> String? {
        var bytes: [UInt8] = []
        let input = Array(text.utf8)
        func hexValue(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 0x30...0x39: return byte - 0x30
            case 0x41...0x46: return byte - 0x41 + 10
            case 0x61...0x66: return byte - 0x61 + 10
            default: return nil
            }
        }
        var i = 0
        while i < input.count {
            let byte = input[i]
            if byte == 0x25, i + 2 < input.count, let high = hexValue(input[i + 1]), let low = hexValue(input[i + 2]) {
                bytes.append(high * 16 + low)
                i += 3
            } else if byte == 0x2B && plusAsSpace {
                bytes.append(0x20)
                i += 1
            } else {
                bytes.append(byte)
                i += 1
            }
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}
