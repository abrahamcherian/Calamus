import Foundation

/// The text produced by the Insert menu items (kept separate from the UI so it is easy to test).
enum InsertSnippets {
    // MARK: - Horizontal lines

    struct LineStyle {
        let id: String
        let label: String
        let character: String
    }

    static let lineWidths = [40, 60, 72, 80, 100, 120]

    static let lineStyles: [LineStyle] = [
        LineStyle(id: "line.dash", label: "Dashes", character: "-"),
        LineStyle(id: "line.equals", label: "Equals signs", character: "="),
        LineStyle(id: "line.asterisk", label: "Asterisks", character: "*"),
        LineStyle(id: "line.tilde", label: "Tildes", character: "~"),
        LineStyle(id: "line.underscore", label: "Underscores", character: "_"),
        LineStyle(id: "line.box", label: "Box line", character: "\u{2500}"),
        LineStyle(id: "line.double", label: "Double box line", character: "\u{2550}"),
        LineStyle(id: "line.dots", label: "Dots", character: "\u{00B7}")
    ]

    /// A line of repeated characters for the style id, or the Markdown rule.
    static func horizontalLine(id: String, width: Int) -> String? {
        if id == "line.markdown" { return "---" }
        guard let style = lineStyles.first(where: { $0.id == id }) else { return nil }
        return String(repeating: style.character, count: max(3, width))
    }

    // MARK: - Lorem ipsum

    static let loremParagraphs: [String] = [
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.",
        "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.",
        "Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur."
    ]

    static func lorem(id: String) -> String? {
        let first = loremParagraphs[0]
        switch id {
        case "lorem.words":
            let words = first.split(separator: " ").prefix(10).joined(separator: " ")
            return words.trimmingCharacters(in: CharacterSet(charactersIn: ",.")) + "."
        case "lorem.sentence":
            if let end = first.firstIndex(of: ".") { return String(first[...end]) }
            return first
        case "lorem.p1": return loremParagraphs.prefix(1).joined(separator: "\n\n")
        case "lorem.p3": return loremParagraphs.prefix(3).joined(separator: "\n\n")
        case "lorem.p5": return loremParagraphs.prefix(5).joined(separator: "\n\n")
        default: return nil
        }
    }

    // MARK: - Comment banner

    enum BannerStyle {
        case line(String)                       // e.g. "//" or "#": every line starts with it
        case block(open: String, close: String) // e.g. "<!--" and "-->": every line is wrapped
        case plain                              // no comment characters
    }

    /// A three-line boxed heading:  bar / title / bar.
    static func banner(text: String, style: BannerStyle, width: Int) -> String {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch style {
        case .line(let prefix):
            let lead = prefix + " "
            let bar = String(repeating: "=", count: max(10, max(width, lead.count + title.count) - lead.count))
            return [lead + bar, lead + title, lead + bar].joined(separator: "\n")
        case .block(let open, let close):
            let overhead = open.count + close.count + 2
            let barWidth = max(10, max(width, overhead + title.count) - overhead)
            let bar = String(repeating: "=", count: barWidth)
            let padded = title.padding(toLength: max(barWidth, title.count), withPad: " ", startingAt: 0)
            return ["\(open) \(bar) \(close)", "\(open) \(padded) \(close)", "\(open) \(bar) \(close)"].joined(separator: "\n")
        case .plain:
            let bar = String(repeating: "=", count: max(10, max(width, title.count)))
            return [bar, title, bar].joined(separator: "\n")
        }
    }

    // MARK: - Special characters

    struct CharacterGroup {
        let title: String
        let items: [(text: String, name: String)]
    }

    static let specialGroups: [CharacterGroup] = [
        CharacterGroup(title: "Punctuation and Marks", items: [
            ("\u{00A9}", "Copyright"), ("\u{00AE}", "Registered"), ("\u{2122}", "Trademark"),
            ("\u{00A7}", "Section"), ("\u{00B6}", "Paragraph mark"), ("\u{2020}", "Dagger"),
            ("\u{2022}", "Bullet"), ("\u{2026}", "Ellipsis"), ("\u{2013}", "En dash"), ("\u{2014}", "Em dash"),
            ("\u{2018}", "Left single quote"), ("\u{2019}", "Right single quote"),
            ("\u{201C}", "Left double quote"), ("\u{201D}", "Right double quote"),
            ("\u{00AB}", "Left guillemet"), ("\u{00BB}", "Right guillemet")
        ]),
        CharacterGroup(title: "Math and Units", items: [
            ("\u{00B1}", "Plus-minus"), ("\u{00D7}", "Multiplication"), ("\u{00F7}", "Division"),
            ("\u{2248}", "Approximately equal"), ("\u{2260}", "Not equal"), ("\u{2264}", "Less than or equal"),
            ("\u{2265}", "Greater than or equal"), ("\u{221E}", "Infinity"), ("\u{00B0}", "Degree"),
            ("\u{00B5}", "Micro"), ("\u{03C0}", "Pi"), ("\u{221A}", "Square root"), ("\u{2211}", "Sum")
        ]),
        CharacterGroup(title: "Currency", items: [
            ("\u{20AC}", "Euro"), ("\u{00A3}", "Pound"), ("\u{00A5}", "Yen"), ("\u{00A2}", "Cent"),
            ("\u{20B9}", "Indian rupee"), ("\u{20A9}", "Won"), ("\u{20BF}", "Bitcoin")
        ]),
        CharacterGroup(title: "Arrows", items: [
            ("\u{2192}", "Right arrow"), ("\u{2190}", "Left arrow"), ("\u{2191}", "Up arrow"), ("\u{2193}", "Down arrow"),
            ("\u{2194}", "Left-right arrow"), ("\u{21D2}", "Implies"), ("\u{21D0}", "Left double arrow"),
            ("\u{21D4}", "If and only if"), ("\u{21B5}", "Return arrow")
        ]),
        CharacterGroup(title: "Symbols and Checks", items: [
            ("\u{2713}", "Check mark"), ("\u{2714}", "Heavy check mark"), ("\u{2717}", "Cross mark"), ("\u{2718}", "Heavy cross mark"),
            ("\u{2605}", "Black star"), ("\u{2606}", "White star"), ("\u{2665}", "Heart"),
            ("\u{25CF}", "Black circle"), ("\u{25CB}", "White circle"), ("\u{25A0}", "Black square"), ("\u{25A1}", "White square"),
            ("\u{25B2}", "Up triangle"), ("\u{25BC}", "Down triangle"), ("\u{26A0}", "Warning sign")
        ]),
        CharacterGroup(title: "Spacing", items: [
            ("\t", "Tab character"), ("\u{00A0}", "Non-breaking space"), ("\u{200B}", "Zero-width space"),
            ("\u{2002}", "En space"), ("\u{2003}", "Em space"), ("\u{2009}", "Thin space")
        ])
    ]
}
