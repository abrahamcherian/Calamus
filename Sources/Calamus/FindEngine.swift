import Foundation

struct FindOptions {
    var matchCase = false
    var wholeWord = false
    var useRegex = false
    var extended = false      // interpret \n \r \t \0 \\ \xHH in normal mode
    var dotMatchesNewline = false
    var wrap = true
}

enum FindError: Error {
    case invalidPattern(String)
}

/// Builds regular expressions for Normal / Extended / Regular-expression search modes.
enum FindEngine {
    static func makeRegex(_ query: String, _ o: FindOptions) throws -> NSRegularExpression {
        var pattern: String
        if o.useRegex {
            pattern = query
        } else {
            let q = o.extended ? expandExtended(query) : query
            pattern = NSRegularExpression.escapedPattern(for: q)
        }
        if o.wholeWord {
            pattern = "(?<![\\w])(?:" + pattern + ")(?![\\w])"
        }
        var opts: NSRegularExpression.Options = [.anchorsMatchLines]
        if !o.matchCase { opts.insert(.caseInsensitive) }
        if o.useRegex && o.dotMatchesNewline { opts.insert(.dotMatchesLineSeparators) }
        do {
            return try NSRegularExpression(pattern: pattern, options: opts)
        } catch {
            throw FindError.invalidPattern(error.localizedDescription)
        }
    }

    /// Template for NSRegularExpression replacement (`$1` groups only work in regex mode).
    static func replacementTemplate(_ replacement: String, _ o: FindOptions) -> String {
        if o.useRegex {
            return expandRegexTemplate(replacement)
        }
        let r = o.extended ? expandExtended(replacement) : replacement
        return NSRegularExpression.escapedTemplate(for: r)
    }

    static func expandExtended(_ s: String) -> String {
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\" && i + 1 < chars.count {
                let n = chars[i + 1]
                switch n {
                case "n": out.append("\n"); i += 2; continue
                case "r": out.append("\r"); i += 2; continue
                case "t": out.append("\t"); i += 2; continue
                case "0": out.append("\0"); i += 2; continue
                case "\\": out.append("\\"); i += 2; continue
                case "x":
                    if i + 3 < chars.count,
                       let v = UInt32(String(chars[i + 2...i + 3]), radix: 16),
                       let scalar = Unicode.Scalar(v) {
                        out.unicodeScalars.append(scalar)
                        i += 4
                        continue
                    }
                default: break
                }
            }
            out.append(c)
            i += 1
        }
        return out
    }

    /// In regex mode allow \n, \r and \t in the replacement text; leave `\\`, `\$` and `$1` alone.
    private static func expandRegexTemplate(_ s: String) -> String {
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\" && i + 1 < chars.count {
                let n = chars[i + 1]
                switch n {
                case "n": out.append("\n"); i += 2; continue
                case "r": out.append("\r"); i += 2; continue
                case "t": out.append("\t"); i += 2; continue
                default:
                    out.append(c)
                    out.append(n)
                    i += 2
                    continue
                }
            }
            out.append(c)
            i += 1
        }
        return out
    }
}
