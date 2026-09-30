import Foundation

// MARK: - The Format > Text Formatting tools

/// One command of Format > Text Formatting: its options and the function that rewrites the text.
enum TextFormatTool: String, CaseIterable {
    case addLineNumbers, addCommas, quotes, tabsToSpaces, spacesToTabs, padText, wordWrap, justify, center, tabularize, sortText, reverseText

    var title: String {
        switch self {
        case .addLineNumbers: return "Add Line Numbers"
        case .addCommas: return "Add Commas to Numbers"
        case .quotes: return "Replace Smart/Straight Quotes"
        case .tabsToSpaces: return "Tabs to Spaces"
        case .spacesToTabs: return "Spaces to Tabs"
        case .padText: return "Pad Text"
        case .wordWrap: return "Word Wrap"
        case .justify: return "Justify Text"
        case .center: return "Center Text"
        case .tabularize: return "Tabularize Data"
        case .sortText: return "Sort Text"
        case .reverseText: return "Reverse Text"
        }
    }

    var summary: String {
        switch self {
        case .addLineNumbers: return "Add sequential numbers, letters, or roman numerals at the beginning of each line."
        case .addCommas: return "Add commas or periods to unformatted numbers in a text."
        case .quotes: return "Replace curly/smart quotes with regular straight quotes and vice versa."
        case .tabsToSpaces: return "Take up less white space by converting tabs to spaces."
        case .spacesToTabs: return "Convert spaces to tabs for formatting purposes."
        case .padText: return "Pad text to the left or right with spaces or any character."
        case .wordWrap: return "Wrap text based on the specified number of characters per line."
        case .justify: return "Wraps words to a specified length and justifies the text in each line."
        case .center: return "Center text horizontally by equally padding the left and the right side with spaces."
        case .tabularize: return "Turn delimited text (CSV, tab, pipe, ...) into neatly aligned columns or a table."
        case .sortText: return "Sort lines, words, comma-separated items or characters in different ways."
        case .reverseText: return "Reverse the whole text, the order of its lines or words, or the characters in each line or word."
        }
    }

    static let numberStyles = [
        "Numbers (1, 2, 3)", "Letters lowercase (a, b, c)", "Letters UPPERCASE (A, B, C)",
        "Roman numerals lowercase (i, ii, iii)", "Roman numerals UPPERCASE (I, II, III)"
    ]
    static let commaStyles = [
        "1,234,567.89  (commas, decimal point)", "1.234.567,89  (periods, decimal comma)"
    ]
    static let quoteModes = ["Curly to straight", "Straight to curly"]
    static let tabWidths = ["2", "4", "8"]
    static let tabSeparators = [
        "Auto-detect", "Comma ( , )", "Tab", "Semicolon ( ; )", "Pipe ( | )", "Colon ( : )",
        "Spaces (one or more)", "Custom text", "JSON (list of records)"
    ]
    static let tabStyles = ["Aligned columns", "Markdown table", "Box table (+---+)", "Columns separated by |"]
    static let tabAlignments = ["Numbers right, text left", "Left", "Right", "Center"]
    static let sortTargets = [
        "Lines", "Words in each line", "Comma-separated items in each line",
        "Characters in each line", "Every word in the text (one per line)"
    ]
    static let sortOrders = [
        "A to Z", "Z to A", "Natural (item2 before item10)", "Numbers ascending", "Numbers descending",
        "Shortest first", "Longest first", "Random (shuffle)"
    ]
    static let reverseModes = [
        "Whole text (last character first)", "Order of the lines", "Characters in each line",
        "Order of the words in each line", "Letters of each word"
    ]
    static let padModes = ["Add this many characters to every line", "Pad every line to this total length"]

    var fields: [ToolField] {
        switch self {
        case .addLineNumbers:
            return [
                ToolField(id: "style", label: "Style", kind: .choice(TextFormatTool.numberStyles), defaultValue: TextFormatTool.numberStyles[0]),
                ToolField(id: "start", label: "Start at", kind: .number, defaultValue: "1"),
                ToolField(id: "separator", label: "After the number", kind: .text, defaultValue: ". "),
                ToolField(id: "skipEmpty", label: "Skip empty lines", kind: .toggle, defaultValue: "0")
            ]
        case .addCommas:
            return [
                ToolField(id: "style", label: "Format", kind: .choice(TextFormatTool.commaStyles), defaultValue: TextFormatTool.commaStyles[0]),
                ToolField(id: "minDigits", label: "Only numbers with at least this many digits", kind: .number, defaultValue: "4")
            ]
        case .quotes:
            return [ToolField(id: "mode", label: "Replace", kind: .choice(TextFormatTool.quoteModes), defaultValue: TextFormatTool.quoteModes[0])]
        case .tabsToSpaces:
            return [ToolField(id: "width", label: "Spaces per tab", kind: .choice(TextFormatTool.tabWidths), defaultValue: "4")]
        case .spacesToTabs:
            return [
                ToolField(id: "width", label: "Spaces per tab", kind: .choice(TextFormatTool.tabWidths), defaultValue: "4"),
                ToolField(id: "leadingOnly", label: "Only leading spaces (indentation)", kind: .toggle, defaultValue: "1")
            ]
        case .padText:
            return [
                ToolField(id: "side", label: "Pad on the", kind: .choice(["Left", "Right"]), defaultValue: "Left"),
                ToolField(id: "mode", label: "Amount means", kind: .choice(TextFormatTool.padModes), defaultValue: TextFormatTool.padModes[0]),
                ToolField(id: "amount", label: "Amount", kind: .number, defaultValue: "10"),
                ToolField(id: "char", label: "Pad with", kind: .text, defaultValue: " ")
            ]
        case .wordWrap:
            return [
                ToolField(id: "width", label: "Characters per line", kind: .number, defaultValue: "80"),
                ToolField(id: "reflow", label: "Join the lines of each paragraph first", kind: .toggle, defaultValue: "0")
            ]
        case .justify:
            return [ToolField(id: "width", label: "Characters per line", kind: .number, defaultValue: "60")]
        case .tabularize:
            return [
                ToolField(id: "separator", label: "Values are separated by", kind: .choice(TextFormatTool.tabSeparators), defaultValue: TextFormatTool.tabSeparators[0]),
                ToolField(id: "custom", label: "Custom separator", kind: .text, defaultValue: ""),
                ToolField(id: "style", label: "Make", kind: .choice(TextFormatTool.tabStyles), defaultValue: TextFormatTool.tabStyles[0]),
                ToolField(id: "align", label: "Align", kind: .choice(TextFormatTool.tabAlignments), defaultValue: TextFormatTool.tabAlignments[0]),
                ToolField(id: "header", label: "First row is a header", kind: .toggle, defaultValue: "1"),
                ToolField(id: "gap", label: "Spaces between columns", kind: .number, defaultValue: "2"),
                ToolField(id: "trim", label: "Trim spaces around values", kind: .toggle, defaultValue: "1")
            ]
        case .sortText:
            return [
                ToolField(id: "target", label: "Sort", kind: .choice(TextFormatTool.sortTargets), defaultValue: TextFormatTool.sortTargets[0]),
                ToolField(id: "order", label: "Order", kind: .choice(TextFormatTool.sortOrders), defaultValue: TextFormatTool.sortOrders[0]),
                ToolField(id: "ignoreCase", label: "Ignore upper/lower case", kind: .toggle, defaultValue: "1"),
                ToolField(id: "unique", label: "Remove duplicates", kind: .toggle, defaultValue: "0"),
                ToolField(id: "dropEmpty", label: "Remove empty lines or items", kind: .toggle, defaultValue: "0")
            ]
        case .reverseText:
            return [ToolField(id: "mode", label: "Reverse", kind: .choice(TextFormatTool.reverseModes), defaultValue: TextFormatTool.reverseModes[0])]
        case .center:
            return [
                ToolField(id: "width", label: "Line width", kind: .number, defaultValue: "80"),
                ToolField(id: "padRight", label: "Also pad the right side with spaces", kind: .toggle, defaultValue: "1")
            ]
        }
    }

    /// Option values to start the sheet with: the ones used last time, else the defaults.
    func initialValues() -> [String: String] {
        var values: [String: String] = [:]
        for field in fields { values[field.id] = field.defaultValue }
        if let saved = UserDefaults.standard.dictionary(forKey: "textformat." + rawValue) as? [String: String] {
            for field in fields {
                guard let value = saved[field.id] else { continue }
                if case .choice(let options) = field.kind, !options.contains(value) { continue }
                values[field.id] = value
            }
        }
        return values
    }

    func remember(_ values: [String: String]) {
        UserDefaults.standard.set(values, forKey: "textformat." + rawValue)
    }

    /// Rewrites `text` with the given option values.
    func transform(_ text: String, _ values: GeneratorValues) -> String {
        switch self {
        case .addLineNumbers:
            let style = TextFormatTool.numberStyles.firstIndex(of: values.string("style")) ?? 0
            return TextFormatter.addLineNumbers(text, style: style, start: values.int("start", 1, min: -1_000_000, max: 1_000_000),
                                                separator: values.string("separator", ". "), skipEmpty: values.bool("skipEmpty"))
        case .addCommas:
            let periods = TextFormatTool.commaStyles.firstIndex(of: values.string("style")) == 1
            return TextFormatter.addCommas(text, periodsForThousands: periods, minDigits: values.int("minDigits", 4, min: 1, max: 30))
        case .quotes:
            return values.string("mode") == TextFormatTool.quoteModes[1]
                ? TextFormatter.straightToCurly(text) : TextFormatter.curlyToStraight(text)
        case .tabsToSpaces:
            return TextFormatter.tabsToSpaces(text, width: values.int("width", 4, min: 1, max: 16))
        case .spacesToTabs:
            return TextFormatter.spacesToTabs(text, width: values.int("width", 4, min: 1, max: 16), leadingOnly: values.bool("leadingOnly"))
        case .padText:
            return TextFormatter.pad(text, toLeft: values.string("side") != "Right",
                                     toTotalLength: values.string("mode") == TextFormatTool.padModes[1],
                                     amount: values.int("amount", 10, min: 0, max: 1000), with: values.string("char", " "))
        case .wordWrap:
            return TextFormatter.wrap(text, width: values.int("width", 80, min: 2, max: 1000), reflow: values.bool("reflow"))
        case .justify:
            return TextFormatter.justify(text, width: values.int("width", 60, min: 2, max: 1000))
        case .tabularize:
            return TextFormatter.tabularize(text, separator: TextFormatTool.tabSeparators.firstIndex(of: values.string("separator")) ?? 0,
                                            custom: values.string("custom"),
                                            style: TextFormatTool.tabStyles.firstIndex(of: values.string("style")) ?? 0,
                                            alignment: TextFormatTool.tabAlignments.firstIndex(of: values.string("align")) ?? 0,
                                            header: values.bool("header"), gap: values.int("gap", 2, min: 1, max: 20),
                                            trim: values.bool("trim"))
        case .sortText:
            return TextFormatter.sort(text, target: TextFormatTool.sortTargets.firstIndex(of: values.string("target")) ?? 0,
                                      order: TextFormatTool.sortOrders.firstIndex(of: values.string("order")) ?? 0,
                                      ignoreCase: values.bool("ignoreCase"), unique: values.bool("unique"),
                                      dropEmpty: values.bool("dropEmpty"), seed: UInt64(values.string("_seed")) ?? UInt64.random(in: 1...UInt64.max))
        case .reverseText:
            return TextFormatter.reverse(text, mode: TextFormatTool.reverseModes.firstIndex(of: values.string("mode")) ?? 0)
        case .center:
            return TextFormatter.center(text, width: values.int("width", 80, min: 2, max: 1000), padRight: values.bool("padRight"))
        }
    }
}

// MARK: - The algorithms (pure functions on strings)

enum TextFormatter {
    /// Splits into lines, remembering whether the text ended with a line break.
    private static func split(_ text: String) -> (lines: [String], trailingNewline: Bool) {
        var lines = text.components(separatedBy: "\n")
        var trailing = false
        if lines.count > 1, lines.last == "" {
            lines.removeLast()
            trailing = true
        }
        return (lines, trailing)
    }

    private static func join(_ lines: [String], _ trailingNewline: Bool) -> String {
        lines.joined(separator: "\n") + (trailingNewline ? "\n" : "")
    }

    private static func mapLines(_ text: String, _ transform: (String) -> String) -> String {
        let (lines, trailing) = split(text)
        return join(lines.map(transform), trailing)
    }

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Add line numbers

    static func roman(_ number: Int) -> String {
        guard number > 0, number < 4000 else { return String(number) }
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = number
        var result = ""
        for (value, symbol) in table {
            while n >= value {
                result += symbol
                n -= value
            }
        }
        return result
    }

    /// 1 → A, 26 → Z, 27 → AA, 28 → AB, ...
    static func letters(_ number: Int) -> String {
        guard number > 0 else { return String(number) }
        var n = number
        var result: [Character] = []
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        while n > 0 {
            n -= 1
            result.append(alphabet[n % 26])
            n /= 26
        }
        return String(result.reversed())
    }

    static func label(_ number: Int, style: Int) -> String {
        switch style {
        case 1: return letters(number).lowercased()
        case 2: return letters(number)
        case 3: return roman(number).lowercased()
        case 4: return roman(number)
        default: return String(number)
        }
    }

    static func addLineNumbers(_ text: String, style: Int, start: Int, separator: String, skipEmpty: Bool) -> String {
        var number = start
        return mapLines(text) { line in
            if skipEmpty && isBlank(line) { return line }
            defer { number += 1 }
            return label(number, style: style) + separator + line
        }
    }

    // MARK: Add commas to numbers

    static func addCommas(_ text: String, periodsForThousands: Bool, minDigits: Int) -> String {
        let pattern = "(?<![\\w.,])(\\d{\(max(1, minDigits)),})(\\.\\d+)?(?!\\w)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        let thousands = periodsForThousands ? "." : ","
        let decimal = periodsForThousands ? "," : "."
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let integer = ns.substring(with: match.range(at: 1))
            let fraction = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : ""
            if integer.count > 1 && integer.hasPrefix("0") {
                result += ns.substring(with: match.range)          // leading zeros: an ID or code, leave alone
            } else {
                var grouped = ""
                for (offset, digit) in integer.reversed().enumerated() {
                    if offset > 0 && offset % 3 == 0 { grouped += thousands }
                    grouped.append(digit)
                }
                result += String(grouped.reversed())
                if !fraction.isEmpty { result += decimal + String(fraction.dropFirst()) }
            }
            last = NSMaxRange(match.range)
        }
        result += ns.substring(from: last)
        return result
    }

    // MARK: Quotes

    static func curlyToStraight(_ text: String) -> String {
        var result = ""
        for ch in text {
            switch ch {
            case "\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}", "\u{2032}": result.append("'")
            case "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{2033}": result.append("\"")
            default: result.append(ch)
            }
        }
        return result
    }

    static func straightToCurly(_ text: String) -> String {
        let openers = Set<Character>(["(", "[", "{", "<", "\u{2014}", "\u{2013}", "/", "\u{2018}", "\u{201C}"])
        var result = ""
        var previous: Character? = nil
        for ch in text {
            if ch == "\"" || ch == "'" {
                let opening: Bool
                if let p = previous {
                    opening = p.isWhitespace || openers.contains(p)
                } else {
                    opening = true
                }
                if ch == "\"" { result.append(opening ? "\u{201C}" : "\u{201D}") }
                else { result.append(opening ? "\u{2018}" : "\u{2019}") }
            } else {
                result.append(ch)
            }
            previous = ch
        }
        return result
    }

    // MARK: Tabs and spaces

    static func tabsToSpaces(_ text: String, width: Int) -> String {
        let w = max(1, width)
        return mapLines(text) { line in
            guard line.contains("\t") else { return line }
            var out = ""
            var column = 0
            for ch in line {
                if ch == "\t" {
                    let n = w - column % w
                    out += String(repeating: " ", count: n)
                    column += n
                } else {
                    out.append(ch)
                    column += 1
                }
            }
            return out
        }
    }

    static func spacesToTabs(_ text: String, width: Int, leadingOnly: Bool) -> String {
        let w = max(1, width)
        return mapLines(text) { line in
            let chars = Array(line)
            if leadingOnly {
                var n = 0
                while n < chars.count && chars[n] == " " { n += 1 }
                guard n >= w else { return line }
                return String(repeating: "\t", count: n / w) + String(repeating: " ", count: n % w) + String(chars[n...])
            }
            var out = ""
            var column = 0
            var i = 0
            while i < chars.count {
                let ch = chars[i]
                if ch == " " {
                    var j = i
                    while j < chars.count && chars[j] == " " { j += 1 }
                    let run = j - i
                    if run >= 2 {
                        var c = column
                        let end = column + run
                        while (c / w + 1) * w <= end {
                            out += "\t"
                            c = (c / w + 1) * w
                        }
                        out += String(repeating: " ", count: end - c)
                        column = end
                    } else {
                        out += " "
                        column += 1
                    }
                    i = j
                } else {
                    out.append(ch)
                    column += ch == "\t" ? (w - column % w) : 1
                    i += 1
                }
            }
            return out
        }
    }

    // MARK: Pad, wrap, justify, center

    /// Pads every line on the left or right. Either adds `amount` pad characters, or pads short lines up to
    /// `amount` characters in total. A pad text of several characters is repeated as needed.
    static func pad(_ text: String, toLeft: Bool, toTotalLength: Bool, amount: Int, with padding: String) -> String {
        let pattern = Array(padding.isEmpty ? " " : padding)
        func filler(_ count: Int) -> String {
            String((0..<count).map { pattern[$0 % pattern.count] })
        }
        return mapLines(text) { line in
            let count = toTotalLength ? amount - line.count : amount
            guard count > 0 else { return line }
            return toLeft ? filler(count) + line : line + filler(count)
        }
    }

    /// Breaks words into lines of at most `width` characters (a word longer than that is cut).
    private static func wrapWords(_ words: [String], width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in words {
            var piece = word
            while piece.count > width {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                }
                lines.append(String(piece.prefix(width)))
                piece = String(piece.dropFirst(width))
            }
            if piece.isEmpty { continue }
            if current.isEmpty {
                current = piece
            } else if current.count + 1 + piece.count <= width {
                current += " " + piece
            } else {
                lines.append(current)
                current = piece
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func words(_ line: String) -> [String] {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    static func wrap(_ text: String, width: Int, reflow: Bool) -> String {
        let (lines, trailing) = split(text)
        var out: [String] = []
        if reflow {
            var paragraph: [String] = []
            func flush() {
                if !paragraph.isEmpty {
                    out.append(contentsOf: wrapWords(paragraph.flatMap(words), width: width))
                    paragraph = []
                }
            }
            for line in lines {
                if isBlank(line) {
                    flush()
                    out.append("")
                } else {
                    paragraph.append(line)
                }
            }
            flush()
        } else {
            for line in lines {
                if isBlank(line) {
                    out.append("")
                    continue
                }
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                let room = max(1, width - indent.count)
                for wrapped in wrapWords(words(line), width: room) { out.append(indent + wrapped) }
            }
        }
        return join(out, trailing)
    }

    static func justify(_ text: String, width: Int) -> String {
        let (lines, trailing) = split(text)
        var out: [String] = []
        var paragraph: [String] = []
        func flush() {
            guard !paragraph.isEmpty else { return }
            let wrapped = wrapWords(paragraph.flatMap(words), width: width)
            for (index, line) in wrapped.enumerated() {
                let parts = words(line)
                if index == wrapped.count - 1 || parts.count < 2 {
                    out.append(line)
                    continue
                }
                let letters = parts.reduce(0) { $0 + $1.count }
                let spaces = max(parts.count - 1, width - letters)
                let gaps = parts.count - 1
                let base = spaces / gaps
                let extra = spaces % gaps
                var justified = ""
                for (i, part) in parts.enumerated() {
                    justified += part
                    if i < gaps { justified += String(repeating: " ", count: base + (i < extra ? 1 : 0)) }
                }
                out.append(justified)
            }
            paragraph = []
        }
        for line in lines {
            if isBlank(line) {
                flush()
                out.append("")
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return join(out, trailing)
    }

    static func center(_ text: String, width: Int, padRight: Bool) -> String {
        mapLines(text) { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }
            let missing = width - trimmed.count
            guard missing > 0 else { return trimmed }
            let left = missing / 2
            return String(repeating: " ", count: left) + trimmed + (padRight ? String(repeating: " ", count: missing - left) : "")
        }
    }
}

// MARK: - Sort and reverse

/// A small repeatable random generator, so a shuffle previewed in the sheet is the one that gets applied.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension TextFormatter {
    private static func firstNumber(_ text: String) -> Double? {
        guard let range = text.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    /// Sorts `items` in one of the ways in `TextFormatTool.sortOrders`. Equal items keep their order.
    static func sortItems(_ input: [String], order: Int, ignoreCase: Bool, seed: UInt64) -> [String] {
        if order == 7 {
            var generator = SeededGenerator(seed: seed)
            return input.shuffled(using: &generator)
        }
        let indexed = Array(input.enumerated())
        func compare(_ a: String, _ b: String) -> ComparisonResult {
            switch order {
            case 0, 1:
                let r = a.compare(b, options: ignoreCase ? [.caseInsensitive] : [])
                return order == 0 ? r : (r == .orderedAscending ? .orderedDescending : (r == .orderedDescending ? .orderedAscending : .orderedSame))
            case 2:
                return a.compare(b, options: ignoreCase ? [.numeric, .caseInsensitive] : [.numeric])
            case 3, 4:
                let x = firstNumber(a), y = firstNumber(b)
                switch (x, y) {
                case (nil, nil): return .orderedSame
                case (nil, _): return .orderedDescending      // items without a number go last
                case (_, nil): return .orderedAscending
                case let (p?, q?):
                    if p == q { return .orderedSame }
                    let ascending = p < q
                    return (ascending == (order == 3)) ? .orderedAscending : .orderedDescending
                }
            case 5:
                return a.count == b.count ? .orderedSame : (a.count < b.count ? .orderedAscending : .orderedDescending)
            default:
                return a.count == b.count ? .orderedSame : (a.count > b.count ? .orderedAscending : .orderedDescending)
            }
        }
        return indexed.sorted { lhs, rhs in
            let r = compare(lhs.element, rhs.element)
            return r == .orderedSame ? lhs.offset < rhs.offset : r == .orderedAscending
        }.map { $0.element }
    }

    private static func prepare(_ items: [String], unique: Bool, dropEmpty: Bool, ignoreCase: Bool) -> [String] {
        var result = items
        if dropEmpty { result = result.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        if unique {
            var seen = Set<String>()
            result = result.filter { seen.insert(ignoreCase ? $0.lowercased() : $0).inserted }
        }
        return result
    }

    static func sort(_ text: String, target: Int, order: Int, ignoreCase: Bool, unique: Bool, dropEmpty: Bool, seed: UInt64) -> String {
        func arrange(_ items: [String]) -> [String] {
            sortItems(prepare(items, unique: unique, dropEmpty: dropEmpty, ignoreCase: ignoreCase),
                      order: order, ignoreCase: ignoreCase, seed: seed)
        }
        let hasTrailingNewline = text.hasSuffix("\n") && text.count > 1
        let body = hasTrailingNewline ? String(text.dropLast()) : text
        let lines = body.components(separatedBy: "\n")
        var out: String
        switch target {
        case 1:
            out = lines.map { line in
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
                return parts.isEmpty ? line : indent + arrange(parts).joined(separator: " ")
            }.joined(separator: "\n")
        case 2:
            out = lines.map { line in
                guard line.contains(",") else { return line }
                let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return arrange(parts).joined(separator: ", ")
            }.joined(separator: "\n")
        case 3:
            out = lines.map { line in arrange(line.map { String($0) }).joined() }.joined(separator: "\n")
        case 4:
            let all = body.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }).map(String.init)
            out = arrange(all).joined(separator: "\n")
        default:
            out = arrange(lines).joined(separator: "\n")
        }
        return out + (hasTrailingNewline && !out.isEmpty ? "\n" : "")
    }

    static func reverse(_ text: String, mode: Int) -> String {
        let hasTrailingNewline = text.hasSuffix("\n") && text.count > 1
        let body = hasTrailingNewline ? String(text.dropLast()) : text
        let lines = body.components(separatedBy: "\n")
        let out: String
        switch mode {
        case 1:
            out = lines.reversed().joined(separator: "\n")
        case 2:
            out = lines.map { String($0.reversed()) }.joined(separator: "\n")
        case 3:
            out = lines.map { line in
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
                return parts.isEmpty ? line : indent + parts.reversed().joined(separator: " ")
            }.joined(separator: "\n")
        case 4:
            out = lines.map { line in
                var result = ""
                var word = ""
                for ch in line {
                    if ch == " " || ch == "\t" {
                        result += String(word.reversed()) + String(ch)
                        word = ""
                    } else {
                        word.append(ch)
                    }
                }
                return result + String(word.reversed())
            }.joined(separator: "\n")
        default:
            out = String(body.reversed())
        }
        return out + (hasTrailingNewline ? "\n" : "")
    }
}

// MARK: - Tabularize

extension TextFormatter {
    private enum Delimiter {
        case character(Character)
        case text(String)
        case whitespace
    }

    private static func splitRow(_ line: String, _ delimiter: Delimiter, trim: Bool) -> [String] {
        var cells: [String] = []
        switch delimiter {
        case .whitespace:
            cells = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        case .text(let separator):
            cells = line.components(separatedBy: separator)
        case .character(let separator):
            // Values may be wrapped in double quotes ("a, b"); "" inside quotes is one quote.
            let chars = Array(line)
            var current = ""
            var inQuotes = false
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if c == "\"" {
                    if inQuotes {
                        if i + 1 < chars.count && chars[i + 1] == "\"" {
                            current.append("\"")
                            i += 2
                            continue
                        }
                        inQuotes = false
                    } else if current.trimmingCharacters(in: .whitespaces).isEmpty {
                        inQuotes = true
                        current = ""
                    } else {
                        current.append(c)
                    }
                } else if c == separator && !inQuotes {
                    cells.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
                i += 1
            }
            cells.append(current)
        }
        return trim ? cells.map { $0.trimmingCharacters(in: .whitespaces) } : cells
    }

    /// Picks the separator that splits the most lines into the same number of columns.
    private static func detectDelimiter(_ lines: [String]) -> Delimiter {
        let candidates: [Character] = [",", "\t", ";", "|"]
        var best: Delimiter = .whitespace
        var bestScore = 0
        for candidate in candidates {
            var counts: [Int: Int] = [:]
            for line in lines {
                let parts = splitRow(line, .character(candidate), trim: false).count - 1
                if parts > 0 { counts[parts, default: 0] += 1 }
            }
            let score = counts.values.max() ?? 0
            if score > bestScore {
                bestScore = score
                best = .character(candidate)
            }
        }
        return best
    }

    private static func looksNumeric(_ cell: String) -> Bool {
        cell.range(of: #"^[+-]?[$€£]?\(?[+-]?\d[\d,.]*\)?%?$"#, options: .regularExpression) != nil
    }

    private static func padCell(_ text: String, _ width: Int, _ align: Int) -> String {
        let missing = width - text.count
        guard missing > 0 else { return text }
        switch align {
        case 1: return String(repeating: " ", count: missing) + text
        case 2:
            let left = missing / 2
            return String(repeating: " ", count: left) + text + String(repeating: " ", count: missing - left)
        default: return text + String(repeating: " ", count: missing)
        }
    }

    private static func trimTrailing(_ line: String) -> String {
        var result = line
        while let last = result.last, last == " " { result.removeLast() }
        return result
    }

    /// Lays out one table (rows of cells) in the chosen style.
    private static func layoutTable(_ input: [[String]], style: Int, alignment: Int, header: Bool, gap: Int) -> [String] {
        let columns = input.map { $0.count }.max() ?? 0
        guard columns > 0 else { return [] }
        let rows = input.map { row in row + Array(repeating: "", count: columns - row.count) }
        let minimum = style == 1 ? 3 : 1
        var widths = [Int](repeating: minimum, count: columns)
        for row in rows {
            for (c, cell) in row.enumerated() { widths[c] = max(widths[c], cell.count) }
        }
        // 0 left, 1 right, 2 center for each column
        let body = header ? Array(rows.dropFirst()) : rows
        let aligns: [Int] = (0..<columns).map { c in
            switch alignment {
            case 1: return 0
            case 2: return 1
            case 3: return 2
            default:
                let values = body.map { $0[c] }.filter { !$0.isEmpty }
                return (!values.isEmpty && values.allSatisfy(looksNumeric)) ? 1 : 0
            }
        }
        func line(_ row: [String]) -> [String] {
            row.enumerated().map { padCell($0.element, widths[$0.offset], aligns[$0.offset]) }
        }
        let gapText = String(repeating: " ", count: gap)
        var out: [String] = []
        switch style {
        case 1:
            for (r, row) in rows.enumerated() {
                out.append("| " + line(row).joined(separator: " | ") + " |")
                if r == 0 {
                    let marks = (0..<columns).map { c -> String in
                        let w = widths[c]
                        switch aligns[c] {
                        case 1: return String(repeating: "-", count: w - 1) + ":"
                        case 2: return ":" + String(repeating: "-", count: w - 2) + ":"
                        default: return String(repeating: "-", count: w)
                        }
                    }
                    out.append("| " + marks.joined(separator: " | ") + " |")
                }
            }
        case 2:
            let rule = "+" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "+") + "+"
            out.append(rule)
            for (r, row) in rows.enumerated() {
                out.append("| " + line(row).joined(separator: " | ") + " |")
                if header && r == 0 { out.append(rule) }
            }
            out.append(rule)
        case 3:
            for (r, row) in rows.enumerated() {
                out.append(trimTrailing(line(row).joined(separator: " | ")))
                if header && r == 0 {
                    out.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-"))
                }
            }
        default:
            for (r, row) in rows.enumerated() {
                out.append(trimTrailing(line(row).joined(separator: gapText)))
                if header && r == 0 {
                    out.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: gapText))
                }
            }
        }
        return out
    }

    // MARK: JSON to table

    /// A JSON string or key is stored with its quotes and escapes; this gives the plain text.
    private static func jsonText(_ raw: String) -> String {
        if raw == "null" { return "" }
        if raw.hasPrefix("\""), let data = "[\(raw)]".data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [Any], let string = array.first as? String {
            return string
        }
        return raw
    }

    private static func jsonCell(_ node: JSONFormatter.Node) -> String {
        if case .scalar(let raw) = node { return jsonText(raw) }
        return JSONFormatter.minified(node)      // nested objects and lists stay as compact JSON
    }

    /// Rows for a JSON list of records ([{...}, {...}]), a list of lists, one object, or JSON Lines.
    /// `header` tells whether the first row holds column names.
    private static func jsonRows(_ text: String) -> (rows: [[String]], header: Bool)? {
        let root: JSONFormatter.Node
        if let node = try? JSONFormatter.parse(text) {
            root = node
        } else {
            var items: [JSONFormatter.Node] = []
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let node = try? JSONFormatter.parse(trimmed) else { return nil }
                items.append(node)
            }
            guard !items.isEmpty else { return nil }
            root = .array(items)
        }
        switch root {
        case .array(let items):
            guard !items.isEmpty else { return nil }
            var records: [[(key: String, value: String)]] = []
            var lists: [[String]] = []
            for item in items {
                switch item {
                case .object(let members): records.append(members.map { (key: jsonText($0.key), value: jsonCell($0.value)) })
                case .array(let cells): lists.append(cells.map(jsonCell))
                case .scalar: break
                }
            }
            if records.count == items.count {
                var keys: [String] = []
                for record in records { for member in record where !keys.contains(member.key) { keys.append(member.key) } }
                let rows = records.map { record in
                    keys.map { key in record.first(where: { $0.key == key })?.value ?? "" }
                }
                return ([keys] + rows, true)
            }
            if lists.count == items.count { return (lists, false) }
            return ([["value"]] + items.map { [jsonCell($0)] }, true)
        case .object(let members):
            return ([["key", "value"]] + members.map { [jsonText($0.key), jsonCell($0.value)] }, true)
        case .scalar:
            return nil
        }
    }

    static func tabularize(_ text: String, separator: Int, custom: String, style: Int, alignment: Int,
                           header: Bool, gap: Int, trim: Bool) -> String {
        let jsonCandidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if separator == 8 || (separator == 0 && (jsonCandidate.hasPrefix("[") || jsonCandidate.hasPrefix("{"))) {
            if let json = jsonRows(jsonCandidate) {
                let lines = layoutTable(json.rows, style: style, alignment: alignment, header: json.header || header, gap: gap)
                return lines.joined(separator: "\n") + (text.hasSuffix("\n") ? "\n" : "")
            }
            if separator == 8 { return text }      // not valid JSON: leave the text alone
        }
        let hasTrailingNewline = text.hasSuffix("\n") && text.count > 1
        let body = hasTrailingNewline ? String(text.dropLast()) : text
        let lines = body.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonBlank.isEmpty else { return text }

        let delimiter: Delimiter
        switch separator {
        case 1: delimiter = .character(",")
        case 2: delimiter = .character("\t")
        case 3: delimiter = .character(";")
        case 4: delimiter = .character("|")
        case 5: delimiter = .character(":")
        case 6: delimiter = .whitespace
        case 7: delimiter = custom.isEmpty ? .whitespace : (custom.count == 1 ? .character(custom.first!) : .text(custom))
        default: delimiter = detectDelimiter(nonBlank)
        }

        var out: [String] = []
        var block: [[String]] = []
        func flush() {
            if !block.isEmpty {
                out.append(contentsOf: layoutTable(block, style: style, alignment: alignment, header: header, gap: gap))
                block = []
            }
        }
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
                out.append("")
            } else {
                var cells = splitRow(line, delimiter, trim: trim)
                // A leading/trailing pipe (as in a Markdown table) does not make an empty column.
                if case .character("|") = delimiter {
                    if cells.first?.isEmpty == true { cells.removeFirst() }
                    if cells.last?.isEmpty == true { cells.removeLast() }
                }
                block.append(cells)
            }
        }
        flush()
        return out.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
    }
}
