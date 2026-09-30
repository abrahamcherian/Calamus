
# Calamus

A native macOS text and code editor, written from scratch in Swift and AppKit — no Electron, no third-party dependencies, just a fast, small app that feels like it belongs on your Mac. It was built one request at a time, and this guide walks through everything it can do today: tabs and split panes, syntax highlighting for eighteen languages, a full toolkit of text-formatting and random-data generators, voice dictation and read-aloud, JSON tools, a terminal launcher, and a deep Preferences setup for making it look and behave exactly the way you want. It has its own icon too — a gold reed pen (the *calamus* the name refers to), tip pointing down, on a clean white background.

Needs Swift 5.7 or later and macOS 12 or later.

## Build and run (on your Mac)

Install the command-line tools once: `xcode-select --install`

Then, in Terminal:

```
cd path/to/Calamus
./build_app.sh
open "build/Calamus.app"
```

(First launch: if macOS blocks it, right-click the app > Open.)

### Create an installer (.dmg)

To package the built app into a `.dmg` someone else can install by dragging Calamus into
Applications:

```
./build_app.sh
bash create_dmg.sh
```

The `.dmg` lands in `Releases/`, named after the version in `Resources/Info.plist` (for example
`Calamus_v0.30.12_2026-09-29_120000.dmg`). Calamus isn't code-signed with an Apple Developer ID,
so it's built ad-hoc-signed (`build_app.sh` already does this) — that's enough for it to launch at
all on Apple Silicon, but anyone installing it from the `.dmg` will still see an "unidentified
developer" warning the first time and need to right-click > Open once. The `.dmg` includes a short
"Read Before Installing.txt" with those steps.

## A guided tour of what's inside

### Tabs, windows, and split panes

Calamus uses macOS's own native window tabs, the same tab bar you see in Safari or Finder, so every open document lives as a tab in one tidy window instead of a pile of separate windows. From there:

A tab can be **pinned**, which does two things: it decorates the tab's label so it stands out, and it makes Calamus reopen that file automatically the next time the app launches — handy for the file you always want open, like a running notes document or a project's TODO list. Trying to close a pinned tab asks first, so you don't lose track of it by accident.

**Duplicate Tab** opens a second, independent tab with a copy of whatever you're looking at right now, unattached to any file on disk — a quick way to fork off an experiment without touching the original.

When you've got a lot of tabs open, **Close Tabs to the Right** and **Close Tabs to the Left** clear everything on one side of the tab you're currently on in a single move, which beats clicking a dozen little close buttons one at a time. Pinned tabs caught in the sweep still ask before they go.

And when one document isn't enough screen at once, **Split Horizontally** and **Split Vertically** open a second pane right inside the same window, showing a *different* open tab side by side with this one — pick which tab from the list Calamus shows you (if only one other tab is open, it fills the pane right away). Each pane stays exactly itself: its own file, its own undo history, its own saving — Split View just lets you see two of them at once, the way you'd drag a second window alongside the first, but without leaving the tab bar. **Change Split Tab** swaps which tab fills the pane without closing it first. Splitting horizontally stacks the panes top and bottom; splitting vertically puts them side by side. Choosing the same layout again removes the split, and choosing the other layout just flips the divider without losing your place. (Menu commands like Insert and Format always act on the tab you're on, not whichever pane you're looking at — only typing, clicking, and Read Aloud follow the pane that actually has focus.)

All of the tab commands above — pin, duplicate, close left/right, split — live in the Window menu, and also in a "Tab" section of the right-click menu in the editor itself (macOS doesn't give apps a way to add items to its native tab bar's own right-click menu, so the editor's own right-click menu is the closest stand-in, and it works just as well).

### Editing essentials

Underneath everything, Calamus is a fast, plain-feeling text editor: type, select, cut, copy, paste, undo and redo exactly like you'd expect. On top of that are a set of line-level tools grouped under Edit > Line Operations — duplicate a line, delete it, move it up or down, join it with the next line, sort lines alphabetically in either direction, strip out duplicate lines, and trim trailing whitespace from every line at once. Selected text (or the word under your cursor if nothing's selected) can be flipped to UPPERCASE or lowercase in one click, and comment toggling — turning the current line or selection into a comment and back, using whatever comment style the current language actually uses — is built in for every supported language, with a separate command for wrapping a selection in a block comment where the language has one.

Two word-count commands sit in the Edit menu and the right-click menu: one for the whole document, one for just your selection. Each reports word count, character count with and without spaces, line and paragraph counts, and a rough reading-time estimate.

### Finding things

The Find panel (a small floating window, so it stays out of your way) handles ordinary find-as-you-type searching, replace and replace-all, whole-word and match-case options, wraparound searching, and a genuine regular-expression mode with its own escape-sequence support for things like `\n` and `\t`. Selecting some text and asking Calamus to "use selection for find" loads it straight into the search field.

For searching across more than one file at once, **Find in Files** opens its own panel: give it a search term, a folder, and an optional file-name filter (like `*.swift; *.md`), tick a box if you want it to dig into subfolders too, and it hands back a results list of every match with the file, line and column, and a preview of the matching line. Double-clicking a result jumps straight to that spot in the file. It's smart enough to skip binary files, hidden folders, and common build/dependency directories like `node_modules` automatically.

### Syntax highlighting and languages

Calamus recognizes and colors eighteen languages out of the box: Swift, C/C++/Objective-C, Java, C#, Go, Rust, Kotlin, JavaScript and TypeScript, Python, Shell scripts, SQL, JSON, HTML/XML, CSS, YAML, Markdown, and INI/TOML-style config files, plus plain text for everything else. Opening a file detects its language from the extension automatically, but you're never stuck with the guess — the Format menu, and a language popup right in the status bar, let you switch languages for the current document at any time.

### Making it look right: fonts, colors, and themes

The Font & Colors window is where the editor's whole visual identity lives, and every change in it takes effect immediately across every open tab. Pick a font — Calamus ships its own set of coding fonts (Cascadia Code, JetBrains Mono, Fira Code, Source Code Pro, and DejaVu Sans Mono) so you get a good monospaced choice even on a fresh Mac, on top of whatever else you already have installed — and a size from 6 to 72 points. Choose from seven built-in themes (Light, Dark, Monokai, Solarized Light, Dracula, Nord, and Sepia) or set it to Automatic so it follows whatever appearance macOS itself is in, light or dark. If none of the themes are quite right, background and text color wells let you override just those two colors on top of whichever theme you've picked, and a Reset button puts them back.

From the same window you can set the tab width (2, 4, or 8 spaces), turn word wrap on or off, show or hide the line-number gutter, reveal whitespace and line-ending characters, highlight whichever line the cursor is currently on, and even choose whether Calamus' own menus use your editor font instead of the system font.

The line-number gutter itself isn't just decoration — click a line number to select that whole line, or drag down through several numbers to select a run of lines at once.

### The Insert menu: instant content

The Insert menu is a grab bag of things that are tedious to type by hand:

**Date and Time** offers a long list of ready-made formats, from a plain 24-hour clock to ISO 8601, RFC 2822, and Unix timestamps, in both your local time zone and UTC — pick one and it's inserted at the cursor. The same list is also available by right-clicking anywhere in a document.

**Horizontal Line** inserts a full-width rule made of dashes, equals signs, asterisks, tildes, underscores, box-drawing characters, or dots, plus a plain `---` Markdown rule; the line's width is a shared setting you control in Preferences.

**UUID** covers every practical UUID version — 1, 3, 4, 5, 6, 7, and 8, plus the all-zeros Nil UUID and all-F Max UUID — with the name-based versions (3 and 5) prompting for a namespace and a name, since those always produce the same result for the same input. A "Generate Multiple" command inserts a batch of up to 500 UUIDs of one version at once, one per line, and a Format submenu controls whether every UUID you insert comes out lowercase, UPPERCASE, without dashes, or wrapped in braces.

**Random Generator** opens onto eight focused little tools — usernames, passwords, pronounceable passwords, random strings, random words, filler/placeholder text, random numbers, and disposable-looking email addresses — each detailed further down. **Lorem Ipsum** inserts a quick chunk of filler Latin text at a few common lengths. **File Info** inserts the current file's name, its name without the extension, its full path, or just its containing folder's path. And **Comment Banner** prompts for a short title and builds a boxed, three-line heading comment using whatever comment style the current language uses.

Rounding it out, **Special Characters** organizes a couple hundred symbols — punctuation and typographic marks, math and unit symbols, currency signs, arrows, check marks and stars, and invisible spacing characters — into browsable groups so you're never stuck hunting for an em dash or a checkmark.

### The Random Generator toolkit

Each of these opens as its own small window with a live preview, a Generate Again button to reroll, and buttons to copy the result or insert it straight into your document. Every tool remembers its own settings, and you can set your own defaults for any of them (or tell Calamus to just remember whatever you used last) in Preferences.

- **Username Generator** builds usernames from adjective/noun/number combinations, with control over the style, separator, and letter casing.
- **Strong Password Generator** produces passwords of a chosen length with independent control over uppercase letters, lowercase letters, numbers, and symbols, an option to avoid confusable look-alike characters, and a live strength estimate.
- **Pronounceable Password Generator** builds passwords from syllable-like patterns so they're actually possible to read back or say out loud, with optional capitalization and trailing numbers or a symbol.
- **Random String Generator** produces raw strings from a chosen character set — letters and digits, letters only, hex, URL-safe characters, or a fully custom set you type in yourself — at any length.
- **Random Word Generator** pulls real words from a bundled word list within a length range you set, in your choice of casing and separator.
- **Filler Text** generates placeholder paragraphs, sentences, or words for mocking up layouts, with the option to start with the classic "Lorem ipsum" opener or wrap the output in HTML paragraph tags.
- **Random Number Generator** produces whole or decimal numbers within a range, with options for decimal places, no-repeats, sort order, and how the numbers are separated.
- **Random Email Generator** builds email-shaped addresses in several name styles, using the reserved example.com/example.org/example.net domains by default (so nothing you generate is ever a real inbox) or a custom domain of your choosing if you need one.

### The Text Formatting toolkit

Format > Text Formatting holds twelve tools that transform a selection — or the whole document, if nothing's selected — with a live preview before anything is applied:

- **Add Line Numbers** prefixes each line with a number, letter, or roman numeral, with control over the starting value and separator.
- **Add Commas to Numbers** formats raw numbers with thousands separators, in either the comma-and-period or period-and-comma convention.
- **Replace Smart/Straight Quotes** converts curly quotation marks to straight ones or back again.
- **Tabs to Spaces** and **Spaces to Tabs** convert between the two, with the latter able to target just leading indentation.
- **Pad Text** adds spaces (or any character you like) to the left or right of every line, either a fixed amount or up to a target total width.
- **Word Wrap** reflows text to a chosen line width, with an option to first rejoin each paragraph before rewrapping it.
- **Justify Text** wraps to a width and stretches each line so it ends exactly at that column.
- **Center Text** centers every line within a given width.
- **Tabularize Data** is the toolkit's heavy hitter: feed it CSV, tab-separated, pipe-separated, or otherwise delimited text (it can auto-detect the separator, or you tell it) and it turns it into aligned columns, a ready-to-paste Markdown table, an ASCII box table, or pipe-separated output, with control over alignment and whether the first row is a header. It also understands a JSON array of objects as input, turning API-style data straight into a table.
- **Sort Text** sorts lines, the words within each line, comma-separated items, or individual characters, with alphabetical, natural (so `item2` comes before `item10`), numeric, length-based, or shuffled ordering, plus options to ignore case and drop duplicates or empty lines.
- **Reverse Text** flips the whole document end to end, reverses the order of its lines, reverses the characters within each line, reverses word order, or reverses the letters within each word.

### JSON tools

Format > JSON covers the everyday JSON workflow: pretty-print with sorted or original key order, minify down to one line, and validate — which, on a broken file, jumps straight to the exact spot the error was found and explains what's wrong, or on a valid one reports how many objects, arrays, and values it contains and how deeply nested it gets. Quick fixed-indent shortcuts format with 2 spaces, 4 spaces, or tabs in one click, and Convert to Table hands a JSON array of objects straight to the Tabularize Data tool.

### URL and HTML encoding

Edit > URL Encode / Decode and Edit > HTML Escape / Unescape (both also available from the right-click menu) handle the conversions you need when moving text between a document and a URL or a web page: full percent-encoding or the lighter version that leaves a URL's own structural characters alone, decoding either way (including the `+`-means-space convention from form submissions), and HTML entity escaping and unescaping that understands both numeric entities and around seventy named ones, from `&amp;` to accented letters and currency symbols.

### Voice to Text and Read Aloud

Edit > Start Voice to Text turns on dictation, transcribing your speech straight into the document at the cursor — and unlike a lot of dictation tools, it keeps right on listening through pauses in your speech instead of stopping and making you start it again, so a natural conversational pace works fine. Words are written in as they're confirmed, one at a time, so nothing you've already said gets rewritten out from under you as you keep talking. A microphone button in the status bar mirrors the menu command for a one-click toggle.

Edit > Read Aloud does the reverse: it reads your current selection out loud, or if nothing's selected, reads from the cursor to the end of the document, using the system's speech synthesis. A speaker button sits right next to the microphone button in the status bar.

Both features are tuned in the Voice tab of Preferences: choose the recognition language for dictation (or leave it on System Default), decide whether to prefer on-device recognition for privacy and offline use, check your Microphone and Speech Recognition permission status with a direct link to fix it in System Settings if needed, and for Read Aloud, pick which installed voice to use and adjust its speaking rate, with a Test Voice button to preview your choice immediately.

### Markdown Preview

View > Markdown Preview swaps a Markdown document's editable view for a read-only rendered one — headers, bold and italic text, inline code, links, bulleted and numbered lists, blockquotes, fenced code blocks, and horizontal rules all render properly, on a clean white page regardless of whatever editor theme you're using. Toggle it off and you're straight back to editing; nothing about the preview ever touches what gets saved to disk.

### Open in Default Browser

For HTML and XML files, View > Open in Default Browser (⇧⌘B) hands the file straight to whichever browser macOS has set as your default — the same thing you'd get double-clicking it in Finder, but without leaving the editor. If you've made changes since the last save, Calamus asks whether to save first or show the browser the last-saved version, so you never get caught wondering why your edits aren't showing up. A file that's never been saved at all doesn't have anywhere on disk for a browser to open, so Calamus writes a throwaway temporary copy and opens that instead — handy for a quick look, though it won't keep updating itself as you keep typing the way a saved file would.

### Journal Mode

Format > Journal Mode turns a plain text document into a running log: the first time you type after being away for a while, Calamus inserts a dated banner at the end of the file and drops you onto a fresh line beneath it, so each session of writing gets its own clearly marked entry without any manual bookkeeping. How long counts as "away" is configurable in Preferences, from five minutes up to four hours, or you can set it to start a fresh entry every single time you open the file. Format > Add Journal Entry Now inserts that same banner on demand, whenever you want one, regardless of timing.

### Terminal integration

The Terminal menu bridges Calamus and macOS's own Terminal app: open a Terminal window right in the current file's folder, open one in a folder you pick, or — for a good range of common languages, including Python, Shell scripts, Swift, Go, Java, JavaScript, C, and C++ — run the current file directly and watch it execute in its own Terminal window, complete with its exit status reported when it finishes.

### Encodings, line endings, and printing

Format > Save Encoding covers UTF-8, UTF-8 with a byte-order mark, UTF-16 in both byte orders, Windows-1252, ISO-8859-1 (Latin-1), and Mac Roman; opening a file detects its encoding automatically, and if you ever choose an encoding that can't represent every character in your document, Calamus tells you exactly what won't survive before it lets a bad save happen. Format > Line Endings switches between Unix (LF), Windows (CRLF), and classic Mac (CR) line breaks, detected automatically on open and rewritten to match your choice every time you save.

Printing goes through the standard macOS print dialog (File > Page Setup and File > Print), including proper support for landscape orientation — a detail that's easy to get wrong, since macOS doesn't automatically widen the page for you, but Calamus handles it correctly either way.

### Preferences, all in one place

There are two separate settings windows, each with its own job. **Font & Colors** is exactly what it sounds like — the visual side of things, described above — and it's reachable straight from the app menu or the View menu. **File > Preferences** is everything else, organized into four tabs:

**General** holds Journal Mode's timing, the window and text-area transparency sliders (with an option to keep your transparency settings between launches instead of resetting each time), a shortcut back to Font & Colors, and a full Reset All Settings to Factory Defaults button for starting completely fresh.

**Insert** sets the shared line width used by Horizontal Line and Comment Banner, and the UUID format applied to every UUID you insert.

**Voice** holds every Voice to Text and Read Aloud setting described above: recognition language, on-device preference, permission status and quick links to fix it, Read Aloud voice, speaking rate, and a Test Voice button.

**Random Generator** lets you dial in your own default settings for every one of the eight generator tools, choose whether tools should remember whatever you used most recently instead, and reset any individual tool back to its built-in defaults.

### The status bar

Every editor window has a status bar along the bottom showing your current line and column, the length of your selection when you have one, the document's total character and line counts, the Voice to Text and Read Aloud buttons, the current line-ending style, the current encoding, and a language popup for switching the document's syntax highlighting on the fly.

## Not yet built

Code folding, macros, multi-caret/column editing, a function list, a document map, plugins, and user-defined custom languages.

## Support

Questions, bug reports, or feature requests: support@abrahamcherian.in

## Disclaimer

Calamus is free, open-source software provided "as is," with no warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement.

By downloading, installing, or using Calamus, you agree that you do so entirely at your own risk. The developer is not liable for any damages, data loss, or other losses of any kind – direct, indirect, incidental, or consequential – arising from your use of, or inability to use, this software, including losses caused by any inaccuracies, bugs, or unexpected behavior it may produce.

You are solely responsible for backing up your work and independently verifying any results before relying on them.

Calamus shows this same disclaimer once, the first time it's launched, and won't open until it's accepted (Preferences > General > Reset All Settings to Factory Defaults will show it again).

## License

Calamus is provided as is, with no warranty of any kind, express or implied. It's free, open-source software with no ads, no subscription, and no telemetry.
