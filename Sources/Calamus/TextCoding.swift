import Foundation

/// Encodings the editor can read and write.
enum TextEncodingChoice: Int, CaseIterable {
    case utf8, utf8BOM, utf16LE, utf16BE, windows1252, isoLatin1, macRoman

    var label: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 with BOM"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        case .windows1252: return "Windows-1252"
        case .isoLatin1: return "ISO-8859-1"
        case .macRoman: return "Mac Roman"
        }
    }

    /// Encodes text for saving. Returns nil if the text cannot be represented without loss.
    func encode(_ string: String) -> Data? {
        switch self {
        case .utf8:
            return string.data(using: .utf8)
        case .utf8BOM:
            guard let d = string.data(using: .utf8) else { return nil }
            return Data([0xEF, 0xBB, 0xBF]) + d
        case .utf16LE:
            guard let d = string.data(using: .utf16LittleEndian) else { return nil }
            return Data([0xFF, 0xFE]) + d
        case .utf16BE:
            guard let d = string.data(using: .utf16BigEndian) else { return nil }
            return Data([0xFE, 0xFF]) + d
        case .windows1252:
            return string.data(using: .windowsCP1252, allowLossyConversion: false)
        case .isoLatin1:
            return string.data(using: .isoLatin1, allowLossyConversion: false)
        case .macRoman:
            return string.data(using: .macOSRoman, allowLossyConversion: false)
        }
    }

    /// Detects the encoding of raw file data (BOMs first, then UTF-8, then legacy 8-bit fallbacks).
    static func decode(_ data: Data) -> (text: String, encoding: TextEncodingChoice) {
        let bytes = [UInt8](data.prefix(3))
        if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
            let body = data.dropFirst(3)
            return (String(decoding: body, as: UTF8.self), .utf8BOM)
        }
        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
            if let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) { return (s, .utf16LE) }
        }
        if bytes.count >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
            if let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) { return (s, .utf16BE) }
        }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }
        if let s = String(data: data, encoding: .windowsCP1252) { return (s, .windows1252) }
        // ISO-8859-1 maps every byte, so this never fails.
        return (String(data: data, encoding: .isoLatin1) ?? "", .isoLatin1)
    }
}

/// Line-ending styles (Windows CR LF, Unix LF, Old Mac CR).
enum LineEnding: Int, CaseIterable {
    case lf, crlf, cr

    var string: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    var label: String {
        switch self {
        case .lf: return "Unix (LF)"
        case .crlf: return "Windows (CRLF)"
        case .cr: return "Classic Mac (CR)"
        }
    }

    var shortLabel: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }

    /// Returns the dominant line ending in the text (LF when there are none).
    static func detect(_ text: String) -> LineEnding {
        var lf = 0, crlf = 0, cr = 0
        let bytes = Array(text.utf8)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 13 {
                if i + 1 < bytes.count && bytes[i + 1] == 10 { crlf += 1; i += 1 } else { cr += 1 }
            } else if b == 10 {
                lf += 1
            }
            i += 1
        }
        if crlf > lf && crlf >= cr { return .crlf }
        if cr > lf && cr > crlf { return .cr }
        return .lf
    }

    /// Converts every line ending in `text` to `target`.
    static func convert(_ text: String, to target: LineEnding) -> String {
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        if target != .lf { s = s.replacingOccurrences(of: "\n", with: target.string) }
        return s
    }
}
