import Foundation

public struct BarLoopBackup: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var practiceSettings: PracticeSettings
    public var metronomeSettings: MetronomeSettings
    public var tempoTrainerSettings: TempoTrainerSettings
    public var sections: [PracticeSection]
    public var sessions: [PracticeSession]
    public var patterns: [DrumPattern]
    public var routines: [PracticeRoutine]

    public init(
        version: Int = currentVersion,
        exportedAt: Date = .now,
        practiceSettings: PracticeSettings,
        metronomeSettings: MetronomeSettings,
        tempoTrainerSettings: TempoTrainerSettings = .init(),
        sections: [PracticeSection],
        sessions: [PracticeSession],
        patterns: [DrumPattern],
        routines: [PracticeRoutine]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.practiceSettings = practiceSettings
        self.metronomeSettings = metronomeSettings
        self.tempoTrainerSettings = tempoTrainerSettings
        self.sections = sections
        self.sessions = sessions
        self.patterns = patterns
        self.routines = routines
    }
}

public enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version): "Unsupported BarLoop backup version \(version)."
        case .invalidData: "The selected file is not a valid BarLoop backup."
        }
    }
}

public enum BackupCodec {
    public static func encode(_ backup: BarLoopBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    public static func decode(_ data: Data) throws -> BarLoopBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BarLoopBackup.self, from: data) else {
            throw BackupError.invalidData
        }
        guard backup.version == BarLoopBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return backup
    }
}
