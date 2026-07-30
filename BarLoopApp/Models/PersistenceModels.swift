import BarLoopCore
import Foundation
import SwiftData

@Model
final class StoredPracticeSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var activeSeconds: Int
    var label: String
    var startBPM: Int?
    var bestBPM: Int?
    var completed: Bool
    var note: String

    init(_ value: PracticeSession) {
        id = value.id
        startedAt = value.startedAt
        endedAt = value.endedAt
        activeSeconds = value.activeSeconds
        label = value.label
        startBPM = value.startBPM
        bestBPM = value.bestBPM
        completed = value.completed
        note = value.note
    }

    var value: PracticeSession {
        .init(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            label: label,
            startBPM: startBPM,
            bestBPM: bestBPM,
            completed: completed,
            note: note
        )
    }
}

@Model
final class StoredPracticeSection {
    @Attribute(.unique) var id: UUID
    var mediaKey: String
    var name: String
    var loopData: Data
    var note: String
    var targetRepeats: Int

    init(_ value: PracticeSection) {
        id = value.id
        mediaKey = value.mediaKey
        name = value.name
        loopData = (try? JSONEncoder().encode(value.loop)) ?? Data()
        note = value.note
        targetRepeats = value.targetRepeats
    }

    var value: PracticeSection? {
        guard let loop = try? JSONDecoder().decode(LoopDefinition.self, from: loopData) else { return nil }
        return .init(
            id: id,
            mediaKey: mediaKey,
            name: name,
            loop: loop,
            note: note,
            targetRepeats: targetRepeats
        )
    }
}

@Model
final class StoredDrumPattern {
    @Attribute(.unique) var id: String
    var data: Data

    init(_ value: DrumPattern) {
        id = value.id
        data = (try? JSONEncoder().encode(value)) ?? Data()
    }

    var value: DrumPattern? {
        try? JSONDecoder().decode(DrumPattern.self, from: data)
    }
}

@Model
final class StoredPracticeRoutine {
    @Attribute(.unique) var id: UUID
    var data: Data

    init(_ value: PracticeRoutine) {
        id = value.id
        data = (try? JSONEncoder().encode(value)) ?? Data()
    }

    var value: PracticeRoutine? {
        try? JSONDecoder().decode(PracticeRoutine.self, from: data)
    }
}

@Model
final class StoredMediaAsset {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var kindRawValue: String
    var byteCount: Int64
    var importedAt: Date

    init(id: UUID, fileName: String, kind: MediaKind, byteCount: Int64, importedAt: Date = .now) {
        self.id = id
        self.fileName = fileName
        kindRawValue = kind.rawValue
        self.byteCount = byteCount
        self.importedAt = importedAt
    }

    var kind: MediaKind {
        MediaKind(rawValue: kindRawValue) ?? .audio
    }
}

