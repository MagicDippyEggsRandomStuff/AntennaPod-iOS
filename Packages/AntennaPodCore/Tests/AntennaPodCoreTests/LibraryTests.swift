import XCTest
@testable import AntennaPodCore

final class LibraryTests: XCTestCase {
    private func makeFeed(url: String = "https://example.com/feed.xml",
                          episodeGUIDs: [String],
                          published: Date? = Date(timeIntervalSince1970: 1_700_000_000)) -> ParsedFeed {
        let feedURL = URL(string: url)!
        let podcast = Podcast(feedURL: feedURL, title: "Podcast", isSubscribed: true)
        let episodes = episodeGUIDs.enumerated().map { index, guid in
            Episode(id: "\(podcast.id)#\(guid)",
                    podcastID: podcast.id,
                    title: "Episode \(guid)",
                    publishedAt: published?.addingTimeInterval(TimeInterval(index)),
                    guid: guid,
                    media: Media(url: URL(string: "https://example.com/\(guid).mp3")!, duration: 600))
        }
        return ParsedFeed(podcast: podcast, episodes: episodes)
    }

    func testSubscribeAndMerge() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b"])
        let added = library.merge(feed: feed)

        XCTAssertEqual(added, 2)
        XCTAssertEqual(library.subscribedPodcasts.count, 1)
        XCTAssertEqual(library.episodes.count, 2)
    }

    func testMergeIsIdempotentAndPreservesState() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b"])
        library.merge(feed: feed)
        let episodeID = feed.episodes[0].id
        library.setPlayed(episodeID, played: true)
        library.setFavorite(episodeID, favorite: true)
        library.updatePlaybackPosition(episodeID, position: 120)

        let addedAgain = library.merge(feed: makeFeed(episodeGUIDs: ["a", "b"]))
        XCTAssertEqual(addedAgain, 0)
        XCTAssertEqual(library.episodes.count, 2)
        XCTAssertTrue(library.episode(id: episodeID)?.isPlayed ?? false)
        XCTAssertTrue(library.episode(id: episodeID)?.isFavorite ?? false)
        XCTAssertEqual(library.episode(id: episodeID)?.playbackPosition, 120)
    }

    func testMergeAddsNewEpisodesAndKeepsOld() {
        var library = Library()
        library.merge(feed: makeFeed(episodeGUIDs: ["a"]))
        let added = library.merge(feed: makeFeed(episodeGUIDs: ["b", "c"]))
        XCTAssertEqual(added, 2)
        XCTAssertEqual(library.episodes.count, 3)
    }

    func testUnsubscribeHidesPodcastAndClearsQueue() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a"])
        library.merge(feed: feed)
        library.enqueue(feed.episodes[0].id)
        library.unsubscribe(podcastID: feed.podcast.id)

        XCTAssertEqual(library.subscribedPodcasts.count, 0)
        XCTAssertTrue(library.queue.isEmpty)
        XCTAssertNotNil(library.episode(id: feed.episodes[0].id), "episode history should be kept")
    }

    func testQueueOperations() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b", "c"])
        library.merge(feed: feed)
        let ids = feed.episodes.map(\.id)

        library.enqueue(ids[0])
        library.enqueue(ids[1])
        library.enqueue(ids[2], next: true)
        XCTAssertEqual(library.queue, [ids[2], ids[0], ids[1]])

        library.moveQueue(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(library.queue, [ids[0], ids[1], ids[2]])

        library.dequeue(ids[1])
        XCTAssertEqual(library.queue, [ids[0], ids[2]])
        XCTAssertEqual(library.queueEpisodes.map(\.id), [ids[0], ids[2]])
    }

    func testNextEpisode() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b", "c"])
        library.merge(feed: feed)
        let ids = feed.episodes.map(\.id)
        XCTAssertEqual(library.nextEpisode(after: ids[1])?.id, ids[0])
    }

    func testInboxContainsOnlyUnplayedSubscribed() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b"])
        library.merge(feed: feed)
        library.setPlayed(feed.episodes[0].id, played: true)
        XCTAssertEqual(library.inbox.count, 1)
        XCTAssertEqual(library.inbox.first?.id, feed.episodes[1].id)
    }

    func testSorting() {
        var library = Library()
        let feed = makeFeed(episodeGUIDs: ["a", "b"])
        library.merge(feed: feed)
        let newest = library.episodes(for: feed.podcast.id, sort: .newestFirst)
        let oldest = library.episodes(for: feed.podcast.id, sort: .oldestFirst)
        XCTAssertEqual(newest.map(\.id), oldest.map(\.id).reversed())
    }

    func testCodableRoundTrip() throws {
        var library = Library()
        library.merge(feed: makeFeed(episodeGUIDs: ["a"]))
        library.settings.playbackSpeed = 1.5
        library.enqueue(library.episodes[0].id)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let encoded = try encoder.encode(library)
        let decoded = try decoder.decode(Library.self, from: encoded)
        let reencoded = try encoder.encode(decoded)
        XCTAssertEqual(encoded, reencoded, "encoding a decoded library must be stable")
        XCTAssertEqual(decoded.podcasts.map(\.id), library.podcasts.map(\.id))
        XCTAssertEqual(decoded.episodes.map(\.id), library.episodes.map(\.id))
        XCTAssertEqual(decoded.queue, library.queue)
        XCTAssertEqual(decoded.settings, library.settings)
    }
}

final class LibraryStoreTests: XCTestCase {
    func testSaveAndLoad() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("antennapod-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LibraryStore(directory: directory)
        var library = Library()
        let feedURL = URL(string: "https://example.com/feed.xml")!
        library.subscribe(to: feedURL)
        library.settings.playbackSpeed = 1.25

        store.saveAndWait(library)
        let loaded = store.load()
        XCTAssertEqual(loaded.settings.playbackSpeed, 1.25)
        XCTAssertEqual(loaded.podcasts.count, 1)
    }

    func testMissingFileReturnsEmptyLibrary() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("antennapod-tests-\(UUID().uuidString)")
        let store = LibraryStore(directory: directory)
        XCTAssertTrue(store.load().podcasts.isEmpty)
    }
}

final class OPMLLTests: XCTestCase {
    func testParseOPML() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Subscriptions</title></head>
          <body>
            <outline text="Tech">
              <outline type="rss" text="Podcast One" xmlUrl="https://example.com/one.xml" htmlUrl="https://example.com/one"/>
            </outline>
            <outline type="rss" text="Podcast Two" xmlUrl="https://example.com/two.xml"/>
          </body>
        </opml>
        """
        let feeds = try OPML.parse(data: Data(xml.utf8))
        XCTAssertEqual(feeds.count, 2)
        XCTAssertEqual(feeds[0].title, "Podcast One")
        XCTAssertEqual(feeds[0].feedURL.absoluteString, "https://example.com/one.xml")
        XCTAssertEqual(feeds[1].feedURL.absoluteString, "https://example.com/two.xml")
    }

    func testOPMLRoundTrip() throws {
        let document = OPMLDocument(feeds: [
            OPMLFeed(title: "A & B", feedURL: URL(string: "https://example.com/a.xml")!),
            OPMLFeed(title: "C", feedURL: URL(string: "https://example.com/c.xml")!)
        ])
        let xml = OPML.write(document)
        let parsed = try OPML.parse(data: Data(xml.utf8))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].title, "A & B")
    }

    func testRejectsNonOPML() {
        XCTAssertThrowsError(try OPML.parse(data: Data("<rss></rss>".utf8)))
    }
}
