import Foundation

/// A single text replacement plus the selection to restore afterwards.
struct TextEdit {
    var range: NSRange
    var replacement: String
    var selection: NSRange
}

/// Line-level editing operations. Pure functions over NSString so they are easy to test.
enum LineOps {
    private static func isNewline(_ c: unichar) -> Bool { c == 10 || c == 13 }

    private static func has(_ s: String, _ needle: String) -> Bool {
        (s as NSString).range(of: needle).location != NSNotFound
    }

    private static func endsWithNewline(_ s: String) -> Bool {
        let ns = s as NSString
        return ns.length > 0 && isNewline(ns.character(at: ns.length - 1))
    }

    /// The document's dominant line terminator, used when a new one has to be created.
    static func documentEOL(_ ns: NSString) -> String {
        if ns.range(of: "\r\n").location != NSNotFound { return "\r\n" }
        if ns.range(of: "\n").location != NSNotFound { return "\n" }
        if ns.range(of: "\r").location != NSNotFound { return "\r" }
        return "\n"
    }

    /// Range of whole lines touched by the selection (a selection that ends right after a newline
    /// does not pull in the following line).
    static func coveredLines(_ ns: NSString, _ sel: NSRange) -> NSRange {
        var end = NSMaxRange(sel)
        if sel.length > 0 && end <= ns.length && isNewline(ns.character(at: end - 1)) { end -= 1 }
        let probe = NSRange(location: min(sel.location, ns.length), length: max(0, end - sel.location))
        return ns.lineRange(for: probe)
    }

    /// Splits a block of text into lines (without terminators).
    private static func split(_ block: String, fallbackEOL: String) -> (lines: [String], eol: String, trailing: Bool) {
        let eol: String
        if has(block, "\r\n") { eol = "\r\n" }
        else if has(block, "\n") { eol = "\n" }
        else if has(block, "\r") { eol = "\r" }
        else { eol = fallbackEOL }
        var lines: [String] = []
        let ns = block as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byLines, .substringNotRequired]) { _, subRange, _, _ in
            lines.append(ns.substring(with: subRange))
        }
        return (lines, eol, endsWithNewline(block))
    }

    /// Removes a trailing terminator and returns the body plus the terminator that was removed.
    private static func stripTerminator(_ s: String) -> (body: String, terminator: String) {
        let ns = s as NSString
        var len = ns.length
        guard len > 0, isNewline(ns.character(at: len - 1)) else { return (s, "") }
        len -= 1
        if len > 0 && ns.character(at: len) == 10 && ns.character(at: len - 1) == 13 { len -= 1 }
        return (ns.substring(to: len), ns.substring(from: len))
    }

    // MARK: - Line transforms

    /// Applies `transform` to the covered lines (or the whole document when nothing is selected and
    /// `wholeIfEmpty` is true).
    private static func transformLines(_ ns: NSString, _ sel: NSRange, wholeIfEmpty: Bool,
                                       transform: ([String]) -> [String]) -> TextEdit? {
        let lr = (wholeIfEmpty && sel.length == 0) ? NSRange(location: 0, length: ns.length) : coveredLines(ns, sel)
        guard lr.length > 0 else { return nil }
        let block = ns.substring(with: lr)
        let parts = split(block, fallbackEOL: documentEOL(ns))
        let newLines = transform(parts.lines)
        let rep = newLines.joined(separator: parts.eol) + (parts.trailing ? parts.eol : "")
        if rep == block { return nil }
        let repLen = (rep as NSString).length
        let selection: NSRange
        if sel.length == 0 {
            let delta = repLen - lr.length
            let loc = max(lr.location, min(sel.location + delta, lr.location + repLen))
            selection = NSRange(location: loc, length: 0)
        } else {
            selection = NSRange(location: lr.location, length: repLen)
        }
        return TextEdit(range: lr, replacement: rep, selection: selection)
    }

    static func sortLines(_ ns: NSString, _ sel: NSRange, ascending: Bool, ignoreCase: Bool) -> TextEdit? {
        transformLines(ns, sel, wholeIfEmpty: true) { lines in
            let opts: NSString.CompareOptions = ignoreCase ? [.caseInsensitive] : []
            return lines.sorted { a, b in
                let r = a.compare(b, options: opts)
                return ascending ? r == .orderedAscending : r == .orderedDescending
            }
        }
    }

    static func removeDuplicateLines(_ ns: NSString, _ sel: NSRange) -> TextEdit? {
        transformLines(ns, sel, wholeIfEmpty: true) { lines in
            var seen = Set<String>()
            var out: [String] = []
            for l in lines where seen.insert(l).inserted { out.append(l) }
            return out
        }
    }

    /// Comments or uncomments the covered lines (the cursor's line when nothing is selected). If every
    /// non-blank line is already commented the comments are removed, otherwise all lines get one.
    /// `suffix` closes the comment on each line for languages that need it (HTML "-->", CSS "*/").
    static func toggleComment(_ ns: NSString, _ sel: NSRange, prefix: String, suffix: String = "") -> TextEdit? {
        transformLines(ns, sel, wholeIfEmpty: false) { lines in
            func isCommented(_ line: String) -> Bool {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix(prefix) && (suffix.isEmpty || (trimmed.hasSuffix(suffix) && trimmed.count >= prefix.count + suffix.count))
            }
            let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let allCommented = !nonBlank.isEmpty && nonBlank.allSatisfy(isCommented)
            return lines.map { line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                let indentCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                let idx = line.index(line.startIndex, offsetBy: indentCount)
                let indent = String(line[..<idx])
                var rest = String(line[idx...])
                if allCommented {
                    rest.removeFirst(prefix.count)
                    if rest.hasPrefix(" ") { rest.removeFirst() }
                    if !suffix.isEmpty {
                        while let last = rest.last, last == " " || last == "\t" { rest.removeLast() }
                        rest.removeLast(suffix.count)
                        if rest.hasSuffix(" ") { rest.removeLast() }
                    }
                    return indent + rest
                }
                return indent + prefix + " " + rest + (suffix.isEmpty ? "" : " " + suffix)
            }
        }
    }

    /// Wraps the selection in block comment delimiters, or removes them when the selection is already a
    /// block comment (or sits directly inside one). With nothing selected the cursor's line is used.
    static func toggleBlockComment(_ ns: NSString, _ sel: NSRange, open: String, close: String) -> TextEdit? {
        func isSpace(_ c: unichar) -> Bool {
            guard let scalar = Unicode.Scalar(c) else { return false }
            return CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        var start = sel.location
        var end = NSMaxRange(sel)
        if sel.length == 0 {
            let lr = ns.lineRange(for: sel)
            start = lr.location
            end = NSMaxRange(lr)
        }
        // Ignore blank space at both ends so the delimiters hug the text.
        while start < end && isSpace(ns.character(at: start)) { start += 1 }
        while end > start && isSpace(ns.character(at: end - 1)) { end -= 1 }
        guard end > start else { return nil }
        let range = NSRange(location: start, length: end - start)
        let text = ns.substring(with: range)
        let textLength = (text as NSString).length

        // The selection is itself a block comment: /* text */
        if textLength >= open.count + close.count, text.hasPrefix(open), text.hasSuffix(close) {
            var inner = String(text.dropFirst(open.count).dropLast(close.count))
            if inner.hasPrefix(" ") { inner.removeFirst() }
            if inner.hasSuffix(" ") { inner.removeLast() }
            let length = (inner as NSString).length
            return TextEdit(range: range, replacement: inner, selection: NSRange(location: range.location, length: length))
        }

        // The selection sits directly inside a block comment: /* [text] */
        var openEnd = range.location
        while openEnd > 0 && isSpace(ns.character(at: openEnd - 1)) { openEnd -= 1 }
        var closeStart = NSMaxRange(range)
        while closeStart < ns.length && isSpace(ns.character(at: closeStart)) { closeStart += 1 }
        let openLength = (open as NSString).length
        let closeLength = (close as NSString).length
        if openEnd >= openLength, closeStart + closeLength <= ns.length,
           ns.substring(with: NSRange(location: openEnd - openLength, length: openLength)) == open,
           ns.substring(with: NSRange(location: closeStart, length: closeLength)) == close {
            let whole = NSRange(location: openEnd - openLength, length: NSMaxRange(NSRange(location: closeStart, length: closeLength)) - (openEnd - openLength))
            return TextEdit(range: whole, replacement: text, selection: NSRange(location: whole.location, length: textLength))
        }

        // Otherwise comment it out.
        let wrapped = open + " " + text + " " + close
        return TextEdit(range: range, replacement: wrapped,
                        selection: NSRange(location: range.location, length: (wrapped as NSString).length))
    }

    static func indent(_ ns: NSString, _ sel: NSRange, unit: String = "    ") -> TextEdit? {
        transformLines(ns, sel, wholeIfEmpty: false) { lines in
            lines.map { $0.isEmpty ? $0 : unit + $0 }
        }
    }

    static func unindent(_ ns: NSString, _ sel: NSRange, width: Int = 4) -> TextEdit? {
        transformLines(ns, sel, wholeIfEmpty: false) { lines in
            lines.map { line in
                if line.hasPrefix("\t") { return String(line.dropFirst()) }
                var removed = 0
                var result = Substring(line)
                while removed < width, result.first == " " {
                    result = result.dropFirst()
                    removed += 1
                }
                return String(result)
            }
        }
    }

    // MARK: - Structural operations

    static func duplicateLines(_ ns: NSString, _ sel: NSRange) -> TextEdit {
        let lr = coveredLines(ns, sel)
        let block = ns.substring(with: lr)
        let rep = endsWithNewline(block) ? block : documentEOL(ns) + block
        let shift = (rep as NSString).length
        return TextEdit(range: NSRange(location: NSMaxRange(lr), length: 0),
                        replacement: rep,
                        selection: NSRange(location: sel.location + shift, length: sel.length))
    }

    static func deleteLines(_ ns: NSString, _ sel: NSRange) -> TextEdit {
        var lr = coveredLines(ns, sel)
        // Deleting the last line (no trailing newline) also removes the newline before it.
        if NSMaxRange(lr) == ns.length, lr.location > 0, !endsWithNewline(ns.substring(with: lr)) {
            var back = 1
            if lr.location > 1 && ns.character(at: lr.location - 1) == 10 && ns.character(at: lr.location - 2) == 13 { back = 2 }
            lr = NSRange(location: lr.location - back, length: lr.length + back)
        }
        return TextEdit(range: lr, replacement: "", selection: NSRange(location: lr.location, length: 0))
    }

    static func moveLinesUp(_ ns: NSString, _ sel: NSRange) -> TextEdit? {
        let lr = coveredLines(ns, sel)
        guard lr.location > 0 else { return nil }
        let prev = ns.lineRange(for: NSRange(location: lr.location - 1, length: 0))
        let a = stripTerminator(ns.substring(with: prev))
        let b = stripTerminator(ns.substring(with: lr))
        let rep = b.body + a.terminator + a.body + b.terminator
        return TextEdit(range: NSUnionRange(prev, lr),
                        replacement: rep,
                        selection: NSRange(location: sel.location - prev.length, length: sel.length))
    }

    static func moveLinesDown(_ ns: NSString, _ sel: NSRange) -> TextEdit? {
        let lr = coveredLines(ns, sel)
        guard NSMaxRange(lr) < ns.length else { return nil }
        let next = ns.lineRange(for: NSRange(location: NSMaxRange(lr), length: 0))
        let b = stripTerminator(ns.substring(with: lr))
        let c = stripTerminator(ns.substring(with: next))
        let rep = c.body + b.terminator + b.body + c.terminator
        let shift = (c.body as NSString).length + (b.terminator as NSString).length
        return TextEdit(range: NSUnionRange(lr, next),
                        replacement: rep,
                        selection: NSRange(location: sel.location + shift, length: sel.length))
    }

    static func joinLines(_ ns: NSString, _ sel: NSRange) -> TextEdit? {
        var lr = coveredLines(ns, sel)
        var parts = split(ns.substring(with: lr), fallbackEOL: documentEOL(ns))
        if parts.lines.count < 2 {
            guard NSMaxRange(lr) < ns.length else { return nil }
            let next = ns.lineRange(for: NSRange(location: NSMaxRange(lr), length: 0))
            lr = NSUnionRange(lr, next)
            parts = split(ns.substring(with: lr), fallbackEOL: documentEOL(ns))
        }
        guard let first = parts.lines.first else { return nil }
        var firstBody = first
        while firstBody.hasSuffix(" ") || firstBody.hasSuffix("\t") { firstBody.removeLast() }
        let rest = parts.lines.dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let joined = ([firstBody] + rest).joined(separator: " ")
        let rep = joined + (parts.trailing ? parts.eol : "")
        return TextEdit(range: lr, replacement: rep,
                        selection: NSRange(location: lr.location + (firstBody as NSString).length, length: 0))
    }

    static func trimTrailingWhitespace(_ ns: NSString, _ sel: NSRange) -> TextEdit? {
        guard let regex = try? NSRegularExpression(pattern: "[ \\t]+$", options: [.anchorsMatchLines]) else { return nil }
        let full = NSRange(location: 0, length: ns.length)
        let original = ns as String
        let result = regex.stringByReplacingMatches(in: original, options: [], range: full, withTemplate: "")
        if result == original { return nil }
        let newLen = (result as NSString).length
        let loc = min(sel.location, newLen)
        return TextEdit(range: full, replacement: result, selection: NSRange(location: loc, length: 0))
    }

    static func changeCase(_ ns: NSString, _ sel: NSRange, upper: Bool) -> TextEdit? {
        guard sel.length > 0 else { return nil }
        let s = ns.substring(with: sel)
        let r = upper ? s.uppercased() : s.lowercased()
        return TextEdit(range: sel, replacement: r,
                        selection: NSRange(location: sel.location, length: (r as NSString).length))
    }
}
