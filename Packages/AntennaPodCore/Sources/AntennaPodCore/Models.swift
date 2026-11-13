import Foundation

public enum EpisodeSortOrder: String, Codable, CaseIterable, Sendable {
    case newestFirst
    case oldestFirst
    case title
    case duration
    case smart

    public var displayName: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        case .title: return "Title"
        case .duration: return "Duration"
        case .smart: return "Smart (unplayed first)"
        }
    }
}

public struct Podcast: Codable, Identifiable, Hashable, Sendable {
    public var feedURL: URL
    public var title: String
    public var customTitle: String?
    public var author: String?
    public var summary: String?
    public var imageURL: URL?
    public var websiteURL: URL?
    public var language: String?
    public var isExplicit: Bool
    public var fundingURL: URL?
    public var isSubscribed: Bool
    public var autoDownload: Bool
    public var sortOrder: EpisodeSortOrder
    public var addedAt: Date
    public var lastRefreshedAt: Date?
    public var lastRefreshFailed: Bool
    public var etag: String?
    public var lastModified: String?

    public var id: String { Self.identifier(for: feedURL) }

    public var displayTitle: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        return title.isEmpty ? feedURL.absoluteString : title
    }

    public init(feedURL: URL,
                title: String = "",
                customTitle: String? = nil,
                author: String? = nil,
                summary: String? = nil,
                imageURL: URL? = nil,
                websiteURL: URL? = nil,
                language: String? = nil,
                isExplicit: Bool = false,
                fundingURL: URL? = nil,
                isSubscribed: Bool = true,
                autoDownload: Bool = false,
                sortOrder: EpisodeSortOrder = .newestFirst,
                addedAt: Date = Date(),
                lastRefreshedAt: Date? = nil,
                lastRefreshFailed: Bool = false,
                etag: String? = nil,
                lastModified: String? = nil) {
        self.feedURL = feedURL
        self.title = title
        self.customTitle = customTitle
        self.author = author
        self.summary = summary
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.language = language
        self.isExplicit = isExplicit
        self.fundingURL = fundingURL
        self.isSubscribed = isSubscribed
        self.autoDownload = autoDownload
        self.sortOrder = sortOrder
        self.addedAt = addedAt
        self.lastRefreshedAt = lastRefreshedAt
        self.lastRefreshFailed = lastRefreshFailed
        self.etag = etag
        self.lastModified = lastModified
    }

    public static func identifier(for feedURL: URL) -> String {
        feedURL.absoluteString.lowercased()
    }
}

public struct Media: Codable, Hashable, Sendable {
    public var url: URL
    public var mimeType: String?
    public var byteLength: Int64?
    public var duration: TimeInterval?

    public init(url: URL, mimeType: String? = nil, byteLength: Int64? = nil, duration: TimeInterval? = nil) {
        self.url = url
        self.mimeType = mimeType
        self.byteLength = byteLength
        self.duration = duration
    }

    public var fileExtension: String {
        if let ext = url.pathExtension.isEmpty ? nil : url.pathExtension {
            return ext.lowercased()
        }
        switch mimeType?.lowercased() {
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/aac", "audio/mp4", "audio/x-m4a": return "m4a"
        case "audio/ogg", "application/ogg": return "ogg"
        case "audio/opus": return "opus"
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/wav", "audio/x-wav": return "wav"
        default: return "mp3"
        }
    }
}

public struct Episode: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var podcastID: String
    public var title: String
    public var summary: String?
    public var contentHTML: String?
    public var link: URL?
    public var publishedAt: Date?
    public var guid: String?
    public var media: Media?
    public var imageURL: URL?
    public var chaptersURL: URL?
    public var transcriptURL: URL?
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var isExplicit: Bool
    public var isPlayed: Bool
    public var isFavorite: Bool
    public var playbackPosition: TimeInterval
    public var addedAt: Date

    public init(id: String,
                podcastID: String,
                title: String,
                summary: String? = nil,
                contentHTML: String? = nil,
                link: URL? = nil,
                publishedAt: Date? = nil,
                guid: String? = nil,
                media: Media? = nil,
                imageURL: URL? = nil,
                chaptersURL: URL? = nil,
                transcriptURL: URL? = nil,
                seasonNumber: Int? = nil,
                episodeNumber: Int? = nil,
                isExplicit: Bool = false,
                isPlayed: Bool = false,
                isFavorite: Bool = false,
                playbackPosition: TimeInterval = 0,
                addedAt: Date = Date()) {
        self.id = id
        self.podcastID = podcastID
        self.title = title
        self.summary = summary
        self.contentHTML = contentHTML
        self.link = link
        self.publishedAt = publishedAt
        self.guid = guid
        self.media = media
        self.imageURL = imageURL
        self.chaptersURL = chaptersURL
        self.transcriptURL = transcriptURL
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.isExplicit = isExplicit
        self.isPlayed = isPlayed
        self.isFavorite = isFavorite
        self.playbackPosition = playbackPosition
        self.addedAt = addedAt
    }

    public var displayTitle: String {
        title.isEmpty ? "Untitled episode" : title
    }

    public var duration: TimeInterval? {
        media?.duration
    }

    public var isInProgress: Bool {
        playbackPosition > 5 && !isPlayed
    }

    public var remainingTime: TimeInterval? {
        guard let duration, duration > 0 else { return nil }
        return max(0, duration - playbackPosition)
    }

    public var hasMedia: Bool {
        media != nil
    }
}

public struct Chapter: Codable, Identifiable, Hashable, Sendable {
    public var title: String?
    public var startTime: TimeInterval
    public var imageURL: URL?
    public var linkURL: URL?

    public var id: String {
        "\(Int(startTime))-\(title ?? "")"
    }

    public init(title: String? = nil, startTime: TimeInterval, imageURL: URL? = nil, linkURL: URL? = nil) {
        self.title = title
        self.startTime = startTime
        self.imageURL = imageURL
        self.linkURL = linkURL
    }
}

public struct ParsedFeed: Sendable {
    public var podcast: Podcast
    public var episodes: [Episode]

    public init(podcast: Podcast, episodes: [Episode]) {
        self.podcast = podcast
        self.episodes = episodes
    }
}

public struct PodcastSearchResult: Codable, Identifiable, Hashable, Sendable {
    public var feedURL: URL
    public var title: String
    public var author: String?
    public var artworkURL: URL?
    public var genre: String?
    public var episodeCount: Int?

    public var id: String { feedURL.absoluteString }

    public init(feedURL: URL, title: String, author: String? = nil,
                artworkURL: URL? = nil, genre: String? = nil, episodeCount: Int? = nil) {
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.genre = genre
        self.episodeCount = episodeCount
    }
}

public struct FeedUpdateSummary: Equatable, Sendable {
    public var podcastsRefreshed: Int = 0
    public var podcastsFailed: Int = 0
    public var newEpisodes: Int = 0

    public init() {}
}
