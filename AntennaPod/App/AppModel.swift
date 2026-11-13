import Foundation
import Combine
import SwiftUI
import AntennaPodCore

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

struct RefreshProgress: Equatable {
    var completed: Int = 0
    var total: Int = 0

    var isActive: Bool { total > 0 && completed < total }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var library: Library
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshProgress = RefreshProgress()
    @Published var showNowPlaying = false
    @Published var alert: AppAlert?
    @Published var showingAddPodcast = false

    let store: LibraryStore
    let feedLoader: FeedLoader
    let searchClient: PodcastSearchClient
    let downloads: DownloadManager
    let player: PlaybackController

    private var lastProgressPersist = Date.distantPast

    init(directory: URL = LibraryLocation.applicationSupportDirectory()) {
        let store = LibraryStore(directory: directory)
        self.store = store
        self.library = store.load()
        self.feedLoader = FeedLoader()
        self.searchClient = PodcastSearchClient()
        self.downloads = DownloadManager()
        self.player = PlaybackController()

        downloadManagerWiring()
        applySettingsToPlayer()
        downloads.reconcile(with: library.episodes)
    }

    private func downloadManagerWiring() {
        player.onProgress = { [weak self] episodeID, position, duration in
            self?.handleProgress(episodeID: episodeID, position: position, duration: duration)
        }
        player.onFinished = { [weak self] episodeID in
            self?.handleFinished(episodeID: episodeID)
        }
        player.artworkURLProvider = { [weak self] episode in
            self?.library.podcast(id: episode.podcastID)?.imageURL
        }
        downloads.onDownloadFinished = { [weak self] episodeID, _ in
            self?.objectWillChange.send()
            _ = episodeID
        }
    }

    private func applySettingsToPlayer() {
        player.rate = library.settings.playbackSpeed
        player.skipForwardSeconds = library.settings.skipForwardSeconds
        player.skipBackwardSeconds = library.settings.skipBackwardSeconds
        player.refreshPreferredIntervals()
    }

    var subscribedPodcasts: [Podcast] {
        library.subscribedPodcasts.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    var downloadCount: Int {
        downloads.downloadedFiles.count
    }

    var downloadedBytesDescription: String {
        ByteCountFormatter.string(fromByteCount: downloads.totalDownloadedBytes(), countStyle: .file)
    }

    func podcast(for episode: Episode) -> Podcast? {
        library.podcast(id: episode.podcastID)
    }

    func isDownloaded(_ episode: Episode) -> Bool {
        downloads.isDownloaded(episode)
    }

    func downloadProgress(for episode: Episode) -> Double? {
        downloads.progress[episode.id]
    }

    func isDownloading(_ episode: Episode) -> Bool {
        downloads.activeEpisodeIDs.contains(episode.id)
    }

    func persist() {
        store.save(library)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            persist()
        case .active:
            Task { await refreshIfNeeded() }
        default:
            break
        }
    }

    func refreshIfNeeded() async {
        guard !isRefreshing else { return }
        let last = library.settings.lastRefreshAt ?? .distantPast
        let interval = TimeInterval(max(1, library.settings.refreshIntervalHours)) * 3600
        if Date().timeIntervalSince(last) < interval { return }
        await refreshAll()
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        let podcasts = library.subscribedPodcasts
        guard !podcasts.isEmpty else { return }

        isRefreshing = true
        refreshProgress = RefreshProgress(completed: 0, total: podcasts.count)
        let loader = feedLoader

        for chunk in podcasts.chunked(into: 4) {
            await withTaskGroup(of: (String, Result<FeedLoadResult, Error>).self) { group in
                for podcast in chunk {
                    group.addTask {
                        do {
                            let result = try await loader.load(url: podcast.feedURL,
                                                               etag: podcast.etag,
                                                               lastModified: podcast.lastModified)
                            return (podcast.id, .success(result))
                        } catch {
                            return (podcast.id, .failure(error))
                        }
                    }
                }
                for await (podcastID, result) in group {
                    applyRefreshResult(podcastID: podcastID, result: result)
                    refreshProgress.completed += 1
                }
            }
        }

        library.settings.lastRefreshAt = Date()
        isRefreshing = false
        persist()
        downloads.reconcile(with: library.episodes)
        autoDownloadIfEnabled()
    }

    private func applyRefreshResult(podcastID: String, result: Result<FeedLoadResult, Error>) {
        switch result {
        case .success(let loaded):
            library.merge(feed: loaded.feed, etag: loaded.etag, lastModified: loaded.lastModified)
            library.updatePodcast(id: podcastID) {
                $0.lastRefreshedAt = Date()
                $0.lastRefreshFailed = false
            }
        case .failure:
            library.updatePodcast(id: podcastID) {
                $0.lastRefreshFailed = true
            }
        }
    }

    func refresh(podcastID: String) async {
        guard let podcast = library.podcast(id: podcastID) else { return }
        do {
            let loaded = try await feedLoader.load(url: podcast.feedURL,
                                                   etag: podcast.etag,
                                                   lastModified: podcast.lastModified)
            library.merge(feed: loaded.feed, etag: loaded.etag, lastModified: loaded.lastModified)
            library.updatePodcast(id: podcastID) {
                $0.lastRefreshedAt = Date()
                $0.lastRefreshFailed = false
            }
            persist()
            downloads.reconcile(with: library.episodes)
            if library.settings.autoDownloadNewEpisodes || podcast.autoDownload {
                autoDownloadLatest(for: podcastID)
            }
        } catch {
            library.updatePodcast(id: podcastID) { $0.lastRefreshFailed = true }
            persist()
            alert = AppAlert(title: "Could not refresh podcast", message: error.localizedDescription)
        }
    }

    func subscribe(feedURL: URL) async throws {
        let loaded = try await feedLoader.load(url: feedURL)
        library.merge(feed: loaded.feed, etag: loaded.etag, lastModified: loaded.lastModified)
        library.updatePodcast(id: loaded.feed.podcast.id) {
            $0.isSubscribed = true
            $0.lastRefreshedAt = Date()
            $0.lastRefreshFailed = false
        }
        persist()
        downloads.reconcile(with: library.episodes)
        if library.settings.autoDownloadNewEpisodes {
            autoDownloadLatest(for: loaded.feed.podcast.id)
        }
    }

    func subscribe(searchResult: PodcastSearchResult) async throws {
        library.subscribe(to: searchResult.feedURL)
        persist()
        try await subscribe(feedURL: searchResult.feedURL)
    }

    func unsubscribe(podcastID: String) {
        let episodeIDs = Set(library.episodes.filter { $0.podcastID == podcastID }.map(\.id))
        if let current = player.currentEpisode, episodeIDs.contains(current.id) {
            player.stop()
        }
        let episodes = library.episodes.filter { $0.podcastID == podcastID }
        downloads.deleteAllDownloads(for: episodes)
        library.unsubscribe(podcastID: podcastID)
        persist()
    }

    func setPodcastAutoDownload(podcastID: String, enabled: Bool) {
        library.updatePodcast(id: podcastID) { $0.autoDownload = enabled }
        persist()
        if enabled { autoDownloadLatest(for: podcastID) }
    }

    func renamePodcast(podcastID: String, title: String) {
        library.updatePodcast(id: podcastID) {
            $0.customTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title
        }
        persist()
    }

    func setSortOrder(podcastID: String, order: EpisodeSortOrder) {
        library.updatePodcast(id: podcastID) { $0.sortOrder = order }
        persist()
    }

    func play(_ episode: Episode) {
        guard let media = episode.media else {
            alert = AppAlert(title: "No audio", message: "This episode does not include an audio file.")
            return
        }
        guard downloads.activeEpisodeIDs.contains(episode.id) == false else {
            alert = AppAlert(title: "Downloading", message: "This episode is still downloading.")
            return
        }

        if !library.queue.contains(episode.id) {
            library.enqueue(episode.id, next: true)
            persist()
        }

        let url = downloads.localFile(for: episode) ?? media.url
        let podcastTitle = library.podcast(id: episode.podcastID)?.displayTitle ?? ""
        player.load(episode: episode, podcastTitle: podcastTitle, url: url, startAt: episode.playbackPosition)
        applySettingsToPlayer()
        player.play()
    }

    func playFromQueueOrInbox() {
        if let next = library.queueEpisodes.first(where: { !$0.isPlayed }) {
            play(next)
        } else if let next = library.inbox.first {
            play(next)
        }
    }

    func togglePlayPause() {
        if player.currentEpisode == nil {
            playFromQueueOrInbox()
        } else {
            player.toggle()
        }
    }

    func playNext(_ episode: Episode) {
        library.enqueue(episode.id, next: true)
        persist()
        play(episode)
    }

    func enqueue(_ episode: Episode, next: Bool = false) {
        library.enqueue(episode.id, next: next)
        persist()
    }

    func dequeue(_ episode: Episode) {
        library.dequeue(episode.id)
        persist()
    }

    func moveQueue(from source: IndexSet, to destination: Int) {
        library.moveQueue(from: source, to: destination)
        persist()
    }

    func removeFromQueue(at offsets: IndexSet) {
        library.removeFromQueue(at: offsets)
        persist()
    }

    func clearQueue() {
        library.clearQueue()
        persist()
    }

    func setPlayed(_ episode: Episode, played: Bool) {
        library.setPlayed(episode.id, played: played)
        persist()
    }

    func toggleFavorite(_ episode: Episode) {
        library.setFavorite(episode.id, favorite: !episode.isFavorite)
        persist()
    }

    func markAllPlayed(podcastID: String) {
        library.markAllPlayed(podcastID: podcastID)
        persist()
    }

    func download(_ episode: Episode) {
        downloads.download(episode)
    }

    func cancelDownload(_ episode: Episode) {
        downloads.cancel(episode.id)
    }

    func deleteDownload(_ episode: Episode) {
        downloads.deleteDownload(for: episode)
        persist()
    }

    func deleteAllDownloads() {
        downloads.removeAllDownloads()
        persist()
    }

    func handleProgress(episodeID: String, position: TimeInterval, duration: TimeInterval) {
        library.updatePlaybackPosition(episodeID, position: position, duration: duration)
        if Date().timeIntervalSince(lastProgressPersist) > 10 {
            lastProgressPersist = Date()
            persist()
        }
    }

    private func handleFinished(episodeID: String) {
        library.setPlayed(episodeID, played: true)
        library.dequeue(episodeID)
        persist()

        guard library.settings.continuousPlayback else { return }
        if let next = library.nextEpisode(after: episodeID) {
            play(next)
        } else {
            player.stop()
        }
    }

    private func autoDownloadIfEnabled() {
        for podcast in library.subscribedPodcasts where podcast.autoDownload || library.settings.autoDownloadNewEpisodes {
            autoDownloadLatest(for: podcast.id)
        }
    }

    private func autoDownloadLatest(for podcastID: String) {
        guard let podcast = library.podcast(id: podcastID) else { return }
        let limit = max(1, library.settings.autoDownloadLimitPerPodcast)
        let candidates = library.episodes(for: podcastID, sort: .newestFirst)
            .filter { !$0.isPlayed && $0.media != nil && !downloads.isDownloaded($0) }
            .prefix(limit)
        for episode in candidates {
            downloads.download(episode)
        }
    }

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        update(&library.settings)
        applySettingsToPlayer()
        persist()
    }

    func setPlaybackSpeed(_ speed: Double) {
        updateSettings { $0.playbackSpeed = speed }
    }

    func setSkipIntervals(forward: Int, backward: Int) {
        updateSettings {
            $0.skipForwardSeconds = forward
            $0.skipBackwardSeconds = backward
        }
    }

    func exportOPML() -> String {
        let feeds = library.subscribedPodcasts.map {
            OPMLFeed(title: $0.displayTitle, feedURL: $0.feedURL, htmlURL: $0.websiteURL)
        }
        return OPML.write(OPMLDocument(feeds: feeds))
    }

    func importOPML(data: Data) async -> String {
        guard let feeds = try? OPML.parse(data: data), !feeds.isEmpty else {
            return "No subscriptions were found in that file."
        }
        let newFeeds = feeds.filter { !library.contains(feedURL: $0.feedURL) }
        guard !newFeeds.isEmpty else { return "All subscriptions in that file are already in your library." }

        var succeeded = 0
        var failed = 0
        let loader = feedLoader

        for chunk in newFeeds.chunked(into: 4) {
            await withTaskGroup(of: Result<FeedLoadResult, Error>.self) { group in
                for feed in chunk {
                    group.addTask {
                        do { return .success(try await loader.load(url: feed.feedURL)) }
                        catch { return .failure(error) }
                    }
                }
                for await result in group {
                    switch result {
                    case .success(let loaded):
                        library.merge(feed: loaded.feed, etag: loaded.etag, lastModified: loaded.lastModified)
                        library.updatePodcast(id: loaded.feed.podcast.id) {
                            $0.isSubscribed = true
                            $0.lastRefreshedAt = Date()
                        }
                        succeeded += 1
                    case .failure:
                        failed += 1
                    }
                }
            }
        }

        persist()
        downloads.reconcile(with: library.episodes)
        if succeeded == 0 {
            return "Could not import any podcasts. \(failed) failed to load."
        }
        if failed > 0 {
            return "Imported \(succeeded) podcast(s). \(failed) could not be loaded."
        }
        return "Imported \(succeeded) podcast(s)."
    }

    func normalizedFeedURL(from input: String) -> URL? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.lowercased().hasPrefix("feed://") {
            value = "https://" + value.dropFirst("feed://".count)
        }
        if !value.contains("://") {
            value = "https://" + value
        }
        guard let url = URL(string: value), let host = url.host, host.contains(".") else { return nil }
        return url
    }
}
