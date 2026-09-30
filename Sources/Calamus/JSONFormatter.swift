import Foundation

/// A small strict JSON parser/printer. It keeps the original key order and the exact text of numbers
/// and strings (unlike JSONSerialization, which reorders keys and rewrites numbers), and reports
/// the position of the first error.
enum JSONFormatter {
    enum Node {
        case object([(key: String, value: Node)])
        case array([Node])
        case scalar(String) // raw text: a quoted string, a number, true, false or null
    }

    struct ParseError: Error {
        let message: String
        let offset: Int // UTF-16 offset into the parsed text
    }

    struct Stats {
        var objects = 0
        var arrays = 0
        var values = 0
        var maxDepth = 0
    }

    // MARK: - Public API

    static func parse(_ text: String) throws -> Node {
        var parser = Parser(units: Array(text.utf16))
        return try parser.parseDocument()
    }

    static func pretty(_ node: Node, indent: String, sortKeys: Bool) -> String {
        var out = ""
        write(node, indent: indent, sortKeys: sortKeys, level: 0, into: &out)
        return out
    }

    static func minified(_ node: Node) -> String {
        switch node {
        case .scalar(let raw):
            return raw
        case .array(let items):
            return "[" + items.map { minified($0) }.joined(separator: ",") + "]"
        case .object(let members):
            return "{" + members.map { $0.key + ":" + minified($0.value) }.joined(separator: ",") + "}"
        }
    }

    static func stats(_ node: Node) -> Stats {
        var s = Stats()
        collect(node, depth: 1, &s)
        return s
    }

    /// 1-based line and column of a UTF-16 offset.
    static func lineAndColumn(of offset: Int, in text: String) -> (line: Int, column: Int) {
        let ns = text as NSString
        let end = min(max(0, offset), ns.length)
        var line = 1
        var lineStart = 0
        var idx = 0
        while idx < end {
            let c = ns.character(at: idx)
            if c == 10 {
                line += 1
                lineStart = idx + 1
            } else if c == 13 && !(idx + 1 < ns.length && ns.character(at: idx + 1) == 10) {
                line += 1
                lineStart = idx + 1
            }
            idx += 1
        }
        return (line, end - lineStart + 1)
    }

    // MARK: - Printing

    private static func write(_ node: Node, indent: String, sortKeys: Bool, level: Int, into out: inout String) {
        switch node {
        case .scalar(let raw):
            out += raw
        case .array(let items):
            if items.isEmpty {
                out += "[]"
                return
            }
            let inner = String(repeating: indent, count: level + 1)
            out += "[\n"
            for (n, item) in items.enumerated() {
                out += inner
                write(item, indent: indent, sortKeys: sortKeys, level: level + 1, into: &out)
                out += n < items.count - 1 ? ",\n" : "\n"
            }
            out += String(repeating: indent, count: level) + "]"
        case .object(let members):
            if members.isEmpty {
                out += "{}"
                return
            }
            let ordered = sortKeys ? members.sorted { $0.key < $1.key } : members
            let inner = String(repeating: indent, count: level + 1)
            out += "{\n"
            for (n, member) in ordered.enumerated() {
                out += inner + member.key + ": "
                write(member.value, indent: indent, sortKeys: sortKeys, level: level + 1, into: &out)
                out += n < ordered.count - 1 ? ",\n" : "\n"
            }
            out += String(repeating: indent, count: level) + "}"
        }
    }

    private static func collect(_ node: Node, depth: Int, _ s: inout Stats) {
        s.maxDepth = max(s.maxDepth, depth)
        switch node {
        case .scalar:
            s.values += 1
        case .array(let items):
            s.arrays += 1
            for item in items { collect(item, depth: depth + 1, &s) }
        case .object(let members):
            s.objects += 1
            for member in members { collect(member.value, depth: depth + 1, &s) }
        }
    }

    // MARK: - Parsing

    private struct Parser {
        let units: [UInt16]
        var i = 0

        init(units: [UInt16]) {
            self.units = units
        }

        func fail(_ message: String, at offset: Int? = nil) -> ParseError {
            ParseError(message: message, offset: offset ?? i)
        }

        func isDigit(_ c: UInt16) -> Bool { c >= 0x30 && c <= 0x39 }

        func isHex(_ c: UInt16) -> Bool {
            (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66)
        }

        mutating func skipWhitespace() {
            while i < units.count {
                let c = units[i]
                if c == 32 || c == 9 || c == 10 || c == 13 { i += 1 } else { break }
            }
        }

        mutating func parseDocument() throws -> Node {
            if i < units.count && units[i] == 0xFEFF { i += 1 } // byte-order mark
            skipWhitespace()
            let node = try parseValue(depth: 0)
            skipWhitespace()
            if i < units.count { throw fail("Unexpected content after the end of the JSON value") }
            return node
        }

        mutating func parseValue(depth: Int) throws -> Node {
            guard depth < 512 else { throw fail("The JSON is nested too deeply") }
            skipWhitespace()
            guard i < units.count else { throw fail("Unexpected end of JSON") }
            let c = units[i]
            switch c {
            case 0x7B: return try parseObject(depth: depth)
            case 0x5B: return try parseArray(depth: depth)
            case 0x22: return .scalar(try parseString())
            case 0x2D, 0x30...0x39: return .scalar(try parseNumber())
            case 0x74: return .scalar(try parseLiteral("true"))
            case 0x66: return .scalar(try parseLiteral("false"))
            case 0x6E: return .scalar(try parseLiteral("null"))
            default:
                let shown = String(decoding: [c], as: UTF16.self)
                throw fail("Unexpected character '\(shown)'")
            }
        }

        mutating func parseObject(depth: Int) throws -> Node {
            i += 1 // {
            var members: [(key: String, value: Node)] = []
            skipWhitespace()
            if i < units.count && units[i] == 0x7D {
                i += 1
                return .object(members)
            }
            while true {
                skipWhitespace()
                guard i < units.count else { throw fail("Unexpected end of JSON inside an object") }
                guard units[i] == 0x22 else { throw fail("Expected a property name in double quotes (is there a trailing comma?)") }
                let key = try parseString()
                skipWhitespace()
                guard i < units.count, units[i] == 0x3A else { throw fail("Expected ':' after the property name") }
                i += 1
                let value = try parseValue(depth: depth + 1)
                members.append((key: key, value: value))
                skipWhitespace()
                guard i < units.count else { throw fail("Unexpected end of JSON inside an object") }
                if units[i] == 0x2C {
                    i += 1
                    continue
                }
                if units[i] == 0x7D {
                    i += 1
                    return .object(members)
                }
                throw fail("Expected ',' or '}' after the property value")
            }
        }

        mutating func parseArray(depth: Int) throws -> Node {
            i += 1 // [
            var items: [Node] = []
            skipWhitespace()
            if i < units.count && units[i] == 0x5D {
                i += 1
                return .array(items)
            }
            while true {
                let value = try parseValue(depth: depth + 1)
                items.append(value)
                skipWhitespace()
                guard i < units.count else { throw fail("Unexpected end of JSON inside an array") }
                if units[i] == 0x2C {
                    i += 1
                    continue
                }
                if units[i] == 0x5D {
                    i += 1
                    return .array(items)
                }
                throw fail("Expected ',' or ']' after the array item")
            }
        }

        mutating func parseString() throws -> String {
            let start = i
            i += 1 // opening quote
            while i < units.count {
                let c = units[i]
                if c == 0x22 {
                    i += 1
                    return String(decoding: units[start..<i], as: UTF16.self)
                }
                if c == 0x5C {
                    guard i + 1 < units.count else { break }
                    switch units[i + 1] {
                    case 0x22, 0x5C, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74:
                        i += 2
                    case 0x75:
                        guard i + 5 < units.count else { throw fail("Incomplete \\u escape in string", at: i) }
                        for k in 2...5 where !isHex(units[i + k]) {
                            throw fail("Invalid \\u escape in string", at: i)
                        }
                        i += 6
                    default:
                        throw fail("Invalid escape sequence in string", at: i)
                    }
                    continue
                }
                if c < 0x20 {
                    throw fail("Line break or control character inside a string (use \\n instead)", at: i)
                }
                i += 1
            }
            throw fail("Unterminated string (missing closing quote)", at: start)
        }

        mutating func parseNumber() throws -> String {
            let start = i
            if units[i] == 0x2D { i += 1 }
            guard i < units.count, isDigit(units[i]) else { throw fail("Invalid number", at: start) }
            if units[i] == 0x30 {
                i += 1
            } else {
                while i < units.count && isDigit(units[i]) { i += 1 }
            }
            if i < units.count && units[i] == 0x2E {
                i += 1
                guard i < units.count, isDigit(units[i]) else { throw fail("Digits expected after the decimal point") }
                while i < units.count && isDigit(units[i]) { i += 1 }
            }
            if i < units.count && (units[i] == 0x65 || units[i] == 0x45) {
                i += 1
                if i < units.count && (units[i] == 0x2B || units[i] == 0x2D) { i += 1 }
                guard i < units.count, isDigit(units[i]) else { throw fail("Digits expected in the exponent") }
                while i < units.count && isDigit(units[i]) { i += 1 }
            }
            return String(decoding: units[start..<i], as: UTF16.self)
        }

        mutating func parseLiteral(_ word: String) throws -> String {
            let expected = Array(word.utf16)
            guard i + expected.count <= units.count, Array(units[i..<(i + expected.count)]) == expected else {
                throw fail("Unexpected token; expected '\(word)'")
            }
            i += expected.count
            return word
        }
    }
}
