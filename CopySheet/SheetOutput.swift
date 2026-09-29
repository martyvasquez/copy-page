import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Print and PDF export for a sheet.
enum SheetOutput {
    static func print(_ sheet: CopySheet) {
        guard let pdf = PDFDocument(data: SheetLayout(sheet: sheet).pdfData()) else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = SheetLayout.pageSize
        info.orientation = .portrait
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.jobDisposition = .spool
        guard let op = pdf.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) else { return }
        op.jobTitle = fileName(for: sheet)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        if let window = NSApp.keyWindow {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
    }

    static func exportPDF(_ sheet: CopySheet) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName(for: sheet) + ".pdf"
        panel.canCreateDirectories = true
        let data = SheetLayout(sheet: sheet).pdfData()
        let save = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: save)
        } else {
            save(panel.runModal())
        }
    }

    private static func fileName(for sheet: CopySheet) -> String {
        let title = sheet.title.trimmingCharacters(in: .whitespaces)
        let safe = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return safe.isEmpty ? "Copy Sheet" : safe
    }
}
