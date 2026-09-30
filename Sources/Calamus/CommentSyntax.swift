import Foundation

/// How a language writes comments.
struct CommentSyntax {
    /// Start of a one-line comment ("//", "#", "--", or "<!--" for languages that only have block comments).
    let line: String
    /// End of a one-line comment; empty for most languages, "-->" or "*/" where a comment must be closed.
    let lineEnd: String
    /// The block comment delimiters, or nil when the language has none (then block commands use line comments).
    let blockOpen: String?
    let blockClose: String?

    static let hash = CommentSyntax(line: "#", lineEnd: "", blockOpen: nil, blockClose: nil)
    static let cStyle = CommentSyntax(line: "//", lineEnd: "", blockOpen: "/*", blockClose: "*/")
}

extension Language {
    /// Comment characters for this language. Plain text and anything unknown use "#".
    var commentSyntax: CommentSyntax {
        switch name {
        case "Swift", "C / C++ / Obj-C", "Java", "C#", "Go", "Rust", "Kotlin", "JavaScript / TypeScript", "JSON":
            return .cStyle
        case "Python":
            return CommentSyntax(line: "#", lineEnd: "", blockOpen: "\"\"\"", blockClose: "\"\"\"")
        case "SQL":
            return CommentSyntax(line: "--", lineEnd: "", blockOpen: "/*", blockClose: "*/")
        case "HTML / XML", "Markdown":
            return CommentSyntax(line: "<!--", lineEnd: "-->", blockOpen: "<!--", blockClose: "-->")
        case "CSS":
            return CommentSyntax(line: "/*", lineEnd: "*/", blockOpen: "/*", blockClose: "*/")
        default:   // Plain Text, Shell, YAML, INI / TOML / Config
            return .hash
        }
    }
}
