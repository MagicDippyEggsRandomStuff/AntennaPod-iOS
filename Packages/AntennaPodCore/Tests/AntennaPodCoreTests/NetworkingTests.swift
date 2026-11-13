import XCTest
@testable import AntennaPodCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var responseData: Data = Data()
    var statusCode: Int = 200
    var headers: [String: String] = [:]
    var lastRequest: URLRequest?
    var error: Error?

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        if let error { throw error }
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode,
                                       httpVersion: nil, headerFields: headers)!
        return (responseData, response)
    }
}

final class FeedLoaderTests: XCTestCase {
    func testLoadsRSSFeed() async throws {
        let client = MockHTTPClient()
        client.responseData = Data("""
        <rss version="2.0"><channel><title>Loaded</title>
        <item><title>E1</title><guid>1</guid><enclosure url="https://example.com/1.mp3" type="audio/mpeg"/></item>
        </channel></rss>
        """.utf8)
        client.headers = ["ETag": "\"abc\""]

        let loader = FeedLoader(client: client)
        let result = try await loader.load(url: URL(string: "https://example.com/feed.xml")!)
        XCTAssertEqual(result.feed.podcast.title, "Loaded")
        XCTAssertEqual(result.feed.episodes.count, 1)
        XCTAssertEqual(result.etag, "\"abc\"")
        XCTAssertNotNil(client.lastRequest?.value(forHTTPHeaderField: "User-Agent"))
    }

    func testSendsConditionalHeaders() async throws {
        let client = MockHTTPClient()
        client.responseData = Data("<rss version=\"2.0\"><channel><title>T</title></channel></rss>".utf8)
        let loader = FeedLoader(client: client)
        _ = try await loader.load(url: URL(string: "https://example.com/feed.xml")!,
                                  etag: "etag-value", lastModified: "date-value")
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "If-None-Match"), "etag-value")
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "If-Modified-Since"), "date-value")
    }

    func testRejectsHTMLPage() async {
        let client = MockHTTPClient()
        client.responseData = Data("<!DOCTYPE html><html><body>Hi</body></html>".utf8)
        let loader = FeedLoader(client: client)
        do {
            _ = try await loader.load(url: URL(string: "https://example.com/")!)
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? NetworkError, .notAFeed)
        }
    }

    func testRejectsHTTPError() async {
        let client = MockHTTPClient()
        client.statusCode = 404
        client.responseData = Data("missing".utf8)
        let loader = FeedLoader(client: client)
        do {
            _ = try await loader.load(url: URL(string: "https://example.com/feed.xml")!)
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? NetworkError, .httpStatus(404))
        }
    }

    func testNotModifiedResponse() async {
        let client = MockHTTPClient()
        client.statusCode = 304
        client.responseData = Data()
        let loader = FeedLoader(client: client)
        do {
            _ = try await loader.load(url: URL(string: "https://example.com/feed.xml")!,
                                  etag: "abc")
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? NetworkError, .notModified)
        }
    }
}

final class PodcastSearchClientTests: XCTestCase {
    func testDecodesITunesResults() async throws {
        let client = MockHTTPClient()
        client.responseData = Data("""
        {"resultCount":1,"results":[{
          "collectionName":"Search Result",
          "artistName":"Some Author",
          "feedUrl":"https://example.com/feed.xml",
          "artworkUrl600":"https://example.com/art.jpg",
          "primaryGenreName":"Technology",
          "trackCount":100
        }]}
        """.utf8)

        let search = PodcastSearchClient(client: client)
        let results = try await search.search(term: "swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Search Result")
        XCTAssertEqual(results[0].author, "Some Author")
        XCTAssertEqual(results[0].feedURL.absoluteString, "https://example.com/feed.xml")
        XCTAssertEqual(results[0].episodeCount, 100)
        XCTAssertNotNil(client.lastRequest?.url?.query?.contains("term=swift"))
    }
}

final class DownloadPathsTests: XCTestCase {
    func testStableFileName() {
        let episode = Episode(id: "podcast#episode", podcastID: "podcast", title: "E",
                              media: Media(url: URL(string: "https://example.com/audio.mp3")!))
        let first = DownloadPaths.fileName(for: episode)
        let second = DownloadPaths.fileName(for: episode)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasSuffix(".mp3"))
    }

    func testDifferentEpisodesDifferentNames() {
        let a = Episode(id: "a", podcastID: "p", title: "A", media: Media(url: URL(string: "https://e.com/a.mp3")!))
        let b = Episode(id: "b", podcastID: "p", title: "B", media: Media(url: URL(string: "https://e.com/b.m4a")!))
        XCTAssertNotEqual(DownloadPaths.fileName(for: a), DownloadPaths.fileName(for: b))
        XCTAssertTrue(DownloadPaths.fileName(for: b).hasSuffix(".m4a"))
    }
}
