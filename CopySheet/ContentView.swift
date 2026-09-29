import SwiftUI

struct ContentView: View {
    @Binding var document: CopySheetDocument

    private var sheet: Binding<CopySheet> { $document.sheet }

    var body: some View {
        HSplitView {
            editor
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
            SheetPreview(layout: SheetLayout(sheet: document.sheet))
                .frame(minWidth: 420)
        }
        .focusedSceneValue(\.copySheet, document.sheet)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    SheetOutput.exportPDF(document.sheet)
                } label: {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                }
                .help("Export as PDF (⇧⌘E)")

                Button {
                    SheetOutput.print(document.sheet)
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .help("Print (⌘P)")
            }
        }
    }

    private var editor: some View {
        Form {
            Section("Sheet") {
                TextField("Title", text: sheet.title)
                TextField("Description", text: sheet.description, prompt: Text("Optional instructions"),
                          axis: .vertical)
                    .lineLimit(2...5)
                TextField("Name", text: sheet.studentName, prompt: Text("Leave blank to write in"))
                Toggle("Date line", isOn: sheet.showDate)
            }

            Section("Practice") {
                Picker("Mode", selection: sheet.mode) {
                    ForEach(SheetMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Line size", selection: sheet.lineHeight) {
                    ForEach(LineSize.presets) { Text($0.label).tag($0.inches) }
                }

                if document.sheet.mode == .trace {
                    Stepper("Trace each line: \(document.sheet.traceRepeats)×",
                            value: sheet.traceRepeats, in: 1...6)
                } else {
                    Stepper("Blank lines under each: \(document.sheet.copyLines)",
                            value: sheet.copyLines, in: 1...6)
                }
                Toggle("Fill rest of page with blank lines", isOn: sheet.fillPage)
            }

            Section {
                TextEditor(text: sheet.body)
                    .font(.system(size: 15))
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Text")
            } footer: {
                Text("Each line you type starts a new row. Long lines wrap automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Live preview drawn with the same code that makes the PDF.
struct SheetPreview: View {
    let layout: SheetLayout

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(layout.pages.indices, id: \.self) { index in
                    Canvas { context, size in
                        context.withCGContext { cg in
                            cg.translateBy(x: 0, y: size.height)
                            cg.scaleBy(x: size.width / SheetLayout.pageSize.width,
                                       y: -size.height / SheetLayout.pageSize.height)
                            layout.draw(page: index, in: cg)
                        }
                    }
                    .aspectRatio(SheetLayout.pageSize.width / SheetLayout.pageSize.height, contentMode: .fit)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .overlay(alignment: .bottomTrailing) {
                        if layout.pages.count > 1 {
                            Text("Page \(index + 1) of \(layout.pages.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
