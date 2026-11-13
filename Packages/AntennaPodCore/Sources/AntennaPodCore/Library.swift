import Foundation

public struct Library: Codable, Equatable, Sendable {
    public private(set) var podcasts: [Podcast]
    public private(set) var episodes: [Episode]
    public private(set) var queue: [String]
    public var settings: AppSettings

    public init(podcasts: [Podcast] = [],
                episodes: [Episode] = [],
                queue: [String] = [],
                settings: AppSettings = AppSettings()) {
        self.podcasts = podcasts
        self.episodes = episodes
        self.queue = queue
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        podcasts = try container.decodeIfPresent([Podcast].self, forKey: .podcasts) ?? []
        episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
        queue = try container.decodeIfPresent([String].self, forKey: .queue) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }

    public var subscribedPodcasts: [Podcast] {
        podcasts.filter(\.isSubscribed)
    }

    public func podcast(id: String) -> Podcast? {
        podcasts.first { $0.id == id }
    }

    public func episode(id: String) -> Episode? {
        episodes.first { $0.id == id }
    }

    public func episodes(for podcastID: String, sort: EpisodeSortOrder? = nil) -> [Episode] {
        let filtered = episodes.filter { $0.podcastID == podcastID }
        return Library.sorted(filtered, by: sort ?? podcast(id: podcastID)?.sortOrder ?? .newestFirst)
    }

    public var inbox: [Episode] {
        let subscribedIDs = Set(subscribedPodcasts.map(\.id))
        let unplayed = episodes.filter { subscribedIDs.contains($0.podcastID) && !$0.isPlayed }
        return Library.sorted(unplayed, by: .newestFirst)
    }

    public var inProgress: [Episode] {
        episodes.filter(\.isInProgress)
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    public var favorites: [Episode] {
        episodes.filter(\.isFavorite)
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    public var queueEpisodes: [Episode] {
        queue.compactMap { id in episodes.first { $0.id == id } }
    }

    public func isSubscribed(podcastID: String) -> Bool {
        podcast(id: podcastID)?.isSubscribed ?? false
    }

    @discardableResult
    public mutating func subscribe(to feedURL: URL, now: Date = Date()) -> Podcast {
        let identifier = Podcast.identifier(for: feedURL)
        if let index = podcasts.firstIndex(where: { $0.id == identifier }) {
            podcasts[index].isSubscribed = true
            return podcasts[index]
        }
        let podcast = Podcast(feedURL: feedURL, title: feedURL.host ?? feedURL.absoluteString,
                             isSubscribed: true, addedAt: now)
        podcasts.append(podcast)
        return podcast
    }

    public mutating func unsubscribe(podcastID: String) {
        guard let index = podcasts.firstIndex(where: { $0.id == podcastID }) else { return }
        podcasts[index].isSubscribed = false
        let removedEpisodeIDs = Set(episodes.filter { $0.podcastID == podcastID }.map(\.id))
        queue.removeAll { removedEpisodeIDs.contains($0) }
    }

    @discardableResult
    public mutating func merge(feed: ParsedFeed,
                               etag: String? = nil,
                               lastModified: String? = nil,
                               now: Date = Date()) -> Int {
        var incoming = feed.podcast
        incoming.etag = etag ?? incoming.etag
        incoming.lastModified = lastModified ?? incoming.lastModified

        if let index = podcasts.firstIndex(where: { $0.id == incoming.id }) {
            let existing = podcasts[index]
            incoming.addedAt = existing.addedAt
            incoming.customTitle = existing.customTitle
            incoming.autoDownload = existing.autoDownload
            incoming.sortOrder = existing.sortOrder
            incoming.isSubscribed = existing.isSubscribed || incoming.isSubscribed
            incoming.etag = etag ?? existing.etag
            incoming.lastModified = lastModified ?? existing.lastModified
            if incoming.imageURL == nil { incoming.imageURL = existing.imageURL }
            if incoming.author == nil { incoming.author = existing.author }
            if incoming.summary == nil { incoming.summary = existing.summary }
            podcasts[index] = incoming
        } else if let index = podcasts.firstIndex(where: { $0.feedURL == incoming.feedURL }) {
            podcasts[index] = incoming
        } else {
            podcasts.append(incoming)
        }

        var previous: [String: Episode] = [:]
        for episode in episodes where episode.podcastID == incoming.id {
            previous[episode.id] = episode
        }

        var merged: [Episode] = []
        merged.reserveCapacity(feed.episodes.count)
        var newCount = 0

        for var episode in feed.episodes {
            episode.podcastID = incoming.id
            if let existing = previous.removeValue(forKey: episode.id) {
                episode.isPlayed = existing.isPlayed
                episode.isFavorite = existing.isFavorite
                episode.playbackPosition = existing.playbackPosition
                episode.addedAt = existing.addedAt
                if episode.imageURL == nil { episode.imageURL = existing.imageURL }
            } else {
                episode.addedAt = now
                newCount += 1
            }
            merged.append(episode)
        }

        let localOnly = Array(previous.values)
        if !merged.isEmpty {
            episodes.removeAll { $0.podcastID == incoming.id }
            episodes.append(contentsOf: merged)
            episodes.append(contentsOf: localOnly)
        }
        return newCount
    }

    public mutating func setPlayed(_ episodeID: String, played: Bool, now: Date = Date()) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].isPlayed = played
        if played {
            episodes[index].playbackPosition = episodes[index].duration ?? episodes[index].playbackPosition
        } else if episodes[index].playbackPosition >= (episodes[index].duration ?? .greatestFiniteMagnitude) {
            episodes[index].playbackPosition = 0
        }
    }

    public mutating func markAllPlayed(podcastID: String, played: Bool = true) {
        for index in episodes.indices where episodes[index].podcastID == podcastID {
            episodes[index].isPlayed = played
        }
    }

    public mutating func setFavorite(_ episodeID: String, favorite: Bool) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].isFavorite = favorite
    }

    public mutating func updatePlaybackPosition(_ episodeID: String, position: TimeInterval, duration: TimeInterval? = nil) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].playbackPosition = max(0, position)
        if let duration, duration > 0, episodes[index].duration == nil {
            episodes[index].media?.duration = duration
        }
    }

    public mutating func enqueue(_ episodeID: String, next: Bool = false) {
        guard episodes.contains(where: { $0.id == episodeID }) else { return }
        queue.removeAll { $0 == episodeID }
        if next {
            queue.insert(episodeID, at: 0)
        } else {
            queue.append(episodeID)
        }
    }

    public mutating func dequeue(_ episodeID: String) {
        queue.removeAll { $0 == episodeID }
    }

    public mutating func removeFromQueue(at offsets: IndexSet) {
        let ids = offsets.map { queue[$0] }
        queue.removeAll { ids.contains($0) }
    }

    public mutating func moveQueue(from source: IndexSet, to destination: Int) {
        let moving = source.map { queue[$0] }
        queue.removeAll { moving.contains($0) }
        let adjusted = destination - source.filter { $0 < destination }.count
        queue.insert(contentsOf: moving, at: min(adjusted, queue.count))
    }

    public mutating func clearQueue() {
        queue.removeAll()
    }

    public func nextEpisode(after episodeID: String, respectsQueue: Bool = true) -> Episode? {
        if respectsQueue, let index = queue.firstIndex(of: episodeID), index + 1 < queue.count {
            return self.episode(id: queue[index + 1])
        }
        guard let current = episode(id: episodeID) else { return nil }
        let siblings = Library.sorted(episodes(for: current.podcastID, sort: .newestFirst), by: .newestFirst)
        guard let index = siblings.firstIndex(where: { $0.id == episodeID }),
              index + 1 < siblings.count else { return nil }
        return siblings[index + 1]
    }

    public mutating func updatePodcast(id: String, _ update: (inout Podcast) -> Void) {
        guard let index = podcasts.firstIndex(where: { $0.id == id }) else { return }
        update(&podcasts[index])
    }

    public mutating func removePodcastData(podcastID: String) {
        podcasts.removeAll { $0.id == podcastID }
        let ids = Set(episodes.filter { $0.podcastID == podcastID }.map(\.id))
        episodes.removeAll { $0.podcastID == podcastID }
        queue.removeAll { ids.contains($0) }
    }

    public func contains(feedURL: URL) -> Bool {
        podcasts.contains { $0.feedURL == feedURL }
    }
}

public extension Library {
    static func sorted(_ episodes: [Episode], by order: EpisodeSortOrder) -> [Episode] {
        switch order {
        case .newestFirst:
            return episodes.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        case .oldestFirst:
            return episodes.sorted { ($0.publishedAt ?? .distantPast) < ($1.publishedAt ?? .distantPast) }
        case .title:
            return episodes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            return episodes.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .smart:
            return episodes.sorted { left, right in
                if left.isPlayed != right.isPlayed { return !left.isPlayed }
                return (left.publishedAt ?? .distantPast) > (right.publishedAt ?? .distantPast)
            }
        }
    }
}
