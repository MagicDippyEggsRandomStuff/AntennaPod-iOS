import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPClient: AnyObject, Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public enum NetworkError: Error, LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case notAFeed
    case responseTooLarge
    case emptyResponse
    case notModified

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an invalid response."
        case .httpStatus(let code): return "The server returned HTTP \(code)."
        case .notAFeed: return "This URL points to a web page, not a podcast feed."
        case .responseTooLarge: return "The feed is too large to download."
        case .emptyResponse: return "The server returned an empty response."
        case .notModified: return "The feed has not changed."
        }
    }
}

public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let userAgent: String

    public static let defaultUserAgent =
        "AntennaPod/1.0 (iOS; +https://antennapod.org)"

    public init(session: URLSession = .shared, userAgent: String = URLSessionHTTPClient.defaultUserAgent) {
        self.session = session
        self.userAgent = userAgent
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5",
                             forHTTPHeaderField: "Accept")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw NetworkError.emptyResponse
        }
        return (data, http)
    }
}

public struct FeedLoadResult: Sendable {
    public var feed: ParsedFeed
    public var etag: String?
    public var lastModified: String?

    public init(feed: ParsedFeed, etag: String? = nil, lastModified: String? = nil) {
        self.feed = feed
        self.etag = etag
        self.lastModified = lastModified
    }
}

public struct FeedLoader: Sendable {
    private let client: HTTPClient
    private let maximumSize: Int

    public init(client: HTTPClient = URLSessionHTTPClient(), maximumSize: Int = 32 * 1024 * 1024) {
        self.client = client
        self.maximumSize = maximumSize
    }

    public func load(url: URL, etag: String? = nil, lastModified: String? = nil) async throws -> FeedLoadResult {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(URLSessionHTTPClient.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch NetworkError.httpStatus(304) {
            throw NetworkError.notModified
        }
        guard data.count <= maximumSize else {
            throw NetworkError.responseTooLarge
        }
        guard (200..<300).contains(response.statusCode) else {
            throw response.statusCode == 304 ? NetworkError.notModified : NetworkError.httpStatus(response.statusCode)
        }
        guard !looksLikeHTML(data) else {
            throw NetworkError.notAFeed
        }

        do {
            let feed = try FeedParser.parse(data: data, feedURL: url)
            return FeedLoadResult(
                feed: feed,
                etag: response.value(forHTTPHeaderField: "ETag"),
                lastModified: response.value(forHTTPHeaderField: "Last-Modified")
            )
        } catch {
            throw NetworkError.notAFeed
        }
    }

    private func looksLikeHTML(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(512), encoding: .utf8)?.lowercased() else {
            return false
        }
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<!doctype html") || trimmed.hasPrefix("<html")
    }
}
