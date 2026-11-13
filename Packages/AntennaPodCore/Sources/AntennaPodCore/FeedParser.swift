import Foundation

public enum FeedParseError: Error, LocalizedError, Equatable {
    case unsupportedFormat
    case missingChannel
    case noTitle

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "This URL does not point to an RSS or Atom feed."
        case .missingChannel: return "The feed is missing a channel element."
        case .noTitle: return "The feed has no title."
        }
    }
}

public enum FeedParser {
    public static func parse(data: Data, feedURL: URL) throws -> ParsedFeed {
        let root: XMLNode
        do {
            root = try XMLTree.parse(data: data)
        } catch {
            throw FeedParseError.unsupportedFormat
        }

        switch root.localName.lowercased() {
        case "rss":
            return try parseRSS(root: root, feedURL: feedURL)
        case "feed":
            return try parseAtom(root: root, feedURL: feedURL)
        case "rdf":
            return try parseRDF(root: root, feedURL: feedURL)
        default:
            throw FeedParseError.unsupportedFormat
        }
    }

    private static func parseRSS(root: XMLNode, feedURL: URL) throws -> ParsedFeed {
        guard let channel = root.firstChild(named: "channel") else {
            throw FeedParseError.missingChannel
        }

        var podcast = Podcast(feedURL: feedURL)
        podcast.title = channel.childText("title") ?? feedURL.host ?? "Untitled podcast"
        podcast.summary = HTMLText.plainText(from: channel.childText("description"))
        podcast.language = channel.childText("language")
        podcast.websiteURL = url(from: channel.childText("link"))
        podcast.author = channel.childText("itunes:author")
            ?? channel.childText("managingEditor")
            ?? channel.childText("dc:creator")
        podcast.isExplicit = isExplicit(channel.childText("itunes:explicit"))
        podcast.imageURL = imageURL(from: channel)
        podcast.fundingURL = fundingURL(from: channel)

        var items = channel.children(named: "item")
        if items.isEmpty {
            items = root.children(named: "item")
        }

        let episodes = items.compactMap { episode(fromRSSItem: $0, podcast: podcast) }
        return ParsedFeed(podcast: podcast, episodes: episodes)
    }

    private static func parseRDF(root: XMLNode, feedURL: URL) throws -> ParsedFeed {
        let channel = root.firstChild(named: "channel") ?? root
        var podcast = Podcast(feedURL: feedURL)
        podcast.title = channel.childText("title") ?? feedURL.host ?? "Untitled podcast"
        podcast.summary = HTMLText.plainText(from: channel.childText("description"))
        podcast.language = channel.childText("dc:language") ?? channel.childText("language")
        podcast.websiteURL = url(from: channel.childText("link"))
        podcast.author = channel.childText("dc:creator")
            ?? channel.childText("itunes:author")
        podcast.isExplicit = isExplicit(channel.childText("itunes:explicit"))
        podcast.imageURL = imageURL(from: channel)

        let episodes = root.children(named: "item").compactMap { episode(fromRSSItem: $0, podcast: podcast) }
        return ParsedFeed(podcast: podcast, episodes: episodes)
    }

    private static func parseAtom(root: XMLNode, feedURL: URL) throws -> ParsedFeed {
        var podcast = Podcast(feedURL: feedURL)
        podcast.title = root.childText("title") ?? feedURL.host ?? "Untitled podcast"
        podcast.summary = HTMLText.plainText(from: root.childText("subtitle"))
            ?? HTMLText.plainText(from: root.childText("itunes:summary"))
        podcast.language = root.attributeValue("xml:lang") ?? root.childText("language")
        podcast.author = root.firstChild(named: "author")?.childText("name")
            ?? root.childText("itunes:author")
        podcast.websiteURL = atomLink(in: root, rel: "alternate")
        podcast.imageURL = imageURL(from: root) ?? url(from: root.childText("logo")) ?? url(from: root.childText("icon"))
        podcast.isExplicit = isExplicit(root.childText("itunes:explicit"))
        podcast.fundingURL = fundingURL(from: root)

        let entries = root.children(named: "entry")
        let episodes = entries.compactMap { episode(fromAtomEntry: $0, podcast: podcast) }
        return ParsedFeed(podcast: podcast, episodes: episodes)
    }

    private static func episode(fromRSSItem item: XMLNode, podcast: Podcast) -> Episode? {
        let title = item.childText("title") ?? "Untitled episode"
        let description = item.childText("description")
        let content = item.childText("content:encoded")
            ?? item.childText("content")
        let summary = HTMLText.plainText(from: item.childText("itunes:summary") ?? description)

        let enclosureNode = item.firstChild(named: "enclosure")
            ?? item.firstChild(named: "media:content")
            ?? item.descendants(withName: "enclosure").first
        let media = mediaInfo(from: enclosureNode, item: item)

        let guid = item.childText("guid") ?? item.childText("id")
        let link = url(from: item.childText("link")) ?? atomLink(in: item, rel: "alternate")
        let published = FeedDate.parse(item.childText("pubDate"))
            ?? FeedDate.parse(item.childText("dc:date"))
            ?? FeedDate.parse(item.childText("published"))
            ?? FeedDate.parse(item.childText("updated"))

        let duration = DurationParser.seconds(from: item.childText("itunes:duration"))
            ?? media?.duration

        var episodeMedia = media
        if var mediaValue = episodeMedia {
            if mediaValue.duration == nil { mediaValue.duration = duration }
            episodeMedia = mediaValue
        }

        let identifier = episodeIdentifier(podcast: podcast, guid: guid, enclosure: episodeMedia?.url, link: link, title: title)
        let image = item.firstChild(named: "itunes:image")?.attribute("href")
            ?? item.firstChild(named: "media:thumbnail")?.attribute("url")
            ?? item.firstChild(named: "image")?.attribute("href")

        return Episode(
            id: identifier,
            podcastID: podcast.id,
            title: title,
            summary: summary,
            contentHTML: content ?? description,
            link: link,
            publishedAt: published,
            guid: guid,
            media: episodeMedia,
            imageURL: url(from: image),
            chaptersURL: chaptersURL(from: item),
            transcriptURL: transcriptURL(from: item),
            seasonNumber: intValue(item.childText("itunes:season")),
            episodeNumber: intValue(item.childText("itunes:episode")),
            isExplicit: isExplicit(item.childText("itunes:explicit"))
        )
    }

    private static func episode(fromAtomEntry entry: XMLNode, podcast: Podcast) -> Episode? {
        let title = entry.childText("title") ?? "Untitled episode"
        let summaryHTML = entry.childText("summary") ?? entry.childText("content")
        let content = entry.childText("content:encoded") ?? entry.childText("content")

        var media: Media?
        for link in entry.children(named: "link") {
            let rel = link.attribute("rel")?.lowercased()
            let type = link.attribute("type")?.lowercased() ?? ""
            guard let href = link.attribute("href"), let resolved = url(from: href) else { continue }
            if rel == "enclosure" || type.hasPrefix("audio/") || type.hasPrefix("video/") {
                media = Media(
                    url: resolved,
                    mimeType: link.attribute("type"),
                    byteLength: Int64(link.attribute("length") ?? ""),
                    duration: DurationParser.seconds(from: entry.childText("itunes:duration"))
                )
                break
            }
        }

        let guid = entry.childText("id")
        let link = atomLink(in: entry, rel: "alternate")
        let published = FeedDate.parse(entry.childText("published"))
            ?? FeedDate.parse(entry.childText("updated"))

        let identifier = episodeIdentifier(podcast: podcast, guid: guid, enclosure: media?.url, link: link, title: title)
        let image = entry.firstChild(named: "itunes:image")?.attribute("href")

        return Episode(
            id: identifier,
            podcastID: podcast.id,
            title: title,
            summary: HTMLText.plainText(from: entry.childText("itunes:summary") ?? summaryHTML),
            contentHTML: content ?? summaryHTML,
            link: link,
            publishedAt: published,
            guid: guid,
            media: media,
            imageURL: url(from: image),
            chaptersURL: chaptersURL(from: entry),
            transcriptURL: transcriptURL(from: entry),
            seasonNumber: intValue(entry.childText("itunes:season")),
            episodeNumber: intValue(entry.childText("itunes:episode")),
            isExplicit: isExplicit(entry.childText("itunes:explicit"))
        )
    }

    private static func episodeIdentifier(podcast: Podcast, guid: String?, enclosure: URL?, link: URL?, title: String) -> String {
        let stable = guid ?? enclosure?.absoluteString ?? link?.absoluteString ?? title
        return "\(podcast.id)#\(stable)"
    }

    private static func mediaInfo(from node: XMLNode?, item: XMLNode) -> Media? {
        if let node, let href = node.attribute("url", "href"), let resolved = url(from: href) {
            return Media(
                url: resolved,
                mimeType: node.attribute("type"),
                byteLength: Int64(node.attribute("length", "fileSize") ?? ""),
                duration: DurationParser.seconds(from: node.attribute("duration"))
            )
        }
        if let group = item.firstChild(named: "media:group"),
           let content = group.firstChild(named: "media:content"),
           let href = content.attribute("url"),
           let resolved = url(from: href) {
            return Media(
                url: resolved,
                mimeType: content.attribute("type"),
                byteLength: Int64(content.attribute("fileSize") ?? ""),
                duration: DurationParser.seconds(from: content.attribute("duration"))
            )
        }
        return nil
    }

    private static func imageURL(from node: XMLNode) -> URL? {
        if let itunesImage = node.firstChild(named: "itunes:image"),
           let href = itunesImage.attribute("href") {
            return url(from: href)
        }
        if let image = node.firstChild(named: "image") {
            if let href = image.attribute("href") { return url(from: href) }
            if let text = image.childText("url") { return url(from: text) }
        }
        if let thumbnail = node.firstChild(named: "media:thumbnail") {
            return url(from: thumbnail.attribute("url"))
        }
        return nil
    }

    private static func fundingURL(from node: XMLNode) -> URL? {
        guard let funding = node.firstChild(named: "podcast:funding") else { return nil }
        return url(from: funding.attribute("url"))
    }

    private static func chaptersURL(from node: XMLNode) -> URL? {
        guard let chapters = node.firstChild(named: "podcast:chapters") else { return nil }
        return url(from: chapters.attribute("url"))
    }

    private static func transcriptURL(from node: XMLNode) -> URL? {
        guard let transcript = node.firstChild(named: "podcast:transcript") else { return nil }
        return url(from: transcript.attribute("url"))
    }

    private static func atomLink(in node: XMLNode, rel: String) -> URL? {
        for link in node.children(named: "link") {
            let relValue = link.attribute("rel")?.lowercased() ?? "alternate"
            if relValue == rel, let href = link.attribute("href") {
                return url(from: href)
            }
        }
        return nil
    }

    private static func isExplicit(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "yes" || value == "true" || value == "explicit"
    }

    private static func intValue(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func url(from value: String?) -> URL? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        value = HTMLText.decodeEntities(in: value)
        if value.hasPrefix("//") {
            value = "https:" + value
        }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        if let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        return nil
    }
}

private extension XMLNode {
    func descendants(withName name: String) -> [XMLNode] {
        var result: [XMLNode] = []
        for child in children {
            if child.name.lowercased() == name.lowercased() || child.localName.lowercased() == name.lowercased() {
                result.append(child)
            }
            result.append(contentsOf: child.descendants(withName: name))
        }
        return result
    }
}
