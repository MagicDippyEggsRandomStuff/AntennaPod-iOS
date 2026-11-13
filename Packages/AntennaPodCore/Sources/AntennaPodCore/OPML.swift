import Foundation

public struct OPMLDocument {
    public var title: String
    public var feeds: [OPMLFeed]

    public init(title: String = "AntennaPod Subscriptions", feeds: [OPMLFeed]) {
        self.title = title
        self.feeds = feeds
    }
}

public struct OPMLFeed: Equatable, Sendable {
    public var title: String?
    public var feedURL: URL
    public var htmlURL: URL?

    public init(title: String? = nil, feedURL: URL, htmlURL: URL? = nil) {
        self.title = title
        self.feedURL = feedURL
        self.htmlURL = htmlURL
    }
}

public enum OPML {
    public static func parse(data: Data) throws -> [OPMLFeed] {
        let root = try XMLTree.parse(data: data)
        guard root.localName.lowercased() == "opml" else {
            throw FeedParseError.unsupportedFormat
        }
        let body = root.firstChild(named: "body") ?? root
        var feeds: [OPMLFeed] = []
        collect(outlines: body.children(named: "outline"), into: &feeds)
        return feeds
    }

    private static func collect(outlines: [XMLNode], into feeds: inout [OPMLFeed]) {
        for outline in outlines {
            if let rawURL = outline.attribute("xmlUrl", "xmlurl"), let url = makeURL(rawURL) {
                let title = outline.attribute("text", "title")
                let htmlURL = outline.attribute("htmlUrl", "htmlurl").flatMap(makeURL)
                feeds.append(OPMLFeed(title: title, feedURL: url, htmlURL: htmlURL))
            }
            collect(outlines: outline.children(named: "outline"), into: &feeds)
        }
    }

    public static func write(_ document: OPMLDocument) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head>
            <title>\(escape(document.title))</title>
          </head>
          <body>

        """
        for feed in document.feeds {
            var attributes = """
                  <outline type="rss" text="\(escape(feed.title ?? feed.feedURL.absoluteString))" xmlUrl="\(escape(feed.feedURL.absoluteString))"
            """
            if let htmlURL = feed.htmlURL {
                attributes += " htmlUrl=\"\(escape(htmlURL.absoluteString))\""
            }
            attributes += "/>\n"
            xml += attributes
        }
        xml += """
          </body>
        </opml>

        """
        return xml
    }

    private static func makeURL(_ value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("feed://") {
            trimmed = "https://" + trimmed.dropFirst("feed://".count)
        }
        return URL(string: trimmed)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
