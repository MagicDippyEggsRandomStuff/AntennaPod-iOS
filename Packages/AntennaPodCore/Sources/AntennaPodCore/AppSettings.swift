import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var playbackSpeed: Double
    public var skipForwardSeconds: Int
    public var skipBackwardSeconds: Int
    public var continuousPlayback: Bool
    public var autoDownloadNewEpisodes: Bool
    public var autoDownloadLimitPerPodcast: Int
    public var autoDeletePlayed: Bool
    public var refreshIntervalHours: Int
    public var lastRefreshAt: Date?
    public var theme: AppTheme
    public var episodeSortOrder: EpisodeSortOrder
    public var streamOnlyOnWiFi: Bool
    public var gpodderServer: String?
    public var gpodderUsername: String?

    public static let speedOptions: [Double] = [0.5, 0.75, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    public init(playbackSpeed: Double = 1.0,
                skipForwardSeconds: Int = 30,
                skipBackwardSeconds: Int = 10,
                continuousPlayback: Bool = true,
                autoDownloadNewEpisodes: Bool = false,
                autoDownloadLimitPerPodcast: Int = 3,
                autoDeletePlayed: Bool = true,
                refreshIntervalHours: Int = 6,
                lastRefreshAt: Date? = nil,
                theme: AppTheme = .system,
                episodeSortOrder: EpisodeSortOrder = .newestFirst,
                streamOnlyOnWiFi: Bool = false,
                gpodderServer: String? = nil,
                gpodderUsername: String? = nil) {
        self.playbackSpeed = playbackSpeed
        self.skipForwardSeconds = skipForwardSeconds
        self.skipBackwardSeconds = skipBackwardSeconds
        self.continuousPlayback = continuousPlayback
        self.autoDownloadNewEpisodes = autoDownloadNewEpisodes
        self.autoDownloadLimitPerPodcast = autoDownloadLimitPerPodcast
        self.autoDeletePlayed = autoDeletePlayed
        self.refreshIntervalHours = refreshIntervalHours
        self.lastRefreshAt = lastRefreshAt
        self.theme = theme
        self.episodeSortOrder = episodeSortOrder
        self.streamOnlyOnWiFi = streamOnlyOnWiFi
        self.gpodderServer = gpodderServer
        self.gpodderUsername = gpodderUsername
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        playbackSpeed = try container.decodeIfPresent(Double.self, forKey: .playbackSpeed) ?? defaults.playbackSpeed
        skipForwardSeconds = try container.decodeIfPresent(Int.self, forKey: .skipForwardSeconds) ?? defaults.skipForwardSeconds
        skipBackwardSeconds = try container.decodeIfPresent(Int.self, forKey: .skipBackwardSeconds) ?? defaults.skipBackwardSeconds
        continuousPlayback = try container.decodeIfPresent(Bool.self, forKey: .continuousPlayback) ?? defaults.continuousPlayback
        autoDownloadNewEpisodes = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadNewEpisodes) ?? defaults.autoDownloadNewEpisodes
        autoDownloadLimitPerPodcast = try container.decodeIfPresent(Int.self, forKey: .autoDownloadLimitPerPodcast) ?? defaults.autoDownloadLimitPerPodcast
        autoDeletePlayed = try container.decodeIfPresent(Bool.self, forKey: .autoDeletePlayed) ?? defaults.autoDeletePlayed
        refreshIntervalHours = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalHours) ?? defaults.refreshIntervalHours
        lastRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastRefreshAt)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? defaults.theme
        episodeSortOrder = try container.decodeIfPresent(EpisodeSortOrder.self, forKey: .episodeSortOrder) ?? defaults.episodeSortOrder
        streamOnlyOnWiFi = try container.decodeIfPresent(Bool.self, forKey: .streamOnlyOnWiFi) ?? defaults.streamOnlyOnWiFi
        gpodderServer = try container.decodeIfPresent(String.self, forKey: .gpodderServer)
        gpodderUsername = try container.decodeIfPresent(String.self, forKey: .gpodderUsername)
    }

    public var skipForwardLabel: String { DurationParser.formatted(TimeInterval(skipForwardSeconds)) }
    public var skipBackwardLabel: String { DurationParser.formatted(TimeInterval(skipBackwardSeconds)) }
}
