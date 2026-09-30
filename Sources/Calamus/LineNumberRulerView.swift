import AppKit

/// Line-number gutter attached to the editor's scroll view. Click a line number to select that
/// whole line; drag down or up to select several lines; Shift-click to extend the selection.
final class LineNumberRulerView: NSRulerView {
    private let lineIndex: LineIndex
    /// Gutter background including its transparency. Kept as a layer color so the alpha is honored.
    var gutterColor = NSColor.windowBackgroundColor {
        didSet {
            wantsLayer = true
            layer?.backgroundColor = gutterColor.cgColor
            layer?.isOpaque = false
            needsDisplay = true
        }
    }
    var numberColor = NSColor.secondaryLabelColor
    /// Color for the numbers of the lines that are currently selected (or hold the cursor).
    var activeNumberColor = NSColor.labelColor
    var numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { updateThickness() }
    }

    /// The line (or lines) where the current click or drag started.
    private var anchorRange = NSRange(location: 0, length: 0)

    init(textView: NSTextView, lineIndex: LineIndex) {
        self.lineIndex = lineIndex
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        wantsLayer = true
        layer?.backgroundColor = gutterColor.cgColor
        self.ruleThickness = 44
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    /// Always repaint the whole gutter. Drawing only the dirty rectangle left blocks of numbers
    /// (and their background) unpainted while scrolling quickly.
    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: bounds)
    }

    func contentChanged() {
        updateThickness()
        needsDisplay = true
    }

    private func updateThickness() {
        let digits = max(3, String(lineIndex.count).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: numberFont]).width
        let thickness = ceil(CGFloat(digits) * digitWidth) + 18
        if abs(thickness - ruleThickness) > 0.5 { ruleThickness = thickness }
    }

    // MARK: - Clicking a line number

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    /// The whole line (including its line break) at a point given in window coordinates.
    private func lineRange(atWindowPoint location: NSPoint, in textView: NSTextView) -> NSRange {
        let ns = textView.string as NSString
        let point = textView.convert(location, from: nil)
        let probe = NSPoint(x: textView.textContainerInset.width + 2, y: point.y)
        let index = max(0, min(textView.characterIndexForInsertion(at: probe), ns.length))
        return ns.lineRange(for: NSRange(location: index, length: 0))
    }

    override func mouseDown(with event: NSEvent) {
        guard let tv = clientView as? NSTextView else { return }
        window?.makeFirstResponder(tv)
        let clicked = lineRange(atWindowPoint: event.locationInWindow, in: tv)
        if event.modifierFlags.contains(.shift) {
            let current = tv.selectedRange()
            anchorRange = current
            tv.setSelectedRange(NSUnionRange(current, clicked))
        } else {
            anchorRange = clicked
            tv.setSelectedRange(clicked)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let tv = clientView as? NSTextView else { return }
        _ = tv.autoscroll(with: event)
        let current = lineRange(atWindowPoint: event.locationInWindow, in: tv)
        tv.setSelectedRange(NSUnionRange(anchorRange, current))
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = clientView as? NSTextView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer else { return }

        // The gutter background is the layer color set above; only the divider and numbers are drawn here.
        numberColor.withAlphaComponent(0.25).setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        let normalAttrs: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: numberColor]
        let activeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: numberFont.pointSize, weight: .semibold),
            .foregroundColor: activeNumberColor
        ]
        let origin = tv.textContainerOrigin
        var visible = tv.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        visible = visible.insetBy(dx: 0, dy: -40)   // a little extra above and below
        let glyphRange = lm.glyphRange(forBoundingRect: visible, in: tc)

        // Lines that hold the cursor or are covered by the selection.
        let selection = tv.selectedRange()
        let firstSelected = lineIndex.lineNumber(at: selection.location)
        let lastSelected = lineIndex.lineNumber(at: selection.length > 0 ? NSMaxRange(selection) - 1 : selection.location)

        func drawNumber(_ number: Int, lineRect: NSRect) {
            let isActive = number >= firstSelected && number <= lastSelected
            let attrs = isActive ? activeAttrs : normalAttrs
            let label = String(number) as NSString
            let size = label.size(withAttributes: attrs)
            let top = convert(NSPoint(x: 0, y: lineRect.minY + origin.y), from: tv)
            let bottom = convert(NSPoint(x: 0, y: lineRect.maxY + origin.y), from: tv)
            let low = min(top.y, bottom.y)
            label.draw(at: NSPoint(x: bounds.maxX - size.width - 8,
                                   y: low + (lineRect.height - size.height) / 2),
                       withAttributes: attrs)
        }

        var glyph = glyphRange.location
        while glyph < NSMaxRange(glyphRange) {
            var effective = NSRange()
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &effective)
            let charIndex = lm.characterIndexForGlyph(at: effective.location)
            if lineIndex.isLineStart(charIndex) {
                drawNumber(lineIndex.lineNumber(at: charIndex), lineRect: lineRect)
            }
            if NSMaxRange(effective) <= glyph { break }
            glyph = NSMaxRange(effective)
        }

        // The empty last line (after a trailing newline, or in an empty document).
        if lm.extraLineFragmentTextContainer != nil {
            drawNumber(lineIndex.count, lineRect: lm.extraLineFragmentRect)
        }
    }
}
