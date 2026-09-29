import SwiftUI

@main
struct CopySheetApp: App {
    init() {
        // Open straight to a new sheet instead of the Open dialog.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    var body: some Scene {
        DocumentGroup(newDocument: CopySheetDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            SheetCommands()
        }
    }
}

struct FocusedSheetKey: FocusedValueKey {
    typealias Value = CopySheet
}

extension FocusedValues {
    var copySheet: CopySheet? {
        get { self[FocusedSheetKey.self] }
        set { self[FocusedSheetKey.self] = newValue }
    }
}

struct SheetCommands: Commands {
    @FocusedValue(\.copySheet) private var sheet

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Export as PDF…") {
                if let sheet { SheetOutput.exportPDF(sheet) }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(sheet == nil)

            Button("Print…") {
                if let sheet { SheetOutput.print(sheet) }
            }
            .keyboardShortcut("p")
            .disabled(sheet == nil)
        }
    }
}
