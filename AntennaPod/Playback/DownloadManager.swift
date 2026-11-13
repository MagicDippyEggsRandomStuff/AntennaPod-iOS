import Foundation
import UIKit
import AntennaPodCore

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let sessionIdentifier = "org.antennapod.ios.downloads"

    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var activeEpisodeIDs: Set<String> = []
    @Published private(set) var downloadedFiles: [String: URL] = [:]
    @Published private(set) var lastError: String?

    let directory: URL
    var onDownloadFinished: ((String, URL) -> Void)?

    private var session: URLSession!

    init(directory: URL = LibraryLocation.downloadsDirectory()) {
        self.directory = directory
        super.init()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func reconcile(with episodes: [Episode]) {
        let existing = DownloadLibrary.existingEpisodeIDs(for: episodes, in: directory)
        DispatchQueue.main.async {
            self.downloadedFiles = existing
        }
    }

    func isDownloaded(_ episode: Episode) -> Bool {
        if downloadedFiles[episode.id] != nil { return true }
        return DownloadLibrary.existingFile(for: episode, in: directory) != nil
    }

    func localFile(for episode: Episode) -> URL? {
        if let url = downloadedFiles[episode.id] { return url }
        return DownloadLibrary.existingFile(for: episode, in: directory)
    }

    func download(_ episode: Episode) {
        guard let media = episode.media, !isDownloaded(episode), !activeEpisodeIDs.contains(episode.id) else { return }
        let payload = Self.payload(episode: episode)
        let task = session.downloadTask(with: media.url)
        task.taskDescription = payload
        task.countOfBytesClientExpectsToReceive = media.byteLength ?? NSURLSessionTransferSizeUnknown
        task.resume()
        activeEpisodeIDs.insert(episode.id)
        progress[episode.id] = 0
    }

    func cancel(_ episodeID: String) {
        session.getAllTasks { [weak self] tasks in
            for task in tasks where task.taskDescription?.hasPrefix("\(episodeID)|") == true {
                task.cancel()
            }
            DispatchQueue.main.async {
                self?.activeEpisodeIDs.remove(episodeID)
                self?.progress[episodeID] = nil
            }
        }
    }

    func deleteDownload(for episode: Episode) {
        DownloadLibrary.deleteDownload(for: episode, in: directory)
        downloadedFiles[episode.id] = nil
        progress[episode.id] = nil
        activeEpisodeIDs.remove(episode.id)
    }

    func deleteAllDownloads(for episodes: [Episode]) {
        for episode in episodes {
            DownloadLibrary.deleteDownload(for: episode, in: directory)
            downloadedFiles[episode.id] = nil
            progress[episode.id] = nil
        }
    }

    func totalDownloadedBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }

    func removeAllDownloads() {
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
        }
        downloadedFiles.removeAll()
        progress.removeAll()
    }

    private static func payload(episode: Episode) -> String {
        "\(episode.id)|\(DownloadPaths.fileName(for: episode))"
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let description = downloadTask.taskDescription,
              let parsed = Self.parsePayloadStatic(description) else { return }
        let fraction: Double
        if totalBytesExpectedToWrite > 0 {
            fraction = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        } else {
            fraction = 0
        }
        DispatchQueue.main.async {
            self.progress[parsed.episodeID] = fraction
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let description = downloadTask.taskDescription,
              let parsed = Self.parsePayloadStatic(description) else { return }
        let destination = directory.appendingPathComponent(parsed.fileName)
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: destination)
        do {
            try fileManager.moveItem(at: location, to: destination)
        } catch {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.progress[parsed.episodeID] = nil
                self.activeEpisodeIDs.remove(parsed.episodeID)
            }
            return
        }

        DispatchQueue.main.async {
            self.progress[parsed.episodeID] = nil
            self.activeEpisodeIDs.remove(parsed.episodeID)
            self.downloadedFiles[parsed.episodeID] = destination
            self.onDownloadFinished?(parsed.episodeID, destination)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let description = task.taskDescription,
              let parsed = Self.parsePayloadStatic(description) else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }
        DispatchQueue.main.async {
            self.lastError = error.localizedDescription
            self.progress[parsed.episodeID] = nil
            self.activeEpisodeIDs.remove(parsed.episodeID)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let delegate = UIApplication.shared.delegate as? AppDelegate,
                  let handler = delegate.backgroundCompletionHandler else { return }
            handler()
            delegate.backgroundCompletionHandler = nil
        }
    }

    private static func parsePayloadStatic(_ description: String) -> (episodeID: String, fileName: String)? {
        let parts = description.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}
