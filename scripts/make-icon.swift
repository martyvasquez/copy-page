// Renders the app icon. Usage: swift scripts/make-icon.swift <font.ttf> <out.png>
import AppKit
import CoreText

let args = CommandLine.arguments
let fontURL = URL(fileURLWithPath: args[1]) as CFURL
let desc = (CTFontManagerCreateFontDescriptorsFromURL(fontURL) as! [CTFontDescriptor])[0]
let S: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Background tile
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.80, blue: 0.36, alpha: 1))
ctx.fillPath()

// Paper
let paper = CGRect(x: 230, y: 170, width: 564, height: 690)
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.25))
ctx.addPath(CGPath(roundedRect: paper, cornerWidth: 28, cornerHeight: 28, transform: nil))
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Two rows of guide lines + letters
let font = CTFontCreateWithFontDescriptor(desc, 230, nil)
func row(top: CGFloat, text: String, fill: CGColor) {
    let base = top - 165
    let mid = base + CTFontGetXHeight(font)
    ctx.setLineWidth(7)
    ctx.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.55, blue: 0.85, alpha: 1))
    ctx.strokeLineSegments(between: [CGPoint(x: 280, y: top), CGPoint(x: 744, y: top),
                                     CGPoint(x: 280, y: base), CGPoint(x: 744, y: base)])
    ctx.setStrokeColor(CGColor(srgbRed: 0.85, green: 0.35, blue: 0.35, alpha: 1))
    ctx.setLineDash(phase: 0, lengths: [26, 20])
    ctx.strokeLineSegments(between: [CGPoint(x: 280, y: mid), CGPoint(x: 744, y: mid)])
    ctx.setLineDash(phase: 0, lengths: [])
    let attr = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): fill])
    ctx.textPosition = CGPoint(x: 320, y: base)
    CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
}
row(top: 790, text: "Aa", fill: CGColor(gray: 0.12, alpha: 1))
row(top: 480, text: "Aa", fill: CGColor(gray: 0.78, alpha: 1))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
