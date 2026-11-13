import Foundation

public enum LibraryStoreError: Error, LocalizedError {
    case unavailable
    case corrupted

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "The library file could not be created."
        case .corrupted: return "The stored library could not be read."
        }
    }
}

public final class LibraryStore: @unchecked Sendable {
    public struct Envelope: Codable {
        public var schemaVersion: Int
        public var library: Library

        public init(schemaVersion: Int = 1, library: Library) {
            self.schemaVersion = schemaVersion
            self.library = library
        }
    }

    private let fileURL: URL
    private let backupURL: URL
    private let queue = DispatchQueue(label: "org.antennapod.library-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, fileName: String = "library.json") {
        self.fileURL = directory.appendingPathComponent(fileName)
        self.backupURL = directory.appendingPathComponent(fileName + ".bak")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public var url: URL { fileURL }

    public func load() -> Library {
        queue.sync {
            if let library = decode(at: fileURL) { return library }
            if let library = decode(at: backupURL) {
                try? FileManager.default.copyItem(at: backupURL, to: fileURL)
                return library
            }
            return Library()
        }
    }

    public func save(_ library: Library) {
        let envelope = Envelope(library: library)
        queue.async { [encoder, fileURL, backupURL] in
            guard let data = try? encoder.encode(envelope) else { return }
            let manager = FileManager.default
            if manager.fileExists(atPath: fileURL.path) {
                try? manager.removeItem(at: backupURL)
                try? manager.copyItem(at: fileURL, to: backupURL)
            }
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Persisting failures should not crash the app; the previous file is kept.
            }
        }
    }

    public func saveAndWait(_ library: Library) {
        let envelope = Envelope(library: library)
        queue.sync { [encoder, fileURL, backupURL] in
            guard let data = try? encoder.encode(envelope) else { return }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func decode(at url: URL) -> Library? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return envelope.library
        }
        return try? decoder.decode(Library.self, from: data)
    }
}
