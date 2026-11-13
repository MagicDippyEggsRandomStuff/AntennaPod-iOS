import XCTest
@testable import AntennaPodCore

final class FeedParserTests: XCTestCase {
    private let rssFeed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
         xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
         xmlns:content="http://purl.org/rss/1.0/modules/content/"
         xmlns:podcast="https://podcastindex.org/namespace/1.0">
      <channel>
        <title>Test Podcast</title>
        <link>https://example.com</link>
        <description>A &lt;b&gt;great&lt;/b&gt; show</description>
        <language>en-us</language>
        <itunes:author>Jane Doe</itunes:author>
        <itunes:image href="https://example.com/cover.jpg"/>
        <itunes:explicit>yes</itunes:explicit>
        <podcast:funding url="https://example.com/fund">Support us</podcast:funding>
        <item>
          <title>Episode One</title>
          <description>First description</description>
          <content:encoded><![CDATA[<p>Full <strong>HTML</strong> notes</p>]]></content:encoded>
          <link>https://example.com/1</link>
          <guid isPermaLink="false">episode-1</guid>
          <pubDate>Tue, 02 Jan 2024 10:00:00 +0000</pubDate>
          <itunes:duration>01:02:03</itunes:duration>
          <itunes:episode>1</itunes:episode>
          <itunes:season>2</itunes:season>
          <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="123456"/>
          <podcast:chapters url="https://example.com/ep1-chapters.json" type="application/json+chapters"/>
        </item>
        <item>
          <title>Episode Two</title>
          <guid>episode-2</guid>
          <pubDate>Wed, 03 Jan 2024 10:00:00 GMT</pubDate>
          <itunes:duration>45:30</itunes:duration>
          <enclosure url="https://example.com/ep2.m4a" type="audio/x-m4a" length="999"/>
        </item>
      </channel>
    </rss>
    """

    func testParsesRSSChannel() throws {
        let feed = try FeedParser.parse(data: Data(rssFeed.utf8), feedURL: URL(string: "https://example.com/feed.xml")!)

        XCTAssertEqual(feed.podcast.title, "Test Podcast")
        XCTAssertEqual(feed.podcast.author, "Jane Doe")
        XCTAssertEqual(feed.podcast.language, "en-us")
        XCTAssertEqual(feed.podcast.summary, "A great show")
        XCTAssertEqual(feed.podcast.imageURL?.absoluteString, "https://example.com/cover.jpg")
        XCTAssertTrue(feed.podcast.isExplicit)
        XCTAssertEqual(feed.podcast.fundingURL?.absoluteString, "https://example.com/fund")
        XCTAssertEqual(feed.podcast.websiteURL?.absoluteString, "https://example.com")
    }

    func testParsesRSSEpisodes() throws {
        let feed = try FeedParser.parse(data: Data(rssFeed.utf8), feedURL: URL(string: "https://example.com/feed.xml")!)

        XCTAssertEqual(feed.episodes.count, 2)
        let first = feed.episodes[0]
        XCTAssertEqual(first.title, "Episode One")
        XCTAssertEqual(first.guid, "episode-1")
        XCTAssertEqual(first.media?.url.absoluteString, "https://example.com/ep1.mp3")
        XCTAssertEqual(first.media?.mimeType, "audio/mpeg")
        XCTAssertEqual(first.media?.byteLength, 123456)
        XCTAssertEqual(first.media?.duration, 3723)
        XCTAssertEqual(first.episodeNumber, 1)
        XCTAssertEqual(first.seasonNumber, 2)
        XCTAssertEqual(first.chaptersURL?.absoluteString, "https://example.com/ep1-chapters.json")
        XCTAssertEqual(first.contentHTML, "<p>Full <strong>HTML</strong> notes</p>")
        XCTAssertNotNil(first.publishedAt)

        let second = feed.episodes[1]
        XCTAssertEqual(second.media?.duration, 2730)
        XCTAssertEqual(second.media?.fileExtension, "m4a")
    }

    func testEpisodeIdentifiersAreStable() throws {
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let first = try FeedParser.parse(data: Data(rssFeed.utf8), feedURL: feedURL)
        let second = try FeedParser.parse(data: Data(rssFeed.utf8), feedURL: feedURL)
        XCTAssertEqual(first.episodes.map(\.id), second.episodes.map(\.id))
        XCTAssertEqual(Set(first.episodes.map(\.id)).count, 2)
    }

    private let atomFeed = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <title>Atom Podcast</title>
      <subtitle>Atom subtitle</subtitle>
      <author><name>Atom Author</name></author>
      <link rel="alternate" href="https://atomexample.com"/>
      <logo>https://atomexample.com/logo.png</logo>
      <entry>
        <title>Atom Episode</title>
        <id>tag:atomexample.com,2024:1</id>
        <published>2024-02-01T12:00:00Z</published>
        <summary>Atom summary</summary>
        <content type="html">&lt;p&gt;Show notes&lt;/p&gt;</content>
        <link rel="alternate" href="https://atomexample.com/1"/>
        <link rel="enclosure" type="audio/mpeg" length="555" href="https://atomexample.com/1.mp3"/>
        <itunes:duration>10:00</itunes:duration>
      </entry>
    </feed>
    """

    func testParsesAtomFeed() throws {
        let feed = try FeedParser.parse(data: Data(atomFeed.utf8), feedURL: URL(string: "https://atomexample.com/feed")!)

        XCTAssertEqual(feed.podcast.title, "Atom Podcast")
        XCTAssertEqual(feed.podcast.author, "Atom Author")
        XCTAssertEqual(feed.podcast.summary, "Atom subtitle")
        XCTAssertEqual(feed.podcast.imageURL?.absoluteString, "https://atomexample.com/logo.png")
        XCTAssertEqual(feed.episodes.count, 1)
        XCTAssertEqual(feed.episodes[0].media?.url.absoluteString, "https://atomexample.com/1.mp3")
        XCTAssertEqual(feed.episodes[0].media?.duration, 600)
        XCTAssertEqual(feed.episodes[0].guid, "tag:atomexample.com,2024:1")
    }

    func testRejectsNonFeed() {
        XCTAssertThrowsError(try FeedParser.parse(data: Data("<html><body>nope</body></html>".utf8),
                                                  feedURL: URL(string: "https://example.com")!))
    }
}
