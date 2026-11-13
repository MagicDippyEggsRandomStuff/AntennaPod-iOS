import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct PodcastSearchClient: Sendable {
    private let client: HTTPClient
    private let countryCode: String

    public init(client: HTTPClient = URLSessionHTTPClient(), countryCode: String? = nil) {
        self.client = client
        self.countryCode = countryCode ?? PodcastSearchClient.defaultCountryCode
    }

    static var defaultCountryCode: String {
        let region = Locale.current.identifier.split(separator: "_").last.map(String.init)
        return region?.isEmpty == false ? region! : "US"
    }

    public func search(term: String, limit: Int = 25) async throws -> [PodcastSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await request(parameters: [
            "term": trimmed,
            "media": "podcast",
            "entity": "podcast",
            "limit": String(limit)
        ])
    }

    public func topPodcasts(limit: Int = 25) async throws -> [PodcastSearchResult] {
        try await request(parameters: [
            "term": "podcast",
            "media": "podcast",
            "entity": "podcast",
            "limit": String(limit)
        ])
    }

    private func request(parameters: [String: String]) async throws -> [PodcastSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        var items = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "country", value: countryCode))
        components.queryItems = items

        guard let url = components.url else { throw NetworkError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, _) = try await client.data(for: request)
        let response = try JSONDecoder().decode(ITunesResponse.self, from: data)
        return response.results.compactMap { item in
            guard let feed = item.feedUrl.flatMap(URL.init(string:)) else { return nil }
            let title = item.collectionName ?? item.trackName ?? "Untitled podcast"
            return PodcastSearchResult(
                feedURL: feed,
                title: title,
                author: item.artistName,
                artworkURL: item.artworkUrl600.flatMap(URL.init(string:))
                    ?? item.artworkUrl100.flatMap(URL.init(string:)),
                genre: item.primaryGenreName,
                episodeCount: item.trackCount
            )
        }
    }
}

private struct ITunesResponse: Decodable {
    var results: [ITunesPodcast]
}

private struct ITunesPodcast: Decodable {
    var collectionName: String?
    var trackName: String?
    var artistName: String?
    var feedUrl: String?
    var artworkUrl600: String?
    var artworkUrl100: String?
    var primaryGenreName: String?
    var trackCount: Int?
}
