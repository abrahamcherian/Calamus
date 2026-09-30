import AppKit

/// Regex-based syntax highlighter. All rules of a language are merged into one alternation so that
/// earlier rules (comments, strings) win over later ones (keywords, numbers). Colors are applied as
/// temporary attributes, so the document text itself is never modified.
enum SyntaxHighlighter {
    private struct Compiled {
        let regex: NSRegularExpression
        let kinds: [TokenKind]
    }

    private static var cache: [String: Compiled] = [:]

    private static func compiled(for language: Language) -> Compiled? {
        if let c = cache[language.name] { return c }
        var parts: [String] = []
        var kinds: [TokenKind] = []
        for rule in language.rules {
            // Skip any rule that fails to compile rather than losing the whole language.
            if (try? NSRegularExpression(pattern: rule.pattern, options: [])) != nil {
                parts.append("(" + rule.pattern + ")")
                kinds.append(rule.kind)
            }
        }
        guard !parts.isEmpty,
              let regex = try? NSRegularExpression(pattern: parts.joined(separator: "|"), options: [.anchorsMatchLines])
        else { return nil }
        let c = Compiled(regex: regex, kinds: kinds)
        cache[language.name] = c
        return c
    }

    static func apply(language: Language, theme: Theme, layoutManager lm: NSLayoutManager,
                      storage: NSTextStorage, range: NSRange) {
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        guard range.length > 0, let c = compiled(for: language) else { return }
        let text = storage.string
        let colors = c.kinds.map { theme.color(for: $0) }
        c.regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            for i in 0..<colors.count {
                let r = match.range(at: i + 1)
                if r.location != NSNotFound {
                    lm.addTemporaryAttribute(.foregroundColor, value: colors[i], forCharacterRange: r)
                    break
                }
            }
        }
    }
}
