import Foundation

/// Word / character / line counts for a piece of text.
struct TextStats {
    private(set) var words = 0
    private(set) var charactersWithSpaces = 0     // every character except line breaks
    private(set) var charactersWithoutSpaces = 0  // no spaces, tabs or line breaks
    private(set) var lines = 0
    private(set) var paragraphs = 0

    init(_ text: String) {
        var inWord = false
        var lineBreaks = 0
        var lineHasContent = false
        var inParagraph = false

        for character in text {
            if character.isNewline {
                lineBreaks += 1
                inWord = false
                if !lineHasContent { inParagraph = false }
                lineHasContent = false
                continue
            }
            charactersWithSpaces += 1
            if character.isWhitespace {
                inWord = false
            } else {
                charactersWithoutSpaces += 1
                if !inWord {
                    words += 1
                    inWord = true
                }
                if !lineHasContent {
                    lineHasContent = true
                    if !inParagraph {
                        paragraphs += 1
                        inParagraph = true
                    }
                }
            }
        }
        if let last = text.last, !last.isNewline {
            lines = lineBreaks + 1
        } else {
            lines = lineBreaks
        }
    }

    private static func format(_ number: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
    }

    /// Estimated reading time at 200 words per minute.
    private var readingTime: String {
        if words == 0 { return "-" }
        let minutes = Double(words) / 200.0
        if minutes < 1 { return "under 1 minute" }
        return "about \(Int(minutes.rounded())) minute\(Int(minutes.rounded()) == 1 ? "" : "s")"
    }

    var summary: String {
        [
            "Words: \(TextStats.format(words))",
            "Characters (with spaces): \(TextStats.format(charactersWithSpaces))",
            "Characters (without spaces): \(TextStats.format(charactersWithoutSpaces))",
            "Lines: \(TextStats.format(lines))",
            "Paragraphs: \(TextStats.format(paragraphs))",
            "Reading time: \(readingTime)",
            "",
            "Line breaks are not counted as characters."
        ].joined(separator: "\n")
    }
}
