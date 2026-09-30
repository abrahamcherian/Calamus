import Foundation

// MARK: - Tool and option definitions

enum FieldKind {
    case text
    case number
    case toggle
    case choice([String])
}

struct ToolField {
    let id: String
    let label: String
    let kind: FieldKind
    let defaultValue: String
}

/// The values typed or chosen in a tool's options.
struct GeneratorValues {
    var raw: [String: String]

    func string(_ id: String, _ fallback: String = "") -> String { raw[id] ?? fallback }

    func int(_ id: String, _ fallback: Int, min lo: Int = -1_000_000_000, max hi: Int = 1_000_000_000) -> Int {
        let parsed = Int(string(id).trimmingCharacters(in: .whitespaces)) ?? fallback
        return Swift.min(hi, Swift.max(lo, parsed))
    }

    func double(_ id: String, _ fallback: Double) -> Double {
        Double(string(id).trimmingCharacters(in: .whitespaces)) ?? fallback
    }

    func bool(_ id: String) -> Bool { raw[id] == "1" }
}

struct GeneratorResult {
    var text: String
    var note: String = ""
}

enum RandomTool: String, CaseIterable {
    case username, strongPassword, pronounceablePassword, randomString, randomWord, fillerText, randomNumber, randomEmail

    /// Label of the "How many" field, showing the global limit.
    static var countLabel: String { "How many (max \(RandomGenerators.maxCount))" }

    var title: String {
        switch self {
        case .username: return "Username Generator"
        case .strongPassword: return "Strong Password Generator"
        case .pronounceablePassword: return "Pronounceable Password"
        case .randomString: return "Random String Generator"
        case .randomWord: return "Random Word Generator"
        case .fillerText: return "Filler Text"
        case .randomNumber: return "Random Number Generator"
        case .randomEmail: return "Random Email Generator"
        }
    }

    var summary: String {
        switch self {
        case .username: return "Find yourself a unique username that you can use on any online social media site."
        case .strongPassword: return "Generate a strong, secure, and valid password that no one can guess."
        case .pronounceablePassword: return "Get yourself a pronounceable password that is both secure and easy to remember."
        case .randomString: return "Generate a random string based on your defined length and character set."
        case .randomWord: return "Generate single or multiple random words based on your defined word length."
        case .fillerText: return "Generate a placeholder/dummy text for your mockup design."
        case .randomNumber: return "Generate one or more numbers randomly from a defined range of numbers."
        case .randomEmail: return "Create unregistered email addresses in bulk using random names and characters."
        }
    }

    var fields: [ToolField] {
        switch self {
        case .username:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "5"),
                ToolField(id: "style", label: "Style", kind: .choice(RandomGenerators.usernameStyles), defaultValue: RandomGenerators.usernameStyles[0]),
                ToolField(id: "separator", label: "Separator", kind: .choice(RandomGenerators.usernameSeparators), defaultValue: "None"),
                ToolField(id: "case", label: "Letters", kind: .choice(["lowercase", "Capitalized", "camelCase"]), defaultValue: "lowercase"),
                ToolField(id: "maxlen", label: "Maximum length", kind: .number, defaultValue: "15")
            ]
        case .strongPassword:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "1"),
                ToolField(id: "length", label: "Length", kind: .number, defaultValue: "16"),
                ToolField(id: "upper", label: "Uppercase letters (A-Z)", kind: .toggle, defaultValue: "1"),
                ToolField(id: "lower", label: "Lowercase letters (a-z)", kind: .toggle, defaultValue: "1"),
                ToolField(id: "digits", label: "Numbers (0-9)", kind: .toggle, defaultValue: "1"),
                ToolField(id: "symbols", label: "Symbols (!@#$%…)", kind: .toggle, defaultValue: "1"),
                ToolField(id: "ambiguous", label: "Avoid look-alike characters (0 O 1 l I)", kind: .toggle, defaultValue: "0")
            ]
        case .pronounceablePassword:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "3"),
                ToolField(id: "length", label: "Length", kind: .number, defaultValue: "12"),
                ToolField(id: "capital", label: "Start with a capital letter", kind: .toggle, defaultValue: "1"),
                ToolField(id: "numbers", label: "End with two numbers", kind: .toggle, defaultValue: "1"),
                ToolField(id: "symbol", label: "Add a symbol at the end", kind: .toggle, defaultValue: "0")
            ]
        case .randomString:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "1"),
                ToolField(id: "length", label: "Length", kind: .number, defaultValue: "16"),
                ToolField(id: "charset", label: "Characters", kind: .choice(RandomGenerators.stringCharsets), defaultValue: RandomGenerators.stringCharsets[0]),
                ToolField(id: "custom", label: "Custom characters", kind: .text, defaultValue: "abc123")
            ]
        case .randomWord:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "5"),
                ToolField(id: "minlen", label: "Shortest word", kind: .number, defaultValue: "4"),
                ToolField(id: "maxlen", label: "Longest word", kind: .number, defaultValue: "8"),
                ToolField(id: "case", label: "Letters", kind: .choice(["lowercase", "Capitalized", "UPPERCASE"]), defaultValue: "lowercase"),
                ToolField(id: "separator", label: "Separate with", kind: .choice(["New line", "Space", "Comma and space", "Dash"]), defaultValue: "New line")
            ]
        case .fillerText:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "3"),
                ToolField(id: "unit", label: "Unit", kind: .choice(["Paragraphs", "Sentences", "Words"]), defaultValue: "Paragraphs"),
                ToolField(id: "classic", label: "Start with \u{201C}Lorem ipsum dolor sit amet\u{201D}", kind: .toggle, defaultValue: "1"),
                ToolField(id: "html", label: "Wrap in HTML <p> tags", kind: .toggle, defaultValue: "0")
            ]
        case .randomNumber:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "1"),
                ToolField(id: "min", label: "From", kind: .number, defaultValue: "1"),
                ToolField(id: "max", label: "To", kind: .number, defaultValue: "100"),
                ToolField(id: "type", label: "Type", kind: .choice(["Whole numbers", "Decimal numbers"]), defaultValue: "Whole numbers"),
                ToolField(id: "decimals", label: "Decimal places", kind: .number, defaultValue: "2"),
                ToolField(id: "unique", label: "No repeated numbers", kind: .toggle, defaultValue: "0"),
                ToolField(id: "sort", label: "Order", kind: .choice(["As generated", "Ascending", "Descending"]), defaultValue: "As generated"),
                ToolField(id: "separator", label: "Separate with", kind: .choice(["New line", "Comma and space", "Space", "Tab"]), defaultValue: "New line")
            ]
        case .randomEmail:
            return [
                ToolField(id: "count", label: RandomTool.countLabel, kind: .number, defaultValue: "10"),
                ToolField(id: "style", label: "Name style", kind: .choice(RandomGenerators.emailStyles), defaultValue: RandomGenerators.emailStyles[0]),
                ToolField(id: "domain", label: "Domain", kind: .choice(RandomGenerators.emailDomains), defaultValue: RandomGenerators.emailDomains[3]),
                ToolField(id: "custom", label: "Custom domain", kind: .text, defaultValue: "example.com"),
                ToolField(id: "separator", label: "Separate with", kind: .choice(["New line", "Comma and space", "Semicolon and space"]), defaultValue: "New line")
            ]
        }
    }

    /// The values this tool starts with when nothing else applies: the built-in defaults, changed by
    /// anything saved in File > Preferences > Random Generator.
    func editableDefaults() -> [String: String] {
        var values: [String: String] = [:]
        for field in fields { values[field.id] = field.defaultValue }
        if let saved = UserDefaults.standard.dictionary(forKey: "randomDefaults." + rawValue) as? [String: String] {
            for field in fields {
                guard let value = saved[field.id] else { continue }
                if case .choice(let options) = field.kind, !options.contains(value) { continue }
                values[field.id] = value
            }
        }
        return values
    }

    func saveEditableDefaults(_ values: [String: String]) {
        UserDefaults.standard.set(values, forKey: "randomDefaults." + rawValue)
    }

    func clearEditableDefaults() {
        UserDefaults.standard.removeObject(forKey: "randomDefaults." + rawValue)
    }

    /// Option values to start with: your saved defaults, or (if "remember last used values" is on
    /// in Preferences) the values used last time.
    func initialValues() -> [String: String] {
        var values = editableDefaults()
        if UserDefaults.standard.bool(forKey: "randomRemembersLast"),
           let saved = UserDefaults.standard.dictionary(forKey: "random." + rawValue) as? [String: String] {
            for field in fields {
                guard let value = saved[field.id] else { continue }
                if case .choice(let options) = field.kind, !options.contains(value) { continue }
                values[field.id] = value
            }
        }
        return values
    }

    func remember(_ values: [String: String]) {
        UserDefaults.standard.set(values, forKey: "random." + rawValue)
    }
}

// MARK: - Generators

enum RandomGenerators {
    /// The most items any Random Generator tool will make at once (the "How many" field).
    /// Change this one number to change the limit for every tool.
    static let maxCount = 100

    static let usernameStyles = ["Adjective + noun + number", "Adjective + noun", "Noun + number"]
    static let usernameSeparators = ["None", "Underscore (_)", "Dot (.)", "Dash (-)"]
    static let stringCharsets = [
        "Letters and digits (a-z, A-Z, 0-9)", "Letters only (a-z, A-Z)", "Lowercase letters (a-z)",
        "Uppercase letters (A-Z)", "Digits (0-9)", "Hexadecimal, lowercase", "Hexadecimal, UPPERCASE",
        "URL-safe (letters, digits, - and _)", "Custom characters"
    ]
    static let emailStyles = ["first.last", "firstlast", "first_last", "First initial + last", "first.last + number", "Random letters and digits"]
    static let emailDomains = ["example.com", "example.org", "example.net", "One of the three example domains", "Custom domain"]

    static let symbols = Array("!@#$%^&*()-_=+[]{};:,.?/")
    private static let ambiguous = Set("0O1lI")

    // MARK: Helpers

    private static func pick<T>(_ items: [T]) -> T {
        var generator = SystemRandomNumberGenerator()
        return items[Int.random(in: 0..<items.count, using: &generator)]
    }

    private static func random(_ range: ClosedRange<Int>) -> Int {
        var generator = SystemRandomNumberGenerator()
        return Int.random(in: range, using: &generator)
    }

    private static func shuffled<T>(_ items: [T]) -> [T] {
        var generator = SystemRandomNumberGenerator()
        return items.shuffled(using: &generator)
    }

    private static func separator(named name: String) -> String {
        switch name {
        case "Space": return " "
        case "Comma and space": return ", "
        case "Dash": return "-"
        case "Tab": return "\t"
        case "Semicolon and space": return "; "
        default: return "\n"
        }
    }

    private static func capitalized(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst().lowercased()
    }

    // MARK: Entry point

    static func generate(_ tool: RandomTool, _ values: GeneratorValues) -> GeneratorResult {
        switch tool {
        case .username: return usernames(values)
        case .strongPassword: return strongPasswords(values)
        case .pronounceablePassword: return pronounceablePasswords(values)
        case .randomString: return randomStrings(values)
        case .randomWord: return randomWords(values)
        case .fillerText: return fillerText(values)
        case .randomNumber: return randomNumbers(values)
        case .randomEmail: return randomEmails(values)
        }
    }

    // MARK: Usernames

    static func usernames(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 5, min: 1, max: maxCount)
        let maxLength = v.int("maxlen", 15, min: 5, max: 30)
        let style = v.string("style", usernameStyles[0])
        let letters = v.string("case", "lowercase")
        let joiner: String
        switch v.string("separator", "None") {
        case "Underscore (_)": joiner = "_"
        case "Dot (.)": joiner = "."
        case "Dash (-)": joiner = "-"
        default: joiner = ""
        }

        var results: [String] = []
        var seen = Set<String>()
        var attempts = 0
        while results.count < count && attempts < count * 60 {
            attempts += 1
            var words: [String]
            var number: String?
            switch style {
            case "Adjective + noun":
                words = [pick(RandomWordLists.adjectives), pick(RandomWordLists.nouns)]
            case "Noun + number":
                words = [pick(RandomWordLists.nouns)]
                number = String(random(10...9999))
            default:
                words = [pick(RandomWordLists.adjectives), pick(RandomWordLists.nouns)]
                number = String(random(1...99))
            }
            switch letters {
            case "Capitalized":
                words = words.map { capitalized($0) }
            case "camelCase":
                words = words.enumerated().map { $0.offset == 0 ? $0.element.lowercased() : capitalized($0.element) }
            default:
                words = words.map { $0.lowercased() }
            }
            let name = (words + (number.map { [$0] } ?? [])).joined(separator: joiner)
            if name.count <= maxLength && seen.insert(name.lowercased()).inserted { results.append(name) }
        }
        var note = "Letters, numbers and one optional separator only, so they work on most sites."
        if results.count < count { note = "Only \(results.count) fit in \(maxLength) characters. Raise the maximum length for more." }
        return GeneratorResult(text: results.joined(separator: "\n"), note: note)
    }

    // MARK: Passwords

    static func strengthLabel(bits: Double) -> String {
        switch bits {
        case ..<40: return "Weak"
        case ..<60: return "Fair"
        case ..<80: return "Strong"
        default: return "Very strong"
        }
    }

    static func strongPasswords(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 1, min: 1, max: maxCount)
        let length = v.int("length", 16, min: 4, max: 256)
        var pools: [[Character]] = []
        let hideLookalikes = v.bool("ambiguous")
        func add(_ characters: [Character]) {
            let usable = hideLookalikes ? characters.filter { !ambiguous.contains($0) } : characters
            if !usable.isEmpty { pools.append(usable) }
        }
        if v.bool("upper") { add(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")) }
        if v.bool("lower") { add(Array("abcdefghijklmnopqrstuvwxyz")) }
        if v.bool("digits") { add(Array("0123456789")) }
        if v.bool("symbols") { add(symbols) }
        guard !pools.isEmpty else {
            return GeneratorResult(text: "", note: "Choose at least one type of character.")
        }
        let combined = pools.flatMap { $0 }
        var passwords: [String] = []
        for _ in 0..<count {
            var characters: [Character] = pools.map { pick($0) } // at least one of every chosen type
            while characters.count < length { characters.append(pick(combined)) }
            passwords.append(String(shuffled(characters).prefix(length)))
        }
        let bits = Double(length) * log2(Double(combined.count))
        var note = "\(strengthLabel(bits: bits)): about \(Int(bits)) bits of randomness. Made with the system's secure random generator."
        if length < pools.count { note = "Length is shorter than the number of character types chosen." }
        return GeneratorResult(text: passwords.joined(separator: "\n"), note: note)
    }

    static func pronounceablePasswords(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 3, min: 1, max: maxCount)
        let length = v.int("length", 12, min: 6, max: 40)
        let addNumbers = v.bool("numbers")
        let addSymbol = v.bool("symbol")
        let starts = ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "r", "s", "t", "v", "w", "z",
                      "br", "cr", "dr", "fr", "gr", "pr", "tr", "st", "sl", "sp", "pl", "bl", "cl", "fl", "gl", "ch", "sh", "th"]
        let vowels = ["a", "e", "i", "o", "u", "a", "e", "i", "o", "u", "ai", "ea", "io", "ou", "oo", "ee"]
        let singleStarts = starts.filter { $0.count == 1 }
        let ends = ["n", "r", "s", "t", "l", "m", "k", "d"]
        let suffixLength = (addNumbers ? 2 : 0) + (addSymbol ? 1 : 0)
        let letterCount = max(4, length - suffixLength)

        var passwords: [String] = []
        for _ in 0..<count {
            var word = ""
            var previousEnded = false // avoid awkward clusters like "ndv": after a closing consonant use a single one
            while word.count < letterCount {
                word += (previousEnded ? pick(singleStarts) : pick(starts)) + pick(vowels)
                previousEnded = random(1...10) <= 4
                if previousEnded { word += pick(ends) }
            }
            word = String(word.prefix(letterCount))
            if v.bool("capital") { word = word.prefix(1).uppercased() + word.dropFirst() }
            if addNumbers { word += String(random(10...99)) }
            if addSymbol { word += String(pick(symbols)) }
            passwords.append(word)
        }
        return GeneratorResult(text: passwords.joined(separator: "\n"),
                               note: "Built from syllables you can say out loud. For the highest security use the Strong Password Generator.")
    }

    // MARK: Random strings

    static func randomStrings(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 1, min: 1, max: maxCount)
        let length = v.int("length", 16, min: 1, max: 4096)
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = lowercase.uppercased()
        let digits = "0123456789"
        let charset: String
        switch v.string("charset", stringCharsets[0]) {
        case stringCharsets[1]: charset = lowercase + uppercase
        case stringCharsets[2]: charset = lowercase
        case stringCharsets[3]: charset = uppercase
        case stringCharsets[4]: charset = digits
        case stringCharsets[5]: charset = "0123456789abcdef"
        case stringCharsets[6]: charset = "0123456789ABCDEF"
        case stringCharsets[7]: charset = lowercase + uppercase + digits + "-_"
        case stringCharsets[8]: charset = v.string("custom")
        default: charset = lowercase + uppercase + digits
        }
        // Remove repeated characters from a custom set so each one is equally likely.
        var unique: [Character] = []
        for character in charset where !unique.contains(character) { unique.append(character) }
        guard !unique.isEmpty else {
            return GeneratorResult(text: "", note: "Type the characters to use in \u{201C}Custom characters\u{201D}.")
        }
        var strings: [String] = []
        for _ in 0..<count {
            strings.append(String((0..<length).map { _ in pick(unique) }))
        }
        return GeneratorResult(text: strings.joined(separator: "\n"),
                               note: "\(unique.count) possible characters, \(length) long: about \(Int(Double(length) * log2(Double(max(2, unique.count))))) bits.")
    }

    // MARK: Random words

    static func randomWords(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 5, min: 1, max: maxCount)
        var shortest = v.int("minlen", 4, min: 2, max: 24)
        var longest = v.int("maxlen", 8, min: 2, max: 24)
        if shortest > longest { swap(&shortest, &longest) }
        let candidates = RandomWordLists.words.filter { $0.count >= shortest && $0.count <= longest }
        guard !candidates.isEmpty else {
            return GeneratorResult(text: "", note: "No words that length. Try between 3 and 12 letters.")
        }
        var chosen: [String] = Array(shuffled(candidates).prefix(count))
        while chosen.count < count { chosen.append(pick(candidates)) } // repeat words only if the list runs out
        chosen = chosen.map { word in
            switch v.string("case", "lowercase") {
            case "Capitalized": return capitalized(word)
            case "UPPERCASE": return word.uppercased()
            default: return word.lowercased()
            }
        }
        let note = candidates.count < count ? "Only \(candidates.count) different words are that long, so some repeat." : "\(candidates.count) words to pick from."
        return GeneratorResult(text: chosen.joined(separator: separator(named: v.string("separator", "New line"))), note: note)
    }

    // MARK: Filler text

    private static func sentence(words wordCount: Int) -> String {
        var words = (0..<wordCount).map { _ in pick(RandomWordLists.latin) }
        if wordCount > 7 { words[random(3...(wordCount - 3))] += "," }
        var text = words.joined(separator: " ")
        text = text.prefix(1).uppercased() + text.dropFirst()
        return text + "."
    }

    static func fillerText(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 3, min: 1, max: maxCount)
        let classic = v.bool("classic")
        let classicStart = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        let unit = v.string("unit", "Paragraphs")
        var text: String

        switch unit {
        case "Words":
            var words = (0..<count).map { _ in pick(RandomWordLists.latin) }
            if classic {
                let start = ["Lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit"]
                for (index, word) in start.enumerated() where index < words.count { words[index] = word }
            }
            text = words.joined(separator: " ")
            text = text.prefix(1).uppercased() + text.dropFirst() + "."
            if v.bool("html") { text = "<p>" + text + "</p>" }
        case "Sentences":
            var sentences = (0..<count).map { _ in sentence(words: random(6...14)) }
            if classic { sentences[0] = classicStart }
            text = sentences.joined(separator: " ")
            if v.bool("html") { text = "<p>" + text + "</p>" }
        default:
            var paragraphs: [String] = []
            for index in 0..<count {
                var sentences = (0..<random(3...6)).map { _ in sentence(words: random(6...14)) }
                if classic && index == 0 { sentences[0] = classicStart }
                paragraphs.append(sentences.joined(separator: " "))
            }
            if v.bool("html") { paragraphs = paragraphs.map { "<p>" + $0 + "</p>" } }
            text = paragraphs.joined(separator: "\n\n")
        }
        return GeneratorResult(text: text, note: "\(text.split(whereSeparator: { $0.isWhitespace }).count) words of placeholder text.")
    }

    // MARK: Random numbers

    static func randomNumbers(_ v: GeneratorValues) -> GeneratorResult {
        var count = v.int("count", 1, min: 1, max: maxCount)
        let joiner = separator(named: v.string("separator", "New line"))
        let sortOrder = v.string("sort", "As generated")
        var note = ""
        var numbers: [String]

        if v.string("type", "Whole numbers") == "Decimal numbers" {
            var low = v.double("min", 1)
            var high = v.double("max", 100)
            if low > high { swap(&low, &high) }
            let places = v.int("decimals", 2, min: 0, max: 10)
            var generator = SystemRandomNumberGenerator()
            var values: [(Double, String)] = []
            var seen = Set<String>()
            var attempts = 0
            while values.count < count && attempts < count * 20 {
                attempts += 1
                let value = low == high ? low : Double.random(in: low...high, using: &generator)
                let text = String(format: "%.\(places)f", value)
                if v.bool("unique") && !seen.insert(text).inserted { continue }
                values.append((Double(text) ?? value, text))
            }
            if sortOrder == "Ascending" { values.sort { $0.0 < $1.0 } }
            if sortOrder == "Descending" { values.sort { $0.0 > $1.0 } }
            numbers = values.map { $0.1 }
        } else {
            var low = v.int("min", 1)
            var high = v.int("max", 100)
            if low > high { swap(&low, &high) }
            var values: [Int] = []
            if v.bool("unique") {
                let size = high - low + 1
                if count > size {
                    count = size
                    note = "Only \(size) different numbers exist in that range."
                }
                if size <= 200_000 {
                    values = Array(shuffled(Array(low...high)).prefix(count))
                } else {
                    var seen = Set<Int>()
                    while values.count < count {
                        let value = random(low...high)
                        if seen.insert(value).inserted { values.append(value) }
                    }
                }
            } else {
                values = (0..<count).map { _ in random(low...high) }
            }
            if sortOrder == "Ascending" { values.sort() }
            if sortOrder == "Descending" { values.sort(by: >) }
            numbers = values.map { String($0) }
        }
        return GeneratorResult(text: numbers.joined(separator: joiner), note: note)
    }

    // MARK: Random email addresses

    static func randomEmails(_ v: GeneratorValues) -> GeneratorResult {
        let count = v.int("count", 10, min: 1, max: maxCount)
        let style = v.string("style", emailStyles[0])
        let domainChoice = v.string("domain", emailDomains[3])
        var customDomain = v.string("custom", "example.com").trimmingCharacters(in: .whitespaces).lowercased()
        if customDomain.hasPrefix("@") { customDomain.removeFirst() }
        if customDomain.isEmpty { customDomain = "example.com" }
        let reserved = ["example.com", "example.org", "example.net"]

        var addresses: [String] = []
        var seen = Set<String>()
        var attempts = 0
        while addresses.count < count && attempts < count * 40 {
            attempts += 1
            let first = pick(RandomWordLists.firstNames).lowercased()
            let last = pick(RandomWordLists.lastNames).lowercased()
            let local: String
            switch style {
            case "firstlast": local = first + last
            case "first_last": local = first + "_" + last
            case "First initial + last": local = String(first.prefix(1)) + last
            case "first.last + number": local = first + "." + last + String(random(1...9999))
            case "Random letters and digits":
                let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789")
                local = String((0..<random(8...12)).map { _ in pick(characters) })
            default: local = first + "." + last
            }
            let domain: String
            switch domainChoice {
            case emailDomains[0], emailDomains[1], emailDomains[2]: domain = domainChoice
            case emailDomains[4]: domain = customDomain
            default: domain = pick(reserved)
            }
            let address = local + "@" + domain
            if seen.insert(address).inserted { addresses.append(address) }
        }
        var note = "example.com, .org and .net are reserved for examples, so these addresses can never belong to a real person."
        if domainChoice == emailDomains[4] && !reserved.contains(customDomain) {
            note = "A custom domain may be real. Don't send mail to these addresses."
        }
        if addresses.count < count { note = "Only \(addresses.count) different addresses are possible with these options." }
        return GeneratorResult(text: addresses.joined(separator: separator(named: v.string("separator", "New line"))), note: note)
    }
}
