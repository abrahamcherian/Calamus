# Calamus – change log

Every update is recorded here, and a full source backup (zip) for each version is kept in `Backups/`.
Newest first. Dates are when the version was delivered. (Versions before 0.18.0 shipped as "Notepad Mac"; 0.18.0 through 0.27.0 shipped as "WriteNotes" — same app both times, renamed.)

## v0.30.12 – 2026-09-29 – Added a .dmg installer script

- New `create_dmg.sh`: packages the already-built `build/Calamus.app` into a distributable `.dmg` (drop Calamus into the Applications shortcut inside it), saved to `Releases/`, named after the version in `Resources/Info.plist`. Run it after `./build_app.sh`, with `bash create_dmg.sh`.
- The `.dmg` includes a short "Read Before Installing.txt" explaining that Calamus is unsigned (no Apple Developer ID yet), so the first launch needs a right-click > Open to get past Gatekeeper's "unidentified developer" warning.
- README.md gained a "Create an installer (.dmg)" section documenting this.
- `backup.sh` now also excludes `Releases/*` from source backup zips, same as it already does for `build/*` - installer .dmg files don't belong in a source backup.
- No app code changed - this is a packaging/tooling addition only.

## v0.30.11 – 2026-09-29 – Fixed the launch disclaimer's stray overflow words

- Not actually a font-size problem: v0.30.10's monospaced block sized itself to exactly its measured width with zero slack, and real text layout (kerning, sub-pixel rounding) came out very slightly wider than that estimate for most lines - just enough to wrap each line's last word onto an unindented second line that appeared to spill outside the dialog's left edge. A small fixed buffer is now added on top of the measured width so every line has headroom and none of them wrap. Font size (12pt) is unchanged.

## v0.30.10 – 2026-09-29 – Launch disclaimer now uses Abraham's hand-formatted 70-column layout

- The launch disclaimer's body now shows Abraham's own hand-formatted text: a fixed 70-column block, each line padded with leading/trailing and inter-word spaces so it reads as a justified block of monospaced text. It's word-for-word identical to the previous wording, only the line breaks/spacing changed, so README.md and Resources/ReadMe.txt don't need updating.
- Because that manual spacing only lines up visually in a monospaced font, the launch disclaimer's dialog now switches to a monospaced font and left alignment for this text, and sizes/centers the resulting block by its own natural width rather than stretching it across the dialog's full column. About Calamus is unaffected — it still shows the plain prose disclaimer, dynamically wrapped and centered, in the regular system font.
- `DisclaimerPanel.present`/`run` gained a `monospaced` parameter alongside the existing `alignment` one, so each dialog picks both independently.

## v0.30.9 – 2026-09-29 – About Calamus text is now centered, not justified

- About Calamus's body text (credits lines plus the disclaimer) is now center-aligned, per Abraham's explicit formatting example. The launch disclaimer is unchanged and stays justified.
- `DisclaimerPanel.present`/`run` now take an `alignment` parameter instead of hardcoding `.justified` for both dialogs, so each caller picks its own.

## v0.30.8 – 2026-09-29 – Disclaimer/About body text back to 12pt

- The body text in the launch disclaimer and About Calamus is back to 12pt (it had grown to 15pt over a few rounds of readability tweaks). The title above it stays at 20pt bold.

## v0.30.7 – 2026-09-29 – Fixed the disclaimer/About body text going completely blank

- v0.30.6's NSTextView switch had a real bug: the text view's height was never given an explicit Auto Layout constraint, left instead to be inferred from its `intrinsicContentSize` - which for an NSTextView has a chicken-and-egg problem, since it needs its own resolved width before it can compute a height from wrapped text. Auto Layout evidently resolved that ambiguity by collapsing the text view to zero height, leaving the scroll area empty (correctly sized, since that came from a separate, already-reliable measurement, but with nothing visible inside it).
- The text view's height is now set directly from that same measurement, as an explicit Auto Layout constraint - no different, in spirit, from the width constraint that was already working correctly - so its size no longer depends on `intrinsicContentSize` at all.

## v0.30.6 – 2026-09-29 – Switched body text to NSTextView for reliable justification

- v0.30.5's justified body text (a wrapping NSTextField) looked like it lost its margin entirely - that's very likely because NSTextField's simpler, cell-based renderer doesn't reliably honor justified alignment. The body text (the disclaimer and the About Calamus text) is now a real NSTextView instead, which has proper, native justification support through TextKit, laid out with the same fixed-width, pinned-to-all-four-edges Auto Layout technique that already worked correctly for wrapping/width. Its width still comes only from an Auto Layout constraint, never a manually-set frame, so it doesn't have the earlier clipping bug either.
- Margin is back to 50pt each side (700pt text column in the 800pt dialog) - the same numbers as v0.30.4, which is the last version with no complaints about the margin itself.

## v0.30.5 – 2026-09-29 – More margin around the text, and true justified alignment

- The 700pt text column left only 50pt of margin on each side of the 800pt-wide dialog, which read as too tight. The text column is now 660pt, with 70pt of margin on each side.
- Body text (the disclaimer and the About Calamus text) is now genuinely **justified** - flush on both the left and right edges, with the text system adding a bit of extra spacing between words on each line to make that happen (except the last line of a paragraph, which stays natural-width, same as any justified column of text) - rather than just centered line by line as before. The title above it stays centered, since it's a single short line where justification wouldn't do anything.

## v0.30.4 – 2026-09-29 – Wider dialog (800pt), 700pt centered text column, centered buttons

- The disclaimer/About dialog is now 800pt wide, with the title and body text wrapping at a 700pt-wide column centered within it (50pt of margin on each side).
- **I Accept**/**Decline and Quit** (and About's **OK**) are back to their natural size, centered under the text, instead of stretched full-width. The earlier full-width attempt used an NSStackView alignment value that doesn't reliably do what its name suggests for a vertical stack, which is very likely what was pushing the buttons off-center in v0.30.2/v0.30.3 too - centered alignment is the one AppKit actually documents for this, so it's what both the buttons and the text column now use.

## v0.30.3 – 2026-09-29 – Fixed text clipping and widened the disclaimer/About dialog

- v0.30.2's dialog had a real bug: the body text was laid out by hand-tracking an NSTextView's frame and text container, and that tracking didn't reliably keep up, so lines were wrapping at the wrong width and getting clipped off the right edge of the dialog (with the buttons pushed out of alignment as a side effect). The body text is now a plain wrapping label laid out with ordinary Auto Layout constraints instead — pinned to a fixed width inside the scroll area, free only to grow taller — which is the standard, well-tested way to put Auto Layout content in a scroll view, and doesn't have that failure mode.
- The dialog is also now wider - 777pt instead of 480pt - so more of each paragraph fits per line before wrapping.
- The disclaimer and About Calamus text itself, the scroll-to-accept behavior, and everything else from v0.30.2 are unchanged.

## v0.30.2 – 2026-09-29 – Disclaimer and About are now a custom dialog (bigger text, scroll-to-accept)

- The v0.30.1 fix tried to enlarge NSAlert's own text fields after the fact, which turned out not to reliably take effect and still read too small. The disclaimer and About Calamus are now a purpose-built dialog (`LegalDisclaimer.swift`'s new `DisclaimerPanel`) instead of NSAlert, with the title fixed at 20pt bold and the body text at 15pt — no longer at the mercy of NSAlert's internals.
- **The dialog no longer scrolls unless it actually needs to.** If the text fits at that size, everything shows at once with no scrollbar, same as before. If it doesn't fit, a scrollbar appears — and, on the launch disclaimer specifically (About's OK button doesn't need this, since there's nothing to decline), **I Accept stays disabled until the text has been scrolled all the way to the bottom**, so it can't be accepted without having passed in front of the user first. Decline and Quit is always clickable.

## v0.30.1 – 2026-09-29 – Larger text in the disclaimer and About dialogs

- The disclaimer and About Calamus text was rendered at the system default label size, which read small in a dialog this size. Both dialogs (`LegalDisclaimer.swift`) now show their title at 16pt bold and their body text at 14pt, matched by NSAlert's own text fields (it has no direct font-size setting) before the dialog is shown, so the larger text is part of the initial layout rather than something the window is resized around afterward.

## v0.30.0 – 2026-09-29 – Liability disclaimer, required at first launch

- New **liability/warranty disclaimer**, added to About Calamus and to the end of `README.md` (below Support), and shown in full to `Resources/ReadMe.txt`. It states that Calamus is provided free, "as is," with no warranty of any kind, and that the developer isn't liable for any damages, data loss, or other losses arising from using it, including losses caused by inaccuracies or bugs — and that you're responsible for backing up your own work and verifying results before relying on them. (This is Abraham's own liability disclaimer, drafted at his request — not legal advice, and worth a lawyer's review if real legal protection matters to you.)
- **The disclaimer must be accepted before Calamus opens.** The very first launch after this update shows it as a dialog with **I Accept** / **Decline and Quit** — declining quits immediately, before any menu, window, or document appears. Once accepted, it's remembered (like every other setting) and won't show again on later launches, unless Preferences > General > Reset All Settings to Factory Defaults is used, which clears the "accepted" flag along with everything else.
- **About Calamus is now a wider, taller alert instead of the system's standard About panel.** The standard panel's credits area is a small, fixed-height scrolling text view — too cramped for the full disclaimer text alongside the usual credits. The replacement widens to fit a full paragraph width and grows to whatever height the text needs, so nothing in it ever needs to scroll.
- New: `LegalDisclaimer.swift` (the disclaimer text, the launch gate, and the widened About alert, all in one place — see its own doc comments for how the three copies of this text, here plus README.md plus ReadMe.txt, are meant to be kept in sync by hand). `Preferences.disclaimerAccepted` (Theme.swift) stores whether it's been accepted.

## v0.29.3 – 2026-09-29 – Support email added

- Added a support contact, **support@abrahamcherian.in**, to the About panel, the bundled Read Me note, and README so there's a clear way to reach out with questions, bug reports, or feature requests.
- No behavior change otherwise.

## v0.29.2 – 2026-09-29 – Internal source folder and identifiers renamed to Calamus

- Finishes the naming cleanup that v0.28.0 (the WriteNotes → Calamus rename) deliberately deferred: the source folder and the last few internal, invisible identifiers that still said `NotepadMac` now say `Calamus` instead. No feature or behavior change.
- `Sources/NotepadMac/` → `Sources/Calamus/`. `Package.swift`'s `name`/target `name`/`path`, and `build_app.sh`'s `-module-name` and source glob, all updated to match. The README's `cd path/to/NotepadMac` build instruction is now `cd path/to/Calamus`.
- Three runtime-only string identifiers renamed to match: `TerminalLauncher.swift`'s temp-directory name for "Run Current File" scripts (`NotepadMacRun` → `CalamusRun`), `TextDocument.swift`'s window-tab-grouping identifier (`NotepadMacEditorTab` → `CalamusEditorTab`), and `Theme.swift`'s preferences-changed notification name (`NotepadMacPreferencesChanged` → `CalamusPreferencesChanged`). All three are purely in-memory/runtime values, never persisted to disk or shown to the user, so this is safe to change without a settings-reset consequence (unlike the bundle-id change in v0.28.0).
- **Deliberately left unchanged, same reasoning as v0.28.0:** `TextDocument`'s `@objc(NPTextDocument)` runtime class name and `Info.plist`'s matching `NSDocumentClass` value (`NPTextDocument`) — these have to stay in lockstep for document-type registration, are never shown to the user, and don't literally contain "NotepadMac" (they're short for "Notepad", the original working name, not this specific rename). Every historical reference to an actual, unrenamed backup filename (`Backups/NotepadMac_v0.4.0_2026-09-25.zip`, `Backups/NotepadMac_v0.5.0_2026-09-25.zip`, both mentioned in source comments and in this changelog's own v0.4.1/v0.4.2 entries) was left as-is, since those files genuinely still have those names on disk — changing the text would make the comment wrong, not right.
- **Not done in this pass, and needs Abraham to do it by hand:** the session that made this change had no shell/file-manager access to the Mac, only the ability to create and update individual files — it could not delete or rename anything. So: (1) the old `Sources/NotepadMac/` folder is still sitting on disk, now unused (nothing in the build points at it anymore) but not deleted — safe to remove once you've confirmed the new `Sources/Calamus/` builds correctly. (2) The project's own top-level folder is still literally named `NotepadMac` (`.../Notepad++Application/NotepadMac`) — purely cosmetic, doesn't affect the build (every path in this project is relative), safe to rename in Finder whenever convenient, but will need reconnecting in the Claude desktop app afterward since the connected-folder path will have changed.
- **Unverified — no compiler in this session** (see "No compiler here" in the release checklist): this is a small, mechanical set of renames, but please run `./build_app.sh` yourself before relying on it.

## v0.29.1 – 2026-09-29 – App icon redesigned: white background, pen pointing down

- Reworked the app icon from v0.29.0: the background is now a clean white (a barely-there warm-white gradient, not a flat white swatch) instead of the dark indigo-to-black gradient, and the reed pen now points downward (tip toward the bottom-left, cap toward the top-right) instead of upward toward the top-left — the whole icon was rotated 90° counterclockwise from the v0.29.0 artwork rather than redrawn from scratch, which is why the pen's diagonal tilt is the same, just turned a quarter turn.
- The pen itself (gold/bronze cylindrical shading, split-nib tip, contour outline) is unchanged; only the background color and the overall orientation changed. The drop shadow under the pen was lightened and warmed slightly (soft grey-brown instead of black) so it reads correctly against the new white background instead of looking muddy.
- Replaces `Resources/Calamus.icns` in place — same filename, same `CFBundleIconFile` key from v0.29.0, so no `Info.plist`/`build_app.sh` changes beyond the version bump.
- No feature or behavior change beyond the icon artwork.

## v0.29.0 – 2026-09-29 – Custom app icon

- Calamus now has its own app icon — a gold reed pen (the calamus the name refers to) laid diagonally across a deep indigo-to-black gradient, in the rounded-square (squircle) shape macOS expects for app icons. Shows in the Dock, Finder, Launchpad, and the ⌘-Tab switcher once you rebuild.
- Added `Resources/Calamus.icns` — a single file bundling every size macOS wants (16, 32, 64, 128, 256, 512 and 1024 px, the same set `iconutil` would produce from a `.iconset` folder) — and pointed `Info.plist`'s new `CFBundleIconFile` key at it. `build_app.sh` now copies it into `Contents/Resources/` alongside the bundled fonts and the Read Me note.
- **If the icon doesn't show up right after rebuilding:** that's a well-known macOS quirk, not a bug here — Finder and the Dock cache an app's icon by its path, and a freshly rebuilt `.app` at the same path can keep showing the old blank/generic icon until the cache notices the change. If that happens, quit and relaunch Calamus once, or run `touch build/Calamus.app` and relaunch, or, failing that, move `Calamus.app` out of `build/` and back in — any of these forces Finder to re-read it.
- No feature or behavior change beyond the new icon.

## v0.28.0 – 2026-09-29 – Renamed to Calamus

- The app is now called **Calamus** — Latin for "the pen" (and a reed once cut and used as one) — replacing **WriteNotes**. Renamed everywhere it's visible: the About/Hide/Quit menu items, the app's display name, the window/build output (`build/Calamus.app`), the bundled Read Me note, README, and this changelog.
- The bundle identifier changed from `com.abrahamcherian.writenotes` to `com.abrahamcherian.calamus`, and the built app's executable is now named `Calamus`. **This means macOS treats it as a different app for saved settings** — on first launch after updating, it will start from factory defaults (JetBrains Mono, size 18, black background, `#CC9933` text) rather than picking up whatever you had set before. Your old settings aren't lost; they're just parked under the old identifier (as they were the last time this happened, in v0.18.0's rename from Notepad Mac to WriteNotes). To bring a specific setting back, open Font & Colors (⌘,) or Preferences (⌥⌘,) and set it again — it only takes a moment since there are just a handful of settings. Any pinned tabs or the last-document-on-launch memory will also start empty under the new identifier for the same reason.
- Also removed the last few lingering internal comments comparing specific behaviors to Notepad++ (search-mode radio buttons, line-ending styles, line operations, the tab bar) — none of these were user-visible, but the app's own source no longer references Notepad++ anywhere either, matching what the About panel and README have said since v0.22.0.
- No feature or behavior change beyond the identity and bundle-id update above — this is a naming/identity update only.

## v0.27.0 – 2026-09-29 – Open HTML/XML files in your default browser

- New **View > Open in Default Browser** (⇧⌘B), enabled for HTML/XML files (matching the same "HTML / XML" language Format > Language and syntax highlighting already use — covers `.html`, `.htm`, `.xhtml`, `.xml`, `.svg`, and friends). Hands the file straight to whichever browser macOS has set as your default, exactly as if you'd double-clicked it in Finder.
- If the file has unsaved changes, WriteNotes asks first — **Save and Open**, **Open Saved Version**, or **Cancel** — so the browser never silently shows a stale copy without you knowing. A file that's never been saved at all (no location on disk yet) gets written to a throwaway temporary copy instead, so there's still something for the browser to show; that copy is a one-time snapshot and won't keep itself in sync with further edits the way a real saved file does.
- New: `EditorViewController.openInBrowser(_:)`.

## v0.26.1 – 2026-09-29 – Build fix: v0.26.0's large-file highlighting loop didn't compile

- **Fixed:** "cannot convert value of type 'Any' to expected argument type 'NSTextView'" in `highlightNow()`. The line combining this pane with any other windows mirroring this document (`[textView] + externalMirrors.map({ $0.textView })`, added in v0.26.0's Split View redesign) is a known Swift type-checker trap: mixing an array literal, the `+` operator, and a trailing-closure `.map` in one expression can defeat type inference, and the compiler silently fell back to treating the combined array as `[Any]` instead of `[EditorTextView]` — which then failed to convert where each element got passed into a function expecting `NSTextView`. Rewritten as an explicitly-typed `[EditorTextView]` array built with `append(contentsOf:)` instead, which sidesteps the inference trap. No behavior change — this only affects whether the app compiles.

## v0.26.0 – 2026-09-29 – Split View now shows two different tabs, not two views of the same file
- **Changed:** Split View used to open a second pane on the *same* document — type in either pane and it showed up in both, since they were really just two windows onto one file. That's no longer how it works. **Split Horizontally** and **Split Vertically** now ask which *other* open tab should fill the new pane (skipping the prompt when there's only one other tab open), and each pane stays completely independent from then on: its own file, its own undo history, its own saving. It's the same idea as opening a second window next to the first, just without leaving the tab bar.
- New **Change Split Tab…** (Window menu, and the right-click "Tab" submenu): swaps which other tab is showing in the split pane, without closing and reopening it.
- Menu commands that act on "the document" (Insert, Format, Find/Replace, Voice to Text) still always act on the tab you're on, not whichever pane you're looking at — same as before. Only typing, clicking, and Read Aloud follow whichever pane actually has focus. The status bar always shows this tab's own stats now too (previously it briefly could have shown the split pane's stats when that pane was focused, which no longer makes sense once the pane is a different file).
- If the tab currently filling a split pane gets closed elsewhere, the split pane closes cleanly along with it rather than being left pointing at a file that's gone.
- New: `EditorViewController.beginSplit(with:vertical:)`, `changeSplitTab(_:)`, `presentSplitTabPicker(vertical:)`, `otherOpenDocuments()`, `pickDocument(from:title:)`, `externalMirrors`, `splitDocumentEditor`, `mirroredBy`, `documentWillClose()`, `removeSplitIfMirroring(_:)`; `TextDocument.close()` now calls into `documentWillClose()` before closing.

## v0.25.6 – 2026-09-29 – Fixed: Split Horizontally didn't visibly split the editor
- **Fixed:** Split Horizontally (Window menu, ⇧⌘', or right-click > Tab) appeared to do nothing — no second pane showed up. The cause was in how the split pane's size was decided: NSSplitView's Auto Layout support keeps both panes pinned to the window edges and to the divider between them, but nothing in that arrangement actually demands an *even* split — with no other constraint fixing either pane's size, the newly added pane could end up with next to no space at all. That's exactly what happened for a horizontal split starting from the un-split state (Split Horizontally doesn't change the split view's orientation flag, since it's already in that orientation by default), while a vertical split happened to divide evenly as an incidental side effect of that orientation flag actually changing. Both cases now explicitly set the new divider to the midpoint (50/50) the moment a pane is added or re-oriented, so the split always shows two evenly sized panes immediately, regardless of which direction is picked first.
- Also worth calling out, since a screen with two panes make it obvious for the first time: **typing in one pane appears in the other pane too, on purpose.** Both panes are two views onto the exact same document (the same underlying text storage) — this is the same behavior as splitting a file in Notepad++ or VS Code, not a bug. If that's not what you had in mind for Split View (for example, if you wanted the second pane to hold a different file instead), let me know and I can look at what that would take.
- New: `EditorViewController.centerSplitDivider()`.

## v0.25.5 – 2026-09-29 – README fix: the build command block wasn't rendering in some Markdown previewers
- **Fixed:** the "Build and run" code block sat indented inside a numbered list item (`2. In Terminal: ` followed by an indented ` ``` ` fence) — valid CommonMark, since a fence lines up with its list item's own indentation, but some simpler Markdown previewers don't handle an indented fence and show the backticks and commands as plain text instead of a code block. Reworded that section as plain paragraphs with the code fence starting at the very left margin, which every Markdown renderer handles. No other code block in the README was indented the same way. No app behavior changed — this is a documentation-only fix.

## v0.25.4 – 2026-09-29 – Build fix: NSSpeechSynthesizer.voice isn't a settable property
- **Fixed:** "cannot assign to value: 'voice' is a method." Checked against Apple's own current documentation this time rather than guessing again: `voice`/`setVoice(_:)` on `NSSpeechSynthesizer` really are a separate getter method and setter method (`- voice`, `- setVoice:` in the docs' own listing), not a combined Swift property the way `rate` and `volume` are — this isn't specific to this project's older SDK, it's just how that particular pair has always been imported. `TextReader.speak(_:)` now calls `synthesizer.setVoice(...)` (discarding its `Bool` success result — an invalid saved voice identifier just falls back to whatever voice was already in effect, rather than failing Read Aloud outright) instead of assigning `synthesizer.voice = ...`. Confirmed while at it that `rate` and `availableVoices` are genuinely plain properties, so nothing else needed to change.

## v0.25.3 – 2026-09-29 – Build fix: split-view code reached a compiler error the Voice preferences fixes had been masking
- **Fixed:** two new errors in `EditorViewController.split(vertical:)` (the Split View code from v0.25.0) — a build only gets past a file's *first* errors, so these hadn't shown up until the v0.25.1/v0.25.2 fixes above cleared the errors that came earlier in the same file. `.greatestFiniteMagnitude` is ambiguous on this SDK when written without a type prefix (it could mean `CGFloat.greatestFiniteMagnitude` or `Double.greatestFiniteMagnitude`) — every other place in the codebase already spells it out as `CGFloat.greatestFiniteMagnitude`, but the two new lines in `split(vertical:)` used the short form. Fixed to match. (A knock-on error on the following line, "reference to member 'width' cannot be resolved without a contextual type" on `tv.autoresizingMask = [.width]`, was the compiler losing its footing after the ambiguity above — it needed no change of its own once that was fixed.)
- Also cleaned up an unrelated compiler *warning* (not an error, but harmless to fix while in the area): `highlightNow()`'s outer `container` binding had become unused once large-file highlighting was extended to check both panes' containers individually.

## v0.25.2 – 2026-09-29 – Build fix: NSSpeechSynthesizer.VoiceName isn't a plain String on this SDK
- **Fixed:** after the v0.25.1 fix, the build failed one step further in with "cannot convert value of type 'NSSpeechSynthesizer.VoiceName' to expected argument type 'String'". Unlike current online Apple documentation (which describes `NSSpeechSynthesizer.VoiceName` as a plain `String` typealias), on this project's SDK (Swift 5.7.2 / the macOS 12 Command Line Tools SDK) it compiles as its own distinct `RawRepresentable` type, not interchangeable with `String`. Every place that read a voice identifier out of `NSSpeechSynthesizer.availableVoices`/`attributes(forVoice:)` now unwraps it with `.rawValue`, and the one place that hands a saved identifier back to `NSSpeechSynthesizer` (`TextReader.speak(_:)`) now rewraps it with `NSSpeechSynthesizer.VoiceName(rawValue:)`. `Preferences.readAloudVoiceIdentifier` itself is unchanged — still a plain `String`, since that's what `UserDefaults` can store; only the two conversion points at the `NSSpeechSynthesizer` boundary changed.

## v0.25.1 – 2026-09-29 – Build fix: Preferences > Voice failed to compile
- **Fixed:** the build failed with "cannot call value of non-function type '[NSSpeechSynthesizer.VoiceName]'" in `AppPreferencesWindowController.swift`. On this SDK, `NSSpeechSynthesizer.availableVoices` is imported as a static property (an array), not a method — the v0.24.0 code called it as `availableVoices()`, which doesn't compile. Changed to `NSSpeechSynthesizer.availableVoices` (no parentheses). No behavior change once it builds — this only affects whether the app compiles.

## v0.25.0 – 2026-09-28 – Split view, and more tab commands (right-click, or the Window menu)
- New **Split Horizontally** / **Split Vertically** (Window menu, ⇧⌘' / ⇧⌘\, or right-click > Tab): opens a second pane on the same document, so you can see or edit two different places in the file at once. Horizontal splits into a top and bottom pane; vertical splits into a left and right pane. Both panes are fully editable and always show the exact same text (they share the file's underlying storage) — only the scroll position and cursor are independent per pane. Font, theme, word wrap, line numbers and every other view setting apply to both. Picking the same split direction again removes the split; picking the other direction re-orients an existing split instead of opening a third pane. Insert/Format menu commands, Find and Replace, and Voice to Text always act on the main (first) pane; typing, clicking and Read Aloud follow whichever pane has focus.
- New tab commands, both on the **Window menu** and on the editor's own **right-click menu, under a new "Tab" submenu**: **Close Tabs to the Right** and **Close Tabs to the Left** (each pinned tab in range still asks before closing, same as ⌘W), plus the existing Duplicate Tab and Pin Tab now also appear in the right-click menu, not just Window. (macOS doesn't expose a way for an app to customize the native tab bar's own right-click menu — there's no public API for it — so these live on the editor's right-click menu and the Window menu instead, which is the closest available equivalent to "right-click a tab.")
- New: `AppDelegate.closeTab(_:)`/`closeTabsToRight(_:)`/`closeTabsToLeft(_:)`/`tabsExist(after:)`, `EditorViewController.splitView`/`split(vertical:)`/`removeSplit()`/`splitHorizontally(_:)`/`splitVertically(_:)`/`activeTextView`, a "Tab" submenu in `EditorTextView.menu(for:)`.

## v0.24.0 – 2026-09-28 – Read Aloud, and Voice settings in Preferences
- New **Edit > Read Aloud** (⇧⌘R), with a matching speaker button in the status bar next to the microphone: reads the current selection aloud, or from the cursor to the end of the document if nothing is selected. Click again (now reading "Stop Reading Aloud") to stop. Uses `NSSpeechSynthesizer` — no permission prompt needed, unlike Voice to Text.
- New **Preferences > Voice** tab (File > Preferences…, ⌥⌘,): recognition language for Voice to Text (System Default, or any language Speech Recognition supports), a "prefer on-device recognition" toggle, live Microphone/Speech Recognition permission status with one-click links to the matching System Settings privacy pane, and — for Read Aloud — a voice picker (every voice installed on the Mac), a speaking-rate slider, and a "Test Voice" button that speaks a sample sentence with the current settings.
- **Reset All Settings to Factory Defaults** (Preferences > General) now also resets the new Voice settings back to System Default / on-device-preferred / default rate.
- New: `TextReader.swift` (an `NSSpeechSynthesizer` wrapper, mirroring how `VoiceTranscriber.swift` wraps Speech + `AVAudioEngine`), `Preferences.voiceRecognitionLocale`/`voiceRequiresOnDeviceRecognition`/`readAloudVoiceIdentifier`/`readAloudRate`, `EditorViewController.readButton`/`toggleReadAloud(_:)`/`refreshReadButtonState()`, a new "Voice" tab in `AppPreferencesWindowController.swift`. `VoiceTranscriber` now reads its recognition language and on-device preference from `Preferences` instead of always using the system locale and forcing on-device recognition.

## v0.23.3 – 2026-09-28 – Voice to Text (and other inserts) now match the editor's text color on a brand-new document
- **Fixed:** starting a new Untitled document and using Voice to Text as the very first thing typed into it inserted the words in plain black, system-font text instead of the editor's actual font and text color (gold/brown by default). The shared `apply(_:)` helper that Voice to Text (and many other Insert/Format commands) use to write text into the document was replacing characters directly in the text storage, which only inherits formatting from an adjacent character — with nothing yet in a brand-new document, there was nothing to inherit from, so AppKit fell back to its bare default. `apply(_:)` now explicitly reapplies the editor's current typing attributes (font, color, paragraph spacing) to whatever it just inserted, the same way normal typing and the Journal Mode banner (fixed for the same reason back in v0.15.1) already do — so this is now fixed everywhere `apply(_:)` is used, not just for Voice to Text.

## v0.23.2 – 2026-09-28 – Voice to Text inserts word by word, Markdown Preview actually renders rich text
- **Fixed:** Voice to Text used to replace the whole in-progress phrase with each update, which looked like text was being deleted and retyped as you spoke. It now inserts one word at a time and never edits or removes a word once it's on the page: each word is written as soon as the next word after it confirms it's settled (or the segment/dictation ends), so what's already there stays put while new words keep appearing after it.
- **Fixed:** Markdown Preview wasn't actually rendering rich formatting — headers, bold/italic, and inline code all showed as plain uniform text, just with a `•` in front of list lines. The renderer was letting Foundation's Markdown parser's own default font override the size/weight each block was supposed to use (a header's bold larger font, a blockquote's italic, and so on), instead of combining the two. It now rebuilds each run's font from the block's intended font, layering on whatever bold/italic/code emphasis the parser found, so headers are genuinely bigger and bold, `**bold**`/`*italic*` show correctly, and `` `inline code` `` renders in monospace.
- New: `EditorViewController.voiceCommittedWords`/`voicePendingWord`/`applyVoiceUpdate(_:)`/`flushPendingVoiceWord()`/`insertVoiceWords(_:)`.

## v0.23.1 – 2026-09-28 – Voice to Text stays listening, Markdown Preview colors, landscape printing
- **Fixed:** Voice to Text stopped listening after every short pause, needing Start clicked again each time. It now keeps listening continuously until you stop it — Apple's speech recognizer still ends a "segment" after a pause, but WriteNotes immediately starts the next one behind the scenes, without dropping the microphone, so it feels uninterrupted. There's also now a small microphone button in the status bar (bottom right, next to the language menu) as a one-click alternative to the Edit menu item — it turns into a red "Stop" button while listening.
- **Fixed:** Markdown Preview had a transparent background, so it showed through to whatever was behind the window (or looked broken in a dark theme) instead of a normal document. It's now always a plain white page with black text — the standard look for a rendered Markdown preview — regardless of which editor theme is active.
- **Fixed:** printing with Page Setup's Orientation set to Landscape still laid the text out for a narrow portrait-width page. `NSPrintInfo.paperSize` doesn't swap itself for landscape — WriteNotes now swaps it manually when orientation is landscape, so the printed text actually uses the wider landscape width.
- New: `VoiceTranscriber.onSegmentEnd`, `EditorViewController.voiceButton`/`refreshVoiceButtonState()`.

## v0.23.0 – 2026-09-28 – Voice to Text, Markdown Preview
- New **Edit > Start Voice to Text** (⇧⌘V): dictates speech into the document at the cursor. Uses Apple's Speech Recognition, on-device when the current language supports it, and asks for microphone and speech-recognition permission the first time it's used (System Settings > Privacy & Security if you need to change it later). Each partial result replaces what's been inserted so far, the way system dictation works, so a misheard word gets corrected in place as recognition catches up. Click the same menu item (now reading "Stop Voice to Text") or quit the app to stop; the microphone is released either way.
- New **View > Markdown Preview** (⇧⌘M): renders the current Markdown file — headers, **bold**/*italic*, `code`, links, lists, blockquotes, horizontal rules, fenced code blocks — in a read-only view, without ever touching what's saved to disk. Only enabled for files WriteNotes recognizes as Markdown (Format > Language, or a `.md`/`.markdown`/`.mdown` file); toggle it off to go back to editing.
- New: `VoiceTranscriber.swift` (a small `AVAudioEngine`/`SFSpeechRecognizer` wrapper), `MarkdownPreview.swift` (a self-contained line-based Markdown renderer, using Foundation's `NSAttributedString(markdown:)` for inline styling within each line). Added `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to `Info.plist` (WriteNotes isn't sandboxed, so no entitlements file was needed).

## v0.22.0 – 2026-09-28 – UUID count field fix, higher max, About panel cleanup
- **Fixed:** Insert > UUID > Generate Multiple's "How many" field would accept anything you typed — including numbers far past the limit — and only clamp it silently when you clicked Insert. It now clamps live as you type, the same way the Random Generator's own "How many" field already behaved, so the box never shows a number it won't actually use.
- **Raised the limit** on Generate Multiple from 100 to **500** UUIDs per batch. (The Random Generator tools elsewhere keep their own 100 limit — this change is just for the UUID sheet.)
- **About WriteNotes** no longer mentions Notepad++; it now closes with a short "provided as is, no warranty" disclaimer line. The same disclaimer, spelled out in full, is now in `README.md` under a new License section. (`README.md`'s opening description was also reworded to drop the same Notepad++ mention.)
- New: `CountFieldClamp` (in `EditorViewController.swift`), `UUIDGenerator.maxMultipleCount`.

## v0.21.0 – 2026-09-28 – Reopens your last document; Read Me is for first launch only
- The very first launch (nothing has ever been opened yet) still shows the bundled **Read Me** note, as before.
- Every launch after that reopens whichever document tab you had frontmost when you last used WriteNotes — no file passed in and no pinned tabs to reopen otherwise still fall back to Read Me. If that remembered file has since been moved, renamed or deleted, it falls back to Read Me too, rather than erroring.
- Pinned tabs (Window > Pin Tab) still take priority: if any pinned files reopen, that's what you see; the last-document behavior only kicks in when there's nothing else to show.
- WriteNotes tracks this by watching which document window is frontmost (and by noticing Save As), the same way it already tracks pins — it isn't tied to which document you last *saved*, just which one you last had open.
- New: `LastDocument.swift`.

## v0.20.0 – 2026-09-28 – Generate Multiple UUIDs
- New **Insert > UUID > Generate Multiple…** command. Pick a UUID version (4, 7, 1, 6, 8, Nil, or Max) and a count (1 to 100), and that many UUIDs are inserted at once, one per line, using whichever UUID format (lowercase/UPPERCASE/no dashes/braces) is currently set in Insert > UUID > Format.
- The name-based versions (3 and 5) aren't in this list, since the same namespace and name always produce the same UUID — generating "multiple" of one would just repeat it. Use Insert > UUID > Version 3/5 for those, one at a time.
- New: `UUIDGenerator.multiple(forID:count:)`; the count is capped at 100, matching the same limit used by the Random Generator tools.

## v0.19.1 – 2026-09-27 – Default text color changed to #CC9933
- The factory-default text color is now **#CC9933** (a gold/brown), replacing #996633. This is what a fresh install starts with and what General > Reset All Settings to Factory Defaults returns to; it does not change a color you've already picked for yourself in Font & Colors (⌘,) unless you reset.
- To pick it up immediately without resetting everything else: Font & Colors (⌘,) > Text Color > set it to `CC9933`.

## v0.19.0 – 2026-09-27 – About window, Read Me, pinned tabs, duplicate tab
- **About WriteNotes** (app menu) now shows the version number and says plainly that WriteNotes is free and open-source — no cost, no subscription, no ads.
- **Read Me note.** A bundled Read Me tab (Resources/ReadMe.txt) opens automatically when WriteNotes starts with nothing else to show (a fresh launch, no file passed in, no pinned tabs to reopen). Find it again any time from the new **Help > Read Me**.
- **Pin Tab** (Window menu, ⌥⌘P): pins the current tab — only works for a saved file. A pinned tab reopens automatically the next time you launch WriteNotes, and its tab is marked with 📌. Closing a pinned tab (⌘W or File > Close) asks first, since closing removes the pin.
- **Duplicate Tab** (Window menu, ⇧⌘D): opens a second, independent tab with a copy of the current tab's text and language, without touching the saved file.
- New: PinnedTabs.swift, AppReadMe.swift, Resources/ReadMe.txt.

## v0.18.0 – 2026-09-27 – Renamed to WriteNotes
- The app is now called **WriteNotes** (was "Notepad Mac"). Renamed everywhere it's visible: the About/Hide/Quit menu items, the app's display name, the window/build output (`build/WriteNotes.app`), README, and this changelog.
- The bundle identifier changed from `com.abrahamcherian.notepadmac` to `com.abrahamcherian.writenotes`, and the built app's executable is now named `WriteNotes`. **This means macOS treats it as a different app for saved settings** — on first launch after updating, it will start from factory defaults (JetBrains Mono, size 18, black background, `#996633` text) rather than picking up whatever you had set before. Your old settings aren't lost; they're just parked under the old identifier. To bring a specific setting back, open Font & Colors (⌘,) or Preferences (⌥⌘,) and set it again — it only takes a moment since there are just a handful of settings.
- No feature, behavior, or file-format change — this is a naming/identity update only.

## v0.17.0 – 2026-09-26 – HTML Escape / Unescape
- New **Edit > HTML Escape / Unescape** submenu (also in the right-click menu). It works on the selected text, or on the whole document when nothing is selected, and ⌘Z undoes it.
  - **HTML Escape ( & < > ):** replaces only `&`, `<` and `>` with `&amp;`, `&lt;` and `&gt;`, so HTML code can be shown on a web page without the browser running it (`<textarea>Hello</textarea>` becomes `&lt;textarea&gt;Hello&lt;/textarea&gt;`). `&` is handled first, so nothing is escaped twice by accident.
  - **HTML Escape, also quotes:** the same plus `"` as `&quot;` and `'` as `&#39;` (for values inside HTML attributes).
  - **HTML Unescape:** turns entities back into characters: the basic ones (`&amp; &lt; &gt; &quot; &apos; &nbsp;`), numeric ones (`&#8364;`, `&#x1F600;`) and about 100 common named ones (`&eacute; &copy; &mdash; &euro; ...`). Entities are converted in one pass, so `&amp;lt;` becomes `&lt;` (text that was escaped twice needs two unescapes). Unknown names and a bare `&` (as in AT&T) are left alone.
- New: HTMLCoding.swift, SampleFiles/html_escape_sample.txt.

## v0.16.0 – 2026-09-26 – URL Encode / Decode
- New **Edit > URL Encode / Decode** submenu (also in the right-click menu) with four commands that work on the selected text, or on the URL-like text around the cursor when nothing is selected (everything up to the nearest spaces or line breaks). ⌘Z undoes them.
  - **URL Encode (all special characters):** everything except letters, digits and `- _ . ~` becomes `%XX` (UTF-8, so `é` becomes `%C3%A9`); use it for values inside a URL.
  - **URL Encode (keep : / ? & = # in a URL):** encodes spaces and other unsafe characters but keeps the characters that give a URL its structure and any existing `%XX` codes; use it on a whole URL.
  - **URL Decode:** turns `%XX` codes back into characters (UTF-8, so `%E4%BD%A0` becomes `你`). A `%` that is not followed by two hex digits is left as it is.
  - **URL Decode (+ becomes a space):** the same, also turning `+` into a space (form data).
- A multi-line selection is converted line by line and its line breaks are kept. If the codes do not form valid text, nothing changes and you hear a beep. New: URLCoding.swift, SampleFiles/url_encoding_sample.txt.

## v0.15.1 – 2026-09-26 – Journal banner uses the editor's look
- Fixed the journal banner appearing in the plain system font and colors (and looking selected) instead of the editor font, text color and spacing. The banner is now inserted like typed text and the cursor is placed on the fresh line below it.

## v0.15.0 – 2026-09-26 – Journal mode
- New **Format > Journal Mode** (off by default, tick to enable). In a plain text file, the first time you type after a pause, a banner with the current date and time (for example `Saturday, September 26, 2026 at 3:45 PM`, between two lines of `=`) is added at the end of the file, with a blank line before it, and the cursor moves to a fresh line below the banner, so what you type becomes that day's entry. This happens even if the cursor was elsewhere in the file. Undo removes the banner.
- A new entry starts when you type after 30 minutes without typing, or the first time you type after opening the file. Change the pause in File > Preferences > General > Journal mode (5 minutes, 15 minutes, 30 minutes, 1 hour, 4 hours, or only when the file is opened).
- **Format > Add Journal Entry Now** adds a banner immediately, in any file.
- Only ordinary typing triggers it (not shortcuts, arrows, paste or the Insert menu), and only in files whose language is Plain Text. The banner width follows Insert > Line Width.

## v0.14.1 – 2026-09-26 – JSON to table
- **Tabularize Data** now reads JSON. A list of records such as `[{"name": "Alice", "city": "Austin"}, ...]` becomes a table with one column per key (keys in the order they first appear, missing values left blank, null shown empty, nested objects and lists shown as compact JSON). Also understood: a list of lists, a single object (key and value columns), and JSON Lines (one object per line).
- Auto-detect recognizes text starting with `[` or `{`; or choose "JSON (list of records)" as the separator. Text that is not valid JSON is left unchanged in that mode. All the output styles work (aligned columns, Markdown, box, pipes).
- New menu item **Format > JSON > Convert to Table…** (opens the same sheet). New: SampleFiles/json_to_table_sample.json.

## v0.14.0 – 2026-09-26 – Tabularize Data
- New **Format > Text Formatting > Tabularize Data…** (also in the right-click menu). Select delimited text such as CSV, or select nothing for the whole document, choose options in the sheet (live preview) and press Apply; ⌘Z undoes it.
- Separator: auto-detected by default (comma, tab, semicolon or pipe, whichever splits the most lines the same way), or comma, tab, semicolon, pipe, colon, runs of spaces, or your own text. Values in double quotes may contain the separator (`"Carol, Jr."`); quotes are removed. Rows with missing values are padded.
- Output: aligned columns (with a chosen number of spaces between them), a Markdown table, a box table (`+---+` borders), or columns separated by ` | `. Alignment: numbers right and text left (default), left, right or center. "First row is a header" adds an underline or separator row. Blocks of lines separated by blank lines become separate tables.
- New: SampleFiles/tabularize_sample.txt (CSV, semicolon and pipe examples).

## v0.13.0 – 2026-09-26 – Sort Text and Reverse Text
- Two new commands at the bottom of Format > Text Formatting, with the same options sheet, live preview and Apply button (selected lines, or the whole document when nothing is selected; ⌘Z undoes).
- **Sort Text…** Sort: lines, words in each line, comma-separated items in each line, characters in each line, or every word in the text (one per line). Order: A to Z, Z to A, natural (item2 before item10), numbers ascending or descending (by the first number in each item; items without one go last), shortest first, longest first, or random shuffle (the previewed shuffle is the one applied). Options: ignore upper/lower case, remove duplicates, remove empty lines or items. Equal items keep their original order.
- **Reverse Text…** the whole text (last character first), the order of the lines, the characters in each line, the order of the words in each line, or the letters of each word.
- Edit > Line Operations keeps its quick Sort Lines Ascending / Descending. New: SampleFiles/sort_reverse_sample.txt.

## v0.12.1 – 2026-09-26 – Comment options in the right-click menu
- The right-click menu now has Toggle Comment (⌘/) and Toggle Block Comment (⌥⌘/), below Insert Date/Time. They use the same language-specific comment styles as the Edit menu. Right-clicking with nothing selected comments the line you clicked (also for the block version).

## v0.12.0 – 2026-09-26 – Comment and uncomment, per language
- **⌘/ (Edit > Toggle Comment)** comments or uncomments the selected lines, or the cursor's line when nothing is selected. If every non-blank line is already commented the comments are removed, otherwise all lines get one; indentation is kept. It now works in every language, including plain text.
- **⌥⌘/ (Edit > Toggle Block Comment)** wraps the selection in a block comment, or removes the block comment when the selection is one, or sits directly inside one. With nothing selected it uses the cursor's line. Languages without a block comment use line comments instead.
- Comment styles: Plain Text, Shell, YAML and INI/TOML use `#`. Swift, C/C++/Obj-C, Java, C#, Go, Rust, Kotlin, JavaScript/TypeScript and JSON use `//` and `/* */`. Python uses `#` and triple double quotes for blocks. SQL uses `--` and `/* */`. HTML/XML and Markdown use `<!-- -->` (each commented line is wrapped). CSS uses `/* */`.
- New file: CommentSyntax.swift. "Toggle Line Comment" was renamed "Toggle Comment".

## v0.11.1 – 2026-09-26 – Pad Text fixed
- Pad Text now adds the amount you type to every line by default: "Add this many characters to every line" (10 puts ten pad characters at the left or right of each line). Before, the number meant a total length, so on lines already longer than it nothing changed. The other choice, "Pad every line to this total length", is still there. A pad text of several characters is repeated as needed.

## v0.11.0 – 2026-09-26 – Format > Text Formatting
- New Format > Text Formatting submenu with nine commands. Each opens an options sheet with a live preview and an Apply button; it works on the selected lines, or on the whole document when nothing is selected, and can be undone with ⌘Z. Options are remembered per command.
  - **Add Line Numbers…** numbers, letters (a, b … z, aa), or roman numerals (lower or upper case); start value, the text after the number (default ". "), optionally skipping empty lines.
  - **Add Commas to Numbers…** groups digits as 1,234,567.89 or 1.234.567,89; only numbers with at least N digits (default 4); leading-zero codes such as 007654 and numbers already containing commas are left alone.
  - **Replace Smart/Straight Quotes…** curly to straight or straight to curly (opening and closing quotes and apostrophes chosen from the surrounding text).
  - **Tabs to Spaces…** and **Spaces to Tabs…** with 2, 4 or 8 spaces per tab; tabs line up on tab stops, and spaces to tabs can convert only leading indentation or runs of spaces anywhere.
  - **Pad Text…** left or right, to a chosen length, with any character.
  - **Word Wrap…** wraps each line (or, optionally, each paragraph after joining its lines) to a chosen length; very long words are cut.
  - **Justify Text…** wraps each paragraph to a length and stretches the spaces so every line but the last fills the width.
  - **Center Text…** centers each line in a chosen width, optionally padding the right side as well.
- New files: TextFormatting.swift, TextFormatSheet.swift; SampleFiles/text_formatting_sample.txt.

## v0.10.10 – 2026-09-25 – Text background at launch
- Fixed the text area being completely see-through when the app opens (it only got its color after a slider was touched). The text background color now lives in a separate plain view right behind the scroll area, which AppKit does not reset, so the 5% transparency shows correctly from launch, and for every new file, tab and window (the color is also re-applied whenever a window or tab appears).

## v0.10.9 – 2026-09-25 – Transparency starts at 5% on every launch
- Every time the app starts, Window and Text background transparency now begin at their defaults (5% each). A high value set while experimenting (for example 90%) no longer carries over and makes the text background look fully see-through at the next launch.
- New checkbox in File > Preferences > General: "Keep my transparency settings when the app restarts". Tick it to have the slider values remembered between launches (off by default). The sliders still change everything live while the app is running.

## v0.10.8 – 2026-09-25 – Transparency defaults set to 5%
- Window and Text background transparency now both default to **5%** (they were 20%), applied at every launch on a fresh install or after a reset. A value you have already set with the sliders is kept: press Reset next to each slider (or File > Preferences > General > Reset All Settings to Factory Defaults) to go to 5%.

## v0.10.7 – 2026-09-25 – See-through edges fixed
- The strips along the right and bottom edges of the editor (where the scroll bars sit) were completely see-through whatever the sliders said. When either transparency is above 0%, the editor now uses overlay scroll bars (thin bars that appear over the text while scrolling), so the text area and the gutter reach the window edge and follow the Text background and Window settings. At 0% / 0% the scroll bars follow your macOS setting again.
- Both transparency defaults are 20% (unchanged); "Reset" and "Reset All Settings to Factory Defaults" restore them.

## v0.10.6 – 2026-09-25 – Build warnings fixed
- Removed the two compiler warnings: the no-longer-needed copiesOnScroll setting (the editor now simply redraws while scrolling when the background is see-through) and the deprecated allowedFileTypes call in the Save panel (same behavior: you can save with any extension).

## v0.10.5 – 2026-09-25 – Transparency drawn as layer colors
- The typing area and the line-number gutter now get their background from a layer color (the same method the status bar already used, which was correctly see-through) instead of drawing it as a filled rectangle, which kept coming out solid grey. The Text background and Window sliders should now show the desktop through the editor, like a Terminal window with a transparent background.

## v0.10.4 – 2026-09-25 – Transparency now really shows the desktop
- Fixed the Text background and Window transparency sliders having no visible effect: the editor was painting its background on top of itself, so it stayed solid. The typing area is now painted once, with the exact color and transparency you choose, and the line-number gutter replaces (instead of blends with) what is behind it, so the desktop shows through like a Terminal window with a transparent background.
- The current-line highlight is now drawn by the text view itself, under the text. New: TranslucentClipView (in EditorTextView.swift).

## v0.10.3 – 2026-09-25 – Two transparency settings, both 20% by default
- File > Preferences > General now has two sliders, each 0% (solid) to 90%, both defaulting to **20%** and applied at every launch:
  - **Window:** the line-number gutter and status bar (the window background).
  - **Text background:** the area you type in.
- Text and cursor stay fully visible. Reset buttons return each one to 20%. "Reset All Settings to Factory Defaults" does too.
- Settings from v0.10.2 (whose default was 80%) are not carried over, so the new 20% defaults apply.

## v0.10.2 – 2026-09-25 – Window transparency (not opacity)
- The window setting is now a **Transparency** slider (File > Preferences > General), 0% (solid) to 90%, default **80%**, applied at every launch. 80% transparency means the editor background is only 20% solid, so the desktop shows through strongly; the text stays fully visible. Lower it for a more solid window; 0% is fully solid.
- Replaces the v0.10.1 "Opacity" slider (which was the opposite scale).

## v0.10.1 – 2026-09-25 – Window background opacity (replaced by transparency in v0.10.2)
- File > Preferences > General has a new "Opacity" slider (20% to 100%, with Reset) for the editor window background. The default is 80%, applied every time the app starts and to every new window and tab, so the desktop shows through softly behind the text. The text, cursor and selection stay fully visible.
- The line-number gutter and the status bar follow the same opacity. Set it to 100% for a fully solid window. "Reset All Settings to Factory Defaults" returns it to 80%.

## v0.10.0 – 2026-09-25 – File > Preferences
- New File > Preferences… (⌥⌘,) window with three tabs:
  - **General:** a button to Font & Colors (⌘,), and "Reset All Settings to Factory Defaults…" (asks first; documents are not touched).
  - **Insert:** default line width (for Horizontal Line and Comment Banner) and default UUID format.
  - **Random Generator:** pick a tool and edit its default values (every option: length, character sets, separators, ranges, "How many" 1–100, and so on). Changes save as you make them, "Restore Built-in Defaults for This Tool" undoes them, and a checkbox chooses whether each tool starts from your defaults or from the values you used last time.
- Change in behavior: Random Generator sheets now start from your defaults every time (before, they reopened with the last values used). Tick "Start each tool with the values I used last time" to get the old behavior back.
- New file: AppPreferencesWindowController.swift. Font & Colors is unchanged and keeps ⌘,.

## v0.9.8 – 2026-09-25 – Menu font checkbox fixed
- Unticking "Use the editor font in menus" in Font & Colors now switches the menus back to the system font (the box was being reset to ticked by the window's own refresh). The other checkboxes (Word wrap, line numbers, invisibles, current line) were made safe against the same problem.

## v0.9.7 – 2026-09-25 – Menus use the editor font
- The app's menu items (File, Edit, Format, Insert, ... and their submenus) are now shown in the editor font (JetBrains Mono by default) at 13 pt, and follow the font you pick in Font & Colors.
- To go back to the normal macOS menu font, untick "Use the editor font in menus (uncheck for the system font)" in Font & Colors (⌘,). The choice is remembered.
- macOS always draws the menu-bar titles themselves (File, Edit, ...) and the shortcut symbols in the system font; only the items inside the menus change. New file: MenuFontStyler.swift.

## v0.9.6 – 2026-09-25 – Line numbers no longer vanish while scrolling
- Fixed blocks of line numbers (and the gutter background) going missing while scrolling up and down: the gutter now repaints completely on every scroll, and the range of lines it draws includes a small margin above and below the window.
- Fixed a packaging mistake in the first copy of this version, where Info.plist was delivered empty and the app would not open ("executable is missing"). build_app.sh now stops with a clear message if Info.plist is ever empty.

## v0.9.5 – 2026-09-25 – New factory defaults
- On a fresh install the editor starts with JetBrains Mono, size 18, a Licorice (black, #000000) background and brown (#996633) text, using the Dark theme's syntax colors.
- These apply only until you change something: settings you already saved on a Mac are kept. "Reset" for the size and Zoom Reset (⌘0) now return to 18. "Reset to Theme Colors" and choosing a theme still clear the color overrides, as before.

## v0.9.4 – 2026-09-25 – More coding fonts (free and open source)
- Five free, open-source coding fonts now ship inside the app and appear at the top of Font & Colors (⌘,) and the Fonts panel: Cascadia Code, DejaVu Sans Mono, Fira Code (ligatures), JetBrains Mono (ligatures) and Source Code Pro. Nothing is installed on the Mac; the fonts are loaded only while the app runs.
- Only fonts with free licences are used (SIL Open Font License 1.1 for four of them, the free DejaVu licence for the other). Licence texts are in Resources/Fonts (LICENSES.md, OFL.txt, DejaVu-LICENSE.txt).
- build_app.sh copies Resources/Fonts into the app. New file: BundledFonts.swift.

## v0.9.3 – 2026-09-25 – Random Generator: one limit for "How many"
- Every Random Generator tool now shares one maximum of 100 for the "How many" field (it was 100 to 10,000 depending on the tool). The label shows "How many (max 100)"; typing a larger number such as 500 is corrected to 100 straight away with a notice, so the box always matches what is generated. 0 or an empty box becomes 1, and an older remembered value above 100 is corrected when the sheet opens.
- The limit is a single setting in the code (RandomGenerators.maxCount).

## v0.9.2 – 2026-09-25 – JSON tools moved under Format
- The JSON menu is no longer a separate menu-bar item: all JSON commands (Format JSON ⌥⌘J, Format and Sort Keys ⌥⇧⌘J, Minify ⌥⌘M, Validate ⌥⌘V, 2 spaces / 4 spaces / tabs) are now under Format > JSON, with the same shortcuts.

## v0.9.1 – 2026-09-25 – Click a line number to select the line
- Clicking a line number in the gutter selects the whole line (including its line break); dragging selects several lines (with auto-scroll) and Shift-click extends the selection. With word wrap on, the whole logical line is selected.
- Numbers of selected lines and the cursor line are drawn brighter and bolder; the pointer is a hand over the gutter.

## v0.9.0 – 2026-09-25 – Insert > Random Generator
- New Insert > Random Generator submenu with eight tools, each with an options sheet, live preview, Generate Again, Copy and Insert: Username Generator, Strong Password Generator (with strength estimate), Pronounceable Password, Random String Generator, Random Word Generator, Filler Text, Random Number Generator, Random Email Generator (reserved example.* domains by default).
- Options are remembered per tool. Passwords and strings use the system's secure random generator.

## v0.8.1 – 2026-09-25 – UUID versions
- Insert > UUID now offers versions 1, 4 (⌥⌘U), 6, 7 and 8, name-based versions 3 (MD5) and 5 (SHA-1) with a namespace/name prompt, and the Nil and Max UUIDs.
- Insert > UUID > Format (lowercase, UPPERCASE, without dashes, in braces) applies to every version and is remembered; it replaces the separate uppercase / without-dashes items.

## v0.8.0 – 2026-09-25 – More Insert menu options
- Insert > Horizontal Line: 8 styles (dashes, equals, asterisks, tildes, underscores, box, double box, dots) plus the Markdown rule; line width 40 to 120 characters (remembered). Always placed on its own line. Shortcut ⌥⌘L.
- Insert > UUID: lowercase (⌥⌘U), UPPERCASE, without dashes.
- Insert > Lorem Ipsum: 10 words, 1 sentence, 1 / 3 / 5 paragraphs.
- Insert > File Info: file name, name without extension, full path, folder path.
- Insert > Comment Banner… (⌥⌘B): boxed heading using the current language's comment style (// # -- <!-- --> /* */ or plain).
- Insert > Special Characters: punctuation and marks, math and units, currency, arrows, symbols and checks, spacing characters.

## v0.7.2 – 2026-09-25 – Date and time shortcuts
- Keyboard shortcuts for the six most common date/time formats (⌥⌘1 to ⌥⌘6): time (12-hour in 12-hour regions like the US, 24-hour elsewhere), short date and time in the region's style, date and time, ISO 8601 with offset, UTC date and time, UTC ISO 8601. They replace the earlier ⇧⌘D and ⌥⇧⌘D shortcuts.

## v0.7.1 – 2026-09-25 – Insert menu layout
- The menu bar now has Insert as the main menu with a Date and Time submenu that holds all the local and UTC time options (same formats and shortcuts as before). The right-click menu is unchanged.

## v0.7.0 – 2026-09-25 – Insert date and time
- New Insert menu: put the current time at the cursor in 10 local formats (24-hour, 12-hour, date and time, time zone, long, short, ISO 8601 with offset, RFC 2822, compact) and 7 UTC formats (time, date and time, ISO 8601, RFC 2822, compact, Unix seconds, Unix milliseconds). Each entry previews the current time when the menu opens.
- Same lists in the right-click menu (Insert Date/Time): with nothing selected it inserts where you clicked.
- Shortcuts: ⇧⌘D local date and time, ⌥⇧⌘D UTC ISO 8601.

## v0.6.0 – 2026-09-25 – Right-click text options
- Right-click menu: Change to UPPERCASE, Change to lowercase, Word Count – Whole Document, Word Count – Selected Text. Right-clicking a word with nothing selected selects that word first.
- Word count summary shows words, characters with and without spaces, lines, paragraphs and reading time, with a Copy button.
- Case commands (also in Edit > Convert Case) now work on the word at the cursor when nothing is selected. Word Count items added to the Edit menu.
- New sample file: SampleFiles/word_count_sample.txt.

## v0.5.1 – 2026-09-25 – Terminal now uses the macOS Terminal app
- The Terminal menu now opens the real Terminal app that comes with macOS instead of the built-in console: Open Terminal Here (^`), Open Terminal in Folder… (⌥⌘T), Run Current File in Terminal (⌘R, with a Save and Run prompt for unsaved changes).
- Removed the built-in console window; TerminalSession.swift and TerminalWindowController.swift are now empty placeholder files and can be deleted (old code is in the v0.5.0 backup).

## v0.5.0 – 2026-09-25 – Terminal window
- New Terminal menu and Terminal window: type shell commands (your login zsh) with the working folder carried between commands, command history (Up/Down), input for running programs, Stop (Esc / ⌘.), Clear (⌘K).
- Run Current File (⌘R) for Python, Shell, Swift, Go, Java, JavaScript (.js) and C/C++ files.
- Open Terminal in Current File's Folder (⌥⌘T) and Open Folder in Terminal App (⇧⌘T) for full-screen programs (vim, ssh, top).
- Follows the editor's font and theme. New sample files: run_me.py, run_me.js, slow_count.sh.
- Limitation: it is a command console, not a full terminal emulator, so full-screen programs are not supported inside it.

## v0.4.2 – 2026-09-25 – Menu fix
- Fixed a duplicate "Open Recent" entry in the File menu (macOS adds its own automatically; the hand-made one was removed).

## v0.4.1 – 2026-09-25 – File explorer reverted
- Removed the left-hand file explorer (pane, folder switching, Open Folder…, Show File Explorer / Show Hidden Files menu items) at the owner's request.
- The app is functionally the same as v0.3.1 plus the backup system. The explorer's source is preserved in `Backups/NotepadMac_v0.4.0_2026-09-25.zip` and in the git history (tag v0.4.0) if it is ever wanted again.
- Workspace.swift, SupportedFiles.swift and FileExplorerViewController.swift are now empty placeholder files and can be deleted.

## v0.4.0 – 2026-09-25 – File explorer
- Left-hand file explorer showing the current folder (folders first, expandable).
- Change folder: folder dropdown (parents, Home, folder of current file, Choose Folder…), Up button, Choose button, File > Open Folder… (⇧⌘O).
- Clicking a text/code file opens it in a tab; other file types (images, PDFs, zips, Office files, apps, binaries) are greyed out and won't open.
- View menu: Show File Explorer (⇧⌘E), Show Hidden Files in Explorer (⇧⌘.). Remembers the last folder.
- Backup system added: Backups/ folder, backup.sh, this change log.

## v0.3.1 – 2026-09-25 – Sample and test files
- SampleFiles/: 35 files (languages, JSON good/bad, line-ending and encoding tests, regex, Find in Files corpus, 830 KB large file) plus TESTING_GUIDE.md.

## v0.3.0 – 2026-09-25 – JSON formatter
- New JSON menu: Format (⌥⌘J), Format and Sort Keys, Minify, Validate, 2 spaces / 4 spaces / tabs.
- Strict parser that keeps key order and exact numbers; errors show line, column and reason.

## v0.2.1 – 2026-09-25 – Font menu
- Format > Font… (system Fonts panel, ⌘T) and Format > Font Size list.

## v0.2.0 – 2026-09-25 – Font & Colors
- Font & Colors window (⌘,): font family, size, theme, custom background/text color, tab width, view toggles.
- New themes: Dracula, Nord, Sepia (now 7 plus Automatic).

## v0.1.1 – 2026-09-25 – Build fixes for Swift 5.7 / macOS 12
- Package.swift tools version 5.7, macOS 12 minimum; build_app.sh now compiles with swiftc directly.
- Fixed `override` on newWindowForTab and the save-panel API for the older SDK.

## v0.1.0 – 2026-09-25 – First version
- Native Swift/AppKit editor: tabs, open/save, line numbers, current-line highlight, word wrap, zoom.
- Syntax highlighting for 17 languages; themes Light, Dark, Monokai, Solarized Light.
- Find/Replace (normal, extended, regex), Find in Files, Go to Line.
- Encodings (UTF-8/16, BOM, Windows-1252, Latin-1, Mac Roman) and line endings (LF/CRLF/CR).
- Line operations: duplicate, delete, move, join, sort, remove duplicates, trim, comment, indent, case.
- Auto-indent, status bar, print, Save All.
