import Foundation

enum SheetMode: String, Codable, CaseIterable, Identifiable {
    case trace, copy
    var id: String { rawValue }
    var label: String { self == .trace ? "Trace" : "Copy" }
}

/// Distance from the top guide line to the baseline, in inches.
struct LineSize: Identifiable, Hashable {
    let inches: Double
    let label: String
    var id: Double { inches }

    static let presets: [LineSize] = [
        LineSize(inches: 1.5, label: "1½\" — Jumbo (age 3–4)"),
        LineSize(inches: 1.25, label: "1¼\" — Extra large"),
        LineSize(inches: 1.0, label: "1\" — Large (Pre-K / K)"),
        LineSize(inches: 0.75, label: "¾\" — Medium (1st grade)"),
        LineSize(inches: 0.625, label: "⅝\" — (2nd grade)"),
        LineSize(inches: 0.5, label: "½\" — Small (2nd–3rd grade)"),
        LineSize(inches: 0.375, label: "⅜\" — Extra small (3rd grade +)"),
    ]
}

/// Everything saved in a .copysheet file.
struct CopySheet: Codable, Equatable {
    var title = "My Copy Sheet"
    var description = ""
    var studentName = ""
    var showDate = true
    var body = "The quick brown fox jumps over the lazy dog."
    var mode: SheetMode = .copy
    var lineHeight: Double = 0.75
    var traceRepeats = 1
    var copyLines = 1
    var fillPage = false

    init() {}

    // Decode leniently so older files keep opening as new options are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CopySheet()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? d.title
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? d.description
        studentName = try c.decodeIfPresent(String.self, forKey: .studentName) ?? d.studentName
        showDate = try c.decodeIfPresent(Bool.self, forKey: .showDate) ?? d.showDate
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? d.body
        mode = try c.decodeIfPresent(SheetMode.self, forKey: .mode) ?? d.mode
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight) ?? d.lineHeight
        traceRepeats = try c.decodeIfPresent(Int.self, forKey: .traceRepeats) ?? d.traceRepeats
        copyLines = try c.decodeIfPresent(Int.self, forKey: .copyLines) ?? d.copyLines
        fillPage = try c.decodeIfPresent(Bool.self, forKey: .fillPage) ?? d.fillPage
    }
}
