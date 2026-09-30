import AppKit

/// The liability/warranty disclaimer: shown once at first launch (see `confirmAccepted()`,
/// called from `AppDelegate.applicationWillFinishLaunching`) and again, for reference, in
/// About Calamus. The same wording also appears in `README.md` and `Resources/ReadMe.txt` -
/// those are plain text, so it's duplicated there by hand rather than shared as code. Keep all
/// three in sync if this text ever changes.
enum LegalDisclaimer {
    static let text = """
    Calamus is free, open-source software provided \u{201C}as is,\u{201D} with no warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement.

    By downloading, installing, or using Calamus, you agree that you do so entirely at your own risk. The developer is not liable for any damages, data loss, or other losses of any kind \u{2013} direct, indirect, incidental, or consequential \u{2013} arising from your use of, or inability to use, this software, including losses caused by any inaccuracies, bugs, or unexpected behavior it may produce.

    You are solely responsible for backing up your work and independently verifying any results before relying on them.
    """

    /// Same wording as `text` above, hand-formatted by Abraham into a fixed 70-column block -
    /// each line padded with leading/trailing spaces and extra inter-word spacing so it reads as
    /// a justified block of monospaced text. This only looks right in a monospaced font (see
    /// `monospaced:` on `DisclaimerPanel.present`), so it's used for the launch disclaimer only;
    /// About Calamus keeps showing the plain `text` above, reflowed dynamically. Re-verified
    /// word-for-word identical to `text` (only whitespace/line-break layout differs), so this
    /// doesn't need a matching update to README.md / Resources/ReadMe.txt.
    static let launchDisclaimerFormatted = """
         Calamus is free, open-source software provided \u{201C}as is,\u{201D} with
         no  warranty  of any kind, express or implied, including but
         not  limited to warranties of merchantability, fitness for a
                  particular purpose, and non-infringement.

         By downloading, installing, or using Calamus, you agree that
         you  do  so  entirely at your own risk. The developer is not
         liable  for  any  damages, data loss, or other losses of any
         kind  \u{2013}  direct,  indirect,  incidental,  or consequential \u{2013}
         arising  from  your  use  of,  or  inability  to  use,  this
         software, including losses caused by any inaccuracies, bugs,
                    or unexpected behavior it may produce.

         You  are  solely  responsible  for  backing up your work and
         independently verifying any results before relying on them.
    """

    /// Shows the disclaimer once - the first launch after it was added (or after Preferences >
    /// General > Reset All Settings to Factory Defaults, which clears the "accepted" flag along
    /// with everything else) - and blocks until the user responds. Returns true if the app may
    /// continue launching; false if the user declined, in which case the caller should quit.
    static func confirmAccepted() -> Bool {
        if Preferences.shared.disclaimerAccepted { return true }

        let accepted = DisclaimerPanel.present(
            title: "Before You Start",
            body: launchDisclaimerFormatted,
            defaultTitle: "I Accept",
            otherTitle: "Decline and Quit",
            alignment: .left,
            monospaced: true)

        guard accepted else { return false }
        Preferences.shared.disclaimerAccepted = true
        return true
    }

    /// The credits lines plus this same disclaimer, shown together in About Calamus so the
    /// disclaimer stays visible from inside the app after the one-time launch prompt.
    static let aboutText = """
        Free and open-source. No cost, no subscription, no ads.
        A native macOS text and code editor, built in Swift and AppKit.
        Help \u{2192} Read Me has a quick tour of what it can do.

        Support: support@abrahamcherian.in

        \(text)
        """

    /// Shows About Calamus in the same style of dialog as the launch disclaimer, so the same
    /// text - credits plus the disclaimer - displays at a comfortable, readable size. Unlike the
    /// launch disclaimer, this text is centered rather than justified, per Abraham's explicit
    /// formatting example.
    static func showAbout(version: String, build: String) {
        _ = DisclaimerPanel.present(
            title: "Calamus \u{2013} Version \(version) (Build \(build))",
            body: aboutText,
            defaultTitle: "OK",
            otherTitle: nil,
            alignment: .center,
            monospaced: false)
    }
}

/// A plain NSView that reports itself as flipped (origin top-left, y grows downward). Used only
/// as the document view inside `DisclaimerPanel`'s scroll area, so "scrolled to the bottom" means
/// what it sounds like - a bigger y - regardless of whichever content view happens to sit inside
/// it (NSTextField's default coordinate system is the other way around, origin bottom-left).
private final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

/// A small modal dialog used for both the launch disclaimer and About Calamus. Built by hand
/// instead of using NSAlert, which gave no reliable control over its text's font size and no way
/// to gate its default button on the user actually having scrolled through the text. The body
/// text is an NSTextView (a wrapping NSTextField didn't reliably honor justified alignment, and
/// NSTextView also lets each caller choose its own alignment and font - the launch disclaimer
/// passes its own pre-formatted, hand-padded text with `alignment: .left, monospaced: true` so
/// its manual spacing lines up as intended; About Calamus passes plain prose with `alignment:
/// .center, monospaced: false`) laid out entirely with Auto Layout - pinned to a fixed width,
/// free to grow in height - inside a scroll view. Its width comes only from an Auto Layout
/// constraint, never from a manually-set frame: an earlier version of this dialog mixed manual
/// frame-setting with the text view's own autoresizing-mask tracking and never actually opted
/// into Auto Layout, which is what let text silently wrap at the wrong width. Text that fits
/// within `maxBodyHeight` at the chosen font size is shown in full with no scrolling, and the
/// default button starts enabled right away. Text that doesn't fit scrolls instead, and - only
/// when there's a second, "otherTitle" button (the launch disclaimer, which can be declined;
/// About has nothing to decline) - the default button stays disabled until the user has scrolled
/// all the way to the bottom, so the disclaimer can't be
/// accepted without the whole thing having passed in front of them first.
private final class DisclaimerPanel: NSObject {
    private var window: NSWindow!
    private var acceptButton: NSButton!
    private var bodyScrollView: NSScrollView!
    private var result = false
    private var reachedBottom = false

    private static let titleFontSize: CGFloat = 20
    private static let bodyFontSize: CGFloat = 12
    private static let dialogWidth: CGFloat = 800
    /// 50pt each side of an 800pt-wide dialog leaves a 700pt-wide column for the title and body
    /// text, with clear breathing room between the text and the window's edges.
    private static let sideInset: CGFloat = 50
    private static let maxBodyHeight: CGFloat = 420

    static func present(title: String, body: String, defaultTitle: String, otherTitle: String?, alignment: NSTextAlignment, monospaced: Bool) -> Bool {
        let panel = DisclaimerPanel()
        return panel.run(title: title, body: body, defaultTitle: defaultTitle, otherTitle: otherTitle, alignment: alignment, monospaced: monospaced)
    }

    private func run(title: String, body: String, defaultTitle: String, otherTitle: String?, alignment: NSTextAlignment, monospaced: Bool) -> Bool {
        let width = DisclaimerPanel.dialogWidth
        let sideInset = DisclaimerPanel.sideInset
        let contentWidth = width - sideInset * 2

        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let titleField = NSTextField(wrappingLabelWithString: title)
        titleField.font = NSFont.boldSystemFont(ofSize: DisclaimerPanel.titleFontSize)
        titleField.alignment = .center
        titleField.preferredMaxLayoutWidth = contentWidth
        titleField.translatesAutoresizingMaskIntoConstraints = false

        // NSTextField's cell-based renderer doesn't reliably honor justified alignment the way
        // it does centered/left text (that's very likely what went wrong when this was a
        // wrapping NSTextField), so the body uses a real NSTextView here instead - it has native,
        // properly-supported justification via TextKit. It's pinned with the exact same
        // pure-Auto-Layout technique that worked correctly for width/wrapping before (fixed
        // width, four edges pinned to a flipped container, translatesAutoresizingMaskIntoConstraints
        // = false throughout) rather than the frame-and-autoresizing-mask approach an earlier,
        // buggy version of this dialog used - that mix of manual frames with implicit tracking,
        // never opted into Auto Layout, is what let text silently wrap at the wrong width back then.
        // The launch disclaimer's body arrives pre-formatted by Abraham as a fixed-width block
        // (each line manually padded with leading/trailing/inter-word spaces to line up as a
        // justified column) - that spacing only lines up visually in a monospaced font, so this
        // dialog switches fonts for that case. About Calamus keeps the normal proportional font.
        let bodyFont: NSFont = monospaced
            ? NSFont.monospacedSystemFont(ofSize: DisclaimerPanel.bodyFontSize, weight: .regular)
            : NSFont.systemFont(ofSize: DisclaimerPanel.bodyFontSize)

        // A monospaced pre-formatted block is narrower than the dialog's full content column
        // (it's a fixed number of columns, not a paragraph that wraps to fill the width), so its
        // width comes from measuring its own longest line rather than from contentWidth. The
        // mainStack's existing .centerX alignment then centers this narrower block horizontally,
        // giving it even margins on both sides rather than leaving a lopsided gap on the right.
        //
        // v0.30.10 sized this to the measured width with no slack at all, which was the actual
        // bug behind the "words spilling outside the dialog" report: NSString's size(withAttributes:)
        // is only an estimate of how wide a line will render, and real TextKit layout (kerning,
        // sub-pixel rounding) came out very slightly wider for most lines - just enough to push
        // their last word onto a wrapped, un-indented second line that spilled left of the block.
        // A fixed-point buffer, comfortably larger than that kind of rounding error, is added on
        // top of the measured width so every real line has headroom and none of them wrap.
        let bodyWidth: CGFloat
        if monospaced {
            let longest = body.components(separatedBy: "\n")
                .map { ($0 as NSString).size(withAttributes: [.font: bodyFont]).width }
                .max() ?? contentWidth
            bodyWidth = min(longest + 24, contentWidth)
        } else {
            bodyWidth = contentWidth
        }

        let bodyTextView = NSTextView()
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false
        bodyTextView.isEditable = false
        bodyTextView.isSelectable = true
        bodyTextView.isRichText = false
        bodyTextView.drawsBackground = false
        bodyTextView.font = bodyFont
        bodyTextView.textColor = .labelColor
        // Caller-chosen: .center for About Calamus's plain, dynamically-wrapped prose, or .left
        // for the launch disclaimer, whose pre-formatted text already carries its own manual
        // spacing and shouldn't have TextKit's own alignment applied on top of it.
        bodyTextView.alignment = alignment
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer?.lineFragmentPadding = 0
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.textContainer?.containerSize = NSSize(width: bodyWidth, height: .greatestFiniteMagnitude)
        bodyTextView.string = body

        // Measure the natural height at this width before ever placing the view in a window.
        // This isn't just informational - NSTextView's intrinsicContentSize has a chicken-and-egg
        // problem in a pure Auto Layout setup (it needs to know its own resolved width before it
        // can compute a height from wrapped text, so leaving Auto Layout to infer the height on
        // its own is unreliable and is very likely what made the text collapse to nothing/invisible
        // in an earlier version of this dialog). Using this measurement as an explicit height
        // constraint below sidesteps that entirely.
        if let layoutManager = bodyTextView.layoutManager, let container = bodyTextView.textContainer {
            layoutManager.ensureLayout(for: container)
        }
        let naturalHeight = bodyTextView.layoutManager?.usedRect(for: bodyTextView.textContainer!).height ?? 200
        let fits = naturalHeight <= DisclaimerPanel.maxBodyHeight
        let bodyHeight = min(max(naturalHeight, 1), DisclaimerPanel.maxBodyHeight)

        let documentContainer = FlippedContainerView()
        documentContainer.translatesAutoresizingMaskIntoConstraints = false
        documentContainer.addSubview(bodyTextView)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = !fits
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = documentContainer

        NSLayoutConstraint.activate([
            // Pinning all four edges of the text view to its (flipped) container, plus fixed
            // width AND height (both taken from the measurements above, not inferred), makes the
            // container's size exactly match the content at that width - nothing here can grow
            // wider than bodyWidth, and its height is pinned rather than guessed.
            bodyTextView.topAnchor.constraint(equalTo: documentContainer.topAnchor),
            bodyTextView.bottomAnchor.constraint(equalTo: documentContainer.bottomAnchor),
            bodyTextView.leadingAnchor.constraint(equalTo: documentContainer.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: documentContainer.trailingAnchor),
            bodyTextView.widthAnchor.constraint(equalToConstant: bodyWidth),
            bodyTextView.heightAnchor.constraint(equalToConstant: naturalHeight),
            scrollView.widthAnchor.constraint(equalToConstant: bodyWidth),
            scrollView.heightAnchor.constraint(equalToConstant: bodyHeight)
        ])
        bodyScrollView = scrollView

        let acceptBtn = NSButton(title: defaultTitle, target: self, action: #selector(acceptClicked))
        acceptBtn.bezelStyle = .rounded
        acceptBtn.keyEquivalent = "\r"
        acceptButton = acceptBtn

        // Centered, natural-width buttons (not stretched edge-to-edge) - .centerX is a
        // genuinely supported NSStackView alignment for a vertical stack, unlike the earlier
        // attempt at a ".width" alignment to stretch them, which didn't reliably center the
        // stack itself and was very likely what pushed the buttons off to one side.
        let buttonStack: NSStackView
        if let otherTitle = otherTitle {
            let declineBtn = NSButton(title: otherTitle, target: self, action: #selector(declineClicked))
            declineBtn.bezelStyle = .rounded
            buttonStack = NSStackView(views: [acceptBtn, declineBtn])
            buttonStack.orientation = .vertical
            buttonStack.alignment = .centerX
            buttonStack.spacing = 8
        } else {
            buttonStack = NSStackView(views: [acceptBtn])
            buttonStack.orientation = .vertical
            buttonStack.alignment = .centerX
        }

        // Nothing to gate on when the text already fits with no scrolling, or for About (no
        // otherTitle - nothing to decline, so nothing worth blocking).
        reachedBottom = fits || otherTitle == nil
        acceptBtn.isEnabled = reachedBottom

        if !reachedBottom {
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(scrollDidChange),
                                                    name: NSView.boundsDidChangeNotification,
                                                    object: scrollView.contentView)
        }

        let mainStack = NSStackView(views: [icon, titleField, scrollView, buttonStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 24, left: sideInset, bottom: 20, right: sideInset)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 400),
                            styleMask: [.titled],
                            backing: .buffered,
                            defer: false)
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.contentView = contentView
        window = win

        contentView.layoutSubtreeIfNeeded()
        win.setContentSize(mainStack.fittingSize)
        win.center()
        win.makeKeyAndOrderFront(nil)

        NSApp.runModal(for: win)

        NotificationCenter.default.removeObserver(self)
        win.orderOut(nil)
        return result
    }

    @objc private func acceptClicked() {
        result = true
        NSApp.stopModal()
    }

    @objc private func declineClicked() {
        result = false
        NSApp.stopModal()
    }

    @objc private func scrollDidChange() {
        guard !reachedBottom, let scrollView = bodyScrollView, let doc = scrollView.documentView else { return }
        let visible = scrollView.contentView.documentVisibleRect
        if visible.maxY >= doc.frame.height - 2 {
            reachedBottom = true
            acceptButton.isEnabled = true
        }
    }
}
