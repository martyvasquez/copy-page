import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let copySheet = UTType(exportedAs: "com.vasquez.copysheet")
}

struct CopySheetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.copySheet] }

    var sheet: CopySheet

    init(sheet: CopySheet = CopySheet()) {
        self.sheet = sheet
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        sheet = try JSONDecoder().decode(CopySheet.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(sheet))
    }
}
