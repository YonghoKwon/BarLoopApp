import BarLoopCore
import Foundation
import Observation
import UniformTypeIdentifiers

struct LocalMediaItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let fileName: String
    let kind: MediaKind
    let byteCount: Int64
    let url: URL

    var source: MediaSource {
        .localAsset(id: id, fileName: fileName, kind: kind)
    }
}

@MainActor
@Observable
final class LocalMediaLibrary {
    private(set) var items: [LocalMediaItem] = []
    private(set) var isImporting = false
    var errorMessage: String?

    static let supportedTypes: [UTType] = [.audio, .movie, .mpeg4Movie, .quickTimeMovie]

    private let fileManager = FileManager.default

    func refresh() async {
        do {
            let directory = try mediaDirectory()
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            )
            items = urls.compactMap(Self.item(from:)).sorted {
                $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func importFile(from sourceURL: URL) async -> LocalMediaItem? {
        isImporting = true
        defer { isImporting = false }
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let directory = try mediaDirectory()
            let id = UUID()
            let destination = directory.appendingPathComponent("\(id.uuidString)--\(sourceURL.lastPathComponent)")
            try fileManager.copyItem(at: sourceURL, to: destination)
            guard let item = Self.item(from: destination) else {
                try? fileManager.removeItem(at: destination)
                throw CocoaError(.fileReadUnknown)
            }
            items.append(item)
            items.sort { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
            return item
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func remove(_ item: LocalMediaItem) {
        do {
            try fileManager.removeItem(at: item.url)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.byteCount }
    }

    private func mediaDirectory() throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Media", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func item(from url: URL) -> LocalMediaItem? {
        let components = url.lastPathComponent.split(separator: "--", maxSplits: 1).map(String.init)
        guard components.count == 2, let id = UUID(uuidString: components[0]) else { return nil }
        let resource = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let type = resource?.contentType
        let kind: MediaKind
        if type?.conforms(to: .movie) == true {
            kind = .video
        } else if type?.conforms(to: .audio) == true {
            kind = .audio
        } else {
            let ext = url.pathExtension.lowercased()
            kind = ["mp4", "mov", "m4v", "webm"].contains(ext) ? .video : .audio
        }
        return .init(
            id: id,
            fileName: components[1],
            kind: kind,
            byteCount: Int64(resource?.fileSize ?? 0),
            url: url
        )
    }
}

