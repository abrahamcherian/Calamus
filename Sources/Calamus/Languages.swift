import Foundation

enum TokenKind: Int, CaseIterable {
    case comment, string, number, keyword, type, tag, attribute, heading, special
}

/// One highlighting rule. Patterns must not contain capturing groups (use `(?:...)`).
struct SyntaxRule {
    let pattern: String
    let kind: TokenKind
}

struct Language: Equatable {
    let name: String
    let extensions: [String]
    let fileNames: [String]
    let lineComment: String?
    let rules: [SyntaxRule]

    static func == (lhs: Language, rhs: Language) -> Bool { lhs.name == rhs.name }
}

private enum Pat {
    static let cBlock = #"/\*[\s\S]*?(?:\*/|\z)"#
    static let cLine = #"//[^\n]*"#
    static let hash = #"#[^\n]*"#
    static let dash = #"--[^\n]*"#
    static let dq = #""(?:[^"\\\n]|\\.)*""#
    static let sq = #"'(?:[^'\\\n]|\\.)*'"#
    static let backtick = #"`(?:[^`\\]|\\[\s\S])*`"#
    static let number = #"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)\b"#
    static let capitalized = #"\b[A-Z][A-Za-z0-9_]*\b"#

    static func words(_ list: [String], ignoreCase: Bool = false) -> String {
        let body = list.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return (ignoreCase ? "(?i:" : "(?:") + "\\b(?:" + body + ")\\b" + ")"
    }
}

private func kw(_ s: String) -> [String] {
    s.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
}

extension Language {
    static let plain = Language(name: "Plain Text", extensions: ["txt", "text", "log"], fileNames: [],
                                lineComment: nil, rules: [])

    /// Builds a language with C-style comments and strings.
    private static func cLike(_ name: String, _ exts: [String], keywords: [String], types: [String] = [],
                              preprocessor: Bool = false, capitalizedTypes: Bool = true,
                              extra: [SyntaxRule] = []) -> Language {
        var rules: [SyntaxRule] = [
            SyntaxRule(pattern: Pat.cBlock, kind: .comment),
            SyntaxRule(pattern: Pat.cLine, kind: .comment)
        ]
        if preprocessor {
            rules.append(SyntaxRule(pattern: #"^[ \t]*#[ \t]*[A-Za-z_]+"#, kind: .special))
        }
        rules += extra
        rules.append(SyntaxRule(pattern: Pat.dq, kind: .string))
        rules.append(SyntaxRule(pattern: Pat.sq, kind: .string))
        rules.append(SyntaxRule(pattern: Pat.number, kind: .number))
        rules.append(SyntaxRule(pattern: Pat.words(keywords), kind: .keyword))
        if !types.isEmpty { rules.append(SyntaxRule(pattern: Pat.words(types), kind: .type)) }
        if capitalizedTypes { rules.append(SyntaxRule(pattern: Pat.capitalized, kind: .type)) }
        return Language(name: name, extensions: exts, fileNames: [], lineComment: "//", rules: rules)
    }

    static let swift = cLike("Swift", ["swift"],
        keywords: kw("""
        associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private
        precedencegroup protocol public rethrows static struct subscript typealias var break case catch continue default
        defer do else fallthrough for guard if in repeat return throw switch where while Any as await async false is nil
        self Self super throws true try actor some any nonisolated mutating nonmutating override final lazy weak unowned
        convenience required indirect get set willSet didSet
        """),
        capitalizedTypes: true,
        extra: [
            SyntaxRule(pattern: "\"\"\"[\\s\\S]*?(?:\"\"\"|\\z)", kind: .string),
            SyntaxRule(pattern: #"@[A-Za-z_]\w*|#[a-z]\w*"#, kind: .special)
        ])

    static let cFamily = cLike("C / C++ / Obj-C", ["c", "h", "cpp", "cc", "cxx", "hpp", "hh", "m", "mm"],
        keywords: kw("""
        auto break case const continue default do else enum extern for goto if inline register restrict return sizeof
        static struct switch typedef union volatile while class namespace template typename public private protected
        virtual override final new delete this throw try catch using operator nullptr true false constexpr noexcept
        explicit friend mutable static_cast dynamic_cast reinterpret_cast const_cast @interface @implementation @end
        @property @protocol @class @selector self super nil YES NO
        """),
        types: kw("""
        int char short long float double void unsigned signed bool size_t uint8_t uint16_t uint32_t uint64_t int8_t
        int16_t int32_t int64_t id BOOL NSString NSObject
        """),
        preprocessor: true, capitalizedTypes: false)

    static let java = cLike("Java", ["java"],
        keywords: kw("""
        abstract assert break case catch class const continue default do else enum extends final finally for goto if
        implements import instanceof interface native new package private protected public return static strictfp
        super switch synchronized this throw throws transient try volatile while true false null var record sealed
        permits yield
        """),
        types: kw("int long short byte float double boolean char void String Object"),
        extra: [SyntaxRule(pattern: #"@[A-Za-z_]\w*"#, kind: .special)])

    static let csharp = cLike("C#", ["cs"],
        keywords: kw("""
        abstract as base break case catch checked class const continue default delegate do else enum event explicit
        extern finally fixed for foreach goto if implicit in interface internal is lock namespace new operator out
        override params private protected public readonly ref return sealed sizeof stackalloc static struct switch this
        throw try typeof unchecked unsafe using virtual volatile while var async await true false null record init
        get set yield
        """),
        types: kw("bool byte char decimal double float int long object sbyte short string uint ulong ushort void dynamic"),
        preprocessor: true)

    static let go = cLike("Go", ["go"],
        keywords: kw("""
        break case chan const continue default defer else fallthrough for func go goto if import interface map package
        range return select struct switch type var true false nil iota
        """),
        types: kw("""
        bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16
        uint32 uint64 uintptr any
        """),
        extra: [SyntaxRule(pattern: Pat.backtick, kind: .string)])

    static let rust = cLike("Rust", ["rs"],
        keywords: kw("""
        as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move
        mut pub ref return self Self static struct super trait true type unsafe use where while
        """),
        types: kw("""
        bool char f32 f64 i8 i16 i32 i64 i128 isize str u8 u16 u32 u64 u128 usize String Vec Option Result Box
        """),
        extra: [SyntaxRule(pattern: #"#!?\[[^\]\n]*\]"#, kind: .special)])

    static let kotlin = cLike("Kotlin", ["kt", "kts"],
        keywords: kw("""
        as break class continue do else false for fun if in interface is null object package return super this throw
        true try typealias val var when while by catch constructor delegate dynamic field file finally get import init
        param property receiver set setparam where abstract actual annotation companion const crossinline data enum
        expect external final infix inline inner internal lateinit noinline open operator out override private
        protected public reified sealed suspend tailrec vararg
        """),
        extra: [SyntaxRule(pattern: #"@[A-Za-z_]\w*"#, kind: .special)])

    static let javascript = cLike("JavaScript / TypeScript", ["js", "jsx", "mjs", "cjs", "ts", "tsx"],
        keywords: kw("""
        break case catch class const continue debugger default delete do else export extends finally for function if
        import in instanceof let new of return super switch this throw try typeof var void while with yield async
        await static get set null undefined true false interface type enum implements namespace declare readonly
        abstract public private protected as from keyof
        """),
        types: kw("""
        console Math JSON Object Array Promise Map Set Date RegExp Error document window string number boolean any
        never unknown
        """),
        extra: [SyntaxRule(pattern: Pat.backtick, kind: .string)])

    static let python = Language(
        name: "Python", extensions: ["py", "pyw", "pyi"], fileNames: [], lineComment: "#",
        rules: [
            SyntaxRule(pattern: Pat.hash, kind: .comment),
            SyntaxRule(pattern: "(?:[rRbBfFuU]{1,2})?(?:\"\"\"[\\s\\S]*?(?:\"\"\"|\\z)|'''[\\s\\S]*?(?:'''|\\z))", kind: .string),
            SyntaxRule(pattern: #"(?:\b[rRbBfFuU]{1,2})?"(?:[^"\\\n]|\\.)*""#, kind: .string),
            SyntaxRule(pattern: #"(?:\b[rRbBfFuU]{1,2})?'(?:[^'\\\n]|\\.)*'"#, kind: .string),
            SyntaxRule(pattern: #"^[ \t]*@[\w.]+"#, kind: .special),
            SyntaxRule(pattern: Pat.number, kind: .number),
            SyntaxRule(pattern: Pat.words(kw("""
            and as assert async await break class continue def del elif else except finally for from global if import
            in is lambda nonlocal not or pass raise return try while with yield None True False self cls match case
            """)), kind: .keyword),
            SyntaxRule(pattern: Pat.words(kw("""
            int str float bool list dict set tuple bytes object print len range type isinstance open super enumerate
            zip map filter sorted sum min max abs
            """)), kind: .type),
            SyntaxRule(pattern: Pat.capitalized, kind: .type)
        ])

    static let shell = Language(
        name: "Shell", extensions: ["sh", "bash", "zsh", "command", "ksh"],
        fileNames: [".zshrc", ".bashrc", ".bash_profile", ".profile", ".zprofile"], lineComment: "#",
        rules: [
            SyntaxRule(pattern: #"^#![^\n]*"#, kind: .special),
            SyntaxRule(pattern: Pat.hash, kind: .comment),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: #"'[^']*'"#, kind: .string),
            SyntaxRule(pattern: #"\$(?:\{[^}\n]*\}|[A-Za-z_]\w*|[0-9@#?$!*-])"#, kind: .type),
            SyntaxRule(pattern: Pat.number, kind: .number),
            SyntaxRule(pattern: Pat.words(kw("""
            if then else elif fi for while do done case esac in function select until return exit break continue local
            export readonly declare unset echo cd source alias set shift test eval exec trap
            """)), kind: .keyword)
        ])

    static let sql = Language(
        name: "SQL", extensions: ["sql"], fileNames: [], lineComment: "--",
        rules: [
            SyntaxRule(pattern: Pat.dash, kind: .comment),
            SyntaxRule(pattern: Pat.cBlock, kind: .comment),
            SyntaxRule(pattern: Pat.sq, kind: .string),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: Pat.number, kind: .number),
            SyntaxRule(pattern: Pat.words(kw("""
            select from where and or not in is null like between exists insert into values update set delete create
            table drop alter add column index view join inner left right outer full cross on as group by order having
            limit offset union all distinct case when then else end primary key foreign references default unique
            check constraint begin commit rollback transaction with asc desc count sum avg min max
            """), ignoreCase: true), kind: .keyword),
            SyntaxRule(pattern: Pat.words(kw("""
            int integer bigint smallint tinyint decimal numeric float real double varchar char text date datetime
            timestamp boolean bool blob
            """), ignoreCase: true), kind: .type)
        ])

    static let json = Language(
        name: "JSON", extensions: ["json", "jsonc", "geojson", "webmanifest"], fileNames: [], lineComment: nil,
        rules: [
            SyntaxRule(pattern: #""(?:[^"\\\n]|\\.)*"(?=[ \t]*:)"#, kind: .attribute),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: #"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#, kind: .number),
            SyntaxRule(pattern: Pat.words(["true", "false", "null"]), kind: .keyword)
        ])

    static let html = Language(
        name: "HTML / XML", extensions: ["html", "htm", "xhtml", "xml", "svg", "plist", "xsl", "xib", "storyboard", "vue"],
        fileNames: [], lineComment: nil,
        rules: [
            SyntaxRule(pattern: #"<!--[\s\S]*?(?:-->|\z)"#, kind: .comment),
            SyntaxRule(pattern: #"<!\[CDATA\[[\s\S]*?(?:\]\]>|\z)"#, kind: .string),
            SyntaxRule(pattern: #"<![A-Za-z][^>]*>|<\?[\s\S]*?(?:\?>|\z)"#, kind: .special),
            SyntaxRule(pattern: #"</?[A-Za-z][\w:.-]*"#, kind: .tag),
            SyntaxRule(pattern: #"[A-Za-z_:@][\w:.-]*(?=\s*=)"#, kind: .attribute),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: Pat.sq, kind: .string),
            SyntaxRule(pattern: #"&[A-Za-z0-9#]+;"#, kind: .special),
            SyntaxRule(pattern: #"/?>"#, kind: .tag)
        ])

    static let css = Language(
        name: "CSS", extensions: ["css"], fileNames: [], lineComment: nil,
        rules: [
            SyntaxRule(pattern: Pat.cBlock, kind: .comment),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: Pat.sq, kind: .string),
            SyntaxRule(pattern: #"#[0-9a-fA-F]{3,8}\b"#, kind: .number),
            SyntaxRule(pattern: #"@[\w-]+"#, kind: .keyword),
            SyntaxRule(pattern: #"\b\d+(?:\.\d+)?(?:%|[a-zA-Z]+)?"#, kind: .number),
            SyntaxRule(pattern: #"[A-Za-z-]+(?=\s*:)"#, kind: .attribute),
            SyntaxRule(pattern: #"[.#][A-Za-z_-][\w-]*"#, kind: .type)
        ])

    static let yaml = Language(
        name: "YAML", extensions: ["yml", "yaml"], fileNames: [], lineComment: "#",
        rules: [
            SyntaxRule(pattern: Pat.hash, kind: .comment),
            SyntaxRule(pattern: #"^[ \t]*(?:-[ \t]+)?[\w.\-/]+(?=[ \t]*:(?:[ \t]|$))"#, kind: .attribute),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: Pat.sq, kind: .string),
            SyntaxRule(pattern: #"[&*][\w-]+"#, kind: .special),
            SyntaxRule(pattern: Pat.number, kind: .number),
            SyntaxRule(pattern: Pat.words(["true", "false", "null", "yes", "no"]), kind: .keyword)
        ])

    static let markdown = Language(
        name: "Markdown", extensions: ["md", "markdown", "mdown"], fileNames: [], lineComment: nil,
        rules: [
            SyntaxRule(pattern: "```[\\s\\S]*?(?:```|\\z)", kind: .special),
            SyntaxRule(pattern: #"^#{1,6}[^\n]*"#, kind: .heading),
            SyntaxRule(pattern: #"^>[^\n]*"#, kind: .comment),
            SyntaxRule(pattern: #"`[^`\n]+`"#, kind: .special),
            SyntaxRule(pattern: #"\*\*[^*\n]+\*\*|__[^_\n]+__"#, kind: .keyword),
            SyntaxRule(pattern: #"\[[^\]\n]*\]\([^)\n]*\)"#, kind: .tag),
            SyntaxRule(pattern: #"^[ \t]*(?:[-*+]|\d+\.)(?=[ \t])"#, kind: .special)
        ])

    static let ini = Language(
        name: "INI / TOML / Config", extensions: ["ini", "toml", "cfg", "conf", "properties", "env"],
        fileNames: [], lineComment: "#",
        rules: [
            SyntaxRule(pattern: #"[#;][^\n]*"#, kind: .comment),
            SyntaxRule(pattern: #"^[ \t]*\[[^\]\n]+\]"#, kind: .heading),
            SyntaxRule(pattern: #"^[ \t]*[\w.\-]+(?=[ \t]*=)"#, kind: .attribute),
            SyntaxRule(pattern: Pat.dq, kind: .string),
            SyntaxRule(pattern: Pat.sq, kind: .string),
            SyntaxRule(pattern: Pat.number, kind: .number),
            SyntaxRule(pattern: Pat.words(["true", "false"]), kind: .keyword)
        ])

    static let all: [Language] = [
        plain, swift, cFamily, java, csharp, go, rust, kotlin, javascript, python, shell, sql,
        json, html, css, yaml, markdown, ini
    ]

    static func detect(url: URL?) -> Language {
        guard let url = url else { return .plain }
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        if let byName = all.first(where: { $0.fileNames.contains(name) }) { return byName }
        return all.first(where: { $0.extensions.contains(ext) }) ?? .plain
    }
}
