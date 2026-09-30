import AppKit

/// A small, self-contained Markdown renderer for View > Markdown Preview. No third-party
/// dependencies: block structure (headers, lists, code fences, blockquotes, rules) is handled
/// line by line here, and inline styling (**bold**, *italic*, `code`, [links](url)) within each
/// paragraph is handled by Foundation's own Markdown parser (`NSAttributedString(markdown:)`,
/// macOS 12+), used in its default inline-only mode since this renderer already owns the block
/// structure. Not a full CommonMark implementation — covers what everyday notes and READMEs use.
enum MarkdownPreview {
    static func render(_ source: String, baseFont: NSFont, textColor: NSColor, accentColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodySize = baseFont.pointSize
        let monoFont = NSFont.monospacedSystemFont(ofSize: bodySize, weight: .regular)
        let spacing: CGFloat = max(4, bodySize * 0.5)

        var inCodeBlock = false
        var codeBuffer: [String] = []

        func paragraphStyle(indent: CGFloat = 0, extraSpacingBefore: CGFloat = 0) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = spacing
            style.paragraphSpacingBefore = extraSpacingBefore
            style.headIndent = indent
            style.firstLineHeadIndent = indent
            return style
        }

        func flushCodeBlock() {
            guard !codeBuffer.isEmpty else { return }
            let text = codeBuffer.joined(separator: "\n")
            result.append(NSAttributedString(string: text + "\n", attributes: [
                .font: monoFont, .foregroundColor: textColor,
                .backgroundColor: textColor.withAlphaComponent(0.08),
                .paragraphStyle: paragraphStyle(extraSpacingBefore: spacing)
            ]))
            codeBuffer = []
        }

        /// Runs Foundation's Markdown parser for inline styling (bold/italic/code/links), then
        /// rebuilds every run's font from `blockFont` - the size/weight this block actually
        /// wants (a header's bigger bold font, a blockquote's italic, or plain body text) -
        /// layering on top of it whatever extra emphasis the parser found for that run: bold or
        /// italic become added traits, and a `code` span switches to a monospaced font at the
        /// same size. Without this, every run would keep the parser's own default font (roughly
        /// system-regular, one fixed size) instead of the block's - which is what made headers,
        /// quotes and body text all look identical regardless of source formatting.
        func appendInline(_ line: String, style: NSParagraphStyle, fallbackFont blockFont: NSFont) {
            if let parsed = try? NSAttributedString(markdown: line), parsed.length > 0 {
                let mutable = NSMutableAttributedString(attributedString: parsed)
                let whole = NSRange(location: 0, length: mutable.length)
                mutable.enumerateAttribute(.font, in: whole, options: []) { value, range, _ in
                    let parsedFont = value as? NSFont
                    if let pf = parsedFont, pf.isFixedPitch {
                        // An inline `code` span: keep it monospaced, at this block's size.
                        let weight: NSFont.Weight = pf.fontDescriptor.symbolicTraits.contains(.bold) ? .bold : .regular
                        mutable.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: blockFont.pointSize, weight: weight), range: range)
                        return
                    }
                    var traits = blockFont.fontDescriptor.symbolicTraits
                    if let pf = parsedFont {
                        let parsedTraits = pf.fontDescriptor.symbolicTraits
                        if parsedTraits.contains(.bold) { traits.insert(.bold) }
                        if parsedTraits.contains(.italic) { traits.insert(.italic) }
                    }
                    let descriptor = blockFont.fontDescriptor.withSymbolicTraits(traits)
                    mutable.addAttribute(.font, value: NSFont(descriptor: descriptor, size: blockFont.pointSize) ?? blockFont, range: range)
                }
                mutable.addAttribute(.paragraphStyle, value: style, range: whole)
                mutable.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
                    if value == nil { mutable.addAttribute(.foregroundColor, value: textColor, range: range) }
                }
                result.append(mutable)
            } else {
                result.append(NSAttributedString(string: line, attributes: [
                    .font: blockFont, .foregroundColor: textColor, .paragraphStyle: style
                ]))
            }
            result.append(NSAttributedString(string: "\n"))
        }

        for rawLine in source.components(separatedBy: "\n") {
            if rawLine.hasPrefix("```") {
                if inCodeBlock { flushCodeBlock() }
                inCodeBlock.toggle()
                continue
            }
            if inCodeBlock { codeBuffer.append(rawLine); continue }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(NSAttributedString(string: String(repeating: "\u{2014}", count: 24) + "\n", attributes: [
                    .font: baseFont, .foregroundColor: accentColor, .paragraphStyle: paragraphStyle(extraSpacingBefore: spacing)
                ]))
                continue
            }

            if let (level, text) = headerLevel(of: trimmed) {
                let size = bodySize + CGFloat(max(0, 7 - level)) * 4
                let font = NSFont.boldSystemFont(ofSize: size)
                appendInline(text, style: paragraphStyle(extraSpacingBefore: spacing * 1.4), fallbackFont: font)
                continue
            }

            if trimmed.hasPrefix("> ") || trimmed == ">" {
                let text = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : ""
                appendInline(text, style: paragraphStyle(indent: 24), fallbackFont: italic(of: baseFont))
                continue
            }

            if let bulletText = unorderedListText(trimmed) {
                appendInline("\u{2022}\u{2003}" + bulletText, style: paragraphStyle(indent: 20), fallbackFont: baseFont)
                continue
            }

            if isOrderedListLine(trimmed) {
                appendInline(trimmed, style: paragraphStyle(indent: 20), fallbackFont: baseFont)
                continue
            }

            appendInline(trimmed, style: paragraphStyle(), fallbackFont: baseFont)
        }
        flushCodeBlock()
        return result
    }

    private static func italic(of font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    /// "# Title" through "###### Title" -> (level, "Title"). Nil for anything else, including a
    /// bare run of #'s with no following space (not a header).
    private static func headerLevel(of line: String) -> (Int, String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", level < 6 {
            level += 1
            index = line.index(after: index)
        }
        guard level > 0, index < line.endIndex, line[index] == " " else { return nil }
        let text = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)
        return (level, text)
    }

    private static func unorderedListText(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// "1. text", "12. text", etc. — digits, then ". ".
    private static func isOrderedListLine(_ line: String) -> Bool {
        guard let dotSpace = line.range(of: ". ") else { return false }
        let prefix = line[line.startIndex..<dotSpace.lowerBound]
        return !prefix.isEmpty && prefix.allSatisfy { $0.isNumber }
    }
}
