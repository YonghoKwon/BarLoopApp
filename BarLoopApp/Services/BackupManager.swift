import BarLoopCore
import SwiftUI
import UniformTypeIdentifiers

struct BarLoopBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(exportedAs: "com.yonghokwon.barloop.backup", conformingTo: .json)]
    }

    var backup: BarLoopBackup

    init(backup: BarLoopBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupError.invalidData
        }
        backup = try BackupCodec.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try BackupCodec.encode(backup))
    }
}

