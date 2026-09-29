import CoreGraphics
import CoreText
import Foundation

// MARK: - Fonts

enum Fonts {
    private static let descriptors: [String: CTFontDescriptor] = {
        var result: [String: CTFontDescriptor] = [:]
        for name in ["KGPrimaryPenmanshipAlt", "KGPrimaryDots"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf"),
                  let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let first = list.first
            else { continue }
            result[name] = first
        }
        return result
    }()

    /// Ball-and-stick manuscript print (single-story a and g).
    static func penmanship(_ size: CGFloat) -> CTFont { font("KGPrimaryPenmanshipAlt", size) }
    /// Dotted version of the same letters, for tracing.
    static func dots(_ size: CGFloat) -> CTFont { font("KGPrimaryDots", size) }

    private static func font(_ name: String, _ size: CGFloat) -> CTFont {
        if let d = descriptors[name] {
            return CTFontCreateWithFontDescriptor(d, size, nil)
        }
        return CTFontCreateUIFontForLanguage(.system, size, nil)!
    }
}

// MARK: - Guide metrics

/// Sizes for one handwriting row: top line, dashed midline, baseline, descender space.
struct GuideMetrics {
    let font: CTFont
    let ascent: CGFloat       // top line → baseline
    let xHeight: CGFloat      // baseline → midline
    let descentSpace: CGFloat // baseline → bottom of row
    let gap: CGFloat          // space between rows

    var rowHeight: CGFloat { ascent + descentSpace + gap }

    init(lineHeightInches: Double, dotted: Bool) {
        let target = CGFloat(lineHeightInches) * 72
        let make = dotted ? Fonts.dots : Fonts.penmanship
        // Scale the font so tall letters (d, l, capitals) touch the top line.
        let ref = make(100)
        let tall = "bdfhklAT".map { GuideMetrics.glyphTop($0, ref) }.reduce(CTFontGetCapHeight(ref), max)
        let font = make(100 * target / tall)
        self.font = font
        ascent = target
        // Put the midline where the short letters actually reach.
        xHeight = GuideMetrics.glyphTop("x", font)
        descentSpace = max(CTFontGetDescent(font) * 1.1, target * 0.4)
        gap = target * 0.3
    }

    private static func glyphTop(_ char: Character, _ font: CTFont) -> CGFloat {
        var chars = Array(String(char).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count) else { return 0 }
        return CTFontGetBoundingRectsForGlyphs(font, .default, &glyphs, nil, 1).maxY
    }
}

// MARK: - Layout

enum SheetRow: Equatable {
    case text(String)
    case blank
}

struct SheetLayout {
    static let pageSize = CGSize(width: 612, height: 792) // 8.5 × 11 in
    static let margin: CGFloat = 36                        // 0.5 in

    let sheet: CopySheet
    let guide: GuideMetrics
    let headerHeight: CGFloat
    let pages: [[SheetRow]]

    private static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    init(sheet: CopySheet) {
        self.sheet = sheet
        let guide = GuideMetrics(lineHeightInches: sheet.lineHeight,
                                 dotted: sheet.mode == .trace)
        self.guide = guide
        let headerHeight = SheetLayout.drawHeader(sheet, in: nil)
        self.headerHeight = headerHeight

        // Build groups of rows that should stay together on a page.
        let textInset = guide.ascent * 0.15
        let wrapWidth = SheetLayout.contentWidth - textInset * 2
        var groups: [[SheetRow]] = []
        for paragraph in sheet.body.components(separatedBy: .newlines) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            for line in wrap(trimmed, font: guide.font, width: wrapWidth) {
                switch sheet.mode {
                case .trace:
                    groups.append(Array(repeating: .text(line), count: max(1, sheet.traceRepeats)))
                case .copy:
                    groups.append([.text(line)] + Array(repeating: .blank, count: max(1, sheet.copyLines)))
                }
            }
        }

        // Paginate.
        let fullPage = SheetLayout.pageSize.height - SheetLayout.margin * 2
        var pages: [[SheetRow]] = [[]]
        var remaining = fullPage - headerHeight
        for group in groups {
            let needed = CGFloat(group.count) * guide.rowHeight
            if needed > remaining && !pages[pages.count - 1].isEmpty && needed <= fullPage {
                pages.append([])
                remaining = fullPage
            }
            for row in group {
                if guide.rowHeight > remaining && !pages[pages.count - 1].isEmpty {
                    pages.append([])
                    remaining = fullPage
                }
                pages[pages.count - 1].append(row)
                remaining -= guide.rowHeight
            }
        }
        if sheet.fillPage || groups.isEmpty {
            // Leave the page usable even with no text yet: fill with blank guides.
            while remaining >= guide.rowHeight - guide.gap {
                pages[pages.count - 1].append(.blank)
                remaining -= guide.rowHeight
            }
        }
        self.pages = pages
    }

    // MARK: Drawing

    /// Draws one page into a context using PDF coordinates (origin bottom-left, 612 × 792).
    func draw(page index: Int, in ctx: CGContext) {
        guard pages.indices.contains(index) else { return }
        ctx.saveGState()
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: SheetLayout.pageSize))

        var top = SheetLayout.margin
        if index == 0 {
            top += SheetLayout.drawHeader(sheet, in: ctx)
        }
        for row in pages[index] {
            drawRow(row, top: top, in: ctx)
            top += guide.rowHeight
        }
        ctx.restoreGState()
    }

    func pdfData() -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: SheetLayout.pageSize)
        let info = [kCGPDFContextTitle as String: sheet.title, kCGPDFContextCreator as String: "Copy Sheets"]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary)
        else { return Data() }
        for i in pages.indices {
            ctx.beginPDFPage(nil)
            draw(page: i, in: ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    private func drawRow(_ row: SheetRow, top: CGFloat, in ctx: CGContext) {
        let pageH = SheetLayout.pageSize.height
        let left = SheetLayout.margin
        let right = SheetLayout.pageSize.width - SheetLayout.margin
        let topY = pageH - top
        let baseY = topY - guide.ascent
        let midY = baseY + guide.xHeight
        let lineWidth = max(0.75, guide.ascent / 60)

        ctx.saveGState()
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(gray: 0.45, alpha: 1)
        ctx.strokeLineSegments(between: [CGPoint(x: left, y: topY), CGPoint(x: right, y: topY),
                                         CGPoint(x: left, y: baseY), CGPoint(x: right, y: baseY)])
        ctx.setStrokeColor(gray: 0.6, alpha: 1)
        ctx.setLineDash(phase: 0, lengths: [lineWidth * 5, lineWidth * 4])
        ctx.strokeLineSegments(between: [CGPoint(x: left, y: midY), CGPoint(x: right, y: midY)])
        ctx.restoreGState()

        guard case .text(let string) = row else { return }
        let path = glyphPath(string, font: guide.font)
        let gray: CGFloat = sheet.mode == .trace ? 0.25 : 0.1
        ctx.saveGState()
        ctx.translateBy(x: left + guide.ascent * 0.15, y: baseY)
        ctx.addPath(path)
        ctx.setFillColor(gray: gray, alpha: 1)
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// Draws (or just measures, when `ctx` is nil) the first-page header. Returns its height.
    @discardableResult
    private static func drawHeader(_ sheet: CopySheet, in ctx: CGContext?) -> CGFloat {
        let pageH = pageSize.height
        let left = margin
        let right = pageSize.width - margin
        var y = margin

        // Name / Date line
        let labelFont = Fonts.penmanship(15)
        let nameBase = y + 18
        let nameLabelW = drawText("Name:", font: labelFont, x: left, baseline: pageH - nameBase, in: ctx)
        let nameLineEnd = sheet.showDate ? left + contentWidth * 0.62 : right
        if let ctx {
            ctx.setStrokeColor(gray: 0.3, alpha: 1)
            ctx.setLineWidth(0.8)
            ctx.strokeLineSegments(between: [CGPoint(x: left + nameLabelW + 6, y: pageH - nameBase - 2),
                                             CGPoint(x: nameLineEnd, y: pageH - nameBase - 2)])
        }
        let name = sheet.studentName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            drawText(name, font: Fonts.penmanship(17), x: left + nameLabelW + 14, baseline: pageH - nameBase, in: ctx)
        }
        if sheet.showDate {
            let dateX = nameLineEnd + 24
            let dateLabelW = drawText("Date:", font: labelFont, x: dateX, baseline: pageH - nameBase, in: ctx)
            if let ctx {
                ctx.strokeLineSegments(between: [CGPoint(x: dateX + dateLabelW + 6, y: pageH - nameBase - 2),
                                                 CGPoint(x: right, y: pageH - nameBase - 2)])
            }
        }
        y = nameBase + 22

        // Title, shrunk to fit on one line
        let title = sheet.title.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty {
            var size: CGFloat = 28
            while size > 14 && textWidth(title, font: Fonts.penmanship(size)) > contentWidth { size -= 1 }
            let font = Fonts.penmanship(size)
            let w = textWidth(title, font: font)
            y += CTFontGetAscent(font)
            drawText(title, font: font, x: left + max(0, (contentWidth - w) / 2), baseline: pageH - y, in: ctx)
            y += CTFontGetDescent(font) + 6
        }

        // Description, centered and wrapped
        let desc = sheet.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !desc.isEmpty {
            let font = Fonts.penmanship(13)
            for paragraph in desc.components(separatedBy: .newlines) {
                for line in wrap(paragraph, font: font, width: contentWidth) {
                    y += 17
                    let w = textWidth(line, font: font)
                    drawText(line, font: font, x: left + (contentWidth - w) / 2, baseline: pageH - y,
                             gray: 0.25, in: ctx)
                }
            }
            y += 6
        }

        y += 18
        return y - margin
    }
}

// MARK: - Text helpers

private func attributed(_ s: String, font: CTFont, gray: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1),
    ])
}

private func textWidth(_ s: String, font: CTFont) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed(s, font: font)), nil, nil, nil))
}

/// Draws a single line of text and returns its width. With a nil context, only measures.
@discardableResult
private func drawText(_ s: String, font: CTFont, x: CGFloat, baseline: CGFloat,
                      gray: CGFloat = 0, in ctx: CGContext?) -> CGFloat {
    let line = CTLineCreateWithAttributedString(attributed(s, font: font, gray: gray))
    if let ctx {
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

/// Outlines of a line of text, origin at the start of the baseline.
private func glyphPath(_ s: String, font: CTFont) -> CGPath {
    let line = CTLineCreateWithAttributedString(attributed(s, font: font))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let runFont = attrs[kCTFontAttributeName as String] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(), &glyphs)
        CTRunGetPositions(run, CFRange(), &positions)
        for i in 0..<count {
            if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                path.addPath(g, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
    }
    return path
}

/// Greedy word wrap; words wider than the line are broken by character.
private func wrap(_ text: String, font: CTFont, width: CGFloat) -> [String] {
    var lines: [String] = []
    var current = ""
    for word in text.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
        let candidate = current.isEmpty ? word : current + " " + word
        if textWidth(candidate, font: font) <= width {
            current = candidate
            continue
        }
        if !current.isEmpty { lines.append(current) }
        current = ""
        for ch in word {
            if !current.isEmpty && textWidth(current + String(ch), font: font) > width {
                lines.append(current)
                current = ""
            }
            current.append(ch)
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}
