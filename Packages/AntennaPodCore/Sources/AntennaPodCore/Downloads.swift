import Foundation

public enum DownloadPaths {
    public static func fileName(for episode: Episode) -> String {
        let extensionPart = episode.media?.fileExtension ?? "mp3"
        return "\(stableHash(episode.id)).\(extensionPart)"
    }

    public static func fileURL(for episode: Episode, in directory: URL) -> URL {
        directory.appendingPathComponent(fileName(for: episode))
    }

    public static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

public enum LibraryLocation {
    public static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("AntennaPod", isDirectory: true)
    }

    public static func downloadsDirectory(fileManager: FileManager = .default) -> URL {
        let url = applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func artwororkCacheDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base.appendingPathComponent("Artwork", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

public struct DownloadedEpisode: Equatable, Sendable {
    public var episodeID: String
    public var fileURL: URL
    public var downloadedAt: Date

    public init(episodeID: String, fileURL: URL, downloadedAt: Date = Date()) {
        self.episodeID = episodeID
        self.fileURL = fileURL
        self.downloadedAt = downloadedAt
    }
}

public enum DownloadLibrary {
    public static func existingFile(for episode: Episode, in directory: URL,
                                    fileManager: FileManager = .default) -> URL? {
        let url = DownloadPaths.fileURL(for: episode, in: directory)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    public static func existingEpisodeIDs(for episodes: [Episode], in directory: URL,
                                          fileManager: FileManager = .default) -> [String: URL] {
        var result: [String: URL] = [:]
        for episode in episodes {
            if let url = existingFile(for: episode, in: directory, fileManager: fileManager) {
                result[episode.id] = url
            }
        }
        return result
    }

    public static func deleteDownload(for episode: Episode, in directory: URL,
                                      fileManager: FileManager = .default) {
        let url = DownloadPaths.fileURL(for: episode, in: directory)
        try? fileManager.removeItem(at: url)
    }
}
